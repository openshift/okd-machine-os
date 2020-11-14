#!/bin/sh
set -exuo pipefail

REPOS=()
STREAM="next-devel"
REF="fedora/x86_64/coreos/${STREAM}"

# additional RPMs to install via os-extensions
EXTENSION_RPMS=(
  attr
  glusterfs
  glusterfs-client-xlators
  glusterfs-fuse
  libgfrpc0
  libgfxdr0
  libglusterfs0
  psmisc
  NetworkManager-ovs
  openvswitch
  dpdk
  gdbm-libs
  libxcrypt-compat
  unbound-libs
  python3-libs
  libdrm
  libmspack
  libpciaccess
  pciutils
  pciutils-libs
  hwdata
  python3-libs
  python3-pip
  python3
  python-unversioned-command
  python-pip-wheel
  python3-setuptools
  python-setuptools-wheel
  open-vm-tools
  xmlsec1
  xmlsec1-openssl
  libxslt
  libtool-ltdl
)
CRIO_RPMS=(
  cri-o
  cri-tools
)
CRIO_VERSION="1.18"
ADDON_RPMS=/tmp/rpms

# fetch binaries and configure working env, prow doesn't allow init containers or a second container
dir=/tmp/ostree
mkdir -p "${dir}"
export PATH=$PATH:/tmp/bin
export HOME=/tmp

# fetch jq binary
mkdir $HOME/bin
curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 2>/dev/null >/tmp/bin/jq
chmod ug+x $HOME/bin/jq

# fetch fcos release info and check whether we've already built this image
build_url="https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds"
curl "${build_url}/builds.json" 2>/dev/null >${dir}/builds.json
build_id="$( <"${dir}/builds.json" jq -r '.builds[0].id' )"
base_url="${build_url}/${build_id}/x86_64"
curl "${base_url}/meta.json" 2>/dev/null >${dir}/meta.json
tar_url="${base_url}/$( <${dir}/meta.json jq -r .images.ostree.path )"
commit_id="$( <${dir}/meta.json jq -r '."ostree-commit"' )"

# fetch existing machine-os-content
mkdir /srv/repo
curl -L "${tar_url}" | tar xf - -C /srv/repo/ --no-same-owner

# use repos from FCOS
rm -rf /etc/yum.repos.d
ostree --repo=/srv/repo checkout "${REF}" --subpath /usr/etc/yum.repos.d --user-mode /etc/yum.repos.d
dnf clean all
ostree --repo=/srv/repo cat "${REF}" /usr/lib/os-release > /tmp/os-release
source /tmp/os-release

# prepare a list of repos to download packages from
REPOLIST="--enablerepo=fedora --enablerepo=updates"
for i in "${!REPOS[@]}"; do
  REPOLIST="${REPOLIST} --repofrompath=repo${i},${REPOS[$i]}"
done

YUMDOWNLOADER="yumdownloader --archlist=x86_64 --archlist=noarch --disablerepo=* --releasever=${VERSION_ID} ${REPOLIST}"

# Install CRI-O / hyperkube / oc RPMs updating RPM DB
mkdir /tmp/working
pushd /tmp/working
  # Extract RPM DB
  mkdir -p usr/lib
  ostree --repo=/srv/repo checkout "${REF}" --subpath /usr/lib/rpm --user-mode $(pwd)/usr/lib/rpm

  # Download crio from modular repo
  sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/fedora-updates-testing-modular.repo
  dnf --installroot=$(pwd) --releasever=${VERSION_ID} module enable -y cri-o:${CRIO_VERSION}
  ${YUMDOWNLOADER} --destdir=/tmp/rpms --enablerepo=updates-testing-modular cri-o cri-tools
  # Install additional RPMs
  rpm -ivh ${ADDON_RPMS}/* --nodeps --dbpath $(pwd)/usr/lib/rpm --prefix $(pwd)
popd

# build extension repo
mkdir /extensions
pushd /extensions
  mkdir okd
  ${YUMDOWNLOADER} --destdir=/extensions/okd ${EXTENSION_RPMS[*]}
  createrepo_c --no-database .
popd

# Overlay additional settings
pushd /tmp/working
  # Fix localtime symlink
  #rm -rf etc/localtime
  #ln -s ../usr/share/zoneinfo/UTC etc/localtime
  # disable systemd-resolved.service. Having it enabled breaks machine-api DNS resolution
  mkdir -p etc/systemd/system/systemd-resolved.service.d
  echo -e "[Unit]\nConditionPathExists=/enoent" > etc/systemd/system/systemd-resolved.service.d/disabled.conf
  mkdir -p etc/NetworkManager/conf.d
  echo -e "[main]\ndns=default" > etc/NetworkManager/conf.d/dns.conf
  rm -rf usr/etc/tmpfiles.d/dns.conf
  mkdir -p etc/systemd/system/coreos-migrate-to-systemd-resolved.service.d
  echo -e "[Unit]\nConditionPathExists=/enoent" > etc/systemd/system/coreos-migrate-to-systemd-resolved.service.d/disabled.conf
popd

# add binaries (MCD) from /srv/addons
mkdir -p /tmp/working/usr/bin
cp -rvf /srv/addons/* /tmp/working/

# move config to /usr/etc so that it would be persisted
mv /tmp/working/etc /tmp/working/usr/

# build new commit
coreos-assembler dev-overlay --repo /srv/repo --rev "${REF}" --add-tree /tmp/working --output-ref "${REF}"

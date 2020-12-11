#!/bin/sh
set -exuo pipefail

REPOS=()
STREAM="next-devel"
REF="fedora/x86_64/coreos/${STREAM}"

# additional RPMs to install via os-extensions
EXTENSION_RPMS=(
  NetworkManager-ovs
  checkpolicy
  dpdk
  gdbm-libs
  glusterfs
  glusterfs-client-xlators
  glusterfs-fuse
  kernel-devel
  kernel-headers
  libdrm
  libgfrpc0
  libgfxdr0
  libglusterfs0
  libmspack
  libpciaccess
  libqb
  libtool-ltdl
  libxcrypt-compat
  libxslt
  open-vm-tools
  openvswitch
  perl-Carp
  perl-Errno
  perl-Exporter
  perl-NDBM_File
  perl-PathTools
  perl-Scalar-List-Utils
  perl-constant
  perl-interpreter
  perl-libs
  perl-macros
  policycoreutils-python-utils
  protobuf
  python-pip-wheel
  python-setuptools-wheel
  python-unversioned-command
  python3
  python3-audit
  python3-libs
  python3-libselinux
  python3-libsemanage
  python3-pip
  python3-policycoreutils
  python3-setools
  python3-setuptools
  qemu-guest-agent
  unbound-libs
  usbguard
  usbguard-selinux
  xmlsec1
  xmlsec1-openssl
)
BOOTSTRAP_RPMS=(
  libdrm
  libmspack
  libpciaccess
  libtool-ltdl
  libxslt
  open-vm-tools
  xmlsec1
  xmlsec1-openssl
)
CRIO_RPMS=(
  cri-o
  cri-tools
)
CRIO_VERSION="1.19"

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

# Remove all refs except ${REF} so that bootstrap pivot would not be confused
ostree --repo=/srv/repo refs | grep -v "${REF}" | xargs -n1 ostree --repo=/srv/repo refs --delete

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

# build extension repo
mkdir /extensions
pushd /extensions
  mkdir okd
  yumdownloader --archlist=x86_64 --archlist=noarch --disablerepo='*' --destdir=/extensions/okd --releasever=${VERSION_ID} ${REPOLIST} ${EXTENSION_RPMS[*]}
  createrepo_c --no-database .
popd

# inject MCD binary and cri-o, hyperkube, and bootstrap RPMs in the ostree commit
mkdir /tmp/working
pushd /tmp/working
  # enable crio
  sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/fedora-updates-testing-modular.repo
  dnf module enable -y cri-o:${CRIO_VERSION}
  yumdownloader --archlist=x86_64 --disablerepo='*' --destdir=/tmp/rpms --enablerepo=updates-testing-modular cri-o cri-tools

  yumdownloader --archlist=x86_64 --archlist=noarch --disablerepo='*' --destdir=/tmp/rpms  --releasever=${VERSION_ID} ${REPOLIST} ${BOOTSTRAP_RPMS[*]}

  for i in $(find /tmp/rpms/ -iname *.rpm); do
    echo "Extracting $i ..."
    rpm2cpio $i | cpio -div
  done

  # append additional configuration
  cp -rvf /srv/overlay/* .

  # move etc configuration to /usr/etc so that it would be merged by rpm-ostree
  mv etc usr/

  # add binaries (MCD) from /srv/addons
  mkdir -p usr/bin usr/libexec
  cp -rvf /srv/addons/* .
popd

# build new commit
coreos-assembler dev-overlay --repo /srv/repo --rev "${REF}" --add-tree /tmp/working --output-ref "${REF}"

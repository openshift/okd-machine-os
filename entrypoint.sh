#!/bin/sh
set -exuo pipefail
export COSA_SKIP_OVERLAY=1

IMAGE="quay.io/vrutkovs/okd-os:${CIRRUS_CHANGE_IN_REPO}"
export REGISTRY_AUTH_FILE="/tmp/auth.json"
echo ${QUAY_PASSWORD} | skopeo login --authfile=${REGISTRY_AUTH_FILE} quay.io --username "vrutkovs+cirrus" --password-stdin

cosa init /src --force

# Copy overrides
mkdir -p ./overrides/rootfs
cp -rvf /overrides/* ./overrides
cp -rvf /src/overlay.d ./overrides/rootfs/

# Create repo for OKD RPMs
pushd /srv/okd-repo
  createrepo_c .
popd

# build ostree commit
cosa fetch
cosa build ostree

# Create repo for OS Extensions
mkdir -p /overlay/extensions
pushd /overlay/extensions
  createrepo_c .
popd

echo "Building container"
cosa upload-oscontainer --name "quay.io/vrutkovs/okd-os" --add-directory /overlay

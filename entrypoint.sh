#!/bin/sh
set -exuo pipefail
export COSA_SKIP_OVERLAY=1

# tmpdir for cosa
tmpsrc=$(mktemp -d)
cp -a /src "${tmpsrc}"/src
cd "$(mktemp -d)"
cosa init https://github.com/coreos/fedora-coreos-config --branch next-devel

# Copy overrides
cp -rvf /overrides/* ./overrides

cosa fetch --update-lockfile
cosa build ostree

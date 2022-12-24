#!/bin/bash
set -eux

# Load common functions
. /usr/local/bin/release-image.sh

# Copy pivot files
cp overlay/etc / -rvf
cp manifests/* /opt/openshift/openshift/ -rvf

# Pivot to new os content
MACHINE_OS_IMAGE=$(image_for fedora-coreos)
# Make sure registries.conf is readable by rpm-ostree
chmod 0644 /etc/containers/registries.conf
rpm-ostree rebase --experimental "ostree-unverified-registry:${MACHINE_OS_IMAGE}"

# Remove mitigations kargs
rpm-ostree kargs --delete mitigations=auto,nosmt
touch /opt/openshift/.pivot-done
systemctl reboot

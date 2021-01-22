#!/bin/bash

# Load common functions
. /usr/local/bin/release-image.sh

# Copy pivot files
cp overlay/etc / -rvf
rm -rf /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
cp overlay/usr/local/bin/* /usr/local/bin/ -rvf
cp manifests/* /opt/openshift/openshift/ -rvf

# Copy machine-config-daemon binary from payload
MACHINE_CONFIG_OPERATOR_IMAGE=$(image_for machine-config-operator)
while ! podman pull --quiet "$MACHINE_CONFIG_OPERATOR_IMAGE"
do
    echo "Pull failed. Retrying $MACHINE_CONFIG_OPERATOR_IMAGE..."
done
mnt=$(podman image mount "${MACHINE_CONFIG_OPERATOR_IMAGE}")
cp ${mnt}/usr/bin/machine-config-daemon /usr/local/bin/machine-config-daemon
chmod +x /usr/local/bin/machine-config-daemon
restorecon /usr/local/bin/machine-config-daemon

# Set image-pullspec for pivot
mkdir --parents /run/pivot /etc/pivot
MACHINE_CONFIG_OSCONTENT=$(image_for machine-os-content)
echo "${MACHINE_CONFIG_OSCONTENT}" > /etc/pivot/image-pullspec
touch /run/pivot/reboot-needed

touch /opt/openshift/.pivot-done
/usr/local/bin/machine-config-daemon pivot

systemctl reboot

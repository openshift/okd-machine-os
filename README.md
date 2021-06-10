# OKD Machine OS

This repository contains the components necessary to build a Fedora CoreOS based OKD node. The process involves creating a container that incorporates the latest developer release of Fedora CoreOS, the OpenShift cluster artifacts, the Machine Controller Daemon, and various container overlays specific to OKD. To better understand the various components, please see the following resources:

* [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/)
* [Machine Config Operator](https://github.com/openshift/machine-config-operator)
* [CoreOS Assembler](https://github.com/coreos/coreos-assembler)
* [cri-o](https://cri-o.io)

## Structure

This repo uses [fedora-coreos-config](https://github.com/coreos/fedora-coreos-config) as a submodule for basic configuration.
Stable OKD versions use `stable` branch, OKD development versions use `testing-devel` for latest packages.

[manifest.yaml](manifest.yaml) is a copy of FCOS manifest with the following changes:
* tweaked version (special OKD version is set to designate the difference between OKD image and FCOS) and custom ostree ref
* On top of FCOS base configuration additional OKD packages are installed:
  * `openshift-hyperkube` - kubelet
  * `crio`, `cri-tools` - container runtime
  * `NetworkManager-ovs` for OpenshiftOVN
  * `open-vm-tools`, `qemu-guest-agent` - cloud tools for vSphere/oVirt
  * `openshift-clients` - RPM with `oc` binary
  * `glusterfs`, `glusterfs-fuse` - required to pass glusterfs tests
* `packages` is updated to avoid including `zincati` (OKD uses CVO/MCO for updates)
* Available repos are disabled in `postprocess` section to make sure updates are reproducible

OKD machine-os inherits `image.yaml` to produce ostree commit and `manifest-lock.*` files to ensure base packages are as close to FCOS as possible.

Overlayed configuration is used in [overlay.d](overlay.d/), symlinking FCOS settings. The repo also has OKD-specific [99okd](overlay.d/99okd) overlay, which does the following:
* [dhclient.conf](overlay.d/99okd/etc/dhclient/dhclient.conf) in order to prevent `br-ex` interface from getting a wrong MAC
* [sshd_config.d](overlay.d/99okd/etc/ssh/sshd_config.d/10-insecure-rsa-keysig.conf) dropin to allow `ssh-rsa` keys to be compatible with OCP.
* [localtime](overlay.d/99okd/etc/localtime) symlinked to UTC (required for fluentd).
* [gcp-hostname](overlay.d/99okd/usr/lib/systemd/system/gcp-hostname.service) service which uses Afterburn to set GCP hostname.

## Build process

`Dockerfile.ci` is creating a new build on [Cirrus CI](cirrus-ci.com/), templating configuration from [.cirrus.yml.j2](.cirrus.yml.j2) via [cirrus-run](https://pypi.org/project/cirrus-run/) tool. This is required to have KVM socket passed in the container build. Cirrus CI builds [Dockerfile.cosa](Dockerfile.cosa), fetches latest promoted kubelet and MCD and runs [entrypoint.sh](entrypoint.sh) in latest CoreOS Assembler image. During the build `upload-oscontainer` subcommand is executed and the new machine-os image is pushed to `quay.io/vrutkovs/okd-os:$CIRRUS_BUILD_ID`.

During the run the build updates [Dockerfile.template](Dockerfile.template) replacing `INITIAL_IMAGE` with a pullspec of the build container. This dockerfile is used to build a final oscontainer image, which includes OKD specific manifests:
* the setting to use community operator collection only
* MachineConfigs which set cgroupsv1 kernel arguments on boot

In order to have them applied during machine-config phase these manifests are placed in `/manifests` and `io.openshift.release.operator=true` label is added.

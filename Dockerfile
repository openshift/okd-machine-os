FROM registry.ci.openshift.org/origin/4.15:artifacts as artifacts

FROM quay.io/fedora/fedora-coreos:next
ARG FEDORA_COREOS_VERSION=415.39.0

WORKDIR /go/src/github.com/openshift/okd-machine-os
COPY . .
COPY --from=artifacts /srv/repo/ /tmp/rpms/
ADD overrides.yaml /etc/rpm-ostree/origin.d/overrides.yaml
RUN cat /etc/os-release \
    && rpm-ostree --version \
    && ostree --version \
    && for overlay in overlay.d/*; do cp -rvf ${overlay}/* /; done \
    && cp -irvf bootstrap / \
    && cp -irvf manifests / \
    && cp -ivf *.repo /etc/yum.repos.d/ \
    && rpm-ostree install \
        NetworkManager-ovs \
        open-vm-tools \
        qemu-guest-agent \
        cri-o \
        cri-tools \
        netcat \
        # TODO: temporary fix in the next two rows: see okd-project/okd-payload-pipeline#15
        /tmp/rpms/$([ -d /tmp/rpms/$(uname -m) ] && echo $(uname -m)/)openshift-clients-[0-9]*.rpm \
        /tmp/rpms/$([ -d /tmp/rpms/$(uname -m) ] && echo $(uname -m)/)openshift-hyperkube-*.rpm \
    && rpm-ostree cliwrap install-to-root / \
    && rpm-ostree override replace \
    https://kojipkgs.fedoraproject.org//packages/kernel/6.5.4/300.fc39/x86_64/kernel-6.5.4-300.fc39.x86_64.rpm \
    https://kojipkgs.fedoraproject.org//packages/kernel/6.5.4/300.fc39/x86_64/kernel-core-6.5.4-300.fc39.x86_64.rpm \
    https://kojipkgs.fedoraproject.org//packages/kernel/6.5.4/300.fc39/x86_64/kernel-modules-6.5.4-300.fc39.x86_64.rpm \
    https://kojipkgs.fedoraproject.org//packages/kernel/6.5.4/300.fc39/x86_64/kernel-modules-core-6.5.4-300.fc39.x86_64.rpm \
    && rpm-ostree ex rebuild \
    && rpm-ostree cleanup -m \
    # Symlink ovs-vswitchd to dpdk version of OVS
    && ln -s /usr/sbin/ovs-vswitchd.dpdk /usr/sbin/ovs-vswitchd \
    # Symlink nc to netcat due to known issue in rpm-ostree - https://github.com/coreos/rpm-ostree/issues/1614
    && ln -s /usr/bin/netcat /usr/bin/nc \
    && rm -rf /go /var/lib/unbound /tmp/rpms \
    && systemctl preset-all \
    && ostree container commit

LABEL io.openshift.release.operator=true \
      io.openshift.build.version-display-names="machine-os=Fedora CoreOS" \
      io.openshift.build.versions="machine-os=${FEDORA_COREOS_VERSION}"

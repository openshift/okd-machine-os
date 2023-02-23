FROM registry.ci.openshift.org/origin/4.13:artifacts as artifacts

FROM quay.io/fedora/fedora-coreos:testing-devel
ARG FEDORA_COREOS_VERSION=413.37.0

WORKDIR /go/src/github.com/openshift/okd-machine-os
COPY . .
COPY --from=artifacts /srv/repo/ /tmp/rpms/
ADD overrides.yaml /etc/rpm-ostree/origin.d/overrides.yaml
RUN cat /etc/os-release \
    && rpm-ostree --version \
    && ostree --version \
    && cp -irvf overlay.d/*/* / \
    && systemctl preset-all \
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
    && rpm-ostree ex rebuild \
    && rpm-ostree cleanup -m \
    && ln -s /usr/sbin/ovs-vswitchd.dpdk /usr/sbin/ovs-vswitchd \
    && rm -rf /go /var/lib/unbound /tmp/rpms \
    && ostree container commit

LABEL io.openshift.release.operator=true \
      io.openshift.build.version-display-names="machine-os=Fedora CoreOS" \
      io.openshift.build.versions="machine-os=${FEDORA_COREOS_VERSION}"

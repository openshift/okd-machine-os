FROM registry.ci.openshift.org/origin/4.12:artifacts as artifacts

FROM quay.io/fedora/fedora-coreos:next-devel
ARG FEDORA_COREOS_VERSION=412.37.0

WORKDIR /go/src/github.com/openshift/okd-machine-os
COPY . .
COPY --from=artifacts /srv/repo/*.rpm /tmp/rpms/
ADD overrides.yaml /etc/rpm-ostree/origin.d/overrides.yaml
RUN cat /etc/os-release \
    && rpm-ostree --version \
    && ostree --version \
    && cp -irvf overlay.d/*/* / \
    && systemctl enable gcp-routes gcp-hostname \
    && cp -irvf bootstrap / \
    && cp -irvf manifests / \
    && cp -ivf okd-copr.repo /etc/yum.repos.d/ \
    && rpm-ostree install \
        NetworkManager-ovs \
        open-vm-tools \
        qemu-guest-agent \
        cri-o \
        cri-tools \
        /tmp/rpms/openshift-clients-[0-9]*.rpm \
        /tmp/rpms/openshift-hyperkube-*.rpm \
    && rpm-ostree cleanup -m \
    && ln -s /usr/sbin/ovs-vswitchd.dpdk /usr/sbin/ovs-vswitchd \
    && rm -rf /go /tmp/rpms /var/cache /var/lib/unbound \
    && ostree container commit
LABEL io.openshift.release.operator=true \
      io.openshift.build.version-display-names="machine-os=Fedora CoreOS" \
      io.openshift.build.versions="machine-os=${FEDORA_COREOS_VERSION}"

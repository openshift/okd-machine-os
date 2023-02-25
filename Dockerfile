FROM registry.ci.openshift.org/origin/4.12:artifacts as artifacts

FROM quay.io/fedora/fedora-coreos:stable
ARG FEDORA_COREOS_VERSION=412.37.0

WORKDIR /go/src/github.com/openshift/okd-machine-os
COPY . .
COPY --from=artifacts /srv/repo/ /tmp/rpms/
RUN cat /etc/os-release \
    && rpm-ostree --version \
    && ostree --version \
    && cp -irvf overlay.d/*/* / \
    && cp -irvf bootstrap / \
    && cp -irvf manifests / \
    && cp -ivf crio.repo /etc/yum.repos.d/ \
    && rpm-ostree install \
        NetworkManager-ovs \
        open-vm-tools \
        qemu-guest-agent \
        cri-o \
        cri-tools \
        netcat \
        /tmp/rpms/openshift-clients-[0-9]*.rpm \
        /tmp/rpms/openshift-hyperkube-*.rpm \
    && rpm-ostree cleanup -m \
    && ln -s /usr/sbin/ovs-vswitchd.dpdk /usr/sbin/ovs-vswitchd \
    && rm -rf /go /tmp/rpms /var/cache /var/lib/unbound \
    && systemctl preset-all \
    && ostree container commit

LABEL io.openshift.release.operator=true \
      io.openshift.build.version-display-names="machine-os=Fedora CoreOS" \
      io.openshift.build.versions="machine-os=${FEDORA_COREOS_VERSION}"

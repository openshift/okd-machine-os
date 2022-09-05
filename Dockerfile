FROM registry.ci.openshift.org/origin/4.12:okd-rpms as rpms

FROM quay.io/coreos-assembler/fcos:testing-devel
ARG FEDORA_COREOS_VERSION=412.36.0

WORKDIR /go/src/github.com/openshift/okd-machine-os
COPY . .
COPY --from=rpms /rpms/ /tmp/rpms
RUN cat /etc/os-release \
    && rpm-ostree --version \
    && ostree --version \
    && cp -irvf overlay.d/*/* / \
    && systemctl enable gcp-routes gcp-hostname \
    && cp -irvf bootstrap / \
    && cp -irvf manifests / \
    && rpm-ostree install \
        NetworkManager-ovs \
        open-vm-tools \
        qemu-guest-agent \
        /tmp/rpms/cri-o-*.rpm \
        /tmp/rpms/cri-tools-*.rpm \
        /tmp/rpms/openshift-clients-[0-9]*.rpm \
        /tmp/rpms/openshift-hyperkube-*.rpm \
    && rpm-ostree cleanup -m \
    && sed -i 's/^enabled=1/enabled=0/g' /etc/yum.repos.d/*.repo \
    && rm -rf /go /tmp/rpms /var/cache \
    && ostree container commit
LABEL io.openshift.release.operator=true \
      io.openshift.build.version-display-names="machine-os=Fedora CoreOS" \
      io.openshift.build.versions="machine-os=${FEDORA_COREOS_VERSION}"
ENTRYPOINT ["/noentry"]

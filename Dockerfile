FROM registry.ci.openshift.org/origin/4.14:artifacts as artifacts

FROM quay.io/openshift/okd-content@sha256:b85f120103b2e92e35999203d1ad1bc3f2e6a33f2aa97c7a8b21b0b62d5c96f0
ARG FEDORA_COREOS_VERSION=414.38.3

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
    && rpm-ostree override replace \
        /tmp/rpms/$([ -d /tmp/rpms/$(uname -m) ] && echo $(uname -m)/)openshift-hyperkube-*.rpm \
    && rpm-ostree cleanup -m \
    && rm -rf /go /var/lib/unbound /tmp/rpms \
    && systemctl preset-all \
    && ostree container commit

LABEL io.openshift.release.operator=true \
      io.openshift.build.version-display-names="machine-os=Fedora CoreOS" \
      io.openshift.build.versions="machine-os=${FEDORA_COREOS_VERSION}"

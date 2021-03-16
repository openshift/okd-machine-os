FROM quay.io/openshift/origin-machine-config-operator:4.8 as mcd
FROM quay.io/openshift/origin-artifacts:4.8 as artifacts

FROM quay.io/coreos-assembler/coreos-assembler:latest AS build
WORKDIR /src
COPY . .
COPY --from=mcd /usr/bin/machine-config-daemon /overrides/rootfs/usr/libexec/machine-config-daemon
COPY --from=artifacts /srv/repo/*.rpm /overrides/rpms
RUN entrypoint.sh

FROM scratch
COPY --from=build tmp/repo /srv/repo
RUN mkdir /extensions/
COPY manifests/ /manifests/
COPY bootstrap/ /bootstrap/
LABEL io.openshift.release.operator=true
ENTRYPOINT ["/noentry"]

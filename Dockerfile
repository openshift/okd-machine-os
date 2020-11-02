FROM quay.io/openshift/origin-machine-config-operator:4.6 as mcd
FROM quay.io/openshift/origin-artifacts:4.6 as artifacts

FROM quay.io/coreos-assembler/coreos-assembler:latest AS build
COPY --from=mcd /usr/bin/machine-config-daemon /srv/addons/usr/libexec/machine-config-daemon
COPY --from=artifacts /srv/repo/*.rpm /tmp/rpms/
USER 0
COPY ./entrypoint.sh /usr/bin
RUN /usr/bin/entrypoint.sh

FROM scratch
COPY --from=build /srv/ /srv/
COPY --from=build /extensions/ /extensions/
COPY manifests/ /manifests/
LABEL io.openshift.release.operator=true
ENTRYPOINT ["/noentry"]

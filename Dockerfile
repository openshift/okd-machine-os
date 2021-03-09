FROM quay.io/openshift/origin-machine-config-operator:4.7 as mcd
FROM quay.io/openshift/origin-artifacts:4.7 as artifacts

FROM quay.io/coreos-assembler/coreos-assembler:master AS build
COPY --from=mcd /usr/bin/machine-config-daemon /srv/addons/usr/libexec/machine-config-daemon
COPY --from=artifacts /srv/repo/*.rpm /tmp/rpms/
USER 0
COPY ./entrypoint.sh /usr/bin
COPY ./overlay /srv/overlay
RUN /usr/bin/entrypoint.sh

FROM scratch
COPY --from=build /srv/ /srv/
COPY --from=build /extensions/ /extensions/
COPY manifests/ /manifests/
COPY bootstrap/ /bootstrap/
LABEL io.openshift.release.operator=true
ENTRYPOINT ["/noentry"]

#!/bin/sh
set -exuo pipefail
export OPENSHIFT_BUILD_REFERENCE=$(git rev-parse FETCH_HEAD)
export FETCH_HEAD_CONTENT="$(cat ./.git/FETCH_HEAD)"
export OPENSHIFT_BUILD_SOURCE="${FETCH_HEAD_CONTENT##* }"


echo "Building ${OPENSHIFT_BUILD_REFERENCE} in ${OPENSHIFT_BUILD_SOURCE}"
cirrus-run --github vrutkovs/okd-os --branch main --show-build-log always | tee /tmp/build.log

INITIAL_IMAGE=$(grep "Committing container" -A1 /tmp/build.log | tail -n1 | tr ' ' '\n' | head -n1)
sed "s;INITIAL_IMAGE;${INITIAL_IMAGE};g" Dockerfile.template > /tmp/Dockerfile

OSTREE_VERSION="$(grep "OSTREE_VERSION" /tmp/build.log | cut -d'=' -f2)"
sed -i "s;OSTREE_VERSION;${OSTREE_VERSION};g" /tmp/Dockerfile

CRIO_RPM="$(grep -m1 -o "cri-o-\S*" /tmp/build.log | sed 's;cri-o-\(.*\).x86_64;\1;g')"
sed -i "s;CRIO_RPM;${CRIO_RPM};g" /tmp/Dockerfile

HYPERKUBE_RPM="$(grep -m1 -o "openshift-hyperkube-\S*" /tmp/build.log | sed 's;openshift-hyperkube-\(.*\).x86_64;\1;g')"
sed -i "s;HYPERKUBE_RPM;${HYPERKUBE_RPM};g" /tmp/Dockerfile

mkdir ./extensions

# syntax=docker.io/docker/dockerfile:1.25.0

ARG BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0

FROM --platform=${BUILDPLATFORM} ${BASE_IMAGE} AS base

ARG GITHUB_URL=https://github.com
# ARG GITHUB_URL=https://gh-proxy.org/https://github.com
# ARG GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github

# distribution registry
# https://github.com/distribution/distribution/releases
ARG INST_REGISTRY_V=v3.1.2

ARG VENDOR_ARCHES="amd64 arm64"

ENV \
    GITHUB_URL=${GITHUB_URL} \
    INST_REGISTRY_V=${INST_REGISTRY_V} \
    VENDOR_ARCHES=${VENDOR_ARCHES}

# ---------------------------------------------------------------------------
# binaries
#    /cpaas/vendor/registry/<arch>/{registry,LICENSE}
#    /cpaas/vendor/registry/<arch>/{registry,LICENSE}.sha256sum
#    /cpaas/vendor/registry/<arch>/registry_<ver>_linux_<arch>.tar.gz.sha256
#
# ---------------------------------------------------------------------------
FROM --platform=${BUILDPLATFORM} base AS binaries

RUN --mount=type=cache,target=/tmp,id=build-tmp,sharing=locked \
    set -eu \
    && ver="${INST_REGISTRY_V#v}" \
    && for arch in ${VENDOR_ARCHES}; do \
    tarball="registry_${ver}_linux_${arch}.tar.gz" ; \
    dst="/cpaas/vendor/registry/${arch}" ; \
    base_url="${GITHUB_URL}/distribution/distribution/releases/download/${INST_REGISTRY_V}" ; \
    curl --fail -sL -m 300 --retry 3 --retry-delay 5 \
    "${base_url}/${tarball}" -o "/tmp/${tarball}" ; \
    curl --fail -sL -m 60 --retry 3 --retry-delay 5 \
    "${base_url}/${tarball}.sha256" -o "/tmp/${tarball}.sha256" ; \
    want_sum="$(cut -d' ' -f1 "/tmp/${tarball}.sha256")" ; \
    echo "${want_sum}" | grep -qE '^[0-9a-f]{64}$' \
    || { echo "bad upstream checksum file: ${tarball}.sha256" >&2; exit 1; } ; \
    echo "${want_sum}  /tmp/${tarball}" | sha256sum --check --strict - ; \
    mkdir -p "${dst}" ; \
    tar zxf "/tmp/${tarball}" -C "${dst}" registry LICENSE ; \
    chmod +x "${dst}/registry" ; \
    ( cd "${dst}" && for f in * ; do sha256sum "${f}" > "${f}.sha256sum" ; done ) ; \
    echo "${want_sum}  ${tarball}" > "${dst}/${tarball}.sha256" ; \
    done

RUN set -eu \
    && for arch in ${VENDOR_ARCHES}; do \
    dst="/cpaas/vendor/registry/${arch}" ; \
    test -x "${dst}/registry" \
    || { echo "missing binary: ${arch}/registry" >&2; exit 1; } ; \
    test -s "${dst}/LICENSE" \
    || { echo "missing license: ${arch}/LICENSE" >&2; exit 1; } ; \
    magic="$(od -An -tx1 -N4 "${dst}/registry" | tr -d ' \n')" ; \
    test "${magic}" = "7f454c46" \
    || { echo "not an ELF binary: ${arch}/registry (magic=${magic})" >&2; exit 1; } ; \
    case "${arch}" in \
    amd64) want="3e00" ;; \
    arm64) want="b700" ;; \
    *) echo "unsupported arch: ${arch} (only amd64 / arm64)" >&2; exit 1 ;; \
    esac ; \
    machine="$(od -An -tx1 -j18 -N2 "${dst}/registry" | tr -d ' \n')" ; \
    test "${machine}" = "${want}" \
    || { echo "ELF arch mismatch: ${arch}/registry (e_machine=${machine}, want=${want})" >&2; exit 1; } ; \
    for f in registry LICENSE; do \
    test -s "${dst}/${f}.sha256sum" \
    || { echo "missing checksum: ${arch}/${f}.sha256sum" >&2; exit 1; } ; \
    done ; \
    ( cd "${dst}" && sha256sum --check --strict ./*.sha256sum ) ; \
    done

# ---------------------------------------------------------------------------
# target
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG TARGETARCH

# distribution registry
# https://github.com/distribution/distribution/releases
ARG INST_REGISTRY_V=v3.1.2

ENV INST_REGISTRY_V=${INST_REGISTRY_V}

COPY --from=binaries /cpaas/vendor/registry/${TARGETARCH}/ /cpaas/vendor/registry/

LABEL \
    org.opencontainers.image.title="kluster-vendor-registry" \
    org.opencontainers.image.description="Upstream distribution registry binaries repackaged as OCI artifacts" \
    org.opencontainers.image.version="${INST_REGISTRY_V}" \
    org.opencontainers.image.source="https://github.com/cpaas-dev/kluster-vendor-registry" \
    org.opencontainers.image.vendor="Kluster" \
    org.opencontainers.image.licenses="Apache-2.0"

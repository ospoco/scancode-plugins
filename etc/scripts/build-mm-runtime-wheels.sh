#!/usr/bin/env bash
# Build prebuilt mm runtime wheels (pyicu with vendored ICU, py-ubjson with its
# C extension) for linux x86_64 + aarch64, plus sdist mirrors, into ../../dist.
#
# These wheels let the mm host weft venv (`mm/bin/sync_host_weft_runtime.sh`)
# install without a compiler toolchain on production hosts. The build base is
# python:3.14.5-slim-trixie, the same image mm's Dockerfile uses for Python
# headers, so the cp314 ABI and Debian 13 (trixie) ICU match the fleet.
#
# Bumping pyicu or py-ubjson in mm requires rebuilding here and republishing
# the index BEFORE locking mm to the new version: the packages are pinned to
# this index via [tool.uv.sources], so a version that is absent here fails at
# `uv lock`/deploy time instead of falling back to a source build on prod.
set -euo pipefail

PYICU_VERSION="${PYICU_VERSION:-2.16.2}"
PY_UBJSON_VERSION="${PY_UBJSON_VERSION:-0.16.1}"
BUILD_IMAGE="${BUILD_IMAGE:-python:3.14.5-slim-trixie}"
PLATFORMS="${PLATFORMS:-linux/amd64 linux/arm64}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"
dist_dir="$repo_root/dist"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

cat > "$work_dir/Dockerfile" <<EOF
FROM ${BUILD_IMAGE} AS build
ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends \\
        build-essential pkg-config libicu-dev patchelf \\
    && rm -rf /var/lib/apt/lists/*
RUN pip install auditwheel
WORKDIR /w
RUN pip wheel --no-deps --no-binary :all: -w /w/raw \\
        pyicu==${PYICU_VERSION} py-ubjson==${PY_UBJSON_VERSION}
RUN auditwheel repair -w /w/out /w/raw/pyicu-*.whl \\
 && auditwheel repair -w /w/out /w/raw/py_ubjson-*.whl
RUN pip download --no-deps --no-binary :all: -d /w/sdist \\
        pyicu==${PYICU_VERSION} py-ubjson==${PY_UBJSON_VERSION}
FROM scratch AS artifacts
COPY --from=build /w/out /out
COPY --from=build /w/sdist /sdist
EOF

mkdir -p "$dist_dir"
for platform in $PLATFORMS; do
  echo "==> building mm runtime wheels for $platform"
  out="$work_dir/${platform//\//-}"
  docker build --platform "$platform" --target artifacts \
    -o "type=local,dest=$out" "$work_dir"
  cp -f "$out"/out/*.whl "$dist_dir/"
  cp -f "$out"/sdist/*.tar.gz "$dist_dir/"
done

echo "==> artifacts in $dist_dir:"
ls -la "$dist_dir" | grep -E 'pyicu|py.ubjson'

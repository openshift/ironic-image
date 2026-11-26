#!/usr/bin/bash

# This script builds Python wheels from cachito sources for the OCP build.
# It runs in the wheel-builder stage of the Docker build.
# Adapted from the upstream build-wheels.sh for the downstream cachito pipeline.

set -euxo pipefail

. /bin/python-config.sh
configure_python

# PyO3 0.23.5 (used by bcrypt 4.3.0) needs ABI3 forward compatibility for Python 3.14.
if [[ "${PYTHON_VERSION}" == "3.14" ]]; then
    export PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1
fi

REQS="${REMOTE_SOURCES_DIR}/requirements.cachito"

# load cachito variables only if they're available
if [[ -d "${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps" ]]; then
    source "${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps/cachito.env"
    REQS="${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps/app/requirements.cachito"
fi

# NOTE(elfosardo): --no-build-isolation is needed to allow build engine
# to use build tools already installed in the system, for our case
# setuptools and pbr, instead of installing them in the isolated
# pip environment.
WHEEL_OPTIONS="--no-cache-dir --no-build-isolation --no-index"

# ssh-python's SYSTEM_LIBSSH mode expects libssh under /usr/local, while the
# RHEL packages install it under /usr and /usr/lib64. Use the RHEL 9
# backported CVE-2026-59847 fix rather than ssh-python's bundled libssh 0.11.3.
mkdir -p /usr/local/include /usr/local/lib
ln -sfnT /usr/include/libssh /usr/local/include/libssh
ln -sfnT /usr/lib64/libssh.so /usr/local/lib/libssh.so

# NOTE(elfosardo): download all the libraries and dependencies first,
# using --no-deps to avoid chain-downloading packages.
# This forces to download only the packages specified in the requirements file.
# This is done to allow testing any source code package in CI emulating
# the cachito downstream build pipeline.
# See https://issues.redhat.com/browse/METAL-1049 for more details.
PIP_SOURCES_DIR="/tmp/all_sources"
mkdir -p $PIP_SOURCES_DIR
SYSTEM_LIBSSH=1 "${PYTHON_BIN}" -m pip download \
    --no-binary=:all: \
    --no-build-isolation \
    --no-deps \
    -r "${REQS}" \
    -d "${PIP_SOURCES_DIR}"

# Build wheels from downloaded sources
mkdir -p /wheels
SYSTEM_LIBSSH=1 "${PYTHON_BIN}" -m pip wheel \
    $WHEEL_OPTIONS \
    --wheel-dir=/wheels \
    --no-deps \
    --find-links="${PIP_SOURCES_DIR}" \
    -r "${REQS}"

rm -rf $PIP_SOURCES_DIR

echo "Wheels built successfully in /wheels"
ls -la /wheels/

#!/usr/bin/bash

set -euxo pipefail

echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
# Tell RPM to skip installing documentation
echo "tsflags=nodocs" >> /etc/dnf/dnf.conf

dnf upgrade -y

xargs -rtd'\n' dnf install -y < /tmp/${PKGS_LIST}
if [ $(uname -m) = "x86_64" ]; then
    dnf install -y syslinux-nonlinux;
fi

if [[ -n "${EXTRA_PKGS_LIST:-}" ]]; then
    if [[ -s "/tmp/${EXTRA_PKGS_LIST}" ]]; then
        xargs -rtd'\n' dnf install -y < /tmp/"${EXTRA_PKGS_LIST}"
    fi
fi

### cachito magic works for OCP only
if  [[ -f /tmp/main-packages-list.ocp ]]; then

    REQS="${REMOTE_SOURCES_DIR}/requirements.cachito"
    IRONIC_UID=1002
    IRONIC_GID=1003

    ls -la "${REMOTE_SOURCES_DIR}/" # DEBUG

    # load cachito variables only if they're available
    if [[ -d "${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps" ]]; then
        source "${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps/cachito.env"
        REQS="${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps/app/requirements.cachito"
    fi

    ### source install ###
    BUILD_DEPS="python3.12-devel gcc gcc-c++ python3.12-wheel"

    # NOTE(elfosardo): wheel is needed because of pip "no-build-isolation" option
    # setting installation of setuptoools here as we may want to remove it
    # in teh future once the container build is done
    dnf install -y python3.12-pip 'python3.12-setuptools >= 64.0.0' python3.12-setuptools_scm $BUILD_DEPS

    # NOTE(elfosardo): --no-index is used to install the packages emulating
    # an isolated environment in CI. Do not use the option for downstream
    # builds.
    # NOTE(janders): adding --no-compile option to avoid issues in FIPS
    # enabled environments. See https://issues.redhat.com/browse/RHEL-29028
    # for more information
    # NOTE(elfosardo): --no-build-isolation is needed to allow build engine
    # to use build tools already installed in the system, for our case
    # setuptools and pbr, instead of installing them in the isolated
    # pip environment. We may change this in the future and just use
    # full isolated environment and source build dependencies.
    PIP_OPTIONS="--no-compile --no-cache-dir --no-build-isolation"
    if [[ ! -d "${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps" ]]; then
        PIP_OPTIONS="$PIP_OPTIONS --no-index"
    fi

    # NOTE(elfosardo): download all the libraries and dependencies first, removing
    # --no-index but using --no-deps to avoid chain-downloading packages.
    # This forces to download only the packages specified in the requirements file,
    # but we leave the --no-index in the installation phase to again avoid
    # downloading unexpected packages and install only the downloaded ones.
    # This is done to allow testing any source code package in CI emulating
    # the cachito downstream build pipeline.
    # See https://issues.redhat.com/browse/METAL-1049 for more details.
    PIP_SOURCES_DIR="all_sources"
    mkdir $PIP_SOURCES_DIR
    python3.12 -m pip download --no-binary=:all: --no-build-isolation --no-deps -r "${REQS}" -d $PIP_SOURCES_DIR
    python3.12 -m pip install $PIP_OPTIONS --prefix /usr -r "${REQS}" -f $PIP_SOURCES_DIR

    # NOTE(janders) since we set --no-compile at install time, we need to
    # compile post-install (see RHEL-29028)
    python3.12 -m compileall --invalidation-mode=timestamp -q /usr

    # ironic system configuration
    mkdir -p /var/log/ironic /var/lib/ironic
    getent group ironic >/dev/null || groupadd -r -g "${IRONIC_GID}" ironic
    getent passwd ironic >/dev/null || useradd -r -g ironic -s /sbin/nologin -u "${IRONIC_UID}" ironic -d /var/lib/ironic

    dnf remove -y $BUILD_DEPS
    rm -fr $PIP_SOURCES_DIR

    if [[ -d "${REMOTE_SOURCES_DIR}/cachito-gomod-with-deps" ]]; then
        rm -rf $REMOTE_SOURCES_DIR
    fi

fi
###

chown ironic:ironic /var/log/ironic
# This file is generated after installing mod_ssl and it affects our configuration
rm -f /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/autoindex.conf /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.modules.d/*.conf

# RDO-provided configuration forces creating log files
rm -f /usr/share/ironic/ironic-dist.conf

# add ironic to apache group
usermod -aG ironic apache

dnf clean all
rm -rf /var/cache/{yum,dnf}/*

#!/usr/bin/bash

set -euxo pipefail

echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
# Tell RPM to skip installing documentation
echo "tsflags=nodocs" >> /etc/dnf/dnf.conf

# SOURCE install #

BUILD_DEPS="python3-devel gcc gcc-c++ git-core krb5-devel libxml2-devel libxslt-devel libffi-devel cargo rust"

xargs -rtd'\n' dnf install -y < /tmp/${PKGS_LIST}
if [ $(uname -m) = "x86_64" ]; then
    dnf install -y syslinux-nonlinux;
fi

if [[ -n "${EXTRA_PKGS_LIST:-}" ]]; then
    if [[ -s "/tmp/${EXTRA_PKGS_LIST}" ]]; then
        xargs -rtd'\n' dnf install -y < /tmp/"${EXTRA_PKGS_LIST}"
    fi
fi

echo $REMOTE_SOURCES_DIR
ls -la $REMOTE_SOURCES_DIR
ls -la $REMOTE_SOURCES_DIR/cachito-gomod-with-deps
ls -la $REMOTE_SOURCES_DIR/cachito-gomod-with-deps/app
cat $REMOTE_SOURCES_DIR/cachito-gomod-with-deps/app/requirements.cachito
ls -la $REMOTE_SOURCES_DIR/cachito-gomod-with-deps/deps
cat $REMOTE_SOURCES_DIR/cachito-gomod-with-deps/cachito.env

source "$REMOTE_SOURCES_DIR/cachito-gomod-with-deps/cachito.env"

REQS="$REMOTE_SOURCES_DIR/cachito-gomod-with-deps/app/requirements.cachito"

export CARGO_NET_OFFLINE=true

# NOTE(dtantsur): pip is a requirement of python3 in CentOS
# shellcheck disable=SC2086
dnf install -y python3-pip python3-setuptools $BUILD_DEPS

python3 -m pip install -r /tmp/${BUILD_REQS}

#python3 -m pip install /vendor/*$(uname -m).whl
dnf install -y python-bcrypt-3.1.6-3.el9 

python3 -m pip install --prefix /usr -r ${REQS}

# ironic and ironic-inspector system configuration
mkdir -p /var/log/ironic /var/log/ironic-inspector /var/lib/ironic /var/lib/ironic-inspector
getent group ironic >/dev/null || groupadd -r ironic
getent passwd ironic >/dev/null || useradd -r -g ironic -s /sbin/nologin ironic -d /var/lib/ironic
getent group ironic-inspector >/dev/null || groupadd -r ironic-inspector
getent passwd ironic-inspector >/dev/null || useradd -r -g ironic-inspector -s /sbin/nologin ironic-inspector -d /var/lib/ironic-inspector

# clean installed build dependencies
# shellcheck disable=SC2086
dnf remove -y $BUILD_DEPS

# NOTE(rpittau): jinja2 is misteriuosly removed as dependent package
# reinstall it here as a workaround
dnf install -y python3-jinja2

chown ironic:ironic /var/log/ironic
# This file is generated after installing mod_ssl and it affects our configuration
rm -f /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/autoindex.conf /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.modules.d/*.conf

# RDO-provided configuration forces creating log files
rm -f /usr/share/ironic/ironic-dist.conf /etc/ironic-inspector/inspector-dist.conf

# add ironic and ironic-inspector to apache group
usermod -aG ironic apache
usermod -aG ironic-inspector apache

dnf clean all
rm -rf /var/cache/{yum,dnf}/*

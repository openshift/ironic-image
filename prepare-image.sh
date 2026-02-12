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

### OCP: Install from pre-built wheels (built in wheel-builder stage)
if [[ -f /tmp/main-packages-list.ocp ]]; then

    IRONIC_UID=1002
    IRONIC_GID=1003

    dnf install -y python3.12-pip

    # NOTE(janders): adding --no-compile option to avoid issues in FIPS
    # enabled environments. See https://issues.redhat.com/browse/RHEL-29028
    # for more information
    python3.12 -m pip install \
        --no-compile \
        --no-cache-dir \
        --no-index \
        --find-links=/wheels \
        --prefix /usr \
        /wheels/*.whl

    # NOTE(janders) since we set --no-compile at install time, we need to
    # compile post-install (see RHEL-29028)
    python3.12 -m compileall --invalidation-mode=timestamp -q -x '/usr/share/doc' /usr

    # ironic system configuration
    mkdir -p /var/log/ironic /var/lib/ironic
    getent group ironic >/dev/null || groupadd -r -g "${IRONIC_GID}" ironic
    getent passwd ironic >/dev/null || useradd -r -g ironic -s /sbin/nologin -u "${IRONIC_UID}" ironic -d /var/lib/ironic

fi
###

### OKD/SCOS Python 3.12 setup
if [[ -f /tmp/main-packages-list.okd ]]; then
    setup.okd
fi
###

chown ironic:ironic /var/log/ironic /var/lib/ironic
# This file is generated after installing mod_ssl and it affects our configuration
rm -f /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/autoindex.conf /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.modules.d/*.conf

# RDO-provided configuration forces creating log files
rm -f /usr/share/ironic/ironic-dist.conf

# add ironic to apache group
usermod -aG ironic apache

dnf clean all
rm -rf /var/cache/{yum,dnf}/*

mv /bin/ironic-probe.sh /bin/ironic-readiness
cp /bin/ironic-readiness /bin/ironic-liveness
mkdir /data /conf

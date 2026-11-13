#!/usr/bin/bash

set -euxo pipefail

. /bin/python-config.sh
configure_python

echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
# Tell RPM to skip installing documentation
echo "tsflags=nodocs" >> /etc/dnf/dnf.conf

dnf upgrade -y

grep -v '^#' "/tmp/${PKGS_LIST}" | xargs -rtd'\n' dnf install -y
if [ $(uname -m) = "x86_64" ]; then
    dnf install -y syslinux-nonlinux;
fi

if [[ -n "${EXTRA_PKGS_LIST:-}" ]]; then
    if [[ -s "/tmp/${EXTRA_PKGS_LIST}" ]]; then
        grep -v '^#' "/tmp/${EXTRA_PKGS_LIST}" | xargs -rtd'\n' dnf install -y
    fi
fi

### OCP: Install from pre-built wheels (built in wheel-builder stage)
if [[ -f /tmp/main-packages-list.ocp ]]; then

    IRONIC_UID=1002
    IRONIC_GID=1003

    dnf install -y "${PYTHON_PACKAGE_PREFIX}-pip" patch

    # NOTE(janders): adding --no-compile option to avoid issues in FIPS
    # enabled environments. See https://issues.redhat.com/browse/RHEL-29028
    # for more information
    "${PYTHON_BIN}" -m pip install \
        --no-compile \
        --no-cache-dir \
        --no-index \
        --find-links=/wheels \
        --prefix /usr \
        /wheels/*.whl

    # Apply the downstream patches in patches/ to the just-installed packages.
    # This happens before compileall below so the .pyc files are built from the
    # patched sources. -p2 strips the "a/src/" prefix of the upstream requests
    # layout, leaving paths relative to site-packages. See patches/README.md.
    #
    # NOTE: the site-packages directory is located via the installed package
    # itself, not via sysconfig: on RHEL sysconfig defaults to the posix_local
    # scheme and reports /usr/local/lib/..., while the pip install above uses
    # --prefix /usr and lands in /usr/lib/....
    SITE_PACKAGES="$("${PYTHON_BIN}" -c 'import importlib.util, pathlib; print(pathlib.Path(importlib.util.find_spec("requests").origin).parents[1])')"
    # -i takes an absolute path because patch(1) chdirs to -d before reading it
    patch -p2 -d "${SITE_PACKAGES}" --no-backup-if-mismatch \
        -i /patches/requests-ipv6-cidr-no_proxy.patch
    rm -rf /patches

    # NOTE(janders) since we set --no-compile at install time, we need to
    # compile post-install (see RHEL-29028)
    "${PYTHON_BIN}" -m compileall --invalidation-mode=timestamp -q -x '/usr/share/doc' /usr

    dnf remove -y "${PYTHON_PACKAGE_PREFIX}-pip" patch

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

# sqlite is in the package list only to initialize the DB; drop it afterwards
mkdir -p /var/lib/ironic
sqlite3 /var/lib/ironic/ironic.sqlite "pragma journal_mode=wal"
dnf remove -y sqlite

dnf clean all
rm -rf /var/cache/{yum,dnf}/*

mv /bin/ironic-probe.sh /bin/ironic-readiness
cp /bin/ironic-readiness /bin/ironic-liveness
mkdir /data /conf

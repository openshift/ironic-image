%{!?upstream_version: %global upstream_version %{_version}.%{_build_date_time}.%{_release}}
%global project ironic

%global common_desc \
Ironic is an open source project that fully manages bare metal infrastructure. \
It discovers bare-metal nodes, catalogs them in a management database, and \
manages the entire server lifecycle including enrolling, provisioning, \
maintenance, and decommissioning.

Name:           openshift-ironic
Version:        %{_version}
Release:        %{_release}
Summary:        Provisioning of Bare Metal Servers
License:        ASL 2.0
URL:            https://ironicbaremetal.org/

Source0:        %{project}-%{upstream_version}.tar.gz
Source1:        ironic-api.service
Source2:        ironic-conductor.service
Source3:        ironic-rootwrap-sudoers
Source4:        ironic-dist.conf
Source5:        ironic.logrotate

BuildArch:      noarch

BuildRequires:  python3-ironic-lib
BuildRequires:  python3-keystoneauth1
BuildRequires:  python3-oslo-concurrency
BuildRequires:  python3-oslo-config
BuildRequires:  python3-oslo-log
BuildRequires:  python3-oslo-policy
BuildRequires:  python3-setuptools
BuildRequires:  python3-devel
BuildRequires:  python3-pbr
BuildRequires:  openssl-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
BuildRequires:  gmp-devel
BuildRequires:  systemd

%prep

%setup -q -n ironic-%{upstream_version}
# Let RPM handle the requirements
rm -f requirements.txt
rm -f test-requirements.txt
rm -f doc/requirements.txt

# Remove tempest plugin entrypoint as a workaround
sed -i '/tempest/d' setup.cfg
rm -rf ironic_tempest_plugin
%build
%{py3_build}

%install
%{py3_install}

install -p -D -m 644 %{SOURCE5} %{buildroot}%{_sysconfdir}/logrotate.d/ironic

# install systemd scripts
mkdir -p %{buildroot}%{_unitdir}
install -p -D -m 644 %{SOURCE1} %{buildroot}%{_unitdir}
install -p -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}

# install sudoers file
mkdir -p %{buildroot}%{_sysconfdir}/sudoers.d
install -p -D -m 440 %{SOURCE3} %{buildroot}%{_sysconfdir}/sudoers.d/ironic

mkdir -p %{buildroot}%{_sharedstatedir}/ironic/
mkdir -p %{buildroot}%{_localstatedir}/log/ironic/
mkdir -p %{buildroot}%{_sysconfdir}/ironic/rootwrap.d

#Populate the conf dir
export PYTHONPATH=.
oslo-config-generator --config-file tools/config/ironic-config-generator.conf --output-file %{buildroot}/%{_sysconfdir}/ironic/ironic.conf
oslopolicy-sample-generator --config-file tools/policy/ironic-policy-generator.conf --output-file %{buildroot}/%{_sysconfdir}/ironic/policy.json
mv %{buildroot}%{_prefix}/etc/ironic/rootwrap.conf %{buildroot}/%{_sysconfdir}/ironic/rootwrap.conf
mv %{buildroot}%{_prefix}/etc/ironic/rootwrap.d/* %{buildroot}/%{_sysconfdir}/ironic/rootwrap.d/
# Remove duplicate config files under /usr/etc/ironic
rmdir %{buildroot}%{_prefix}/etc/ironic/rootwrap.d
rmdir %{buildroot}%{_prefix}/etc/ironic

# Install distribution config
install -p -D -m 640 %{SOURCE4} %{buildroot}/%{_datadir}/ironic/ironic-dist.conf

%description
Ironic provides an API for management and provisioning of physical machines

%package common
Summary: Ironic common

Requires:   python3-alembic >= 1.4.2
Requires:   python3-automaton >= 1.9.0
Requires:   python3-cinderclient >= 3.3.0
Requires:   python3-eventlet >= 0.18.2
Requires:   python3-futurist >= 1.2.0
Requires:   python3-glanceclient >= 2.8.0
Requires:   python3-ironic-lib >= 4.3.0
Requires:   python3-jinja2 >= 2.10
Requires:   python3-jsonpatch >= 1.16
Requires:   python3-jsonschema >= 2.6.0
Requires:   python3-keystoneauth1 >= 4.2.0
Requires:   python3-keystonemiddleware >= 4.17.0
Requires:   python3-openstacksdk >= 0.48.0
Requires:   python3-oslo-concurrency >= 4.2.0
Requires:   python3-oslo-config >= 2:5.2.0
Requires:   python3-oslo-context >= 2.19.2
Requires:   python3-oslo-db >= 6.0.0
Requires:   python3-oslo-log >= 3.36.0
Requires:   python3-oslo-messaging >= 5.29.0
Requires:   python3-oslo-middleware >= 3.31.0
Requires:   python3-oslo-policy >= 1.30.0
Requires:   python3-oslo-rootwrap >= 5.8.0
Requires:   python3-oslo-serialization >= 2.18.0
Requires:   python3-oslo-service >= 1.24.0
Requires:   python3-oslo-upgradecheck >= 0.1.0
Requires:   python3-oslo-utils >= 3.38.0
Requires:   python3-oslo-versionedobjects >= 1.31.2
Requires:   python3-osprofiler >= 1.5.0
Requires:   python3-os-traits >= 0.4.0
Requires:   python3-pbr >= 2.0.0
Requires:   python3-pecan >= 1.0.0
Requires:   python3-psutil >= 3.2.2
Requires:   python3-pysendfile >= 2.0.0
Requires:   python3-pytz >= 2013.6
Requires:   python3-requests >= 2.14.2
Requires:   python3-retrying >= 1.2.3
Requires:   python3-rfc3986 >= 0.3.1
Requires:   python3-sqlalchemy >= 1.2.19
Requires:   python3-stevedore >= 1.20.0
Requires:   python3-swiftclient >= 3.2.0
Requires:   python3-tooz >= 2.7.0
Requires:   python3-webob >= 1.7.1

Recommends: ipmitool
Recommends: python3-dracclient >= 3.1.0
Recommends: python3-proliantutils >= 2.9.1
Recommends: python3-pysnmp >= 4.3.0
Recommends: python3-scciclient >= 0.8.0
Recommends: python3-sushy >= 3.2.0

# Optional features
Suggests: python3-oslo-i18n >= 3.15.3
Suggests: python3-oslo-reports >= 1.18.0

Requires(pre):  shadow-utils

%description common
Components common to all Ironic services

%files common
%doc README.rst
%license LICENSE
%{_bindir}/ironic-dbsync
%{_bindir}/ironic-rootwrap
%{_bindir}/ironic-status
%{python3_sitelib}/ironic
%{python3_sitelib}/ironic-*.egg-info
%exclude %{python3_sitelib}/ironic/tests
%{_sysconfdir}/sudoers.d/ironic
%config(noreplace) %{_sysconfdir}/logrotate.d/ironic
%config(noreplace) %attr(-,root,ironic) %{_sysconfdir}/ironic
%attr(-,ironic,ironic) %{_sharedstatedir}/ironic
%attr(0750,ironic,ironic) %{_localstatedir}/log/ironic
%attr(-, root, ironic) %{_datadir}/ironic/ironic-dist.conf
%exclude %{python3_sitelib}/ironic_tests.egg_info

%pre common
getent group ironic >/dev/null || groupadd -r ironic
getent passwd ironic >/dev/null || \
    useradd -r -g ironic -d %{_sharedstatedir}/ironic -s /sbin/nologin \
-c "Ironic Daemons" ironic
exit 0

%package api
Summary: The Ironic API

Requires: %{name}-common = %{version}-%{release}

%{?systemd_requires}

%description api
Ironic API for management and provisioning of physical machines

%files api
%{_bindir}/ironic-api
%{_bindir}/ironic-api-wsgi
%{_unitdir}/ironic-api.service

%post api
%systemd_post ironic-api.service

%preun api
%systemd_preun ironic-api.service

%postun api
%systemd_postun_with_restart ironic-api.service

%package conductor
Summary: The Ironic Conductor

Requires: %{name}-common = %{version}-%{release}
Requires: udev

%{?systemd_requires}

%description conductor
Ironic Conductor for management and provisioning of physical machines

%files conductor
%{_bindir}/ironic-conductor
%{_unitdir}/ironic-conductor.service

%post conductor
%systemd_post ironic-conductor.service

%preun conductor
%systemd_preun ironic-conductor.service

%postun conductor
%systemd_postun_with_restart ironic-conductor.service

Metal3 Ironic Container
=======================

This repo contains the files needed to build the Ironic images used by Metal3.

## Description

When updated, builds are automatically triggered on
<https://quay.io/repository/metal3-io/ironic/>

This repo supports the creation of multiple containers needed when provisioning
baremetal nodes with Ironic. Eventually there will be separate images for each
container, but currently separate containers can share this same image with
specific entry points.

The following entry points are provided:

- `runironic` - Starts the ironic-conductor and ironic-api processes to manage
   the provisioning of baremetal nodes.  Details on Ironic can be found at
   <https://docs.openstack.org/ironic/latest/>.  This is the default entry point
   used by the Dockerfile.
- `runironic-networking` - Starts the ironic-networking service for standalone
   network management of baremetal nodes. This service handles switch port
   configuration for node provisioning, cleaning, and inspection operations.
- `rundnsmasq` - Runs the dnmasq dhcp server to provide addresses and initiate
   PXE boot of baremetal nodes.  This includes a lightweight TFTP server.
   Details on dnsmasq can be found at
   <http://www.thekelleys.org.uk/dnsmasq/doc.html>.
- `runhttpd` - Starts the Apache web server to provide images via http for PXE
   boot and for deployment of the final images.
- `runlogwatch` - Waits for host provisioning ramdisk logs to appear, prints
   their contents and deletes files.

All of the containers must share a common mount point or data store.  Ironic
requires files for both the TFTP server and HTTP server to be stored in the same
partition.  This common store must include, in `<shared store>/html/images`,
the following images:

- ironic-python-agent.kernel
- ironic-python-agent.initramfs
- final image to be deployed onto node in qcow2 format

The following environment variables can be passed in to customize run-time
functionality:

- `PROVISIONING_MACS` - a comma seperated list of mac address of the master
   nodes (used to determine the `PROVISIONING_INTERFACE`)
- `PROVISIONING_INTERFACE` - interface to use for ironic, dnsmasq(dhcpd) and
   httpd (default provisioning, this is calculated if the above
   `PROVISIONING_MACS` is provided)
- `PROVISIONING_IP` - the specific IP to use (instead of calculating it based on
  the `PROVISIONING_INTERFACE`)
- `IRONIC_IP_WAIT_TIMEOUT` - maximum time in seconds to wait for the
  provisioning IP or interface to become available before failing the entry
  point (default `1200`). Set to `0` (or a negative value) to wait
  indefinitely, restoring the previous behaviour.
- `IRONIC_IP_WAIT_INTERVAL` - polling interval in seconds while waiting for the
  provisioning IP or interface (default `1`)
- `DNSMASQ_EXCEPT_INTERFACE` - interfaces to exclude when providing DHCP address
  (default `lo`)
- `HTTP_PORT` - port used by http server (default `80`)
- `HTTPD_SERVE_NODE_IMAGES` - used by runhttpd script, controls access
   to the `/shared/html/images` directory via the default virtual host
   `(HTTP_PORT)`.  (default `true`)
- `DHCP_RANGE` - dhcp range to use for provisioning (e.g.
   `172.22.0.10,172.22.0.100`)
- `DHCP_HOSTS` - a `;` separated list of `dhcp-host` entries, e.g. known MAC
   addresses like `00:20:e0:3b:13:af;00:20:e0:3b:14:af` (empty by default). For
   more details on `dhcp-host` see
   [the man page](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).
- `DHCP_OPTIONS` - a `;` separated list of additional `dhcp-option` directives
   that allows passing specific network configuration parameters (like routers,
   DNS servers, and NTP) to DHCP clients (empty by default). Only applies to
   IPv4 provisioning (`IPV=4` or unset). For more details on `dhcp-option` see
   [the man page](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).
- `DHCP_IGNORE` - a set of tags on hosts that should be ignored and not allocate
   DHCP leases for, e.g. `tag:!known` to ignore any unknown hosts (empty by
   default)
- `OS_<section>_\_<name>=<value>` - This format can be used to set arbitary
   Ironic config options. These OS\_ environment variables take precedence over
   configuration rendered from templates. For example, if both `SEND_SENSOR_DATA=true`
   and `OS_SENSOR_DATA__SEND_SENSOR_DATA=false` are set, the OS_ variable value
   (`false`) will be used at runtime.
- `IRONIC_RAMDISK_SSH_KEY` - A single public key to allow ssh access as root to
   nodes running IPA, takes the format "ssh-rsa AAAAB3.....". This relies on the
   [dynamic-login](https://opendev.org/openstack/diskimage-builder/src/branch/master/diskimage_builder/elements/dynamic-login)
   element to inject the key.
- `IRONIC_KERNEL_PARAMS` - This parameter can be used to add additional kernel
  parameters to nodes running IPA
- `IRONIC_HTTPD_LOGLEVEL` - Log level for the Ironic API's Apache server
  (default `debug`)
- `GATEWAY_IP` - gateway IP address to use for ironic dnsmasq(dhcpd)
- `DNS_IP` - DNS IP address to use for ironic dnsmasq(dhcpd)
- `IRONIC_IPA_COLLECTORS` - Use a custom set of collectors to be run on
   inspection. (default `default,logs,pci-devices`)
- `IRONIC_JSON_RPC_PORT` - port used by the Ironic JSON-RPC service (default
  `6189`)
- `HTTPD_ENABLE_SENDFILE` - Whether to activate the EnableSendfile apache
   directive for httpd `(default, false)`
- `IRONIC_CONDUCTOR_HOST` - Host name of the current conductor (only makes
   sense to change for a multinode setup). Defaults to the IP address used
   for provisioning.
- `IRONIC_EXTERNAL_IP` - Optional external IP if Ironic is not accessible on
  `PROVISIONING_IP`.
- `IRONIC_EXTERNAL_CALLBACK_URL` - Override Ironic's external callback URL.
  Defaults to use `IRONIC_EXTERNAL_IP` if available.
- `IRONIC_EXTERNAL_HTTP_URL` - Override Ironic's external http URL. Defaults to
  use `IRONIC_EXTERNAL_IP` if available.
- `IRONIC_ENABLE_VLAN_INTERFACES` - Which VLAN interfaces to enable on the
  agent start-up. Can be a list of interfaces or a special value `all`.
  Defaults to `all`.
- `DEPLOY_KERNEL_URL` and `DEPLOY_RAMDISK_URL` provide the default IPA kernel
  and initramfs images. If they're not set, the images from IPA downloader are
  used (if present).

The `DNSMASQ_DATA_DIR` build argument (default `/data/dnsmasq`) is used by
`configure-nonroot.sh` to create and set permissions on dnsmasq's runtime
directory. At runtime, that directory is derived from `CUSTOM_DATA_DIR`
(default `/data`) as `${CUSTOM_DATA_DIR}/dnsmasq`.

### Multi-architecture IPA support

The image can serve architecture-specific IPA kernel and ramdisk images for
`x86_64` and `aarch64` nodes:

- `DEPLOY_KERNEL_BY_ARCH` and `DEPLOY_RAMDISK_BY_ARCH` accept comma-separated
  `architecture:URL` entries. For example:

  ```bash
  DEPLOY_KERNEL_BY_ARCH=x86_64:file:///shared/html/images/ipa_x86.kernel,aarch64:file:///shared/html/images/ipa_arm64.kernel
  DEPLOY_RAMDISK_BY_ARCH=x86_64:file:///shared/html/images/ipa_x86.initramfs,aarch64:file:///shared/html/images/ipa_arm64.initramfs
  ```

For automatic detection, set both `DEPLOY_KERNEL_URL_<ARCH>` and
`DEPLOY_RAMDISK_URL_<ARCH>` for an architecture, or place both files named
`ironic-python-agent_<arch>.kernel` and
`ironic-python-agent_<arch>.initramfs` under `/shared/html/images`. Generic IPA
images are used when no architecture-specific mapping is detected and for
architectures without an explicit iPXE branch. Provide a complete kernel and
ramdisk pair for each architecture you intend to boot.

### IPA boot parameters

- `IRONIC_IPA_INSECURE` - Allow insecure connections (default `1`)
- `IRONIC_IPA_DEBUG` - Enable IPA debug mode (default `1`)
- `IRONIC_IPA_INSPECTION_DHCP_ALL_INTERFACES` - Request DHCP on all interfaces
  during inspection (default `1`)
- `IRONIC_IPA_COLLECT_LLDP` - Collect LLDP information (default `1`)
- `IPA_FORWARD_CONSOLE` - Forward console logs (default `yes`)
- `INSPECTOR_EXTRA_ARGS` - Additional inspection kernel parameters
- `WEBSERVER_CACERT_FILE` - CA certificate or bundle used to verify disk and
  IPA images; it is also injected into IPA when configured.

The following mountpoints can be passed in to customize run-time
functionality:

- `/certs/ca/bmc` - The storage path of BMC CA certificates. If the path exists
  and verify_ca field in driver_info is True or None, the certificates in this
  path will be used.

MariaDB configuration:

- `IRONIC_USE_MARIADB` - Whether to use an external MariaDB database instead of
  a local SQLite file (default `false`)
- `MARIADB_HOST` - Host name with an optional port of the MariaDB database
  instance (must be provided if `IRONIC_USE_MARIADB` is `true`)
- `MARIADB_DATABASE` - Database name to use (default `ironic`)
- `MARIADB_USER` - User name to use when connecting to the database (default
  `ironic`). The user must have privileges to create and update tables.
  Can be provided via a secret mounted under `/auth/mariadb`.
- `MARIADB_PASSWORD` - The database password.
   Deprecated. Instead, mount a secret with `password` (optionally with a
   `username`) under `/auth/mariadb` mount point.
- `IRONIC_DBSYNC_TIMEOUT` - maximum time in seconds to wait for `ironic-dbsync`
  to succeed (for example while MariaDB is starting up) before failing the
  entry point (default `600`). Only applies when `IRONIC_USE_MARIADB` is
  `true`. Set to `0` (or a negative value) to retry indefinitely, restoring the
  previous behaviour.
- `IRONIC_DBSYNC_INTERVAL` - interval in seconds between `ironic-dbsync`
  retries (default `1`)

### Overriding Ironic configuration options

Any Ironic configuration option can be overridden at runtime with an
environment variable of the form `OS_<section>__<option>` (note the two
underscores after the section). These variables take precedence over values
rendered from templates. For example:

- `OS_DEFAULT__DEBUG=true` - enable debug logging
- `OS_SENSOR_DATA__SEND_SENSOR_DATA=false` - override the template's
  `SEND_SENSOR_DATA` value
- `OS_CONDUCTOR__DEPLOY_CALLBACK_TIMEOUT=4800` - timeout (seconds) to wait for
  a callback from a deploy ramdisk
- `OS_CONDUCTOR__INSPECT_TIMEOUT=1800` - timeout (seconds) for waiting for node
  inspection
- `OS_CONDUCTOR__CLEAN_CALLBACK_TIMEOUT=1800` - timeout (seconds) to wait for a
  callback from the ramdisk doing the cleaning
- `OS_PXE__BOOT_RETRY_TIMEOUT=1200` - timeout (seconds) to enable boot retries

## TLS configuration

The following environment variables can be passed to customize the Ironic API
TLS configuration:

- `IRONIC_SSL_PROTOCOL` - Apache `SSLProtocol` directive for the Ironic API
  and proxy vhosts (default `-ALL +TLSv1.2 +TLSv1.3`)
- `IRONIC_TLS_12_CIPHERS` - Setting this variable will set the allowed cipher
  suites for TLS up to version 1.2 in order, it needs to be set in the openSSL
  format e.g. `ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305`. If
  left unset it will use default from openSSL.
- `IRONIC_TLS_13_CIPHERS` - Setting this variable will set the allowed cipher
  suites for TLS version 1.3 in order, it needs to be set in the openSSL format
  e.g. `TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256`. If let unset it will
  use default from openSSL.
- `IRONIC_TLS_CURVES` - Setting this variable will set the allowed set of groups
  allowed for TLS negotiation by order of preference, it needs to be set in the
  openSSL format like e.g. `x448:x25519:secp256r1:secp384r1`. If let unset it
  will use default from openSSL.
- `IRONIC_TLS_ENFORCE_SERVER_CIPHER_ORDER` - Setting this variable to
  `true` will make the server enforce its cipher list ordering for TLS version
  up to 1.2, defaults to `false`

The following environment variables can be passed to customize the Ironic
Prometheus Exporter TLS configuration:

- `IRONIC_PROMETHEUS_EXPORTER_CERT_FILE` - TLS certificate for the exporter
  (default `/certs/ironic-prometheus-exporter/tls.crt`)
- `IRONIC_PROMETHEUS_EXPORTER_KEY_FILE` - TLS private key for the exporter
  (default `/certs/ironic-prometheus-exporter/tls.key`)

The following environment variables can be passed to customize the virtual
media HTTP server configuration:

- `IRONIC_VMEDIA_CURVES` - Setting this variable will set the allowed set of
  groups allowed for TLS negotiation by order of preference, it needs to be set
  in the openSSL format like e.g. `x448:x25519:secp256r1:secp384r1`. If let
  unset it will use default from openSSL.
- `IRONIC_VMEDIA_TLS_12_CIPHERS` - Setting this variable will set the allowed
  cipher suites for TLS up to version 1.2 in order, it needs to be set in the
  openSSL format e.g. `ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305`.
  If let unset it will use default from openSSL.
- `IRONIC_VMEDIA_TLS_13_CIPHERS` - Setting this variable will set the allowed
  cipher suites for TLS up to version 1.3 in order, it needs to be set in the
  openSSL format e.g. `TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256`. If
  let unset it will use default from openSSL.
- `IRONIC_VMEDIA_TLS_ENFORCE_SERVER_CIPHER_ORDER` - Setting this variable to
  `true` will make the server enforce its cipher list ordering for TLS version
  up to 1.2, defaults to `false`

## Ironic Networking

The ironic networking configuration can be overridden by various environment
variables.  The following can serve as an example of those most common settings.

- `IRONIC_NETWORKING_ENABLED` - Enable standalone networking service
   (default `false`)
- `IRONIC_NETWORKING_JSON_RPC_HOST` - JSON-RPC host for networking service
   (default `localhost`)
- `IRONIC_NETWORKING_JSON_RPC_PORT` - JSON-RPC port for networking service
   (default `8090`)
- `IRONIC_NETWORKING_ENABLED_SWITCH_DRIVERS` - Enabled switch drivers (default
   `generic-switch`)
- `IRONIC_NETWORKING_SWITCH_CONFIGS` - Path to switch configuration file.
   Switch configurations and SSH keys should be stored in a Secret and mounted
   to the Pod as a file and referenced by this variable.
   (default `${IRONIC_CONF_DIR}/networking/switch-configs.conf`)
- `IRONIC_NETWORKING_PROVISIONING_NETWORK` - Network details for the
   provisioning network (e.g., mode=access/native_vlan=123)
- `IRONIC_NETWORKING_INSPECTION_NETWORK` - Network details for the inspection
   network (e.g., mode=access/native_vlan=123)
- `IRONIC_NETWORKING_SERVICING_NETWORK` - Network details for the servicing
   network (e.g., mode=access/native_vlan=123)
- `IRONIC_NETWORKING_CLEANING_NETWORK` - Network details for the cleaning
   network (e.g., mode=access/native_vlan=123)
- `IRONIC_NETWORKING_RESCUING_NETWORK` - Network details for the rescuing
   network (e.g., mode=access/native_vlan=123)
- `IRONIC_NETWORKING_IDLE_NETWORK` - Network details for the idle
   network (e.g., mode=access/native_vlan=123)

**Note:**  The ironic-networking service requires the `networking-generic-switch`
  package.

## Using a read-only root filesystem

The ironic-image can operate with a read-only root filesystem. However,
it needs a few directories to be mounted as writable `emptyDir` volumes:

- `/conf` - location for rendered configuration files
- `/data` - writable runtime data such as the database
- `/tmp` - temporary directory

This is in addition to the always required `/shared` volume that is used to
share runtime data between Ironic and HTTPD.

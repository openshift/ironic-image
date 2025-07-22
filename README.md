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
- `GATEWAY_IP` - gateway IP address to use for ironic dnsmasq(dhcpd)
- `DNS_IP` - DNS IP address to use for ironic dnsmasq(dhcpd)
- `IRONIC_IPA_COLLECTORS` - Use a custom set of collectors to be run on
   inspection. (default `default,logs`)
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

The ironic configuration can be overridden by various environment variables.
The following can serve as an example:

- `OS_CONDUCTOR__DEPLOY_CALLBACK_TIMEOUT=4800` - timeout (seconds) to wait for
   a callback from a deploy ramdisk
- `OS_CONDUCTOR__INSPECT_TIMEOUT=1800` - timeout (seconds) for waiting for node
   inspection
- `OS_CONDUCTOR__CLEAN_CALLBACK_TIMEOUT=1800` - timeout (seconds) to wait for a
   callback from the ramdisk doing the cleaning
- `OS_PXE__BOOT_RETRY_TIMEOUT=1200` - timeout (seconds) to enable boot retries.

## Using a read-only root filesystem

The ironic-image can operate with a read-only root filesystem. However,
it needs a few directories to be mounted as writable `emptyDir` volumes:

- `/conf` - location for rendered configuration files
- `/data` - writable runtime data such as the database
- `/tmp` - temporary directory

This is in addition to the always required `/shared` volume that is used to
share runtime data between Ironic and HTTPD.

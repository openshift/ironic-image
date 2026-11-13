# Downstream patches

Patches applied to third-party Python packages in the OCP image.

Until this image switched to building its Python dependencies from source,
some of these packages came from RHEL RPMs that carried downstream-only
patches. Building from source silently dropped those patches, which is what
this directory exists to restore.

## How they are applied

`Dockerfile.ocp` copies this directory to `/patches` in the final stage, and
`prepare-image.sh` applies each patch with `patch(1)` directly to the installed
package tree, after `pip install` and before `compileall` so the `.pyc` files
are built from the patched sources. `/patches` and the `patch` RPM are both
removed again in the same layer.

Patches are applied to the **installed** package, not to an sdist, so nothing
here depends on sdist filenames or on the version pinned in
`requirements.cachito`. Each patch is applied by an explicit line in
`prepare-image.sh`; add another line when you add another patch.

Keeping the upstream `src/`-layout paths means `-p2` is what lands the patch on
site-packages. A patch taken from a project that does not use a `src/` layout
needs `-p1` instead.

## Maintenance

If a patched dependency is bumped and the patch no longer applies, `patch`
exits non-zero and **the image build fails**. That is deliberate — a stale
patch must not be silently skipped. When that happens, either rebase the patch
onto the new version, or, if the fix has landed upstream, delete the patch and
its line in `prepare-image.sh`.

Note that patching in place leaves the `RECORD` hashes in the package's
`.dist-info` stale. Nothing in the final image verifies them (pip is removed),
but `pip check`-style tooling run against the image would notice.

## Current patches

### `requests-ipv6-cidr-no_proxy.patch`

Teaches `no_proxy` handling about IPv6 addresses and IPv6 CIDRs. Without it
`NO_PROXY=fd00::/64` never matches, so requests to an IPv6 address in that
range are sent through the proxy and ironic cannot be reached.

- Upstream PR (never merged): <https://github.com/psf/requests/pull/5953>
- Downstream RPM patch: <https://issues.redhat.com/browse/RHEL-17548>, shipped
  by Fedora as `support_IPv6_CIDR_in_no_proxy.patch`
- Lost when the image moved to building `requests` from source:
  <https://issues.redhat.com/browse/OCPBUGS-42216>
- Regression this fixes: <https://issues.redhat.com/browse/OCPBUGS-140637>

This is the Fedora patch rebased onto requests 2.32.5, which predates the type
annotations the Fedora copy is written against; the code changes are otherwise
identical. The upstream `tests/test_utils.py` hunks are dropped, since the
installed package ships no tests.

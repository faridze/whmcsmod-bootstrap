# whmcsmod bootstrap distribution

Public, minimal bootstrap/distribution repository for the private `faridze/whmcs-module-manager` project.

This repository intentionally contains only public installation material and authenticated release payloads. It does **not** contain module source code, GitHub credentials, or private signing-key material.

## Current stable release

```text
whmcsmod 0.4.7
```

When `--version` is omitted, this stable release is selected from the signed `stable.meta` metadata.

Authenticated manager artifact SHA-256:

```text
ed342648e66f6599ed3ac763f2e39fbbf95d1575dcbc6d5dedc9b7c75149ae38
```

Version 0.4.6 adds first-class repository onboarding commands (`whmcsmod repo add/list/status/refresh/remove`). Repository onboarding remains separate from WHMCS deployment and does not deploy module files by itself.

Version 0.4.7 adds authenticated `whmcsmod self-update` and `whmcsmod self-update --check`, using signed release metadata, the pinned release fingerprint, and artifact SHA-256 verification.

## Production install

Use the immutable bootstrap commit below. Do **not** replace the commit SHA with `main`.

```bash
curl -fsSL https://raw.githubusercontent.com/faridze/whmcsmod-bootstrap/211dfce50e06e5c1eb80bd5c5dc84980459281cf/install.sh \
  | sudo bash -s -- \
      --target mywhmcs \
      --whmcs-root /absolute/path/to/whmcs
```

If you are already logged in as `root`, use `bash` instead of `sudo bash`:

```bash
curl -fsSL https://raw.githubusercontent.com/faridze/whmcsmod-bootstrap/211dfce50e06e5c1eb80bd5c5dc84980459281cf/install.sh \
  | bash -s -- \
      --target mywhmcs \
      --whmcs-root /absolute/path/to/whmcs
```

Optional overrides are available when auto-detection cannot determine the correct runtime safely:

```text
--php-bin /absolute/path/to/php
--composer-bin /absolute/path/to/composer
--whmcs-run-user USER
--version 0.4.7
```

PHP ambiguity intentionally fails instead of selecting the newest installed PHP.

## Trust model

The bootstrap installer pins the release-signing primary fingerprint:

```text
9A3FFFFD9AA2CDA1B825A9F90425CF942B02684C
```

The downloaded public key is accepted only if it contains exactly that primary fingerprint. `stable.meta` is detached-signed with the same key and contains the SHA-256 of the manager bundle. The bootstrap verifies the metadata signature and `VALIDSIG` fingerprint before trusting the version/hash, then verifies the bundle SHA-256 and its strict file allow-list before executing the canonical manager installer.

Archive file-name comparison is pinned to `LC_ALL=C`, so valid signed artifacts are not rejected because of host locale collation differences.

The private signing key exists only in the private manager repository's GitHub Actions secret and is never distributed to WHMCS servers.

## Public layout

```text
install.sh
release-signing-public.asc
stable.meta
stable.meta.asc
releases/0.4.1/...
releases/0.4.2/...
releases/0.4.3/release.meta
releases/0.4.3/release.meta.asc
releases/0.4.3/whmcsmod-0.4.3.tar.gz
releases/0.4.4/release.meta
releases/0.4.4/release.meta.asc
releases/0.4.4/whmcsmod-0.4.4.tar.gz
releases/0.4.5/release.meta
releases/0.4.5/release.meta.asc
releases/0.4.5/whmcsmod-0.4.5.tar.gz
releases/0.4.6/release.meta
releases/0.4.6/release.meta.asc
releases/0.4.6/whmcsmod-0.4.6.tar.gz
releases/0.4.7/release.meta
releases/0.4.7/release.meta.asc
releases/0.4.7/whmcsmod-0.4.7.tar.gz
```

`stable.meta` points only to a stable release. Prereleases are never selected implicitly.

## Post-install checks

The bootstrap reports success only after the canonical installer finishes and these checks pass:

```bash
whmcsmod doctor
whmcsmod target list
```

Starting with 0.4.7, future manager upgrades can be checked and installed directly:

```bash
whmcsmod self-update --check
whmcsmod self-update
```

The repository also runs continuous distribution verification plus an end-to-end test that executes the exact pinned curl command against an ephemeral fake WHMCS installation and verifies the installed self-update path.

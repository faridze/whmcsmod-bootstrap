# whmcsmod bootstrap distribution

Public, minimal bootstrap/distribution repository for the private `faridze/whmcs-module-manager` project.

This repository intentionally contains only public installation material and authenticated release payloads. It does **not** contain module source code, GitHub credentials, or private signing-key material.

## Current stable release

```text
whmcsmod 0.7.0
```

When `--version` is omitted, this stable release is selected from the signed `stable.meta` metadata.

Authenticated manager artifact SHA-256:

```text
644a6cf770c63906f7838dd6bff0601b52321d059370028dea51db80fa3d8511
```

Version 0.4.6 added first-class repository onboarding commands (`whmcsmod repo add/list/status/refresh/remove`). Repository onboarding remains separate from WHMCS deployment and does not deploy module files by itself.

Version 0.4.7 added authenticated `whmcsmod self-update` and `whmcsmod self-update --check`, using signed release metadata, the pinned release fingerprint, and artifact SHA-256 verification.

Version 0.5.0 added the operational-safety layer: repository audit, authenticated update planning/dry-run, backup list/show/prune with opt-in retention, multi-target doctor/status summaries, and manager version reporting. Automatic backup pruning remains disabled by default.

Version 0.6.0 added authenticated standalone module packaging. `whmcsmod package` builds a WHMCS-root-relative ZIP from the exact signed module release, emits checksum/provenance sidecars, and vendors production Composer dependencies when declared. It does not modify the configured WHMCS deployment, module state, or backups.

Version 0.7.0 adds read-only multi-component import for existing WHMCS module installations. It can discover addon, gateway/callback, server, registrar, hook, cron, asset/template, and other matching module paths; classify source/ionCube/unknown PHP; warn about common secret risks; and create a local reviewable whmcsmod repository without modifying WHMCS, committing, adding a remote, or pushing to GitHub.

## Production install

Use the immutable bootstrap commit below. Do **not** replace the commit SHA with `main`.

```bash
curl -fsSL https://raw.githubusercontent.com/faridze/whmcsmod-bootstrap/ed44a2bdba852e7bb31e32f945835b542e3c8985/install.sh \
  | sudo bash -s -- \
      --target mywhmcs \
      --whmcs-root /absolute/path/to/whmcs
```

If you are already logged in as `root`, use `bash` instead of `sudo bash`:

```bash
curl -fsSL https://raw.githubusercontent.com/faridze/whmcsmod-bootstrap/ed44a2bdba852e7bb31e32f945835b542e3c8985/install.sh \
  | bash -s -- \
      --target mywhmcs \
      --whmcs-root /absolute/path/to/whmcs
```

Optional overrides are available when auto-detection cannot determine the correct runtime safely:

```text
--php-bin /absolute/path/to/php
--composer-bin /absolute/path/to/composer
--whmcs-run-user USER
--version 0.7.0
```

PHP ambiguity intentionally fails instead of selecting the newest installed PHP.

## Trust model

The bootstrap installer pins the release-signing primary fingerprint:

```text
9A3FFFFD9AA2CDA1B825A9F90425CF942B02684C
```

The downloaded public key is accepted only if it contains exactly that primary fingerprint. `stable.meta` is detached-signed with the same key and contains the SHA-256 of the manager bundle. The bootstrap verifies the metadata signature and `VALIDSIG` fingerprint before trusting the version/hash, then verifies the bundle SHA-256 and its version-specific strict file allow-list before executing the canonical manager installer.

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
releases/0.4.3/...
releases/0.4.4/...
releases/0.4.5/...
releases/0.4.6/...
releases/0.4.7/...
releases/0.5.0/...
releases/0.6.0/...
releases/0.7.0/release.meta
releases/0.7.0/release.meta.asc
releases/0.7.0/whmcsmod-0.7.0.tar.gz
```

`stable.meta` points only to a stable release. Prereleases are never selected implicitly.

## Post-install checks

The bootstrap reports success only after the canonical installer finishes and these checks pass:

```bash
whmcsmod doctor
whmcsmod target list
```

Existing installations starting with 0.4.7 can check and install future manager upgrades directly:

```bash
whmcsmod self-update --check
whmcsmod self-update
```

Useful operational checks include:

```bash
whmcsmod version
whmcsmod status --all
whmcsmod doctor --all
whmcsmod repo audit --all
whmcsmod update --all --dry-run
whmcsmod backup list --all
whmcsmod backup show MODULE BACKUP_ID
```

Export a signed module release for manual installation on a WHMCS that does not run whmcsmod:

```bash
whmcsmod package MODULE
whmcsmod package MODULE v1.2.3
whmcsmod package MODULE latest /root/module-packages
```

The generated ZIP contains only WHMCS-relative deployment files. Manual extraction does not execute whmcsmod database migration or healthcheck hooks.

Import an existing module installation into a local reviewable repository:

```bash
whmcsmod import scan MODULE
whmcsmod import plan MODULE
whmcsmod import create MODULE
```

The default import selects confirmed source/assets only. Likely paths, ionCube-encoded PHP, unknown PHP, and files with common secret-risk patterns are skipped unless explicitly enabled. For unusual module-owned locations, add one or more WHMCS-root-relative paths during plan/create:

```bash
whmcsmod import plan MODULE --include-path includes/custom/module-helper.php
```

`import create` never modifies the source WHMCS installation and creates no commit, remote, or GitHub push. Review the generated `IMPORT-REPORT.md` and `deploy-files.txt` before any Git action.

The repository also runs continuous distribution verification plus an end-to-end test that executes the exact publication bootstrap against an ephemeral fake WHMCS installation and verifies the installed self-update path and current release library set.

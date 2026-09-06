# whmcsmod bootstrap distribution

Public, minimal bootstrap/distribution repository for the private `faridze/whmcs-module-manager` project.

This repository intentionally contains only public installation material and authenticated release payloads. It does **not** contain module source code, GitHub credentials, or private signing-key material.

## Trust model

The bootstrap installer pins the release-signing primary fingerprint:

```text
9A3FFFFD9AA2CDA1B825A9F90425CF942B02684C
```

A downloaded public key is accepted only if it resolves to exactly that fingerprint. Release metadata is detached-signed with the same key and contains the SHA-256 of the manager bundle. The bundle is verified before extraction/execution.

Do not execute a mutable `main` bootstrap URL in production. Use an immutable commit SHA, for example:

```bash
curl -fsSL https://raw.githubusercontent.com/faridze/whmcsmod-bootstrap/<PINNED_COMMIT_SHA>/install.sh \
  | sudo bash -s -- \
      --target mywhmcs \
      --whmcs-root /absolute/path/to/whmcs
```

The concrete pinned command is published after the bootstrap files and first authenticated manager distribution are committed.

## Public layout

```text
install.sh
release-signing-public.asc
stable.meta
stable.meta.asc
releases/<version>/release.meta
releases/<version>/release.meta.asc
releases/<version>/whmcsmod-<version>.tar.gz
```

`stable.meta` is a signed stable-release pointer represented by the same metadata content as the current stable release. Prereleases are never selected implicitly.

#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SIGNING_FINGERPRINT="9A3FFFFD9AA2CDA1B825A9F90425CF942B02684C"
DEFAULT_DISTRIBUTION_BASE_URL="https://raw.githubusercontent.com/faridze/whmcsmod-bootstrap/main"
BOOTSTRAP_TEMP_DIR=""

bootstrap_cleanup() {
  if [[ -n "${BOOTSTRAP_TEMP_DIR:-}" ]]; then
    rm -rf -- "$BOOTSTRAP_TEMP_DIR"
    BOOTSTRAP_TEMP_DIR=""
  fi
}

bootstrap_die() { echo "whmcsmod-bootstrap: ERROR: $*" >&2; exit 1; }
bootstrap_need() { command -v "$1" >/dev/null 2>&1 || bootstrap_die "required command not found: $1"; }

bootstrap_stable_semver() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

bootstrap_verify_public_key() {
  local key_file="$1" gpg_home="$2" expected="$3"
  local -a fingerprints=()
  GNUPGHOME="$gpg_home" gpg --batch --import "$key_file" >/dev/null 2>&1 || return 1
  mapfile -t fingerprints < <(
    GNUPGHOME="$gpg_home" gpg --batch --with-colons --list-keys 2>/dev/null \
      | awk -F: '$1=="pub"{want=1; next} want && $1=="fpr"{print toupper($10); want=0}'
  )
  [[ ${#fingerprints[@]} -eq 1 ]] || return 1
  [[ "${fingerprints[0]}" == "$expected" ]]
}

bootstrap_verify_metadata_signature() {
  local metadata="$1" signature="$2" gpg_home="$3" expected="$4" status actual
  status="$(GNUPGHOME="$gpg_home" gpg --batch --status-fd=1 --verify "$signature" "$metadata" 2>/dev/null)" || return 1
  actual="$(printf '%s\n' "$status" | awk '/^\[GNUPG:\] VALIDSIG / && !seen {print toupper($3); seen=1}')"
  [[ -n "$actual" && "$actual" == "$expected" ]]
}

bootstrap_parse_metadata() {
  local metadata="$1" requested="${2:-}" line key value version="" sha256="" version_count=0 sha_count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || return 1
    [[ "$line" == *=* ]] || return 1
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      version)
        version_count=$((version_count + 1)); version="$value"
        ;;
      sha256)
        sha_count=$((sha_count + 1)); sha256="${value,,}"
        ;;
      *) return 1 ;;
    esac
  done < "$metadata"
  [[ $version_count -eq 1 && $sha_count -eq 1 ]] || return 1
  bootstrap_stable_semver "$version" || return 1
  [[ "$sha256" =~ ^[a-f0-9]{64}$ ]] || return 1
  [[ -z "$requested" || "$requested" == "$version" ]] || return 1
  BOOTSTRAP_RELEASE_VERSION="$version"
  BOOTSTRAP_RELEASE_SHA256="$sha256"
}

bootstrap_verify_archive_layout() {
  local archive="$1" actual expected
  expected=$'VERSION\ninstall.sh\nlib/commands.sh\nlib/common.sh\nlib/deploy.sh\nlib/install-detect.sh\nlib/manifest.php\nlib/release.sh\nwhmcsmod'
  actual="$(tar -tzf "$archive" | sed 's#^\./##' | LC_ALL=C sort)" || return 1
  [[ "$actual" == "$expected" ]] || return 1
  if tar -tvzf "$archive" | awk '$1 ~ /^[lh]/ {found=1} END {exit found ? 0 : 1}'; then
    return 1
  fi
}

bootstrap_download() {
  local url="$1" destination="$2"
  [[ "$url" == https://* ]] || bootstrap_die "refusing non-HTTPS download URL"
  curl -fsSL --proto '=https' --tlsv1.2 "$url" -o "$destination"
}

bootstrap_usage() {
  cat <<'EOF'
Usage:
  install.sh --target NAME --whmcs-root /absolute/path/to/whmcs [options]

Options:
  --php-bin /absolute/path/to/php
  --composer-bin /absolute/path/to/composer
  --whmcs-run-user USER
  --version X.Y.Z
EOF
}

bootstrap_main() {
  (( EUID == 0 )) || bootstrap_die "run as root (sudo)"
  bootstrap_need curl; bootstrap_need gpg; bootstrap_need tar; bootstrap_need sha256sum; bootstrap_need awk; bootstrap_need sed; bootstrap_need sort

  local target="" whmcs_root="" php_bin="" composer_bin="" whmcs_run_user="" requested_version=""
  local base_url="${WHMCSMOD_DISTRIBUTION_BASE_URL:-$DEFAULT_DISTRIBUTION_BASE_URL}"
  while (($#)); do
    case "$1" in
      --target) target="${2:-}"; shift 2 ;;
      --whmcs-root) whmcs_root="${2:-}"; shift 2 ;;
      --php-bin) php_bin="${2:-}"; shift 2 ;;
      --composer-bin) composer_bin="${2:-}"; shift 2 ;;
      --whmcs-run-user) whmcs_run_user="${2:-}"; shift 2 ;;
      --version) requested_version="${2:-}"; shift 2 ;;
      -h|--help) bootstrap_usage; return 0 ;;
      *) bootstrap_die "unknown option: $1" ;;
    esac
  done

  [[ "$target" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] || bootstrap_die "--target is required and must be a valid target id"
  [[ "$whmcs_root" == /* ]] || bootstrap_die "--whmcs-root must be an absolute path"
  [[ -z "$requested_version" ]] || bootstrap_stable_semver "$requested_version" || bootstrap_die "--version must be stable SemVer X.Y.Z; prereleases are never selected by bootstrap"
  [[ "$base_url" == https://* ]] || bootstrap_die "distribution base URL must use HTTPS"
  base_url="${base_url%/}"

  local temp gpg_home public_key metadata metadata_sig artifact release_dir metadata_url artifact_url actual_sha
  temp="$(mktemp -d /tmp/whmcsmod-bootstrap.XXXXXX)"
  BOOTSTRAP_TEMP_DIR="$temp"
  trap bootstrap_cleanup EXIT
  gpg_home="$temp/gnupg"
  mkdir -m 0700 "$gpg_home"
  public_key="$temp/release-signing-public.asc"
  metadata="$temp/release.meta"
  metadata_sig="$temp/release.meta.asc"

  bootstrap_download "$base_url/release-signing-public.asc" "$public_key"
  bootstrap_verify_public_key "$public_key" "$gpg_home" "$EXPECTED_SIGNING_FINGERPRINT" || bootstrap_die "release signing public key fingerprint mismatch"

  if [[ -n "$requested_version" ]]; then
    metadata_url="$base_url/releases/$requested_version/release.meta"
  else
    metadata_url="$base_url/stable.meta"
  fi
  bootstrap_download "$metadata_url" "$metadata"
  bootstrap_download "$metadata_url.asc" "$metadata_sig"
  bootstrap_verify_metadata_signature "$metadata" "$metadata_sig" "$gpg_home" "$EXPECTED_SIGNING_FINGERPRINT" || bootstrap_die "release metadata signature is invalid or signed by an unexpected key"
  bootstrap_parse_metadata "$metadata" "$requested_version" || bootstrap_die "release metadata is malformed, unstable, or does not match the requested version"

  artifact="$temp/whmcsmod-$BOOTSTRAP_RELEASE_VERSION.tar.gz"
  artifact_url="$base_url/releases/$BOOTSTRAP_RELEASE_VERSION/whmcsmod-$BOOTSTRAP_RELEASE_VERSION.tar.gz"
  bootstrap_download "$artifact_url" "$artifact"
  actual_sha="$(sha256sum "$artifact" | awk '{print tolower($1)}')"
  [[ "$actual_sha" == "$BOOTSTRAP_RELEASE_SHA256" ]] || bootstrap_die "release artifact SHA-256 mismatch"
  bootstrap_verify_archive_layout "$artifact" || bootstrap_die "release artifact contains an unexpected file layout"

  release_dir="$temp/release"
  mkdir -m 0700 "$release_dir"
  tar -xzf "$artifact" -C "$release_dir"
  [[ "$(tr -d '[:space:]' < "$release_dir/VERSION")" == "$BOOTSTRAP_RELEASE_VERSION" ]] || bootstrap_die "release bundle VERSION does not match signed metadata"

  local -a install_args=(
    --target "$target"
    --whmcs-root "$whmcs_root"
    --trusted-signing-public-key "$public_key"
    --trusted-signing-fingerprint "$EXPECTED_SIGNING_FINGERPRINT"
  )
  [[ -z "$php_bin" ]] || install_args+=(--php-bin "$php_bin")
  [[ -z "$composer_bin" ]] || install_args+=(--composer-bin "$composer_bin")
  [[ -z "$whmcs_run_user" ]] || install_args+=(--whmcs-run-user "$whmcs_run_user")

  bash "$release_dir/install.sh" "${install_args[@]}"
  /usr/local/sbin/whmcsmod doctor
  /usr/local/sbin/whmcsmod target list

  echo
  echo "SUCCESS: whmcsmod $BOOTSTRAP_RELEASE_VERSION installed and validated"
  echo "Target:      $target"
  echo "WHMCS root:  $whmcs_root"
  echo "Signing:     $EXPECTED_SIGNING_FINGERPRINT"
  echo "Public key:  /etc/whmcsmod/keys/release-signing-public.asc"
}

bootstrap_source="${BASH_SOURCE[0]-}"
if [[ -z "$bootstrap_source" || "$bootstrap_source" == "$0" ]]; then
  bootstrap_main "$@"
fi

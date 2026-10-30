# Shared helpers; sourced by the other scripts.
set -euo pipefail

PLATFORMS="${PLATFORMS:-linux-arm64 linux-amd64 darwin-arm64 win32-x64}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS="$ROOT/versions.json"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

size_of() { wc -c <"$1" | tr -d ' '; }

require_platform() {
  case " $PLATFORMS " in *" $1 "*) ;; *) echo "unknown platform: $1" >&2; exit 2 ;; esac
}

verify_sha256() {
  local file="$1" expected="$2" actual
  actual="$(sha256_of "$file")"
  if [ "$actual" != "$expected" ]; then
    echo "sha256 mismatch for $file: expected $expected, got $actual" >&2
    exit 1
  fi
}

# Deterministic gzip: no name, no timestamp.
pack() { gzip -n -9 -c "$1" >"$2"; }

# HTTPS only, also on redirects; bounded size; a few retries for transient errors.
fetch() { curl -fsSL --proto '=https' --proto-redir '=https' --retry 3 --max-filesize "$3" -o "$1" "$2"; }

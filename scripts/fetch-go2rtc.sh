#!/usr/bin/env bash
# Usage: fetch-go2rtc.sh <platform> <outdir>
# Downloads the upstream go2rtc release asset, verifies its upstream SHA-256 from versions.json,
# extracts the binary and writes <outdir>/go2rtc-<platform>.gz (one gzip per binary).
source "$(dirname "$0")/common.sh"

platform="$1"; out="$2"
require_platform "$platform"
mkdir -p "$out"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

base="$(jq -r '.go2rtc.upstream' "$VERSIONS")"
name="$(jq -r --arg p "$platform" '.go2rtc.assets[$p].name' "$VERSIONS")"
member="$(jq -r --arg p "$platform" '.go2rtc.assets[$p].member // empty' "$VERSIONS")"
expected="$(jq -r --arg p "$platform" '.go2rtc.assets[$p].sha256' "$VERSIONS")"

curl -fsSL --proto '=https' --max-filesize 67108864 -o "$work/$name" "$base$name"
verify_sha256 "$work/$name" "$expected"

if [ -n "$member" ]; then
  unzip -q -j "$work/$name" "$member" -d "$work/bin"
  binary="$work/bin/$member"
else
  binary="$work/$name"
fi
chmod 0755 "$binary"
pack "$binary" "$out/go2rtc-$platform.gz"
echo "$expected" >"$out/go2rtc-$platform.upstream-sha256"
echo "go2rtc $platform: $(size_of "$out/go2rtc-$platform.gz") bytes packed"

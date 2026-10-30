#!/usr/bin/env bash
# Usage: make-manifest.sh <assetdir> <release>
# Writes <assetdir>/components.json: every asset's name, size and SHA-256 per platform. The Gateway build copies these
# values into its pin table; the pin covers the hosted bytes, the upstream go2rtc digest is recorded for provenance.
source "$(dirname "$0")/common.sh"

dir="$1"; release="$2"
entry() { jq -n --arg asset "$1" --arg sha "$(sha256_of "$dir/$1")" --argjson size "$(size_of "$dir/$1")" '{asset: $asset, size: $size, sha256: $sha}'; }

platforms='{}'
for p in $PLATFORMS; do
  g="$(entry "go2rtc-$p.gz" | jq --arg up "$(cat "$dir/go2rtc-$p.upstream-sha256")" --arg v "$(jq -r .go2rtc.version "$VERSIONS")" '. + {version: $v, upstreamSha256: $up}')"
  f="$(entry "ffmpeg-$p.gz" | jq --arg v "$(jq -r .ffmpeg.version "$VERSIONS")" '. + {version: $v}')"
  platforms="$(jq --arg p "$p" --argjson g "$g" --argjson f "$f" '. + {($p): {go2rtc: $g, ffmpeg: $f}}' <<<"$platforms")"
done

files='[]'
for a in go2rtc-MIT.txt ffmpeg-LGPL-2.1.txt NOTICE.txt "ffmpeg-$(jq -r .ffmpeg.version "$VERSIONS").tar.xz" build-ffmpeg.sh; do
  files="$(jq --argjson e "$(entry "$a")" '. + [$e]' <<<"$files")"
done

jq -n --arg r "$release" --argjson p "$platforms" --argjson f "$files" \
  '{schema: 1, release: $r, repository: "SeeTouch/media-components", platforms: $p, files: $f}' >"$dir/components.json"
echo "wrote $dir/components.json"

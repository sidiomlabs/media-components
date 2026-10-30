#!/usr/bin/env bash
# Usage: make-manifest.sh <assetdir> <release> <commit>
# Writes <assetdir>/components.json: every asset's download URL, size and SHA-256 per platform, plus for each packed
# binary its unpacked size and SHA-256 (the Gateway bounds zlib's output with it and re-checks the installed file).
# The Gateway build copies these values into its pin table; the upstream go2rtc digest is recorded for provenance.
source "$(dirname "$0")/common.sh"

dir="$1"; release="$2"; commit="$3"
repo="sidiomlabs/media-components"
base="https://github.com/$repo/releases/download/$release/"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

entry() {
  jq -n --arg asset "$1" --arg url "$base$1" --arg sha "$(sha256_of "$dir/$1")" --argjson size "$(size_of "$dir/$1")" \
    '{asset: $asset, url: $url, size: $size, sha256: $sha}'
}
binary() {
  gzip -dc "$dir/$1" >"$work/bin"
  entry "$1" | jq --arg sha "$(sha256_of "$work/bin")" --argjson size "$(size_of "$work/bin")" \
    '. + {unpackedSize: $size, unpackedSha256: $sha}'
}

platforms='{}'
for p in $PLATFORMS; do
  g="$(binary "go2rtc-$p.gz" | jq --arg up "$(cat "$dir/go2rtc-$p.upstream-sha256")" --arg v "$(jq -r .go2rtc.version "$VERSIONS")" '. + {version: $v, upstreamSha256: $up}')"
  f="$(binary "ffmpeg-$p.gz" | jq --arg v "$(jq -r .ffmpeg.version "$VERSIONS")" '. + {version: $v}')"
  c="$(entry "ffmpeg-$p.configure.txt")"
  platforms="$(jq --arg p "$p" --argjson g "$g" --argjson f "$f" --argjson c "$c" '. + {($p): {go2rtc: $g, ffmpeg: $f, ffmpegConfigure: $c}}' <<<"$platforms")"
done

files='[]'
for a in go2rtc-MIT.txt go2rtc-THIRD-PARTY.txt ffmpeg-LGPL-2.1.txt NOTICE.txt \
         "ffmpeg-$(jq -r .ffmpeg.version "$VERSIONS").tar.xz" build-ffmpeg.sh common.sh versions.json; do
  files="$(jq --argjson e "$(entry "$a")" '. + [$e]' <<<"$files")"
done

jq -n --arg r "$release" --arg repo "$repo" --arg commit "$commit" --argjson p "$platforms" --argjson f "$files" \
  '{schema: 1, release: $r, repository: $repo, commit: $commit, platforms: $p, files: $f}' >"$dir/components.json"
echo "wrote $dir/components.json"

#!/usr/bin/env bash
# Usage: go2rtc-notices.sh <outfile>
# The go2rtc binary statically includes Go's standard library and its module dependencies. This writes their licence
# texts, from the go2rtc source at the pinned tag and commit, into one notices file shipped beside the binary.
source "$(dirname "$0")/common.sh"

out="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
tag="$(jq -r '.go2rtc.tag' "$VERSIONS")"
commit="$(jq -r '.go2rtc.commit' "$VERSIONS")"

git clone -q --depth 1 --branch "$tag" https://github.com/AlexxIT/go2rtc.git "$work/src"
actual="$(git -C "$work/src" rev-parse HEAD)"
[ "$actual" = "$commit" ] || { echo "go2rtc $tag is $actual, expected $commit" >&2; exit 1; }

cd "$work/src"
{
  echo "Third-party notices for go2rtc $tag ($commit)"
  echo
  echo "== Go standard library =="
  cat "$(go env GOROOT)/LICENSE"
  go mod download
  # Per target: modules used only on one platform are listed too.
  for target in linux/arm64 linux/amd64 darwin/arm64 windows/amd64; do
    GOOS="${target%/*}" GOARCH="${target#*/}" \
      go list -deps -f '{{with .Module}}{{if not .Main}}{{.Path}} {{.Version}} {{.Dir}}{{end}}{{end}}' ./...
  done | sort -u |
    while read -r path version dir; do
      echo
      echo "== $path $version =="
      found=0
      for f in "$dir"/LICENSE* "$dir"/LICENCE* "$dir"/COPYING* "$dir"/NOTICE*; do
        [ -f "$f" ] && { cat "$f"; found=1; }
      done
      [ "$found" = 1 ] || echo "(no licence file in the module; see https://pkg.go.dev/$path)"
    done
} >"$out"
echo "wrote $out"

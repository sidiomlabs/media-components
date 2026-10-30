#!/usr/bin/env bash
# Usage: build-ffmpeg.sh <platform> <outdir>
# Builds the minimal LGPL ffmpeg the go2rtc still path needs (`ffmpeg -i - -c:v mjpeg [-vf scale|transpose] -f mjpeg -`
# on an Annex-B H.264/H.265 key frame from stdin) and writes <outdir>/ffmpeg-<platform>.gz plus the exact configure line.
# No GPL or nonfree component, no autodetected system library, no network. Linux builds are fully static.
source "$(dirname "$0")/common.sh"

platform="$1"; out="$2"
require_platform "$platform"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

version="$(jq -r '.ffmpeg.version' "$VERSIONS")"
source_url="$(jq -r '.ffmpeg.source' "$VERSIONS")"
expected="$(jq -r '.ffmpeg.sha256' "$VERSIONS")"

fetch "$work/src.tar.xz" "$source_url" 67108864
verify_sha256 "$work/src.tar.xz" "$expected"
tar -xJf "$work/src.tar.xz" -C "$work"
cd "$work/ffmpeg-$version"

flags=(
  --disable-everything --disable-autodetect --disable-network
  --disable-doc --disable-debug --disable-programs --enable-ffmpeg
  --enable-static --disable-shared
  --enable-avfilter --enable-swscale
  --enable-protocol=fd,pipe,file
  --enable-demuxer=h264,hevc,mjpeg,image_jpeg_pipe
  --enable-parser=h264,hevc,mjpeg
  --enable-decoder=h264,hevc,mjpeg
  --enable-encoder=mjpeg
  --enable-muxer=mjpeg
  --enable-filter=scale,transpose,hflip,vflip,format,null,buffer,buffersink
  --extra-version=sidiom
)
exe="ffmpeg"
case "$platform" in
  linux-*) flags+=(--pkg-config-flags=--static --extra-ldflags=-static) ;;
  darwin-arm64) flags+=(--extra-cflags=-mmacosx-version-min=13.0 --extra-ldflags=-mmacosx-version-min=13.0) ;;
  win32-x64)
    flags+=(--enable-cross-compile --target-os=mingw32 --arch=x86_64 --cross-prefix=x86_64-w64-mingw32- --extra-ldflags=-static)
    exe="ffmpeg.exe" ;;
esac

for f in "${flags[@]}"; do case "$f" in --enable-gpl|--enable-nonfree|--enable-version3) echo "refused flag $f" >&2; exit 1 ;; esac; done

./configure "${flags[@]}"
make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
case "$platform" in
  win32-x64) x86_64-w64-mingw32-strip "$exe" ;;
  *) strip "$exe" ;;
esac

# Licence and feature checks on the built binary (the Windows one under wine).
run=(./"$exe")
[ "$platform" = "win32-x64" ] && run=(env WINEDEBUG=-all "$(command -v wine || command -v wine64)" "./$exe")
grep -q 'CONFIG_GPL 0' config.h && grep -q 'CONFIG_NONFREE 0' config.h
# Captured first: `grep -q` closing a pipe early would fail the pipeline under pipefail.
licence="$("${run[@]}" -hide_banner -L)"; decoders="$("${run[@]}" -hide_banner -decoders)"; encoders="$("${run[@]}" -hide_banner -encoders)"
grep -q 'GNU Lesser General Public' <<<"$licence"; grep -q 'version 2.1 of the License' <<<"$licence"
grep -Eq ' h264 ' <<<"$decoders"
grep -Eq ' hevc ' <<<"$decoders"
grep -Eq ' mjpeg ' <<<"$encoders"

chmod 0755 "$exe"
pack "$exe" "$out/ffmpeg-$platform.gz"
printf '%s\n' "./configure ${flags[*]}" >"$out/ffmpeg-$platform.configure.txt"
echo "ffmpeg $platform: $(size_of "$out/ffmpeg-$platform.gz") bytes packed"

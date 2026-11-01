# Sidiom media components

Release assets for the Sidiom Gateway's media component: go2rtc and a minimal LGPL ffmpeg per platform. The Gateway
starts bare and installs these only when the first camera driver is added (design
`docs/design/2026-10-30-camera-media-service.md` D2 and §3.3 in the Sidiom repository; ticket #1392 C0b).

## Trust

The Gateway build pins every asset's URL, size and SHA-256 (copied from a release's `components.json`). The pin is the
trust, not this host or the transport. A release is never overwritten; a new pin is a new release and a Gateway build.

## Platforms

`linux-arm64` (Wiren Board 8, Raspberry Pi 5), `linux-amd64` (Docker testenv, cloud test Gateways), `darwin-arm64`
(the desktop app on a Mac), `darwin-amd64` (an internal desktop build for Intel Macs), `win32-x64` (the desktop app on Windows).

## A release

| Asset | What |
| --- | --- |
| `go2rtc-<platform>.gz` | the upstream go2rtc binary (version in `versions.json`), checked against its upstream SHA-256, gzip-packed |
| `ffmpeg-<platform>.gz` | ffmpeg built by `scripts/build-ffmpeg.sh` with only what the still path needs |
| `ffmpeg-<platform>.configure.txt` | the exact configure line |
| `ffmpeg-<version>.tar.xz`, `build-ffmpeg.sh`, `common.sh`, `versions.json` | the corresponding source, unmodified from ffmpeg.org, and the build scripts |
| `go2rtc-MIT.txt`, `go2rtc-THIRD-PARTY.txt`, `ffmpeg-LGPL-2.1.txt`, `NOTICE.txt` | licences and notices (the third-party file covers the Go standard library and modules inside go2rtc) |
| `components.json` | URL, size and SHA-256 of every asset per platform, unpacked size and SHA-256 of each binary, the source commit: what the Gateway pins |

Each binary is its own gzip file so the Gateway unpacks it with Node's `zlib` only.

## Making a release

1. Change `versions.json` (new go2rtc version with its upstream SHA-256 from the GitHub release page, or a new ffmpeg
   version with the tarball SHA-256 after checking its signature against the FFmpeg release key) in a reviewed pull
   request.
2. Run the `release` workflow by hand on `main` with a new tag `media-YYYY.MM.N`. It refuses another branch, an
   existing release or tag, builds all five platforms and publishes with the tag on the built commit. Immutable releases
   and a tag ruleset for `media-*` in the repository settings keep a published release unchanged.
3. Copy `components.json` values into the Gateway's pin table in a reviewed Sidiom change; keep the previous pin.

Local check of one platform: `scripts/fetch-go2rtc.sh darwin-arm64 out && scripts/build-ffmpeg.sh darwin-arm64 out`.

## ffmpeg feature set

go2rtc's still (`GET /api/frame.jpeg`) runs `ffmpeg -hide_banner [-v <level>] -i - -c:v mjpeg [-vf scale=W:H,transpose] -f mjpeg -`
with one Annex-B H.264 or H.265 key frame on stdin (go2rtc v1.9.15 `internal/ffmpeg/jpeg.go`). The build enables the
fd, pipe and file protocols (ffmpeg 8 reads `-` through `fd:`), the h264/hevc/mjpeg/image_jpeg_pipe demuxers, parsers and decoders, the mjpeg encoder and muxer, and the
scale, transpose, flip, format and null filters; everything else, autodetected system libraries and the network are
off. Checked on a Mac with synthetic H.264 and H.265 key frames; spike S1 (#1389) and C0b will confirm it on real camera frames.

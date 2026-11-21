# Oku3D FFmpeg

The FFmpeg the [Oku3D](https://oku3d.com) media player ships, built with
[FFmpeg-Builds](https://github.com/FFmpeg-Builds/FFmpeg-Builds) scripts
as the `lgpl-oku3d-shared` variant for `win64`, `linux64`,
`linuxarm64` and `macosarm64`. The branch `oku3d` carries the changes
for every target; upstream is merged into it from its `master`.

## Why not the upstream LGPL build

One GPL component reached upstream's LGPL builds through an LGPL
library that links it:

- **zvbi's `src/packet-830.c`** (GPL-2.0-only, per zvbi's `COPYING.md`).
  The Teletext decoder calls zvbi's packet decoder, which calls into
  it, so a static link puts it in `libavcodec`. Upstream builds zvbi
  only for its nonfree variants since 2026-11-07, so its LGPL builds
  decode no Teletext any more; this build keeps zvbi without that file
  (see below), and `compare_surface.py` fails should its Teletext
  decoder go missing, which the comparison with upstream can no longer
  catch.

FFTW (GPL-2.0-or-later) reached them the same way, through Chromaprint
built with `FFT_LIB=fftw3`, until upstream switched Chromaprint to its
bundled KISS FFT (FFmpeg-Builds/FFmpeg-Builds#691, October 2026). This build
leaves Chromaprint out regardless, since only its fingerprint muxer
uses it, and `gpl_scan.py` still fails on FFTW should it return.

A third rests on link order: upstream builds LittleCMS with its
GPL-3.0 fast-float and threaded plugins and puts them on FFmpeg's link
line. Neither FFmpeg nor libjxl calls them, so they should not reach
the libraries; this build does not build them, so that no longer
depends on what the linker pulls in.

The player is not GPL software, so none of these may ship with it.

## What this build keeps

A player only reads, so everything that reads stays:

- every demuxer, input protocol, parser and bitstream filter;
- every codec, each through the decoder the upstream build picks for
  it, including the libraries those decoders are: dav1d (AV1), libjxl
  (JPEG XL), uavs3d (AVS3), zvbi (Teletext), libaribcaption (ARIB
  captions), plus game-music-emu and libopenmpt behind their demuxers,
  libbluray, and the protocol libraries (OpenSSL or Schannel, libssh,
  librist, libsrt, libzmq, gmp);
- the hardware decode routes the player opens: D3D11VA on Windows,
  VAAPI and Vulkan on Linux, and on both NVDEC with its CUDA device,
  which the player opens for stereo MV-HEVC alone, the one hardware
  decoder that returns both views (FFmpeg 9.1 on);
- the capture input it opens (DirectShow, Video4Linux2), the S/PDIF
  muxer it writes passthrough audio with, and the filters of its
  playback-speed chain;
- for its video export, the H.264 and H.265 encoders that hand the work
  to the GPU or the operating system - NVENC (Windows, Linux), AMF and
  Media Foundation (Windows), VA-API (Linux), VideoToolbox (macOS) -
  with the NVENC and AMF headers they build against, and the MP4 and
  Matroska muxers. No encoder that implements a codec itself is built,
  so the build carries no H.264 or H.265 encoding code of its own
  (owner decision 2026-10-30).

What goes: every other encoder and muxer, filters, output devices, other capture
inputs and hardware APIs, the external decoders upstream never picks
(libvpx, libaom, libopus, libvorbis, opencore-amr, openh264, aribb24),
and SVG decoding, whose librsvg brings glib, cairo and pango for a
format the player renders itself with resvg (owner decision
2026-10-12).

The stage-by-stage policy is `util/oku3d.sh`; `generate.sh` applies it
after sourcing each stage script. zvbi is built with
`patches/zvbi/0001-Leave-out-the-GPL-2-only-PDC-decoding.patch`, which
removes the GPL-2-only units and the 8/30 local time and PDC program-ID
events built on them. Teletext page decoding, text and bitmap alike, is
byte-identical before and after on real broadcasts.

`patches/ffmpeg/` holds changes to FFmpeg itself that upstream does not
carry; `build.sh` and `oku3d/macos/build.sh` apply them on top of the
release branch. A fix is submitted upstream too and dropped once the
branch carries it; a change kept here only says so:

- `0001-vc1_parser-time-a-frame-as-two-field-periods.patch` - raw VC-1
  streams without pulldown flags played at twice their rate since FFmpeg
  6.1. Reported upstream as
  [#25532](https://code.ffmpeg.org/FFmpeg/FFmpeg/issues/25532).
- `0002-hevcdec-start-the-last-layer-s-picture-before-base-layer-slices.patch`
  - frame threads decoded the base layers of consecutive two-view
  MV-HEVC access units one after the other, so a 4K 3D film decoded at
  0.69x realtime on 16 cores; with it, 1.79x. Kept here only (owner
  decision 2026-11-19): it has to be reapplied, or dropped if it no
  longer applies, with every FFmpeg update.

## macOS

`macosarm64` is built natively on a macOS runner by
`oku3d/macos/build.sh`, since macOS cannot run the Linux images the
other targets build in. It runs the same stage scripts under the same
stage policy - dependencies first, each stage's own download recipe
and build function, its install copied into the shared prefix - with
the environment of `oku3d/macos/env.sh` (Apple's clang, macOS 14 as
the oldest system, Homebrew's GNU tools for the stage scripts and none
of its libraries). The stage scripts branch on `macos*` where they
branch on the target at all, and read the Meson cross file from
`FFBUILD_MESON_CROSS` and zvbi's patches from `FFBUILD_PATCHES`, which
default to the paths the Docker images use.

The player decodes through VideoToolbox and captures through
AVFoundation; AudioToolbox stays off, since its decoders duplicate the
ones every other target decodes with. The libraries name themselves by
`@rpath`. `.github/workflows/oku3d-macos.yml`, which `oku3d.yml` calls
with the FFmpeg commit and date the other targets build, builds it, checks that it
loads on macOS 14 and links only the system and itself
(`oku3d/macos/check_links.py`), and compares what it reads with the
upstream `linuxarm64` build, as upstream publishes no macOS one.
`OKU3D_MACOS_LIST=1 oku3d/macos/build.sh macosarm64 lgpl-oku3d-shared
9.0` prints the stage order and the configure line on any host.

## How a build is checked

`.github/workflows/oku3d.yml` builds all four targets and, before
anything is published:

- `oku3d/gpl_scan.py` fails on any shipped library carrying FFTW, the
  zvbi 8/30 decoder, a GPL-only library in its configure line, or a GPL
  license string;
- `oku3d/surface.c` lists what a build reads, and
  `oku3d/compare_surface.py` fails on anything the upstream build in
  `oku3d/reference.env` reads that this one does not - checked natively
  on an x64 and an arm64 Linux runner, a Windows runner and a macOS
  runner.

A run with `doRelease` publishes the four archives, their checksums and
the four comparison reports as a release; the player's
`vendor/ffmpeg.lock` pins one of those releases.

## Updating from upstream

```bash
git fetch upstream
git checkout oku3d
git merge upstream/master
```

A stage upstream adds is dropped until `util/oku3d.sh` names it, so a
new dependency of a kept library fails the build rather than shipping
unreviewed. Point `oku3d/reference.env` at the upstream autobuild of the
same FFmpeg release when moving to a new one, so the comparison measures
against the build the player had.

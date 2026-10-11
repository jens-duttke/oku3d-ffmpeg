# Oku3D FFmpeg

The FFmpeg the [Oku3D](https://oku3d.com) media player ships, built with
[BtbN's FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) scripts
as the `lgpl-oku3d-shared` variant for `win64` and `linux64`. The
branch `oku3d` carries the changes; `master` follows upstream.

## Why not the upstream LGPL build

Two GPL components reach upstream's LGPL builds through LGPL libraries
that link them:

- **FFTW** (GPL-2.0-or-later). Chromaprint is built with `FFT_LIB=fftw3`,
  which its own README says makes the Chromaprint binary GPL, and it
  ends up in `libavformat`.
- **zvbi's `src/packet-830.c`** (GPL-2.0-only, per zvbi's `COPYING.md`).
  The Teletext decoder calls zvbi's packet decoder, which calls into
  it, so a static link puts it in `libavcodec`.

The player is not GPL software, so neither may ship with it.

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
  VAAPI and Vulkan on Linux;
- the capture input it opens (DirectShow, Video4Linux2), the S/PDIF
  muxer it writes passthrough audio with, and the filters of its
  playback-speed chain.

What goes: encoders, muxers, filters, output devices, other capture
inputs and hardware APIs, the external decoders upstream never picks
(libvpx, libaom, libopus, libvorbis, opencore-amr, openh264, aribb24),
and SVG decoding, whose librsvg brings glib, cairo and pango for a
format the player never opens (owner decision 2026-10-11).

The stage-by-stage policy is `util/oku3d.sh`; `generate.sh` applies it
after sourcing each stage script. zvbi is built with
`patches/zvbi/0001-Leave-out-the-GPL-2-only-PDC-decoding.patch`, which
removes the GPL-2-only units and the 8/30 local time and PDC program-ID
events built on them. Teletext page decoding, text and bitmap alike, is
byte-identical before and after on real broadcasts.

## How a build is checked

`.github/workflows/oku3d.yml` builds both targets and, before anything
is published:

- `oku3d/gpl_scan.py` fails on any shipped library carrying FFTW, the
  zvbi 8/30 decoder, a GPL-only library in its configure line, or a GPL
  license string;
- `oku3d/surface.c` lists what a build reads, and
  `oku3d/compare_surface.py` fails on anything the upstream build in
  `oku3d/reference.env` reads that this one does not - checked on Linux
  natively and on a Windows runner.

A run with `doRelease` publishes both archives, their checksums and the
two comparison reports as a release; the player's `vendor/ffmpeg.lock`
pins one of those releases.

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

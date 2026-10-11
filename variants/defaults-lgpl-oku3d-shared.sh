#!/bin/bash
# The Oku3D media player's build: the upstream LGPL shared build with its
# encoders, muxers, filters, output devices and the libraries only they
# use left out. What stays and why is in oku3d/README.md; the stage
# policy is util/oku3d.sh.
source "$(dirname "$BASH_SOURCE")"/defaults-lgpl-shared.sh

# ffprobe stays for diagnosing a build; ffmpeg itself would pull in the
# filters its command line needs, ffplay needs SDL.
FF_CONFIGURE+=" --disable-ffmpeg --disable-ffplay"
FF_CONFIGURE+=" --disable-encoders"
# S/PDIF framing for audio passthrough is the one container the player writes.
FF_CONFIGURE+=" --disable-muxers --enable-muxer=spdif"
# The playback-speed chain (abuffer, atempo, abuffersink) and the
# converter the filter graph inserts between them.
FF_CONFIGURE+=" --disable-filters --enable-filter=abuffer,abuffersink,atempo,aresample,aformat"
FF_CONFIGURE+=" --disable-outdevs --disable-indevs"
# Hardware decode APIs the player has no route for; the target files
# re-enable nothing, so only the routes FFmpeg detects remain.
FF_CONFIGURE+=" --disable-cuda --disable-cuda-llvm --disable-cuvid --disable-nvdec --disable-nvenc --disable-ffnvcodec --disable-amf --disable-vdpau"

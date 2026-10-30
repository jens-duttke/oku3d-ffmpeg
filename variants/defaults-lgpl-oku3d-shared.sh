#!/bin/bash
# The Oku3D media player's build: the upstream LGPL shared build with its
# encoders, muxers, filters, output devices and the libraries only they
# use left out, apart from what the player's video export writes with.
# What stays and why is in oku3d/README.md; the stage policy is
# util/oku3d.sh.
source "$(dirname "$BASH_SOURCE")"/defaults-lgpl-shared.sh

# ffprobe stays for diagnosing a build; ffmpeg itself would pull in the
# filters its command line needs, ffplay needs SDL.
FF_CONFIGURE+=" --disable-ffmpeg --disable-ffplay"
# The video export encodes H.264 and H.265 only through an encoder the
# GPU or the operating system provides, so the build carries no encoding
# implementation of its own; configure leaves out whichever of these a
# target has no API for.
FF_CONFIGURE+=" --disable-encoders"
FF_CONFIGURE+=" --enable-encoder=h264_nvenc,hevc_nvenc,h264_amf,hevc_amf,h264_mf,hevc_mf,h264_vaapi,hevc_vaapi,h264_videotoolbox,hevc_videotoolbox"
# S/PDIF framing for audio passthrough, and the MP4 and Matroska files
# the video export writes.
FF_CONFIGURE+=" --disable-muxers --enable-muxer=spdif,mov,mp4,matroska"
# The playback-speed chain (abuffer, atempo, abuffersink) and the
# converter the filter graph inserts between them.
FF_CONFIGURE+=" --disable-filters --enable-filter=abuffer,abuffersink,atempo,aresample,aformat"
FF_CONFIGURE+=" --disable-outdevs --disable-indevs"
# Hardware decode APIs the player has no route for; the target files
# re-enable nothing, so only the routes FFmpeg detects remain. NVENC and
# AMF stay detectable for the export's encoders.
FF_CONFIGURE+=" --disable-cuda --disable-cuda-llvm --disable-cuvid --disable-nvdec --disable-vdpau"

#!/bin/bash
source "$(dirname "$BASH_SOURCE")"/macos-install-shared.sh
source "$(dirname "$BASH_SOURCE")"/defaults-lgpl-oku3d-shared.sh
# The player decodes through VideoToolbox and captures through
# AVFoundation. AudioToolbox stays off: its decoders duplicate FFmpeg's
# own, which every other platform decodes with.
FF_CONFIGURE+=" --enable-indev=avfoundation --enable-videotoolbox --disable-audiotoolbox"
# The libraries name themselves by @rpath, so the player finds them in
# its bundle wherever it is installed.
FF_CONFIGURE+=" --install-name-dir=@rpath"

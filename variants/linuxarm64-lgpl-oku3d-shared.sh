#!/bin/bash
source "$(dirname "$BASH_SOURCE")"/linux-install-shared.sh
source "$(dirname "$BASH_SOURCE")"/defaults-lgpl-oku3d-shared.sh
# The player decodes through VAAPI and Vulkan and captures through V4L2.
FF_CONFIGURE+=" --enable-indev=v4l2"

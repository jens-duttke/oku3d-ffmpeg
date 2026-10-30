#!/bin/bash
source "$(dirname "$BASH_SOURCE")"/windows-install-shared.sh
source "$(dirname "$BASH_SOURCE")"/defaults-lgpl-oku3d-shared.sh
# The player decodes through D3D11VA, captures through DirectShow and
# encodes its video export through Media Foundation where neither NVENC
# nor AMF is present.
FF_CONFIGURE+=" --enable-indev=dshow"
FF_CONFIGURE+=" --disable-dxva2 --disable-d3d12va --disable-vulkan --disable-vaapi"

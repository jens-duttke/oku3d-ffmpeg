# Oku3D FFmpeg

> [!IMPORTANT]
> ### Watch everything in 3D with [Oku3D](https://oku3d.com)
>
> This repository builds the FFmpeg inside [**Oku3D**](https://oku3d.com), a free desktop media player I develop. Oku3D turns any 2D video or photo into 3D with AI depth estimation, live while it plays, and plays 3D content the way it was recorded.
>
> - **Any film in 3D:** the depth models run on your own GPU in real time, and the converted film can be saved as a 3D video file.
> - **Native 3D too:** side-by-side and top-bottom files, VR180 and VR360, and spatial videos from iPhone and Apple Vision Pro.
> - **On the screen you already have:** 3D TVs and projectors, VR headsets, glasses-free 3D displays, XREAL and other video glasses.
> - **Any GPU:** AMD, Intel and NVIDIA, on Windows, Linux and Apple Silicon Macs.
> - **Free, private, offline:** no account, no subscription, no upload. The depth models download once and run on your machine.
>
> **[Download Oku3D for free](https://oku3d.com)**

## What this repository is

The shared FFmpeg libraries Oku3D ships, built with the [FFmpeg-Builds](https://github.com/FFmpeg-Builds/FFmpeg-Builds) scripts as the `lgpl-oku3d-shared` variant for `win64`, `linux64`, `linuxarm64` and `macosarm64`. Oku3D is not GPL software, so the build carries no GPL code, and a check on every release fails it if any appears or if it reads less than the upstream LGPL build of the same day.

- **Releases:** [github.com/jens-duttke/oku3d-ffmpeg/releases](https://github.com/jens-duttke/oku3d-ffmpeg/releases), one archive per platform with its checksums and comparison report.
- **What differs from upstream and why:** [`oku3d/README.md`](../oku3d/README.md).
- **How the build scripts work in general:** the upstream documentation in [`README.md`](../README.md).

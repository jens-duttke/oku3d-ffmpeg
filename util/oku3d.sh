#!/bin/bash
# Stage policy of the lgpl-oku3d variants: which upstream stages the
# Oku3D media player's FFmpeg is built from. The player decodes, so the
# build keeps every demuxer, decoder, parser, bitstream filter and input
# protocol of the upstream LGPL build - each codec through the decoder
# the upstream build picks for it - and leaves out what only encodes,
# muxes, filters or renders, except the GPU and system video encoders
# its video export drives (NVENC and AMF need their headers here). The
# reasons per stage are in oku3d/README.md.
#
# keep     built, and FFmpeg is configured to use it, as upstream does
# deponly  built only because a kept stage links it; FFmpeg is configured
#          as if it were absent, so none of its own FFmpeg features ship
# drop     not built at all
#
# A stage missing from both lists is dropped, so a stage upstream adds
# is left out until someone has decided it belongs here; a kept stage
# that comes to depend on it then fails the build instead of shipping
# it unreviewed.

oku3d_stage_role() {
    local key="$1"

    case "$key" in
    mingw|mingw-std-threads|schannel)
        [[ $TARGET == win* ]] && echo keep || echo drop
        return
        ;;
    xorg-macros|vulkan/*|vaapi/*)
        [[ $TARGET == linux* ]] && echo keep || echo drop
        return
        ;;
    ffnvcodec)
        [[ $TARGET == win* || $TARGET == linux* ]] && echo keep || echo drop
        return
        ;;
    amf)
        [[ $TARGET == win* ]] && echo keep || echo drop
        return
        ;;
    x11/*)
        [[ $TARGET == linux* ]] && echo deponly || echo drop
        return
        ;;
    esac

    case "$key" in
    base|final|libiconv|zlib|gmp|libxml2|openssl|xz|lcms2|brotli|\
    libjxl/libjxl|dav1d|uavs3d|zvbi|libaribcaption|libbluray|libudfread|\
    gme|openmpt|libogg|vapoursynth|libssh|librist/mbedtls|librist/librist|\
    srt|libzmq|snappy|lcevcdec)
        echo keep
        ;;
    fonts/freetype|fonts/fontconfig|fonts/harfbuzz|libvorbis)
        echo deponly
        ;;
    *)
        echo drop
        ;;
    esac
}

# The key a stage script is known by here: its name without the order
# prefix, behind its directory's for a stage that lives in one.
oku3d_stage_key() {
    local script="$1"
    local name dir
    name="$(basename "$script" .sh)"
    name="${name#??-}"
    dir="$(basename "$(dirname "$script")")"
    if [[ "$dir" == "scripts.d" ]]; then
        echo "$name"
    else
        echo "${dir#??-}/${name}"
    fi
}

# Applies the policy to the stage script just sourced from "$SELF".
# Called by generate.sh right after each `source` of a stage script, so
# the stage's own ffbuild_enabled and ffbuild_configure are the ones it
# replaces.
oku3d_apply_stage_policy() {
    [[ $VARIANT == *oku3d* ]] || return 0
    case "$(oku3d_stage_role "$(oku3d_stage_key "$SELF")")" in
    keep)
        ;;
    deponly)
        ffbuild_configure() {
            type ffbuild_unconfigure &>/dev/null && ffbuild_unconfigure
            return 0
        }
        ;;
    drop)
        ffbuild_enabled() {
            return 1
        }
        ;;
    esac
}

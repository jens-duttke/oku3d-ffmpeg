#!/bin/bash
# Builds the lgpl-oku3d FFmpeg for macosarm64 natively on an Apple
# Silicon host, from the same stage scripts the Docker targets build
# from:
#
#   oku3d/macos/build.sh macosarm64 lgpl-oku3d-shared 9.0
#
# macOS runs no Linux containers, so where generate.sh writes each stage
# as a Dockerfile layer, this runs it in place: dependencies first, the
# source fetched by the stage's own download recipe, its build function
# run with the environment of oku3d/macos/env.sh, and its install copied
# into the shared prefix the next stage builds against - which is what
# the layer copy does in the Docker build. The stage policy of
# util/oku3d.sh and the configure flags each stage contributes are the
# same, so this target differs from the others only where a stage
# script branches on it.
#
# With OKU3D_MACOS_LIST=1 it only prints the stages in build order and
# the configure line, on any host, without fetching or building.
#
# The archive lands in artifacts/, named like the other targets'. Run it
# with a bash of version 4.3 or later - the associative arrays need one,
# and macOS ships 3.2 as /bin/bash.

set -eo pipefail
shopt -s globstar
cd "$(dirname "$0")/../.."
REPO_ROOT="$PWD"

source util/vars.sh "$@"
source util/oku3d.sh

[[ $TARGET == macos* ]] || { echo "oku3d/macos/build.sh builds the macOS targets only" >&2; exit 1; }

export TARGET VARIANT ADDINS_STR
export OKU3D_MACOS_ROOT="${OKU3D_MACOS_ROOT:-$REPO_ROOT/ffbuild-macos}"
LIST_ONLY="${OKU3D_MACOS_LIST:-}"
if [[ -z "$LIST_ONLY" ]]; then
    rm -rf "$OKU3D_MACOS_ROOT"
    mkdir -p "$OKU3D_MACOS_ROOT"/{bin,src,prefix}
    source oku3d/macos/env.sh
fi

# The two helpers the base image puts on PATH for the download recipes.
[[ -n "$LIST_ONLY" ]] || ln -s "$REPO_ROOT/images/base/git-mini-clone.sh" "$OKU3D_MACOS_ROOT/bin/git-mini-clone"
[[ -n "$LIST_ONLY" ]] || ln -s "$REPO_ROOT/images/base/retry-tool.sh" "$OKU3D_MACOS_ROOT/bin/retry-tool"
[[ -n "$LIST_ONLY" ]] || ln -s "$(brew --prefix)/bin/glibtoolize" "$OKU3D_MACOS_ROOT/bin/libtoolize"
for file in toolchain.cmake cross.meson; do
    [[ -n "$LIST_ONLY" ]] || sed "s|@FFBUILD_PREFIX@|$FFBUILD_PREFIX|g" "oku3d/macos/$file.in" > "$OKU3D_MACOS_ROOT/$file"
done

resolvestage() {
    [[ -d "$1" ]] && local SCRIPTDIR=("$1") || local SCRIPTDIR=(scripts.d/??-"$1")
    if [[ -d "${SCRIPTDIR[0]}" ]]; then
        echo scripts.d/??-"${1}"
    else
        echo scripts.d/??-"${1}.sh"
    fi
}

# The stage scripts behind a stage name: the one script, or every script
# of its directory in order.
stage_scripts() {
    local stage
    stage="$(resolvestage "$1")"
    if [[ -d "$stage" ]]; then
        printf '%s\n' "$stage"/??-*.sh
    else
        printf '%s\n' "$stage"
    fi
}

# The stages a stage depends on, after the policy: none for a stage the
# policy drops or the stage itself disables.
stagedeps() {
    local script
    for script in $(stage_scripts "$1"); do
        (
            SELF="$script"
            source util/dl_functions.sh
            source "$script"
            oku3d_apply_stage_policy
            ffbuild_enabled || exit 0
            ffbuild_depends
        )
    done | sort -u
}

# Run one stage script the way util/run_stage.sh runs it in its layer.
run_stage() {
    local script="$1"
    (
        SELF="$script"
        STAGENAME="$(basename "$script" .sh)"
        source util/dl_functions.sh
        source "$script"
        oku3d_apply_stage_policy
        ffbuild_enabled || exit 0
        if [[ -n "$LIST_ONLY" ]]; then
            echo "stage $script"
            exit 0
        fi

        echo "::group::stage $STAGENAME"
        local key patches
        key="$(oku3d_stage_key "$script")"
        patches="$REPO_ROOT/patches/${key##*/}"
        [[ -d "$patches" ]] && export FFBUILD_PATCHES="$patches"

        rm -rf "$FFBUILD_DESTDIR"
        local src="$OKU3D_MACOS_ROOT/src/$STAGENAME"
        rm -rf "$src"
        mkdir -p "$src"
        cd "$src"
        local recipe
        recipe="$(ffbuild_dockerdl)"
        # The recipe leaves the shell in the source root, as the
        # download step archives it.
        [[ -n "$recipe" ]] && eval "set -e; $recipe"

        [[ -n "${STAGE_CFLAGS:-}" ]] && export CFLAGS="$CFLAGS $STAGE_CFLAGS"
        [[ -n "${STAGE_CXXFLAGS:-}" ]] && export CXXFLAGS="$CXXFLAGS $STAGE_CXXFLAGS"
        [[ -n "${STAGE_LDFLAGS:-}" ]] && export LDFLAGS="$LDFLAGS $STAGE_LDFLAGS"
        ffbuild_dockerbuild

        if [[ -d "$FFBUILD_DESTPREFIX" ]]; then
            find "$FFBUILD_DESTDIR" -name "*.la" -delete
            # The C++ stages name GCC's runtime in their pkg-config files;
            # Apple's toolchain has only libc++, under its own name.
            find "$FFBUILD_DESTPREFIX" -name "*.pc" -exec sed -i 's/-lstdc++/-lc++/g' {} +
            rm -rf "$FFBUILD_DESTPREFIX"/bin
            cp -a "$FFBUILD_DESTPREFIX"/. "$FFBUILD_PREFIX"/
        fi
        rm -rf "$FFBUILD_DESTDIR" "$src"
        echo "::endgroup::"
    )
}

declare -A BUILT
BUILT_ORDER=()
build_stage() {
    local stage="$1" dep script
    [[ -v BUILT["$stage"] ]] && return 0
    BUILT["$stage"]=1
    BUILT_ORDER+=("$stage")
    for dep in $(stagedeps "$stage"); do
        build_stage "$dep"
    done
    for script in $(stage_scripts "$stage"); do
        run_stage "$script"
    done
}

ENTRYSCRIPT="$(ls -1d scripts.d/* | tail -n 1)"
ENTRY="$(basename "$ENTRYSCRIPT" .sh)"
ENTRY="${ENTRY#??-}"
build_stage "$ENTRY"

# What each built stage asks of FFmpeg's configure, collected the way
# generate.sh collects it for the Docker targets' final image.
get_output() {
    (
        SELF="$1"
        source "$1"
        oku3d_apply_stage_policy
        if ffbuild_enabled; then
            ffbuild_$2 || exit 0
        else
            ffbuild_un$2 || exit 0
        fi
    )
}

source "variants/${TARGET}-${VARIANT}.sh"
for addin in ${ADDINS[*]}; do
    source "addins/${addin}.sh"
done

for stage in "${BUILT_ORDER[@]}"; do
    for script in $(stage_scripts "$stage"); do
        FF_CONFIGURE+=" $(get_output "$script" configure)"
        FF_CFLAGS+=" $(get_output "$script" cflags)"
        FF_CXXFLAGS+=" $(get_output "$script" cxxflags)"
        FF_LDFLAGS+=" $(get_output "$script" ldflags)"
        FF_LDEXEFLAGS+=" $(get_output "$script" ldexeflags)"
        FF_LIBS+=" $(get_output "$script" libs)"
    done
done
FF_CONFIGURE="$(xargs <<< "$FF_CONFIGURE")"
FF_CFLAGS="$(xargs <<< "$FF_CFLAGS")"
FF_CXXFLAGS="$(xargs <<< "$FF_CXXFLAGS")"
FF_LDFLAGS="$(xargs <<< "$FF_LDFLAGS")"
FF_LDEXEFLAGS="$(xargs <<< "${FF_LDEXEFLAGS:-}")"
FF_LIBS="$(xargs <<< "${FF_LIBS:-}")"

if [[ -n "$LIST_ONLY" ]]; then
    echo "configure $FF_CONFIGURE"
    echo "cflags $FF_CFLAGS | ldflags $FF_LDFLAGS | libs $FF_LIBS"
    exit 0
fi

FFMPEG_REPO="${FFMPEG_REPO:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_REPO="${FFMPEG_REPO_OVERRIDE:-$FFMPEG_REPO}"
GIT_BRANCH="${GIT_BRANCH:-master}"
GIT_BRANCH="${GIT_BRANCH_OVERRIDE:-$GIT_BRANCH}"

echo "::group::ffmpeg"
FFPREFIX="$OKU3D_MACOS_ROOT/ffprefix"
cd "$OKU3D_MACOS_ROOT"
git clone --filter=blob:none --branch="$GIT_BRANCH" "$FFMPEG_REPO" ffmpeg
cd ffmpeg
# shellcheck disable=SC2086 # the flag lists are word lists, as in build.sh
./configure --prefix="$FFPREFIX" --pkg-config-flags="--static" $FFBUILD_TARGET_FLAGS $FF_CONFIGURE \
    --extra-cflags="$FF_CFLAGS" --extra-cxxflags="$FF_CXXFLAGS" --extra-libs="$FF_LIBS" \
    --extra-ldflags="$FF_LDFLAGS" --extra-ldexeflags="$FF_LDEXEFLAGS -Wl,-rpath,@executable_path/../lib" \
    --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --nm="$NM" \
    --extra-version="$(date +%Y%m%d)" || { cat ffbuild/config.log; exit 1; }
make -j"$(nproc)" V=1
make install install-doc
# Local symbols only: the libraries keep every exported one.
find "$FFPREFIX/lib" -name '*.dylib' -type f -exec strip -x {} +
strip "$FFPREFIX"/bin/*
echo "::endgroup::"

cd "$REPO_ROOT"
BUILD_NAME="ffmpeg-$("$OKU3D_MACOS_ROOT/ffmpeg/ffbuild/version.sh" "$OKU3D_MACOS_ROOT/ffmpeg")-${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"
PKGROOT="$OKU3D_MACOS_ROOT/pkgroot"
mkdir -p "$PKGROOT/$BUILD_NAME" artifacts
package_variant "$FFPREFIX" "$PKGROOT/$BUILD_NAME"
[[ -n "$LICENSE_FILE" ]] && cp "$OKU3D_MACOS_ROOT/ffmpeg/$LICENSE_FILE" "$PKGROOT/$BUILD_NAME/LICENSE.txt"
tar -C "$PKGROOT" -I "xz -T0" -cf "artifacts/${BUILD_NAME}.tar.xz" "$BUILD_NAME"
echo "artifacts/${BUILD_NAME}.tar.xz"

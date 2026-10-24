#!/bin/bash

SCRIPT_REPO="https://github.com/zapping-vbi/zvbi"
SCRIPT_COMMIT="d3a5ee9f2b047bf16cd1ee5ccf6ec05ee75409d0"

ffbuild_depends() {
    echo base
    echo libiconv
}

ffbuild_enabled() {
    return 0
}

ffbuild_dockerstage() {
    to_df "RUN --mount=src=${SELF},dst=/stage.sh --mount=src=${SELFCACHE},dst=/cache.tar.xz --mount=src=patches/zvbi,dst=/patches run_stage /stage.sh"
}

ffbuild_dockerbuild() {
    # The lgpl-oku3d variants leave out zvbi's GPL-2-only PDC decoding
    # (src/packet-830.*, src/pdc.*), which the Teletext decoder would
    # otherwise link into an LGPL build.
    if [[ $VARIANT == *oku3d* ]]; then
        for patch in "${FFBUILD_PATCHES:-/patches}"/*.patch; do
            echo "Applying $patch"
            git am < "$patch"
        done
    fi

    ./autogen.sh

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --disable-shared
        --enable-static
        --with-pic
        --without-doxygen
        --without-x
        --disable-dvb
        --disable-bktr
        --disable-nls
        --disable-proxy
    )

    if [[ $TARGET == win* || $TARGET == linux* || $TARGET == macos* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    else
        echo "Unknown target"
        return -1
    fi

    ./configure "${myconf[@]}"
    make -C src -j$(nproc)
    make -C src install DESTDIR="$FFBUILD_DESTDIR"
    make SUBDIRS=. install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libzvbi
}

ffbuild_unconfigure() {
    echo --disable-libzvbi
}

#!/bin/bash

SCRIPT_REPO="https://gitlab.freedesktop.org/freetype/freetype.git"
SCRIPT_COMMIT="4ba7c3d82ab8b3cc80b869337d2c2b1913c5e415"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    ./autogen.sh

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --without-harfbuzz
        --disable-shared
        --enable-static
    )

    if [[ $TARGET == win* || $TARGET == linux* || $TARGET == macos* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    else
        echo "Unknown target"
        return -1
    fi

    # The scaler for Apple's HVF fonts is found by its SDK header, from
    # the macOS 15.4 SDK on, and links a library macOS 14 does not have.
    if [[ $TARGET == macos* ]]; then
        myconf+=( ac_cv_header_hvf_Scaler_h=no )
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

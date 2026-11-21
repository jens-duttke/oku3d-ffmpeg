#!/bin/bash
# The build environment of the macosarm64 target - what the Docker image
# of a Linux target sets with ENV, set here for a native build on an
# Apple Silicon host. Sourced by oku3d/macos/build.sh with
# OKU3D_MACOS_ROOT pointing at the work directory.
#
# Every stage script expects GNU tools under their plain names (sed -i,
# cp -a, nproc, make 4, libtoolize), which macOS does not have, so the
# Homebrew GNU tool directories go in front of PATH. GNU libtool is the
# exception: CMake archives with Apple's `libtool -static`, which the GNU
# one of the same name refuses, so only `libtoolize` is put in reach
# (oku3d/macos/build.sh links it). Homebrew's
# libraries never reach the build: pkg-config only searches the build's
# own prefix, and CMake is told to ignore Homebrew's.

export MACOSX_DEPLOYMENT_TARGET=14.0

BREW="$(brew --prefix)"
for tool in coreutils gnu-sed gnu-tar findutils make grep; do
    PATH="$BREW/opt/$tool/libexec/gnubin:$PATH"
done
PATH="$OKU3D_MACOS_ROOT/bin:$BREW/opt/bison/bin:$BREW/opt/flex/bin:$PATH"
export PATH

export FFBUILD_TOOLCHAIN=aarch64-apple-darwin
export FFBUILD_CROSS_PREFIX=""
export FFBUILD_RUST_TARGET=aarch64-apple-darwin
export FFBUILD_PREFIX="$OKU3D_MACOS_ROOT/prefix"
export FFBUILD_DESTDIR="$OKU3D_MACOS_ROOT/dest"
export FFBUILD_DESTPREFIX="$FFBUILD_DESTDIR$FFBUILD_PREFIX"
export FFBUILD_CMAKE_TOOLCHAIN="$OKU3D_MACOS_ROOT/toolchain.cmake"
export FFBUILD_MESON_CROSS="$OKU3D_MACOS_ROOT/cross.meson"
export FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --arch=aarch64 --target-os=darwin"

export PKG_CONFIG=pkg-config
export PKG_CONFIG_LIBDIR="$FFBUILD_PREFIX/lib/pkgconfig:$FFBUILD_PREFIX/share/pkgconfig"
unset PKG_CONFIG_PATH

export CC=clang CXX=clang++ LD=ld AR=ar RANLIB=ranlib NM=nm STRIP=strip

COMMON_FLAGS="-O2 -pipe -arch arm64 -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -fstack-protector-strong"
export CFLAGS="-I$FFBUILD_PREFIX/include $COMMON_FLAGS -fPIC -DPIC -D_FORTIFY_SOURCE=2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$FFBUILD_PREFIX/lib $COMMON_FLAGS"
export STAGE_CFLAGS="-fvisibility=hidden"
export STAGE_CXXFLAGS="-fvisibility=hidden"

#!/bin/bash
# Builds libwebp-imageio.dylib for arm64 (macOS 11+), the native half of the game's webp-imageio-0.1.6.jar.
# That jar carries only an x86_64 copy, so without this the arm64 Java can't load the first .webp texture
# (MagicLib ships one) and the game hangs while loading.
#   C side:  github.com/sejda-pdf/webp-imageio tag v0.1.6 (Apache-2.0), the version the game ships
#   libwebp: chromium.googlesource.com/webm/libwebp tag v1.6.0 (BSD), built from source and linked statically
# Usage: build_webp.sh <empty work dir> <output libwebp-imageio.dylib>
# Needs: git, make, Xcode Command Line Tools, Temurin JDK 17 (JNI headers).
set -euo pipefail
WORK="$1"; OUT="$2"
JDK=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
SDK="$(xcrun --show-sdk-path)"
FLAGS="-isysroot $SDK -arch arm64 -mmacosx-version-min=11.0 -O2 -fPIC"
export ZERO_AR_DATE=1   # reproducible static archives
mkdir -p "$WORK"; cd "$WORK"

git clone --quiet --depth 1 --branch v1.6.0 https://chromium.googlesource.com/webm/libwebp libwebp
git clone --quiet --depth 1 --branch v0.1.6 https://github.com/sejda-pdf/webp-imageio.git webp-imageio

# libwebp's plain makefile: only the two static libraries webp-imageio needs (no image tools, no png/jpeg deps).
make -s -C libwebp -f makefile.unix -j"$(sysctl -n hw.ncpu)" CC=clang EXTRA_FLAGS="$FLAGS" \
    src/libwebp.a sharpyuv/libsharpyuv.a

C=webp-imageio/src/main/c
clang $FLAGS -dynamiclib -I"$JDK/include" -I"$JDK/include/darwin" -Ilibwebp/src -I"$C" \
    "$C/webp-imageio.c" libwebp/src/libwebp.a libwebp/sharpyuv/libsharpyuv.a \
    -install_name @rpath/libwebp-imageio.dylib -o "$OUT"
strip -S -x "$OUT"
file "$OUT"; otool -L "$OUT" | tail -n +2
echo "JNI functions: $(nm -gU "$OUT" | grep -c ' _Java_')"

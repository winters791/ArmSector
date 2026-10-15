#!/bin/bash
# Compiles LWJGL 2.9.3 liblwjgl for macOS arm64 (mirrors platform_build/macosx_ant/build.xml).
set -e
L="$1"; OUT="$2"
JDK=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
SDK=$(xcrun --show-sdk-path)
cd "$L"

OBJ=bin/arm64; rm -rf $OBJ; mkdir -p $OBJ
CFLAGS="-isysroot $SDK -arch arm64 -mmacosx-version-min=11.0 -O2 -fPIC -w -Wno-error=implicit-function-declaration -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion
  -I$JDK/include -I$JDK/include/darwin -Isrc/native/common -Isrc/native/common/opengl -Isrc/native/macosx -Iheaders"
fail=0
for f in src/native/macosx/*.m src/native/macosx/*.c src/native/common/*.c src/native/common/opengl/*.c \
         src/native/generated/openal/*.c src/native/generated/opencl/*.c src/native/generated/opengl/*.c; do
  o=$OBJ/$(basename "${f%.*}").o
  clang $CFLAGS -ObjC -c "$f" -o "$o" 2> "$o.log" || { echo "FAILED: $f"; head -20 "$o.log"; fail=1; }
done
[ $fail = 0 ] || exit 1
nm -j -g $OBJ/*.o | grep -E "J(ava|NI)_[^.]*$" > bin/lwjgl.symbols
clang -isysroot $SDK -arch arm64 -mmacosx-version-min=11.0 -dynamiclib -install_name @rpath/liblwjgl.dylib -o "$OUT" $OBJ/*.o \
  -exported_symbols_list bin/lwjgl.symbols \
  -framework Foundation -framework AppKit -framework Carbon -framework OpenGL -framework QuartzCore \
  -L$JDK/lib -ljawt -Wl,-rpath,@executable_path/../lib -Wl,-rpath,@loader_path
strip -S -x "$OUT"
file "$OUT"; wc -l < bin/lwjgl.symbols

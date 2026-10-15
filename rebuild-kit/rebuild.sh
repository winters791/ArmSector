#!/bin/bash
# Rebuilds native/macosx-arm64/liblwjgl.dylib from the official LWJGL 2.9.3 source.
# Usage: rebuild.sh <empty work dir> <output liblwjgl.dylib>
# Needs: git, Xcode Command Line Tools, Temurin JDK 11 + 17 (arm64) in /Library/Java/JavaVirtualMachines.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; WORK="$1"; OUT="$2"
mkdir -p "$WORK"; cd "$WORK"
git clone --quiet --depth 1 --branch lwjgl2.9.3 https://github.com/LWJGL/lwjgl.git lwjgl2
L="$WORK/lwjgl2"
python3 -I "$HERE/patch_sources.py" "$L"
"$HERE/generate.sh" "$L" 2>&1 | grep -v '^Note:'
cd "$L"   # JNI headers for the hand-written natives
CLASSES=$(grep -h -o '"org_lwjgl[^"]*\.h"' -r src/native/macosx src/native/common | tr -d '"' | sort -u | grep -v -e opengles -e MacOSXSysImplementation | sed 's/\.h$//' \
  | while read h; do f=$(echo "$h" | sed 's#_#/#g').java; for d in src/java src/generated; do [ -f "$d/$f" ] && echo "$d/$f"; done; done; true)
mkdir -p bin/hdr headers
/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home/bin/javac -nowarn -Xlint:none -implicit:none -d bin/hdr -h headers \
  -sourcepath src/java:src/generated -cp "$(ls libs/*.jar | tr '\n' ':')" $CLASSES 2>&1 | grep -v '^Note' || true
"$HERE/build_natives.sh" "$L" "$OUT"

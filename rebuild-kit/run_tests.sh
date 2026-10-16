#!/bin/bash
# Tests the arm64 runtime and natives installed in a Starsector.app:
#   LwjglSmoke     OpenAL + windowed + fullscreen GL (the fullscreen part takes over the screen for ~4 s)
#   LwjglDpiProbe  the windowed GL surface is 1x, not Retina 2x
#   WebpProbe      the game's webp-imageio decodes WebP with the arm64 libwebp-imageio.dylib, pixel-identical to
#                  the original x86 library (compared under Rosetta when it's installed): test.webp, plus up to
#                  three .webp files from the install's mods
# Usage: run_tests.sh [/path/to/Starsector.app]     (needs a JDK 17 for javac; set JAVAC to pick one)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="${1:-/Applications/Starsector.app}"; APP="${APP%/}"
JAVAC="${JAVAC:-/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/bin/javac}"
JAVA_DIR="$APP/Contents/Resources/Java"
TEST_WEBP_CRC=e0e5a1c9   # test.webp decoded by the original x86 library
OUT="$(mktemp -d)"; trap 'rm -rf "${OUT:?}"' EXIT

"$JAVAC" -nowarn -d "$OUT" -cp "$JAVA_DIR/lwjgl.jar" "$HERE/LwjglSmoke.java" "$HERE/LwjglDpiProbe.java" "$HERE/WebpProbe.java"
cd "$JAVA_DIR"
run() { ../../Home-arm64/bin/java -cp "$OUT:lwjgl.jar" -Djava.library.path=../../Resources/Java/native/macosx-arm64 "$@"; }
webp_arm64() { ../../Home-arm64/bin/java -cp "../../Resources/Java/native/macosx-arm64-cp:$OUT:webp-imageio-0.1.6.jar" WebpProbe "$1" 2>&1 | tail -1; }
webp_x86() { arch -x86_64 ../../Home/bin/java -cp "$OUT:webp-imageio-0.1.6.jar" WebpProbe "$1" 2>&1 | tail -1; }

echo "== LwjglSmoke"
run LwjglSmoke | tee "$OUT/smoke.txt"
echo "== LwjglDpiProbe"
run LwjglDpiProbe | tee "$OUT/dpi.txt"

fail=0
grep -q '^arch=aarch64 ' "$OUT/smoke.txt"   || { echo "FAIL: not running on the arm64 Java"; fail=1; }
grep -q '^READY windowed$' "$OUT/smoke.txt"   || { echo "FAIL: windowed GL"; fail=1; }
grep -q '^READY fullscreen$' "$OUT/smoke.txt" || { echo "FAIL: fullscreen GL"; fail=1; }
grep -q '^OK$' "$OUT/smoke.txt"               || { echo "FAIL: LwjglSmoke didn't finish"; fail=1; }
grep -q '1x (correct)' "$OUT/dpi.txt"         || { echo "FAIL: GL surface is not 1x"; fail=1; }

echo "== WebpProbe"
rosetta=0; arch -x86_64 /usr/bin/true 2>/dev/null && [ -x ../../Home/bin/java ] && rosetta=1
arm="$(webp_arm64 "$HERE/test.webp")"; echo "test.webp  arm64: $arm"
case "$arm" in "aarch64: "*"pixelCRC=$TEST_WEBP_CRC") ;; *) echo "FAIL: test.webp decode on arm64"; fail=1 ;; esac
while IFS= read -r f; do   # mod folder names can contain spaces
    arm="$(webp_arm64 "$f")"; echo "$(basename "$f")  arm64: $arm"
    if [ $rosetta = 1 ]; then
        x86="$(webp_x86 "$f")"; echo "$(basename "$f")  x86:   $x86"
        [ "${arm#aarch64: }" = "${x86#x86_64: }" ] || { echo "FAIL: $(basename "$f") decodes differently on arm64"; fail=1; }
    fi
done < <(find "$APP/mods" -name '*.webp' 2>/dev/null | head -3)

[ $fail = 0 ] && echo "ALL TESTS PASSED"
exit $fail

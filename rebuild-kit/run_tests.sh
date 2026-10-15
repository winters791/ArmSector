#!/bin/bash
# Runs LwjglSmoke (OpenAL + windowed + fullscreen GL) and LwjglDpiProbe (1x vs 2x GL surface) with the arm64
# runtime and natives installed in a Starsector.app. The fullscreen part takes over the screen for ~4 s.
# Usage: run_tests.sh [/path/to/Starsector.app]     (needs a JDK 17 for javac; set JAVAC to pick one)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="${1:-/Applications/Starsector.app}"; APP="${APP%/}"
JAVAC="${JAVAC:-/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/bin/javac}"
JAVA_DIR="$APP/Contents/Resources/Java"
OUT="$(mktemp -d)"; trap 'rm -rf "${OUT:?}"' EXIT

"$JAVAC" -nowarn -d "$OUT" -cp "$JAVA_DIR/lwjgl.jar" "$HERE/LwjglSmoke.java" "$HERE/LwjglDpiProbe.java"
cd "$JAVA_DIR"
run() { ../../Home-arm64/bin/java -cp "$OUT:lwjgl.jar" -Djava.library.path=../../Resources/Java/native/macosx-arm64 "$@"; }

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
[ $fail = 0 ] && echo "ALL TESTS PASSED"
exit $fail

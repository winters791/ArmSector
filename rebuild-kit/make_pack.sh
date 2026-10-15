#!/bin/bash
# Assembles the release zip from this repository, the arm64 natives, and a Temurin 17 aarch64 JDK.
# Usage: make_pack.sh <dir with liblwjgl.dylib + openal.dylib> <Temurin 17 aarch64 JDK home> <output dir>
#   e.g. make_pack.sh /Applications/Starsector.app/Contents/Resources/Java/native/macosx-arm64 \
#        /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home dist
# Writes <output dir>/ArmSector-<version>.zip and the OpenAL Soft source archive
# (LGPL: attach it to the release next to the zip).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/.." && pwd)"
NATIVES="$1"; JDK="$2"; OUTDIR="$3"
VERSION="$(sed -n 's/^PACK_VERSION="\(.*\)"$/\1/p' "$REPO/install.sh")"
NAME="ArmSector-$VERSION"
OPENAL_COMMIT=0d5d3adf0b532c58c7e171078232fc390e18d931

for f in liblwjgl.dylib openal.dylib; do
    [ "$(lipo -archs "$NATIVES/$f")" = arm64 ] || { echo "$NATIVES/$f is not an arm64 library" >&2; exit 1; }
done
mkdir -p "$OUTDIR"; OUTDIR="$(cd "$OUTDIR" && pwd)"
STAGE="$OUTDIR/stage"; rm -rf "${STAGE:?}"; mkdir -p "$STAGE/$NAME"
P="$STAGE/$NAME"

cp "$REPO/README.md" "$REPO/LICENSE" "$REPO/install.sh" "$REPO/uninstall.sh" "$P/"
chmod 755 "$P/install.sh" "$P/uninstall.sh"
ditto "$REPO/LICENSES" "$P/LICENSES"
ditto "$REPO/rebuild-kit" "$P/rebuild-kit"
mkdir -p "$P/payload/native/macosx-arm64"
cp "$NATIVES/liblwjgl.dylib" "$NATIVES/openal.dylib" "$P/payload/native/macosx-arm64/"
chmod 755 "$P/payload/native/macosx-arm64/"*.dylib
"$HERE/make_runtime.sh" "$JDK" "$P/payload/Home-arm64"
chmod -R u+w "$P"                    # jlink's legal/ files are read-only
(cd "$P" && find payload -type f | LC_ALL=C sort | xargs shasum -a 256 > SHA256SUMS.txt)

rm -f "$OUTDIR/$NAME.zip"
(cd "$STAGE" && zip -q -r -X -y "$OUTDIR/$NAME.zip" "$NAME")
rm -rf "${STAGE:?}"

SRC="$OUTDIR/openal-soft-1.23.1-lwjgl-${OPENAL_COMMIT:0:7}-source.tar.gz"
[ -f "$SRC" ] || curl -fsSL -o "$SRC" "https://github.com/LWJGL-CI/openal-soft/archive/$OPENAL_COMMIT.tar.gz"

echo; ls -l "$OUTDIR/$NAME.zip" "$SRC"
shasum -a 256 "$OUTDIR/$NAME.zip" "$SRC"

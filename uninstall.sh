#!/bin/bash
# Removes ArmSector: restores the launcher saved by install.sh and deletes the arm64 runtime and natives
# that install.sh added (Home-arm64, native/macosx-arm64, native/macosx-arm64-cp).
#
#   bash uninstall.sh [/path/to/Starsector.app]    (default: /Applications/Starsector.app)
set -euo pipefail

PACK_NAME="ArmSector"
PACK_VERSION="1.1.0"
MARKER=".installed-by-armsector"
BLOCK_TAG="armsector"
SUFFIX=".before-armsector"

APP="${1:-/Applications/Starsector.app}"
APP="${APP%/}"
C="$APP/Contents"
LAUNCHER="$C/MacOS/starsector_mac.sh"
BACKUP="$LAUNCHER$SUFFIX"

say() { printf '%s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

say "$PACK_NAME $PACK_VERSION — uninstaller"
say "Starsector: $APP"
say ""

[ -f "$LAUNCHER" ] ||
    die "No Starsector launcher at $LAUNCHER. If the game is somewhere else, run: bash uninstall.sh /path/to/Starsector.app"

# True if a Starsector started from this install is running (its working directory is inside the app).
game_running() {
    local app_real pid cwd
    app_real="$(cd "$APP" && pwd -P)"
    for pid in $(pgrep -f com.fs.starfarer.StarfarerLauncher 2>/dev/null || true); do
        cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
        case "$cwd" in "$app_real"/*) return 0 ;; esac
    done
    return 1
}
if game_running; then
    die "Starsector is running from this install. Quit it and run uninstall.sh again."
fi

# 1. Launcher
if grep -q ">>> $BLOCK_TAG" "$LAUNCHER"; then
    [ -f "$BACKUP" ] ||
        die "The launcher has the pack's switch but its backup ($(basename "$BACKUP")) is missing, so it can't be restored. Nothing was changed. To stop using the patch, open the launcher and set USE_NATIVE_ARM64=0."
    ! grep -q ">>> $BLOCK_TAG" "$BACKUP" ||
        die "The launcher backup ($(basename "$BACKUP")) already contains the pack's switch, so restoring it wouldn't help. Nothing was changed."
    mv -f "$BACKUP" "$LAUNCHER"      # the backup was made with cp -p: original contents and permissions
    say "Restored Contents/MacOS/starsector_mac.sh from $(basename "$BACKUP")"
else
    say "The launcher doesn't have the pack's switch; left as it is."
fi

# 2. Runtime and natives (only directories that carry the pack's marker are deleted)
for d in "$C/Home-arm64" "$C/Resources/Java/native/macosx-arm64" "$C/Resources/Java/native/macosx-arm64-cp"; do
    name="${d#"$C"/}"
    if [ -f "$d/$MARKER" ]; then
        rm -rf "${d:?}"
        say "Removed Contents/$name"
    elif [ -e "$d" ]; then
        say "Left Contents/$name (not installed by this pack)"
    fi
    if [ -e "$d$SUFFIX" ] && [ ! -e "$d" ]; then
        mv "$d$SUFFIX" "$d"
        say "Put back your earlier Contents/$name"
    fi
done

say ""
say "Done. Starsector is back to its previous setup."

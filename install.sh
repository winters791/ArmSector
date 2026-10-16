#!/bin/bash
# ArmSector: run Starsector natively on Apple Silicon Macs. Installs into a Starsector 0.98a install that has a
# Java 17 community pack.
#
#   bash install.sh [/path/to/Starsector.app]      (default: /Applications/Starsector.app)
#
# What it changes inside Starsector.app (nothing else on the Mac):
#   Contents/Home-arm64/                        arm64 Java 17 runtime (from payload/)
#   Contents/Resources/Java/native/macosx-arm64/ arm64 LWJGL + OpenAL natives (from payload/)
#   Contents/Resources/Java/native/macosx-arm64-cp/
#                                               arm64 natives that game jars unpack from their own classpath
#                                               (webp-imageio's libwebp-imageio.dylib), put first on the classpath
#   Contents/MacOS/starsector_mac.sh            adds a USE_NATIVE_ARM64 switch and Apple Silicon JVM settings;
#                                               original saved as starsector_mac.sh.before-armsector
# Running a newer install.sh over an older ArmSector rebuilds the launcher from that saved original.
# Undo with uninstall.sh. Runs with the bash 3.2 and tools that ship with macOS.
set -euo pipefail
set -f   # no globbing: launcher flags are split on spaces below

PACK_NAME="ArmSector"
PACK_VERSION="1.1.0"
MARKER=".installed-by-armsector"   # in every directory this pack installs
BLOCK_TAG="armsector"              # marks the block added to the launcher
SUFFIX=".before-armsector"         # launcher backup / directories moved aside

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$HERE/payload"
APP="${1:-/Applications/Starsector.app}"
APP="${APP%/}"
C="$APP/Contents"
LAUNCHER="$C/MacOS/starsector_mac.sh"
BACKUP="$LAUNCHER$SUFFIX"
JAVA_DIR="$C/Resources/Java"
RUNTIME="$C/Home-arm64"
NATIVES="$JAVA_DIR/native/macosx-arm64"
CP_NATIVES="$JAVA_DIR/native/macosx-arm64-cp"

say() { printf '%s\n' "$*"; }
die() { printf '\nERROR: %s\nNothing in Starsector was changed.\n' "$*" >&2; exit 1; }

say "$PACK_NAME $PACK_VERSION — run Starsector natively on Apple Silicon — installer"
say "Starsector: $APP"
say ""

# --- Checks (nothing is changed until all of them pass) -------------------------------------------------

# hw.optional.arm64 is 1 on Apple Silicon even when this Terminal runs under Rosetta.
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ] ||
    die "This Mac has an Intel processor. The pack is only for Apple Silicon (M1 or newer) Macs."

[ -x "$PAYLOAD/Home-arm64/bin/java" ] && [ -f "$PAYLOAD/native/macosx-arm64/liblwjgl.dylib" ] &&
    [ -f "$PAYLOAD/native/macosx-arm64/openal.dylib" ] &&
    [ -f "$PAYLOAD/native/macosx-arm64-cp/native/mac/64/libwebp-imageio.dylib" ] ||
    die "The pack's payload folder is incomplete. Extract the zip again and run install.sh from inside it."

[ -f "$LAUNCHER" ] ||
    die "No Starsector launcher at $LAUNCHER. If the game is somewhere else, run: bash install.sh /path/to/Starsector.app"

version="$(plutil -extract CFBundleShortVersionString raw -o - "$C/Info.plist" 2>/dev/null || true)"
case "$version" in
    *0.98a*) ;;
    *) die "This pack was made and tested for Starsector 0.98a; this install reports '${version:-unknown}'." ;;
esac

grep -q -- '--add-opens' "$LAUNCHER" && grep -q '^JAVA_VERSION="17' "$C/Home/release" 2>/dev/null ||
    die "This install doesn't look like it has a Java 17 community pack (no Java 17 in Contents/Home, or no --add-opens flags in the launcher). The pack only supports installs with a Java 17 pack for now."

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
    die "Starsector is running from this install. Quit it and run install.sh again."
fi

for d in "$C" "$C/MacOS" "$JAVA_DIR/native"; do
    [ -w "$d" ] || die "Can't write to $d. Check that your user owns Starsector.app."
done
[ -w "$LAUNCHER" ] || die "Can't write to $LAUNCHER."

# How the launcher will be handled. SOURCE is the unmodified launcher the edit starts from.
if grep -q ">>> $BLOCK_TAG" "$LAUNCHER"; then
    installed_version="$(sed -nE "s/^# >>> $BLOCK_TAG: $PACK_NAME ([^,]+),.*/\1/p" "$LAUNCHER" | head -1)"
    if [ "$installed_version" = "$PACK_VERSION" ]; then
        launcher_mode=already      # this version installed before: only refresh the files
    else
        launcher_mode=upgrade      # older ArmSector: rebuild the launcher from the original it saved
        [ -f "$BACKUP" ] && ! grep -q ">>> $BLOCK_TAG" "$BACKUP" ||
            die "The launcher has ArmSector ${installed_version:-?} but its saved original ($(basename "$BACKUP")) is missing, so it can't be updated. Run the old version's uninstall.sh, or reapply your Java pack, then run this installer."
        SOURCE="$BACKUP"
    fi
elif grep -q 'USE_NATIVE_ARM64=' "$LAUNCHER"; then
    launcher_mode=foreign          # someone added a switch by hand: leave it alone
else
    launcher_mode=edit
    SOURCE="$LAUNCHER"
    [ ! -e "$RUNTIME$SUFFIX" ] && [ ! -e "$NATIVES$SUFFIX" ] && [ ! -e "$CP_NATIVES$SUFFIX" ] ||
        die "Leftovers from an earlier install exist (*$SUFFIX next to Home-arm64 or the native folders). Run uninstall.sh first."
fi
if [ "$launcher_mode" = edit ] || [ "$launcher_mode" = upgrade ]; then
    [ "$(grep -cE '^[[:space:]]*export JAVA_HOME=\.\./\.\./Home[[:space:]]*$' "$SOURCE")" = 1 ] ||
        die "The launcher doesn't have exactly one 'export JAVA_HOME=../../Home' line, so the pack doesn't know how to edit it."
    [ "$(grep -cE -- '-Djava\.library\.path=\.\./\.\./Resources/Java/native/macosx([[:space:]\\]|$)' "$SOURCE")" = 1 ] ||
        die "The launcher doesn't have exactly one '-Djava.library.path=../../Resources/Java/native/macosx' flag, so the pack doesn't know how to edit it."
    [ "$(grep -cE '^[[:space:]]*-cp[[:space:]]+[^[:space:]]' "$SOURCE")" = 1 ] ||
        die "The launcher doesn't have exactly one '-cp' classpath line, so the pack doesn't know how to edit it."
fi

# --- Install the runtime and the natives ------------------------------------------------------------

installed=()   # directories installed by this run (removed again if a later step fails)
moved=()       # existing directories moved aside by this run (moved back if a later step fails)

rollback() {
    local d
    for d in ${installed[@]+"${installed[@]}"}; do rm -rf "${d:?}"; done
    for d in ${moved[@]+"${moved[@]}"}; do mv "$d$SUFFIX" "$d"; done
}

install_dir() { # <source dir> <destination dir>
    local src="$1" dest="$2"
    if [ -e "$dest" ]; then
        if [ -f "$dest/$MARKER" ]; then
            rm -rf "${dest:?}"                                  # ours, from an earlier install
        else
            [ ! -e "$dest$SUFFIX" ] || { rollback; die "Both $dest and $dest$SUFFIX exist; move one of them away first."; }
            mv "$dest" "$dest$SUFFIX"                           # not ours: keep it, uninstall.sh puts it back
            moved+=("$dest")
            say "  kept your existing $(basename "$dest") as $(basename "$dest")$SUFFIX"
        fi
    fi
    ditto "$src" "$dest"
    installed+=("$dest")
    # Downloaded files carry a quarantine flag; macOS refuses to load quarantined libraries that aren't
    # notarized (the pack's game libraries are only ad-hoc signed). Cleared for these files only.
    xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true
    printf '%s %s, installed %s\n' "$PACK_NAME" "$PACK_VERSION" "$(date '+%Y-%m-%d %H:%M')" > "$dest/$MARKER"
}

say "Installing files:"
install_dir "$PAYLOAD/Home-arm64" "$RUNTIME"
say "  Contents/Home-arm64 (Temurin Java 17 for arm64)"
install_dir "$PAYLOAD/native/macosx-arm64" "$NATIVES"
ditto "$HERE/LICENSES" "$NATIVES/LICENSES"
xattr -dr com.apple.quarantine "$NATIVES/LICENSES" 2>/dev/null || true
say "  Contents/Resources/Java/native/macosx-arm64 (LWJGL 2.9.3 + OpenAL Soft 1.23.1 for arm64)"
install_dir "$PAYLOAD/native/macosx-arm64-cp" "$CP_NATIVES"
say "  Contents/Resources/Java/native/macosx-arm64-cp (WebP image support for arm64)"

J="$RUNTIME/bin/java"
codesign --verify "$J" 2>/dev/null && "$J" -version >/dev/null 2>&1 ||
    { rollback; die "The arm64 Java runtime doesn't start. The zip may have been extracted incompletely; extract it again with Finder."; }

# --- Edit the launcher ---------------------------------------------------------------------------------

if [ "$launcher_mode" = already ]; then
    say ""
    say "The launcher already has $PACK_NAME $PACK_VERSION's switch; it was left as it is."
elif [ "$launcher_mode" = foreign ]; then
    say ""
    say "The launcher already has a USE_NATIVE_ARM64 switch that this pack didn't add; it was left as it is."
else
    cd "$JAVA_DIR"   # the launcher runs java from here; relative paths in flags resolve against it

    # One flag per line ending in a backslash: the layout of the Java 17 pack launchers.
    flag_lines() { sed -nE 's/^[[:space:]]*(-[^[:space:]"$]+)[[:space:]]*\\[[:space:]]*$/\1/p' "$SOURCE"; }

    # The Java pack's -XX tuning flags were written for an x86 Java. Some are x86-only and stop the arm64 Java
    # from starting (-XX:UseAVX=3); others slow the game down here: compiler directives that keep combat code
    # away from the optimizing C2 JIT, Shenandoah's "compact" mode that collects garbage almost nonstop, and
    # AlwaysPreTouch, which touches the whole heap at startup. They all move into JVM_TUNING_FLAGS for the x86
    # Java only, so USE_NATIVE_ARM64=0 runs with every original flag; the arm64 Java gets NATIVE_TUNING instead.
    # Flags that change behaviour rather than speed, and the unlock flags (which must keep their place in front
    # of the flags they unlock), stay where they are, for both.
    NATIVE_TUNING="-XX:+UseG1GC -XX:MaxGCPauseMillis=16 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication
        -XX:+DisableExplicitGC -XX:ReservedCodeCacheSize=256m -XX:-DontCompileHugeMethods"
    keep_for_both() {
        case "$1" in
            -XX:+UnlockDiagnosticVMOptions | -XX:+UnlockExperimentalVMOptions | \
            -XX:[+-]BytecodeVerificationLocal | -XX:[+-]BytecodeVerificationRemote | \
            -XX:[+-]ShowCodeDetailsInExceptionMessages | -XX:MaxDirectMemorySize=* | -XX:ThreadStackSize=* | \
            -XX:MaxMetaspaceSize=* | -XX:MetaspaceSize=*) return 0 ;;
            *) return 1 ;;
        esac
    }
    pack_tuning=""   # for the launcher: six flags per line so the list stays readable
    moved_flags=" "  # the same flags on one line, for lookups
    n_pack=0
    for flag in $(flag_lines | grep '^-XX:' || true); do
        keep_for_both "$flag" && continue
        if [ $n_pack = 0 ]; then pack_tuning="$flag"
        elif [ $((n_pack % 6)) = 0 ]; then pack_tuning="$pack_tuning
        $flag"
        else pack_tuning="$pack_tuning $flag"; fi
        moved_flags="$moved_flags$flag "; n_pack=$((n_pack + 1))
    done

    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:?}"' EXIT
    cat > "$tmp/block" <<EOF
# >>> $BLOCK_TAG: $PACK_NAME $PACK_VERSION, added by install.sh on $(date '+%Y-%m-%d') >>>
# $PACK_NAME: run Starsector natively on Apple Silicon Macs.
# USE_NATIVE_ARM64=1: arm64 Java 17 (Contents/Home-arm64), LWJGL natives built for arm64
#   (Resources/Java/native/macosx-arm64), arm64 copies of natives that game jars unpack from the classpath
#   (Resources/Java/native/macosx-arm64-cp, put first on the classpath), and the JVM settings for Apple Silicon
#   in the first JVM_TUNING_FLAGS. Java errors that don't reach the game log go to logs/starsector-stderr.log.
# USE_NATIVE_ARM64=0: the previous setup under Rosetta (Contents/Home + native/macosx) with all previous flags
#   (the second JVM_TUNING_FLAGS holds the Java pack's tuning flags, unchanged).
# To remove $PACK_NAME, run uninstall.sh from the pack (restores starsector_mac.sh$SUFFIX).
USE_NATIVE_ARM64=1

if [ "\$USE_NATIVE_ARM64" = 1 ] && [ "\$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] \\
        && [ -x ../../Home-arm64/bin/java ] && [ -f ../../Resources/Java/native/macosx-arm64/liblwjgl.dylib ]; then
    export JAVA_HOME=../../Home-arm64
    NATIVE_DIR=../../Resources/Java/native/macosx-arm64
    CP_OVERRIDES=../../Resources/Java/native/macosx-arm64-cp:
    JVM_TUNING_FLAGS="$NATIVE_TUNING"
    if mkdir -p ../../../logs 2>/dev/null && [ -w ../../../logs ]; then
        exec 2>>../../../logs/starsector-stderr.log
        echo "=== \$(date '+%Y-%m-%d %H:%M:%S') Starsector started in $PACK_NAME native mode" >&2
    fi
else
    export JAVA_HOME=../../Home
    NATIVE_DIR=../../Resources/Java/native/macosx
    CP_OVERRIDES=
    JVM_TUNING_FLAGS="$pack_tuning"
fi
# <<< $BLOCK_TAG <<<
EOF

    # Moved flags are replaced by one ${JVM_TUNING_FLAGS} line where the first of them was (or, if there were
    # none, just before -Djava.library.path, which every pack launcher has).
    awk -v blockfile="$tmp/block" -v moved="$moved_flags" '
        BEGIN { n = split(moved, f, " "); for (i = 1; i <= n; i++) ismoved[f[i]] = 1 }
        function placeholder() {
            if (!placed) { match($0, /^[[:space:]]*/); print substr($0, 1, RLENGTH) "${JVM_TUNING_FLAGS} \\"; placed = 1 }
        }
        /^[[:space:]]*export JAVA_HOME=\.\.\/\.\.\/Home[[:space:]]*$/ {
            while ((getline l < blockfile) > 0) print l
            next
        }
        /\\[[:space:]]*$/ {
            t = $0; sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]*\\[[:space:]]*$/, "", t)
            if (t in ismoved) { placeholder(); next }
        }
        /-Djava\.library\.path=/ { placeholder() }
        { print }
    ' "$SOURCE" |
        sed -E -e 's#-Djava\.library\.path=\.\./\.\./Resources/Java/native/macosx([[:space:]\\]|$)#-Djava.library.path=$NATIVE_DIR\1#' \
            -e 's#^([[:space:]]*)-cp[[:space:]]+#\1-cp ${CP_OVERRIDES}#' \
        > "$tmp/launcher"

    # An upgrade keeps the player's USE_NATIVE_ARM64 setting.
    previous_switch="$(sed -nE 's/^USE_NATIVE_ARM64=([01])[[:space:]]*$/\1/p' "$LAUNCHER" | head -1)"
    if [ "$launcher_mode" = upgrade ] && [ "$previous_switch" = 0 ]; then
        sed -i '' 's/^USE_NATIVE_ARM64=1$/USE_NATIVE_ARM64=0/' "$tmp/launcher"
    fi

    grep -q ">>> $BLOCK_TAG" "$tmp/launcher" && grep -q -- '-Djava.library.path=$NATIVE_DIR' "$tmp/launcher" &&
        grep -q '^[[:space:]]*${JVM_TUNING_FLAGS} \\$' "$tmp/launcher" &&
        grep -q '^[[:space:]]*-cp \${CP_OVERRIDES}' "$tmp/launcher" && bash -n "$tmp/launcher" ||
        { rollback; die "Editing the launcher failed (the edited copy didn't check out)."; }

    # Both settings of the switch must start their Java: the edited launcher's one-per-line flags in order, with
    # JVM_TUNING_FLAGS expanded as each branch sets it. (-Xms is left out so the check doesn't commit the heap.)
    effective_flags() { # <tuning flags>
        local flag
        for flag in $(sed -nE 's/^[[:space:]]*(-[^[:space:]"$]+|\$\{JVM_TUNING_FLAGS\})[[:space:]]*\\[[:space:]]*$/\1/p' "$tmp/launcher"); do
            case "$flag" in
                '${JVM_TUNING_FLAGS}') printf '%s\n' $1 ;;
                -Xms*) ;;
                *) printf '%s\n' "$flag" ;;
            esac
        done
    }
    if ! out="$("$J" $(effective_flags "$NATIVE_TUNING") -version 2>&1)"; then
        rollback
        die "The arm64 Java doesn't accept the edited launcher's flags:
$out"
    fi
    if arch -x86_64 /usr/bin/true 2>/dev/null; then
        if ! out="$("$C/Home/bin/java" $(effective_flags "$pack_tuning") -version 2>&1)"; then
            rollback
            die "Your original x86 Java doesn't accept the edited launcher's flags for USE_NATIVE_ARM64=0:
$out"
        fi
    else
        say "  (Rosetta isn't installed, so the USE_NATIVE_ARM64=0 setup couldn't be checked)"
    fi

    if [ "$launcher_mode" = edit ]; then
        if [ -e "$BACKUP" ] && ! cmp -s "$BACKUP" "$LAUNCHER"; then
            old="$BACKUP.old-$(date '+%Y%m%d-%H%M%S')"
            mv "$BACKUP" "$old"
            say "  an older launcher backup was renamed to $(basename "$old")"
        fi
        cp -p "$LAUNCHER" "$BACKUP"
    fi
    cat "$tmp/launcher" > "$LAUNCHER"     # in place: keeps the file's owner and permissions

    say ""
    if [ "$launcher_mode" = upgrade ]; then
        say "Launcher updated from $PACK_NAME $installed_version to $PACK_VERSION, rebuilt from your original launcher"
        say "  (starsector_mac.sh$SUFFIX). USE_NATIVE_ARM64=${previous_switch:-1} was kept; other hand edits to the"
        say "  $PACK_NAME block were replaced."
    else
        say "Launcher edited: Contents/MacOS/starsector_mac.sh (original saved as starsector_mac.sh$SUFFIX)"
    fi
    say "  native mode uses JVM settings for Apple Silicon: G1 garbage collector, no compiler directives,"
    say "  no heap pre-touch ($(echo $NATIVE_TUNING))"
    say "  your Java pack's $n_pack tuning flags are kept, unchanged, for USE_NATIVE_ARM64=0"
fi

say ""
if grep -q '^USE_NATIVE_ARM64=0' "$LAUNCHER"; then
    say "Done. The launcher is set to USE_NATIVE_ARM64=0, so Starsector still runs under Rosetta."
    say "To run natively, set USE_NATIVE_ARM64=1 in Contents/MacOS/starsector_mac.sh."
else
    say "Done. Start Starsector the usual way; it now runs natively on Apple Silicon."
    say "To go back to Rosetta for a while: set USE_NATIVE_ARM64=0 in Contents/MacOS/starsector_mac.sh."
fi
say "To remove the patch completely: bash uninstall.sh"

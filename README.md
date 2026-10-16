# ArmSector: Run Starsector natively on Apple Silicon Macs

On Macs with Apple Silicon (M1 or newer), Starsector runs as an Intel app through Rosetta. ArmSector makes it
run natively instead:

- **No Rosetta.** An arm64 Java 17 runs the game in place of the x86 one, with graphics and sound libraries
  built for Apple Silicon.
- **JVM settings for Apple Silicon.** In native mode the game uses the G1 garbage collector. It also drops the
  Java pack's x86 tuning, which includes compiler directives that kept combat code away from Java's optimizing
  compiler, a garbage-collector mode that runs almost nonstop, and pre-touching the whole heap at startup.
- **Fullscreen that lets you leave.** Cmd+Tab and Mission Control work while the game is fullscreen.

**Upgrading from 1.0.0?** Run the new `install.sh` the same way. It updates the files and rebuilds the launcher
from the original it saved the first time, and it keeps your `USE_NATIVE_ARM64` setting. See the changelog at the
end of this page.

It's not a normal mod. The game chooses its Java and its native graphics/sound libraries before any mod
loads, so ArmSector installs them inside `Starsector.app` and adds a switch to the game's launcher script.

This is an unofficial fan project. It isn't affiliated with or supported by Fractal Softworks, so please don't
report problems with it to them.

## What you need

- A Mac with Apple Silicon (M1 or newer). `install.sh` refuses to run on Intel Macs.
- **Starsector 0.98a with a Java 17 community pack already applied.** ArmSector builds on that setup and
  doesn't support the plain official download yet. To check, right-click Starsector.app → *Show Package
  Contents* → `Contents/Home/release` should contain `JAVA_VERSION="17…`. `install.sh` checks this for you and
  stops without changing anything if your install doesn't match.
- About 130 MB of free space.

## Install

1. Quit Starsector. Optionally, back up your `saves` folder; ArmSector doesn't touch saves, but backups are
   always a good idea.
2. Double-click the zip to extract it.
3. Open **Terminal** (Applications → Utilities). Type `bash ` (with a space after it), drag `install.sh` from
   the extracted folder into the Terminal window, and press Return.
   - If the game isn't at `/Applications/Starsector.app`, also drag Starsector.app into the window after
     `install.sh`, so the line reads `bash …/install.sh …/Starsector.app`.
4. Start Starsector the usual way.

**Why Terminal?** macOS flags everything downloaded from the internet as "quarantined" and refuses to load
quarantined native libraries that aren't notarized by Apple. ArmSector's game libraries are built from
source and only ad-hoc signed. `install.sh` removes the quarantine flag from the files it installs, and only
from those. If you'd rather not run the script, the "Manual install" section shows what it does.

`install.sh` changes only these things inside Starsector.app:

| Path | Change |
|---|---|
| `Contents/Home-arm64/` | new: Java 17 for arm64 (Eclipse Temurin, trimmed with jlink) |
| `Contents/Resources/Java/native/macosx-arm64/` | new: LWJGL 2.9.3 and OpenAL Soft built for arm64, plus their licenses |
| `Contents/Resources/Java/native/macosx-arm64-cp/` | new: WebP image support for arm64 (`libwebp-imageio.dylib`) |
| `Contents/MacOS/starsector_mac.sh` | edited: adds a `USE_NATIVE_ARM64` switch. The original is saved as `starsector_mac.sh.before-armsector` |

Your original Java (`Contents/Home`) and libraries (`native/macosx`) stay untouched.

The launcher edit does these things:

- **Java and natives.** It picks `Home-arm64` and `native/macosx-arm64` when `USE_NATIVE_ARM64=1`, and points
  `-Djava.library.path` at whichever native folder was picked.
- **WebP images.** The game's `webp-imageio` jar unpacks its own native library from the classpath, and it only
  contains an x86 copy. In native mode, the launcher puts `native/macosx-arm64-cp` first on the classpath
  (`CP_OVERRIDES`), so the jar finds the arm64 copy instead. The game's jar itself isn't changed.
- **Error log.** In native mode, Java errors that never reach `starsector.log` go to
  `Starsector.app/logs/starsector-stderr.log`. When the game is started from Finder, these errors are otherwise
  lost.
- **Tuning flags.** It moves the Java pack's `-XX` tuning flags into a `JVM_TUNING_FLAGS` variable, which is set
  differently in each mode:
  - Native mode: `-XX:+UseG1GC -XX:MaxGCPauseMillis=16 -XX:+ParallelRefProcEnabled -XX:+UseStringDeduplication
    -XX:+DisableExplicitGC -XX:ReservedCodeCacheSize=256m -XX:-DontCompileHugeMethods`.
  - `USE_NATIVE_ARM64=0`: the Java pack's original tuning flags, unchanged. About a dozen of them are x86-only,
    such as `-XX:UseAVX=3`, and would stop the arm64 Java from starting.
- **What stays.** Flags that change behaviour rather than speed don't move: memory (`-Xms`/`-Xmx`), stack
  size, bytecode verification, the unlock flags, and the `--add-opens` list.

Before writing the launcher, `install.sh` starts both Javas with the edited launcher's exact flags to make sure
both settings work. To try other JVM settings in native mode, edit the first `JVM_TUNING_FLAGS` line in the
launcher.

## Switching back to Rosetta for a while

Right-click Starsector.app → *Show Package Contents* → `Contents/MacOS/starsector_mac.sh`, open it in
TextEdit, change `USE_NATIVE_ARM64=1` to `USE_NATIVE_ARM64=0`, and save. The game then starts exactly as it
did before ArmSector, with all your original flags. Change it back to `1` to run natively again.

## Uninstall

Run `bash uninstall.sh` from the ArmSector folder the same way you ran the installer. It restores your
original launcher and deletes `Home-arm64`, `native/macosx-arm64` and `native/macosx-arm64-cp`.

## After updating Starsector or reapplying a Java pack

Both replace the launcher, which turns ArmSector off; the game simply runs under Rosetta again. Run
`install.sh` again to switch back to native.

## Known limits

- **Tested on one setup only:** an M3 Mac, macOS 27.2, Starsector 0.98a-RC8 with a Java 17 pack
  (Azul Zulu 17 x86). The speedup from the JVM settings has only been seen on that machine, together with
  the switch to native. Reports from other Macs are very welcome.
- **The notch.** On MacBooks with a camera notch, fullscreen covers the whole display, so the notch hides a
  small part of the top of the screen. Use windowed mode if that gets in the way.
- **Mods with their own native libraries.** A mod that ships Intel-only native code (`.dylib` or `.jnilib`)
  can't load it in an arm64 Java. Pure Java mods, which is nearly all of them, are unaffected. If a mod
  breaks, try `USE_NATIVE_ARM64=0`.
- **Controller library not included.** Starsector doesn't use gamepads, so the arm64 build leaves out LWJGL's
  JInput library.
- **Rendering is unchanged.** The game still draws with OpenGL, which macOS runs on top of Metal. ArmSector
  doesn't add Metal rendering or upscaling such as MetalFX.

## Reporting problems

Open an issue at https://github.com/winters791/ArmSector/issues or post in the ArmSector thread on the Starsector forums, and include:

1. Your Mac model and chip, and your macOS version (Apple menu → About This Mac).
2. Your Starsector version and which Java pack you use.
3. Everything `install.sh` printed.
4. `Starsector.app/logs/starsector.log` (the `logs` folder sits next to `Contents` inside Starsector.app).
5. `Starsector.app/logs/starsector-stderr.log`, which holds Java errors that don't reach `starsector.log`.
6. Any `hs_err_pid*.log` files in `Starsector.app/Contents/Resources/Java` if the game crashed.
7. Whether the problem goes away with `USE_NATIVE_ARM64=0`.

## Manual install

If you don't want to run the script:

1. Copy `payload/Home-arm64` to `Starsector.app/Contents/Home-arm64`.
2. Copy `payload/native/macosx-arm64` to `Starsector.app/Contents/Resources/Java/native/macosx-arm64`.
3. Copy `payload/native/macosx-arm64-cp` to `Starsector.app/Contents/Resources/Java/native/macosx-arm64-cp`.
4. In Terminal, run `xattr -dr com.apple.quarantine` on the three copied folders.
5. Edit `starsector_mac.sh` as described above. The comments in `install.sh` explain each step.

## What's inside, licenses, rebuilding

- `payload/` holds the files that get installed. `SHA256SUMS.txt` lists their checksums.
- `LICENSES/` covers the third-party licenses and exactly what was changed in LWJGL. ArmSector contains no
  Starsector files.
- `rebuild-kit/` has scripts to:
  - rebuild `liblwjgl.dylib` and `libwebp-imageio.dylib` from source (both byte-for-byte reproducible);
  - rebuild the Java runtime;
  - run the graphics, sound and WebP tests;
  - make the zip.

## License

ArmSector's own scripts and docs are under the BSD 3-Clause License (`LICENSE`). The third-party software it
distributes keeps its own licenses:
- Eclipse Temurin: GPLv2 with Classpath Exception
- LWJGL: BSD 3-Clause
- OpenAL Soft: LGPL
- webp-imageio: Apache 2.0
- libwebp: BSD 3-Clause

See `LICENSES/README.md` for details.

## Changelog

- **1.1.0:** fixes a loading hang with mods that ship `.webp` images, such as MagicLib. The game's WebP library had
  only an x86 native, so the arm64 Java couldn't load it and loading stalled with no error shown. Native mode
  now also writes Java errors that don't reach the game log to `logs/starsector-stderr.log`. Running the 1.1.0
  installer over 1.0.0 upgrades in place.
- **1.0.0:** first release.

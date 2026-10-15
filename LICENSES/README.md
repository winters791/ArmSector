# Third-party software in ArmSector

ArmSector contains no Starsector files. Starsector, its jars, data, and launcher script belong to Fractal Softworks.
`install.sh` edits the launcher that is already in your copy of the game; it doesn't ship one.

## LWJGL 2.9.3 native library — `native/macosx-arm64/liblwjgl.dylib`

- License: BSD 3-clause, `LWJGL-2-LICENSE.txt` (the `doc/LICENSE` file from the LWJGL repository).
- Source: https://github.com/LWJGL/lwjgl, tag `lwjgl2.9.3`. This is the same version as the `lwjgl.jar` the game ships.
- **Modified.** It was built for arm64 with the patches in `rebuild-kit/patch_sources.py`. The changes:
  1. Fullscreen keeps the game window at the normal window level on the main screen and hides the Dock
     and menu bar only while the game is in front. Cmd+Tab and Mission Control can then bring other apps
     forward. Stock 2.9.3 covered every screen at the shield level, so nothing could appear above the game.
  2. `NSOpenGLContext` `setView:`, `update` and `clearDrawable`, plus window style-mask changes, run on the
     AppKit main thread. AppKit traps when they're called from other threads in a JVM built with a modern
     macOS SDK. Per-frame `update` calls from the render thread are forwarded only when the drawable size changes.
  3. The windowed OpenGL surface is explicitly 1x unless LWJGL's `enableHighDPI` is set, which is what
     LWJGL's Java side assumes. With a modern JVM, AppKit otherwise defaults to a Retina 2x surface and the
     game draws into the bottom-left quarter of the window.
  4. Build fixes for current toolchains: generator output under JDK 9+ `javac`, a `jawt_md.h` shim for SDKs
     without JavaVM.framework headers, a prototype for the deprecated `CGDisplayBitsPerPixel`, and a `BOOL`
     that stock code passed through `performSelector:withObject:` as an object pointer.
- Rebuild it with `rebuild-kit/rebuild.sh`. The output is byte-for-byte reproducible.

## OpenAL Soft 1.23.1 — `native/macosx-arm64/openal.dylib`

- License: GNU Library General Public License, version 2 (`OpenAL-Soft-COPYING-LGPL-2.txt`).
- The binary is unmodified. It's the macOS arm64 build that ships in LWJGL 3.3.3's natives, and LWJGL
  builds it from https://github.com/LWJGL-CI/openal-soft at commit `0d5d3adf0b532c58c7e171078232fc390e18d931`.
  That commit is OpenAL Soft 1.23.1 (upstream https://github.com/kcat/openal-soft, tag `1.23.1`), plus the next
  upstream commit (`d9fed51`, an alignment fix for 32-bit) and LWJGL's CI configuration. A source archive of
  that commit is attached to the release as well.
- The game loads it as a separate dynamic library, so you can swap in your own build of OpenAL Soft.

## Eclipse Temurin 17.0.20.1+1 (arm64) — `Contents/Home-arm64`

- License: GNU General Public License, version 2, with the Classpath Exception
  (`Temurin-GPLv2-with-Classpath-Exception.txt`). Per-module notices are in `Home-arm64/legal/` and
  Temurin's notice is in `Home-arm64/NOTICE`.
- The binaries are unmodified. The runtime was trimmed with `jlink` from the official Temurin 17.0.20.1+1
  macOS aarch64 JDK, keeping the modules listed in `Home-arm64/release`; see `rebuild-kit/make_runtime.sh`.
- Source: https://github.com/adoptium/jdk17u, tag `jdk-17.0.20.1+1_adopt`.
- Eclipse Temurin is a trademark of the Eclipse Foundation. ArmSector is not affiliated with or endorsed by
  the Eclipse Foundation, Fractal Softworks, or the LWJGL project.

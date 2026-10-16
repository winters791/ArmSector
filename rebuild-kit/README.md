# Rebuild kit

Everything needed to rebuild ArmSector's binaries from source, check them, and assemble the release zip.

| File | What it does |
|---|---|
| `rebuild.sh` | Clones LWJGL 2.9.3 (tag `lwjgl2.9.3`), applies `patch_sources.py`, generates the native sources (`generate.sh`), and compiles `liblwjgl.dylib` for arm64 (`build_natives.sh`). |
| `build_webp.sh` | Builds `libwebp-imageio.dylib` for arm64 (macOS 11+): the C part of webp-imageio 0.1.6 (the game's version), statically linked with libwebp 1.6.0 built from source. |
| `patch_sources.py` | The source patches on top of LWJGL 2.9.3. `LICENSES/README.md` describes what each one does. |
| `make_runtime.sh` | Builds the trimmed Java runtime (`payload/Home-arm64`) from a Temurin 17 aarch64 JDK with `jlink`. |
| `make_pack.sh` | Assembles the release zip, and downloads the OpenAL Soft source archive to attach next to it. |
| `run_tests.sh` | Runs these tests against an installed copy of the game: `LwjglSmoke.java` (OpenAL, windowed GL, and fullscreen GL), `LwjglDpiProbe.java` (1x vs 2x GL surface), and `WebpProbe.java`. The WebP test decodes `test.webp` (a synthetic image made with the original x86 library) and any `.webp` files in the install's mods, and compares the pixels with the x86 decode. |

## Requirements

You need an Apple Silicon Mac with git, the Xcode Command Line Tools, Python 3, and Temurin JDK 11 and 17 for
aarch64 installed in `/Library/Java/JavaVirtualMachines`. JDK 11 runs LWJGL's source generator and JDK 17
supplies the JNI headers. `build_webp.sh` also needs `make`, which comes with the Command Line Tools.

## Rebuild and verify

```bash
./rebuild.sh /tmp/lwjgl-work /tmp/liblwjgl.dylib
shasum -a 256 /tmp/liblwjgl.dylib
```

The build is byte-for-byte reproducible. The 1.0.0 release's `liblwjgl.dylib` has this sha256:
`8fd08cef1ccef9e04207b03521826ad05a1491cd4257ba6bcd4074ca5fefda65`

`openal.dylib` (sha256 `0f2d689195d456ba3a37a80a2168d3c9aafe2b5455e1a5ecb2ad38294c061e86`) is the unmodified
macOS arm64 OpenAL Soft 1.23.1 that ships in LWJGL 3.3.3's natives
(`lwjgl-openal-3.3.3-natives-macos-arm64.jar`, path `macos/arm64/org/lwjgl/openal/libopenal.dylib`).

`libwebp-imageio.dylib` is reproducible too. The 1.1.0 release's copy has this sha256:
`b6ba87840aa41a64271c9c97ef72c15adc8dd4d3bab783fe09171ed5857bb99e` (`./build_webp.sh /tmp/webp-work /tmp/libwebp-imageio.dylib`;
the file name is part of the ad-hoc signature, so keep it).

`make_runtime.sh` gives byte-identical output for the same input JDK (the 1.0.0 release uses Temurin 17.0.20.1+1).

## Make a release

```bash
./make_pack.sh <dir with liblwjgl.dylib + openal.dylib + libwebp-imageio.dylib> /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home ../dist
```

Before publishing, test on a copy of the game, never on your real install:

```bash
cp -cR /Applications/Starsector.app /tmp/ss-test/Starsector.app
bash install.sh /tmp/ss-test/Starsector.app
./rebuild-kit/run_tests.sh /tmp/ss-test/Starsector.app
bash uninstall.sh /tmp/ss-test/Starsector.app
```

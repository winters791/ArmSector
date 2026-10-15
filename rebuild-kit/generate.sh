#!/bin/bash
# Runs LWJGL 2.9.3's native-source generator without Ant (mirrors platform_build/build-generator.xml).
set -e
L="$1"   # path to lwjgl2 checkout
J=/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home/bin
cd "$L"
mkdir -p bin src/generated src/native/generated/{openal,opengl,opencl}
# 1. generator + helper classes
find src/java/org/lwjgl/util/generator -name '*.java' > bin/gen-sources.txt
$J/javac -nowarn -Xlint:none -d bin -sourcepath src/java @bin/gen-sources.txt \
  src/java/org/lwjgl/PointerWrapper.java src/java/org/lwjgl/PointerBuffer.java \
  src/java/org/lwjgl/opengl/GLSync.java src/java/org/lwjgl/opengl/AMDDebugOutputCallback.java \
  src/java/org/lwjgl/opengl/ARBDebugOutputCallback.java src/java/org/lwjgl/opengl/KHRDebugCallback.java \
  src/java/org/lwjgl/opencl/CLPlatform.java src/java/org/lwjgl/opencl/CLDevice.java src/java/org/lwjgl/opencl/CLContext.java \
  src/java/org/lwjgl/opencl/CLCommandQueue.java src/java/org/lwjgl/opencl/CLMem.java src/java/org/lwjgl/opencl/CL*Callback.java \
  src/java/org/lwjgl/opencl/CLNativeKernel.java src/java/org/lwjgl/opencl/CLFunctionAddress.java 2>&1 | grep -v -E "^Note:" || true
CP="src/java:src/templates:bin"
gen() { # $1 native out dir, $2 typemap, $3.. extra args, then templates after --
  local out="$1" tm="$2"; shift 2
  local extra=(); while [ "$1" != "--" ]; do extra+=("$1"); shift; done; shift
  $J/javac -nowarn -proc:only -processor org.lwjgl.util.generator.GeneratorProcessor -cp "$CP" \
    -s src/generated -d "src/native/generated/$out" -Abinpath=bin -Atypemap="$tm" "${extra[@]}" "$@"
}
T=src/templates/org/lwjgl
gen openal org.lwjgl.util.generator.openal.ALTypeMap -- $T/openal/AL*.java $T/openal/EFX*.java
GL=$(cd $T/opengl && ls GL*.java ARB*.java EXT*.java KHR*.java AMD*.java APPLE*.java ATI*.java NV*.java NVX*.java HP*.java IBM*.java SUN*.java SGIS*.java GREMEDY*.java INTEL*.java 2>/dev/null | sort -u | sed "s#^#$T/opengl/#")
gen opengl org.lwjgl.util.generator.opengl.GLTypeMap -Acontextspecific -- $GL
CL=$(cd $T/opencl && ls CL*.java KHR*.java EXT*.java APPLE*.java AMD*.java INTEL*.java NV*.java 2>/dev/null | sort -u | sed "s#^#$T/opencl/#")
gen opencl org.lwjgl.util.generator.opencl.CLTypeMap -Acontextspecific -- $CL
echo "generated: $(ls src/native/generated/openal | wc -l) AL, $(ls src/native/generated/opengl | wc -l) GL, $(ls src/native/generated/opencl | wc -l) CL native files"
# Java-only outputs (ContextCapabilities, References, CLCapabilities) needed to compile the JNI headers
P="$J/javac -nowarn -proc:only -cp $CP -s src/generated"
$P -processor org.lwjgl.util.generator.opengl.GLGeneratorProcessor -Acontextspecific $GL
$P -processor org.lwjgl.util.generator.opengl.GLReferencesGeneratorProcessor $GL
$P -processor org.lwjgl.util.generator.opencl.CLGeneratorProcessor -Acontextspecific $CL
ls src/generated/org/lwjgl/opengl/ContextCapabilities.java src/generated/org/lwjgl/opengl/References.java src/generated/org/lwjgl/opencl/CLCapabilities.java

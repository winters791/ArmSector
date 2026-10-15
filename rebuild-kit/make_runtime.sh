#!/bin/bash
# Builds the trimmed arm64 Java runtime shipped as payload/Home-arm64.
# Usage: make_runtime.sh <Temurin 17 aarch64 JDK home> <output dir (must not exist)>
#   e.g. make_runtime.sh /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home out/Home-arm64
# Same JDK in -> byte-identical runtime out. lib/modules is left uncompressed: the release zip compresses
# it better than jlink does, and the game doesn't pay for decompression when it loads classes.
set -euo pipefail
JDK="$1"; OUT="$2"
[ ! -e "$OUT" ] || { echo "$OUT already exists" >&2; exit 1; }
grep -q '^OS_ARCH="aarch64"' "$JDK/release" && grep -q '^JAVA_VERSION="17\.' "$JDK/release" ||
    { echo "$JDK is not an aarch64 Java 17 JDK" >&2; exit 1; }

# The modules of the Java 17 runtime that the community packs ship (Zulu 17 JRE), minus Azul's own
# com.azul.* modules.
MODULES=java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,\
java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,\
java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml,java.xml.crypto,\
jdk.accessibility,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.httpserver,\
jdk.incubator.foreign,jdk.incubator.vector,jdk.internal.vm.ci,jdk.internal.vm.compiler,\
jdk.internal.vm.compiler.management,jdk.jdwp.agent,jdk.jfr,jdk.jsobject,jdk.localedata,jdk.management,\
jdk.management.agent,jdk.management.jfr,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.nio.mapmode,jdk.random,\
jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.xml.dom,jdk.zipfs

"$JDK/bin/jlink" --module-path "$JDK/jmods" --add-modules "$MODULES" \
    --strip-debug --no-man-pages --no-header-files --output "$OUT" 2>&1 | grep -v '^WARNING: Using incubator' || true
[ -x "$OUT/bin/java" ] || { echo "jlink failed" >&2; exit 1; }
[ ! -f "$JDK/NOTICE" ] || cp "$JDK/NOTICE" "$OUT/NOTICE"
codesign --verify "$OUT/bin/java"
"$OUT/bin/java" -version

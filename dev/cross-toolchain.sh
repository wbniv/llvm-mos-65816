#!/usr/bin/env bash
# dev/cross-toolchain.sh — cross-compile the llvm-mos HOST tools (clang/lld/llvm-*) for a
# NON-native host, from the x86-64 Linux dev container. Runs INSIDE the cross image
# (dev/Dockerfile.cross); drive it from the host:
#
#   dev/run.sh cross-toolchain <linux-arm64 | windows-x86_64 | macos-arm64>
#
# Only the HOST binaries differ per platform. The 65816 TARGET libs (MOS compiler-rt
# builtins + the SNES SDK) are host-agnostic and grafted in at PACKAGE time from the native
# build — so this cross build DISABLES the compiler-rt runtimes sub-build (it would need to
# RUN the just-built cross clang, impossible on this host) and reuses the native tablegens
# via LLVM_NATIVE_TOOL_DIR.
#
# Prereq: the NATIVE build must exist first (dev/run.sh toolchain) — it provides the native
# tablegens (build/llvm-mos/bin) and the host-agnostic artifacts the package reuses. See
# docs/plans/2026-06-25-cross-platform-toolchain-builds.md.
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh cross-toolchain <linux-arm64|windows-x86_64|macos-arm64>"
  echo "  Cross-builds clang/lld/llvm-* for the given host -> build/llvm-mos-install-<profile>"
  exit "${1:-0}"
}
{ [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; } && usage 0
PROFILE="${1:-}"
[ -n "$PROFILE" ] || { echo "FATAL: missing profile" >&2; usage 1 >&2; }

ROOT=/work
SRC="$ROOT/vendor/llvm-mos"
NATIVE_BUILD="$ROOT/build/llvm-mos"
BUILDDIR="$ROOT/build/llvm-mos-$PROFILE"
INSTALL="$ROOT/build/llvm-mos-install-$PROFILE"
TCFILE="$ROOT/dev/cross/$PROFILE.cmake"
JOBS="${BUILD_JOBS:-6}"
export CCACHE_DIR="$ROOT/build/.ccache"
# /opt/llvm-mos/bin (the mos cross toolchain) leads the image PATH; keep host /usr/bin
# first so any native build tool resolves to the real host binary.
export PATH="/usr/bin:$PATH"

# Per-profile LLVM host triple — the OS/arch the produced binaries RUN on. The default
# *target* stays mos-unknown-unknown (from MOS.cmake): we're cross-building a cross-compiler.
case "$PROFILE" in
  linux-arm64)    HOST_TRIPLE="aarch64-unknown-linux-gnu" ;;
  windows-x86_64) HOST_TRIPLE="x86_64-w64-windows-gnu" ;;
  macos-arm64)    HOST_TRIPLE="arm64-apple-darwin" ;;
  *) echo "FATAL: unknown profile '$PROFILE' (want: linux-arm64|windows-x86_64|macos-arm64)" >&2; exit 1 ;;
esac

[ -f "$TCFILE" ] || { echo "FATAL: missing cmake toolchain file $TCFILE" >&2; exit 1; }
[ -x "$NATIVE_BUILD/bin/llvm-tblgen" ] || {
  echo "FATAL: native build missing ($NATIVE_BUILD/bin/llvm-tblgen) — it provides the native" >&2
  echo "       tablegens this cross build runs. Build it first:  dev/run.sh toolchain" >&2
  exit 1
}
[ -d "$SRC/.git" ] || { echo "FATAL: $SRC absent — run dev/run.sh toolchain first (it clones+patches llvm-mos)" >&2; exit 1; }

# Host tools only — NO 'builtins' (runtimes disabled below; the mos builtins come from the
# native build at package time). Mirrors MOS.cmake's distribution list minus builtins and the
# unpackaged clang-refactor/clang-scan-deps.
DIST_COMPONENTS="clang;lld;clang-format;clang-resource-headers;llvm-addr2line;llvm-ar;llvm-cxxfilt;llvm-dwarfdump;llvm-mc;llvm-mlb;llvm-nm;llvm-objcopy;llvm-objdump;llvm-ranlib;llvm-readelf;llvm-readobj;llvm-size;llvm-strings;llvm-strip;llvm-symbolizer"

echo "==> cross-configure [$PROFILE -> $HOST_TRIPLE]: MOS.cmake + $PROFILE.cmake, runtimes OFF, native tools from build/llvm-mos"
cmake -C "$SRC/clang/cmake/caches/MOS.cmake" -G Ninja \
  -S "$SRC/llvm" -B "$BUILDDIR" \
  -DCMAKE_TOOLCHAIN_FILE="$TCFILE" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DLLVM_NATIVE_TOOL_DIR="$NATIVE_BUILD/bin" \
  -DLLVM_HOST_TRIPLE="$HOST_TRIPLE" \
  -DLLVM_ENABLE_RUNTIMES="" \
  -DLLVM_BUILTIN_TARGETS="" \
  -DLLVM_RUNTIME_TARGETS="" \
  -DLLVM_DISTRIBUTION_COMPONENTS="$DIST_COMPONENTS" \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_CCACHE_BUILD=On

echo "==> cross-build the distribution target (-j$JOBS); first build is long (~30-90 min)"
cmake --build "$BUILDDIR" --target distribution --parallel "$JOBS"

echo "==> install-distribution -> $INSTALL"
cmake --build "$BUILDDIR" --target install-distribution

# Windows: the produced .exe dynamically link the mingw posix-threads runtime. Deposit
# those DLLs into the install bin/ so the package step (which runs on the host, where these
# DLLs do NOT exist) can bundle them next to the .exe. Without them clang.exe won't start.
if [ "$PROFILE" = "windows-x86_64" ]; then
  echo "==> bundling mingw runtime DLLs into $INSTALL/bin"
  for dll in \
      /usr/lib/gcc/x86_64-w64-mingw32/*-posix/libstdc++-6.dll \
      /usr/lib/gcc/x86_64-w64-mingw32/*-posix/libgcc_s_seh-1.dll \
      /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll; do
    if [ -f "$dll" ]; then cp -v "$dll" "$INSTALL/bin/"; else echo "  WARN: missing $dll" >&2; fi
  done
fi

echo "==> done in $((SECONDS/60))m $((SECONDS%60))s — $PROFILE host binaries at build/llvm-mos-install-$PROFILE/bin"
echo "    next:  PLATFORM=$PROFILE dev/package-release.sh   (package + self-test)"

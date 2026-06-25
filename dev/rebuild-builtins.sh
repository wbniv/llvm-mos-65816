#!/usr/bin/env bash
# dev/rebuild-builtins.sh — force-rebuild the mos compiler-rt builtins so the
# installed libclang_rt.builtins.a matches the CURRENT backend data layout.
#
# Runs INSIDE the dev container (drive from the host: dev/run.sh rebuild-builtins).
#
# Why this exists: the builtins are an LLVM "runtimes" sub-build. Ninja does NOT
# re-trigger it on a backend-only change — e.g. patch 0006 adding the packed-24
# 'p3:24:8' address space to the MOS data layout. So after such a patch the
# installed builtins keep the OLD layout while user code (and a freshly rebuilt
# libc) get the new one, and every LTO link warns:
#   ld.lld: warning: Linking two modules of different data layouts
# The SNES SDK merges this builtins.a into libcrt (common/crt/CMakeLists.txt),
# so the stale layout propagates to every user build. This is a release blocker
# (a public release must be warning-clean), so we clean + recompile just the
# builtins with the current cross-clang and reinstall.
#
# CCACHE is disabled here so the recompile is genuinely fresh (the whole point is
# to defeat a stale cached object); it's only ~50 tiny files, so this is quick.
set -euo pipefail

ROOT=/work
BUILDDIR="$ROOT/build/llvm-mos"
INSTALL="$ROOT/build/llvm-mos-install"
export CCACHE_DISABLE=1
# /opt/llvm-mos/bin (the mos CROSS toolchain) shadows host tools on the image
# PATH; the runtimes build needs the host clang/llvm. Put /usr/bin first.
export PATH="/usr/bin:$PATH"

[ -d "$BUILDDIR" ] || {
  echo "FATAL: toolchain build tree $BUILDDIR absent." >&2
  echo "  build the toolchain first:  dev/run.sh toolchain" >&2
  exit 1
}

BLT_BEFORE="$INSTALL/lib/clang/23/lib/mos-unknown-unknown/libclang_rt.builtins.a"
echo "==> before: $(ls -la "$BLT_BEFORE" 2>/dev/null | awk '{print $5, $6, $7, $8}')"

echo "==> clean the mos builtins runtimes sub-build (forces recompile)"
ninja -C "$BUILDDIR" builtins-mos-unknown-unknown-clean

echo "==> rebuild the mos builtins with the current cross-clang (ccache off)"
ninja -C "$BUILDDIR" builtins-mos-unknown-unknown

echo "==> reinstall the distribution (refreshes the installed builtins.a)"
cmake --build "$BUILDDIR" --target install-distribution

echo "==> after:  $(ls -la "$BLT_BEFORE" 2>/dev/null | awk '{print $5, $6, $7, $8}')"
echo "==> done — now rebuild the SDK so libcrt re-merges the fresh builtins:"
echo "    task release-sdk   (MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build)"

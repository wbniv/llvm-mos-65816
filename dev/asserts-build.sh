#!/usr/bin/env bash
# dev/asserts-build.sh — build an ISOLATED asserts-enabled llvm-mos toolchain for
# diagnosing backend crashes (the Release toolchain has assertions compiled out, so
# it emits illegal MIR / "ran out of registers" instead of firing the precise
# assert). Reuses the existing patched vendor/llvm-mos and the shared ccache, but
# builds + installs into SEPARATE dirs so the shared Release toolchain
# (build/llvm-mos{,-install}) is left untouched.
#
#   build/llvm-mos-asserts          (build dir)
#   build/llvm-mos-asserts-install  (install prefix; its bin/mos-clang fires asserts)
#
# Drive from the host:  dev/run.sh asserts-build   (runs INSIDE the dev container).
# Then compile a repro with the asserts compiler, e.g.:
#   build/llvm-mos-asserts-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
#     -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs \
#     -c REPRO.c -o /tmp/x.o      # an asserts build aborts at the failing assert
#
# First build ~20-25 min (ccache hits are partial: assertions drop -DNDEBUG, so many
# TUs re-compile). Subsequent rebuilds after a vendor edit are fast.
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh asserts-build   # isolated LLVM_ENABLE_ASSERTIONS=On toolchain -> build/llvm-mos-asserts-install"
  echo "Env: BUILD_JOBS (compile parallelism, default 6 — lower if the 14 GiB host swaps)"
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
SRC="$ROOT/vendor/llvm-mos"
BUILDDIR="$ROOT/build/llvm-mos-asserts"
INSTALL="$ROOT/build/llvm-mos-asserts-install"
JOBS="${BUILD_JOBS:-6}"
export CCACHE_DIR="$ROOT/build/.ccache"
# Host /usr/bin first so the build uses the native clang, not the mos cross at
# /opt/llvm-mos/bin (which shadows it on the image PATH).
export PATH="/usr/bin:$PATH"

if [ ! -d "$SRC/.git" ]; then
  echo "error: $SRC is not present — run 'dev/run.sh toolchain' first to clone+patch vendor/." >&2
  exit 1
fi
echo "==> reusing existing vendor/llvm-mos @ $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$SRC" diff --quiet -- llvm/lib/Target/MOS 2>/dev/null || echo ' +patched')"

# Trim the distribution to clang+lld (idempotent — usually already applied by a prior
# toolchain build; safe no-op otherwise) so install-distribution has no unbuilt targets.
sed -i \
  -e 's/clang;clang-tools-extra;lld/clang;lld/' \
  -e '/^[[:space:]]*clang-apply-replacements[[:space:]]*$/d' \
  -e '/^[[:space:]]*clang-include-fixer[[:space:]]*$/d' \
  -e '/^[[:space:]]*clang-tidy[[:space:]]*$/d' \
  -e '/^[[:space:]]*clangd[[:space:]]*$/d' \
  -e '/^[[:space:]]*find-all-symbols[[:space:]]*$/d' \
  "$SRC/clang/cmake/caches/MOS.cmake"

echo "==> configure (MOS.cmake cache, Release + LLVM_ENABLE_ASSERTIONS=On, ccache) -> $BUILDDIR"
cmake -C "$SRC/clang/cmake/caches/MOS.cmake" -G Ninja \
  -S "$SRC/llvm" -B "$BUILDDIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=On \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_ASM_COMPILER=/usr/bin/clang \
  -DLLVM_USE_LINKER=lld \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_CCACHE_BUILD=On

echo "==> build distribution (-j$JOBS)"
cmake --build "$BUILDDIR" --target distribution --parallel "$JOBS"

echo "==> install-distribution -> $INSTALL"
cmake --build "$BUILDDIR" --target install-distribution

echo "==> done in $((SECONDS/60))m $((SECONDS%60))s: asserts $("$INSTALL/bin/mos-clang" --version | head -1)"
echo "    use it: $INSTALL/bin/mos-clang ... (aborts at the precise assert on a backend crash)"

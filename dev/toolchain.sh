#!/usr/bin/env bash
# dev/toolchain.sh — build llvm-mos (clang/lld) FROM SOURCE, for M1 codegen work.
#
# The bench's default toolchain is a prebuilt, immutable tarball (/opt/llvm-mos);
# you cannot change codegen without building the compiler. This clones llvm-mos into
# vendor/ (gitignored), builds into build/llvm-mos, installs to build/llvm-mos-install,
# then point the bench at it with MOS_TOOLCHAIN=/work/build/llvm-mos-install:
#   MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build && ... corpus
# Runs INSIDE the dev container (clang/lld/ccache/cmake/ninja present). Drive from the
# host: dev/run.sh toolchain. See docs/plans/2026-06-14-m1-from-source-toolchain.md.
#
# RAM is the binding constraint (14 GiB host): Release + lld + a single link job keep
# peak memory down; ccache (persisted in build/.ccache) makes later rebuilds fast.
# Compile parallelism defaults conservative; raise/lower with BUILD_JOBS if it swaps.
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh toolchain   # build llvm-mos clang/lld from source -> build/llvm-mos-install"
  echo "Env: BUILD_JOBS (compile parallelism, default 6 — lower if the 14 GiB host swaps)"
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
SRC="$ROOT/vendor/llvm-mos"
BUILDDIR="$ROOT/build/llvm-mos"
INSTALL="$ROOT/build/llvm-mos-install"
JOBS="${BUILD_JOBS:-6}"
export CCACHE_DIR="$ROOT/build/.ccache"
# /opt/llvm-mos/bin (the mos CROSS toolchain) is first on the image PATH and shadows
# host tools — a bare clang/llvm-ar/assembler there targets mos, not x86-64. Put host
# /usr/bin first for this host build so every tool (incl. the .S assembler) is native.
export PATH="/usr/bin:$PATH"

echo "==> clone llvm-mos (shallow main) into vendor/ (gitignored)"
if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 https://github.com/llvm-mos/llvm-mos.git "$SRC"
fi
echo "    commit: $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo '?')"

# Trim the upstream MOS distribution to just clang + lld + the mos builtins. The
# stock cache also builds clang-tools-extra (clangd, clang-tidy, include-fixer, …) —
# heavy and irrelevant to codegen. We only need a working mos cross-compiler. Idempotent
# (no-op once patched); vendor/ is gitignored and disposable. Drop the 5 clang-tools-extra
# distribution components so install-distribution doesn't reference unbuilt targets.
echo "==> trim distribution to clang+lld (drop clang-tools-extra)"
sed -i \
  -e 's/clang;clang-tools-extra;lld/clang;lld/' \
  -e '/^[[:space:]]*clang-apply-replacements[[:space:]]*$/d' \
  -e '/^[[:space:]]*clang-include-fixer[[:space:]]*$/d' \
  -e '/^[[:space:]]*clang-tidy[[:space:]]*$/d' \
  -e '/^[[:space:]]*clangd[[:space:]]*$/d' \
  -e '/^[[:space:]]*find-all-symbols[[:space:]]*$/d' \
  "$SRC/clang/cmake/caches/MOS.cmake"

echo "==> configure (MOS.cmake cache, Release, host clang+lld, 1 link job, ccache)"
# Absolute host-clang paths: /opt/llvm-mos/bin is first on PATH (it holds the mos
# CROSS compiler, which can't build host binaries), so a bare `clang` would resolve
# there and fail the compiler check. The apt-installed host clang lives in /usr/bin.
cmake -C "$SRC/clang/cmake/caches/MOS.cmake" -G Ninja \
  -S "$SRC/llvm" -B "$BUILDDIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_ASM_COMPILER=/usr/bin/clang \
  -DLLVM_USE_LINKER=lld \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_CCACHE_BUILD=On

echo "==> build the distribution target (-j$JOBS); first build is long (~30-90 min)"
cmake --build "$BUILDDIR" --target distribution --parallel "$JOBS"

echo "==> install-distribution -> $INSTALL"
cmake --build "$BUILDDIR" --target install-distribution

echo "==> done in $((SECONDS/60))m $((SECONDS%60))s: $("$INSTALL/bin/mos-clang" --version | head -1)"
echo "    use it: MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build && ... corpus"

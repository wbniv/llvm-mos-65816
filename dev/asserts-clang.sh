#!/usr/bin/env bash
# dev/asserts-clang.sh — build an ASSERTS clang (with -debug-only support) into a
# SEPARATE build dir so the Release build/llvm-mos stays warm for the actual fix
# rebuild. Diagnostic only: builds just the `clang` + `llc` targets (no lld/builtins/
# install). Run the binary in place: build/llvm-mos-asserts/bin/clang --target=mos ...
# Drive in-container from the host (see command in the rc-undef plan).
set -euo pipefail
ROOT=/work
SRC="$ROOT/vendor/llvm-mos"
BUILDDIR="$ROOT/build/llvm-mos-asserts"
JOBS="${BUILD_JOBS:-6}"
export CCACHE_DIR="$ROOT/build/.ccache"
export PATH="/usr/bin:$PATH"

echo "==> configure asserts (Release+assertions, clang+llc targets only)"
cmake -G Ninja -S "$SRC/llvm" -B "$BUILDDIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="" \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="MOS" \
  -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_ASM_COMPILER=/usr/bin/clang \
  -DLLVM_USE_LINKER=lld \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_CCACHE_BUILD=On

echo "==> build clang + llc (-j$JOBS); first asserts build is long"
cmake --build "$BUILDDIR" --target clang llc --parallel "$JOBS"
echo "==> done in $((SECONDS/60))m $((SECONDS%60))s: $("$BUILDDIR/bin/clang" --version | head -1)"

#!/usr/bin/env bash
# Full build: vendor upstream llvm-mos-sdk, inject our platform(s), build the
# SDK + every SNES program. Runs INSIDE the dev container (/work = repo root).
# Drive it from the host via dev/run.sh.
#
# Toolchain is selectable via MOS_TOOLCHAIN (install prefix; default the prebuilt
# /opt/llvm-mos). Point it at the from-source build to validate codegen changes:
#   MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build   (see dev/toolchain.sh)
set -euo pipefail

ROOT=/work
VENDOR="$ROOT/vendor/llvm-mos-sdk"
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
MOS_TOOLCHAIN="${MOS_TOOLCHAIN:-/opt/llvm-mos}"
MOS_CLANG="$MOS_TOOLCHAIN/bin/mos-clang"
echo "==> toolchain: $MOS_CLANG ($("$MOS_CLANG" --version | head -1))"

echo "==> vendor upstream llvm-mos-sdk (clone once into vendor/, gitignored)"
if [ ! -d "$VENDOR/.git" ]; then
  git clone --depth 1 https://github.com/llvm-mos/llvm-mos-sdk.git "$VENDOR"
fi

echo "==> inject our platforms into the SDK tree"
for p in "$ROOT"/platforms/*/; do
  name="$(basename "$p")"
  rm -rf "$VENDOR/mos-platform/$name"
  cp -r "$p" "$VENDOR/mos-platform/$name"
  grep -q "add_subdirectory($name)" "$VENDOR/mos-platform/CMakeLists.txt" || \
    printf 'add_subdirectory(%s)\n' "$name" >> "$VENDOR/mos-platform/CMakeLists.txt"
  echo "    + $name"
done

# CMake can't change the cross-compiler on an already-configured build tree (it
# re-runs the compiler check and bails). If MOS_TOOLCHAIN differs from the last build,
# wipe the SDK build artifacts (only — never the llvm-mos build/install/.ccache).
STAMP="$BUILD/.mos-toolchain"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" != "$MOS_TOOLCHAIN" ]; then
  echo "==> toolchain changed ($(cat "$STAMP") -> $MOS_TOOLCHAIN); wiping SDK build tree"
  rm -rf "$BUILD/CMakeCache.txt" "$BUILD/CMakeFiles" "$BUILD/mos-platform" \
         "$BUILD/build.ninja" "$BUILD/cmake_install.cmake" "$INSTALL"
fi

echo "==> configure + build SDK"
cmake -S "$VENDOR" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DLLVM_MOS_BUILD_EXAMPLES=Off \
  -DLLVM_MOS="$MOS_TOOLCHAIN" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL"
cmake --build "$BUILD"
cmake --install "$BUILD"
echo "$MOS_TOOLCHAIN" > "$STAMP"

echo "==> build + checksum every SNES program (examples/snes/**/*.c)"
shopt -s globstar nullglob
count=0
for src in "$ROOT"/examples/snes/**/*.c; do
  name="$(basename "$src" .c)"
  rom="$BUILD/$name.sfc"
  "$MOS_CLANG" --config "$INSTALL/bin/mos-snes.cfg" \
    -Os -Wl,-Map="$BUILD/$name.map" -o "$rom" "$src"
  python3 "$ROOT/tools/snes-checksum.py" "$rom"
  printf '    %-14s %6s bytes\n' "$name" "$(stat -c%s "$rom")"
  count=$((count + 1))
done
echo "==> built $count program(s)"

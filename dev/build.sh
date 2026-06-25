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

# Generate the baked Mandelbrot header (gitignored) that examples/snes/mandel-interactive.c needs
# before the loop compiles it — keeps it reproducible-from-source rather than committed.
echo "==> bake examples/snes/mandel_image.h (tools/mandel-bake.c)"
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/mandel-bake.c" -o "$BUILD/mandel-bake" -lm
"$BUILD/mandel-bake" "$ROOT/examples/snes/mandel_image.h" 128 128 32

echo "==> build + checksum every SNES program (examples/snes/**/*.c)"
shopt -s globstar nullglob
# Does this toolchain support the #321 +mos-a16 feature? The prebuilt /opt/llvm-mos does NOT;
# the from-source build/llvm-mos-install does. mos-a16-only examples are skipped if it doesn't.
a16probe="$("$MOS_CLANG" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -x c -S -o /dev/null - <<<'int main(void){return 0;}' 2>&1 || true)"
case "$a16probe" in
  *"not a recognized feature"*) A16_OK=0
    echo "    (+mos-a16 unsupported by this toolchain — mos-a16-only examples SKIPPED; use MOS_TOOLCHAIN=$BUILD/llvm-mos-install for those)" ;;
  *) A16_OK=1 ;;
esac
count=0
for src in "$ROOT"/examples/snes/**/*.c; do
  name="$(basename "$src" .c)"
  rom="$BUILD/$name.sfc"
  # Far-pointer examples (address_space(2) high-WRAM buffers, e.g. mandel-mode7.c) self-declare a
  # `mos-a16-only` marker; they REQUIRE +mos-a16 (default-8bit can't legalize a `p2` G_PTR_ADD).
  # The grep survives the far type being spelled via a macro (M7_FAR). Skip if unsupported.
  a16=()
  if grep -q 'mos-a16-only' "$src"; then
    [ "$A16_OK" = 1 ] || { printf '    %-14s SKIP (mos-a16-only; toolchain lacks +mos-a16)\n' "$name"; continue; }
    a16=(-mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16)
  fi
  "$MOS_CLANG" --config "$INSTALL/bin/mos-snes.cfg" "${a16[@]}" \
    -Os -Wl,-Map="$BUILD/$name.map" -o "$rom" "$src"
  python3 "$ROOT/tools/snes-checksum.py" "$rom"
  printf '    %-14s %6s bytes\n' "$name" "$(stat -c%s "$rom")"
  count=$((count + 1))
done
echo "==> built $count program(s)"

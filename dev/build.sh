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
# Default to the from-source toolchain when it's been built: it carries the #321/#320 fork
# patches, so it supports +mos-a16 (16-bit accumulator + far high-WRAM pointers) and the
# mos-a16-only examples (mandel-display, …) BUILD instead of being skipped. Fall back to the
# prebuilt /opt/llvm-mos only if the from-source toolchain isn't present (then a16 ROMs skip,
# loudly). Override either way with MOS_TOOLCHAIN. Build it with: dev/run.sh toolchain.
if [ -z "${MOS_TOOLCHAIN:-}" ]; then
  if [ -x "$BUILD/llvm-mos-install/bin/mos-clang" ]; then MOS_TOOLCHAIN="$BUILD/llvm-mos-install"
  else MOS_TOOLCHAIN="/opt/llvm-mos"; fi
fi
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
# Does this toolchain support the #321 +mos-a16 feature? The prebuilt /opt/llvm-mos does NOT;
# the from-source build/llvm-mos-install does. mos-a16-only examples are skipped if it doesn't.
a16probe="$("$MOS_CLANG" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -x c -S -o /dev/null - <<<'int main(void){return 0;}' 2>&1 || true)"
case "$a16probe" in
  *"not a recognized feature"*) A16_OK=0
    echo "    (+mos-a16 unsupported by this toolchain — mos-a16-only examples SKIPPED; use MOS_TOOLCHAIN=$BUILD/llvm-mos-install for those)" ;;
  *) A16_OK=1 ;;
esac
OBJCOPY="$MOS_TOOLCHAIN/bin/llvm-objcopy"
count=0
for src in "$ROOT"/examples/snes/**/*.c; do
  name="$(basename "$src" .c)"
  rom="$BUILD/$name.sfc"
  # Far-pointer examples (address_space(2) high-WRAM buffers, e.g. mandel-display.c) self-declare a
  # `mos-a16-only` marker; they REQUIRE +mos-a16 (default-8bit can't legalize a `p2` G_PTR_ADD).
  # The grep survives the far type being spelled via a macro (M7_FAR). Skip if unsupported.
  a16=()
  if grep -q 'mos-a16-only' "$src"; then
    [ "$A16_OK" = 1 ] || { printf '    %-14s SKIP (mos-a16-only; toolchain lacks +mos-a16)\n' "$name"; continue; }
    a16=(-mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16)
  fi
  # Sidecar binary assets: objcopy committed examples/snes/<name>.{pic,pal,map,chr,bin} into
  # bank-$00 .rodata objects and link them (Option B — raw gfx4snes output, no compiled C arrays;
  # symbols _binary_<name>_<ext>_start/_end/_size). Run from the asset dir so symbol names are clean.
  assets=()
  for ext in pic pal map chr bin; do
    a="$ROOT/examples/snes/$name.$ext"
    [ -e "$a" ] || continue
    o="$BUILD/$name.$ext.o"
    ( cd "$ROOT/examples/snes" && "$OBJCOPY" -I binary -O elf32-mos \
        --rename-section ".data=.rodata.${name}_${ext},alloc,load,readonly,data,contents" \
        "$name.$ext" "$o" )
    assets+=("$o")
  done
  "$MOS_CLANG" --config "$INSTALL/bin/mos-snes.cfg" "${a16[@]}" \
    -Os -Wl,-Map="$BUILD/$name.map" -o "$rom" "$src" "${assets[@]}"
  python3 "$ROOT/tools/snes-checksum.py" "$rom"
  printf '    %-14s %6s bytes\n' "$name" "$(stat -c%s "$rom")"
  count=$((count + 1))
done
echo "==> built $count program(s)"

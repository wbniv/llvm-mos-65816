#!/usr/bin/env bash
# Full build: vendor upstream llvm-mos-sdk, inject our platform(s), build the
# SDK + the smoke ROM. Runs INSIDE the dev container (/work = repo root,
# toolchain on PATH at /opt/llvm-mos/bin). Drive it from the host via dev/run.sh.
set -euo pipefail

ROOT=/work
VENDOR="$ROOT/vendor/llvm-mos-sdk"
BUILD="$ROOT/build"
INSTALL="$BUILD/install"

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

echo "==> configure + build SDK"
cmake -S "$VENDOR" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DLLVM_MOS_BUILD_EXAMPLES=Off \
  -DCMAKE_INSTALL_PREFIX="$INSTALL"
cmake --build "$BUILD"
cmake --install "$BUILD"

echo "==> build + checksum the M0 smoke ROM"
/opt/llvm-mos/bin/mos-clang --config "$INSTALL/bin/mos-snes.cfg" \
  -Os -Wl,-Map="$BUILD/hello.map" -o "$BUILD/hello.sfc" "$ROOT/examples/snes/hello.c"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/hello.sfc"
ls -l "$BUILD/hello.sfc"

#!/usr/bin/env bash
# Fast iteration: refresh the snes linker script + header into the already-built
# SDK install tree, recompile the smoke ROM, patch the checksum. Use build.sh
# for a clean from-scratch build. Runs INSIDE the dev container.
set -euo pipefail

ROOT=/work
INSTALL="$ROOT/build/install"
SRC="$ROOT/platforms/snes"

cp "$SRC/link.ld" "$INSTALL/mos-platform/snes/lib/link.ld"
cp "$SRC/snes.h"  "$INSTALL/mos-platform/snes/include/snes.h"

/opt/llvm-mos/bin/mos-clang --config "$INSTALL/bin/mos-snes.cfg" \
  -Os -Wl,-Map="$ROOT/build/hello.map" -o "$ROOT/build/hello.sfc" \
  "$ROOT/examples/snes/hello.c"

python3 "$ROOT/tools/snes-checksum.py" "$ROOT/build/hello.sfc"
ls -l "$ROOT/build/hello.sfc"

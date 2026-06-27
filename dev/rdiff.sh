#!/usr/bin/env bash
# dev/rdiff.sh — render the Gray-Scott reaction-diffusion demo (#8 compiler stress-test) on SNES
# (examples/snes/rdiff.c, +mos-a16) and capture emulator screenshots from BOTH cores headless,
# each asserting corpus_result == the host oracle (tools/rdiff-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps framebuffer + asserts.
#   * MAME     — under Xvfb, dev/rdiff.lua snapshots + asserts.
# Plus a disasm gate proving the gs_step hot loop has __mulsi3 (×≥2) + rep/sep.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh rdiff.  Outputs build/rdiff-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh rdiff   # render Gray-Scott demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/rdiff.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (differential anchor; rdiff.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/rdiff-sim.c" -o "$BUILD/rdiff-sim"
EXPECT=$("$BUILD/rdiff-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: Gray-Scott gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/rdiff.map" -o "$BUILD/rdiff.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/rdiff.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/rdiff.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/rdiff.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: gs_step hot loop must have __mulsi3 (×≥2 from u*v and uv*v) + rep/sep.
echo "==> disasm gate (Gray-Scott u*v² mul-add + native-16 codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/rdiff_sim.c" -I"$ROOT/examples" -o "$BUILD/rdiff_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/rdiff_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$( printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  rep/sep=$rs  (u*v² fixed-point mul-add, native-16)"
else
  echo "    FAIL  __mulsi3=$mul  rep/sep=$rs  (expected __mulsi3>=2 and rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg — build harness if needed, dump framebuffer + assert.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/rdiff-jg.png) + assert"
  "$JGX" "$BUILD/rdiff.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/rdiff-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/rdiff-mame.png)"
  SNAP="$BUILD/.rdiff-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/rdiff.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/rdiff.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/rdiff-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Gray-Scott rdiff rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

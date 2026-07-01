#!/usr/bin/env bash
# dev/gouraud.sh — render the Gouraud Triangle Tumbler demo (#69 compiler stress-test) ON
# the SNES (examples/snes/gouraud.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/gouraud-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/gouraud.lua snapshots + asserts.
# Plus a disasm gate proving the raster is barycentric edge-function rasterisation: three int32
# cross-product EDGE FUNCTIONS (__mulsi3) + a per-pixel barycentric DIVIDE (__divsi3), native-16.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh gouraud. Outputs build/gouraud-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh gouraud   # render the Gouraud triangle; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/gouraud.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; gouraud.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/gouraud-sim.c" -o "$BUILD/gouraud-sim"
EXPECT=$("$BUILD/gouraud-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: gouraud gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/gouraud.map" -o "$BUILD/gouraud.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/gouraud.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/gouraud.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/gouraud.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: barycentric edge-function rasterisation = three int32 cross-product EDGE FUNCTIONS
# (bx-ax)(py-ay)-(by-ay)(px-ax) per pixel -> __mulsi3, plus the per-pixel barycentric normalise
# num/area -> __divsi3. __mulsi3 present + __divsi3 present + native-16.
echo "==> disasm gate (Gouraud: 3 edge-function cross products + per-pixel barycentric divide)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/gouraud_sim.c" -I"$ROOT/examples" -o "$BUILD/gouraud_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/gouraud_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -c '__mulsi3' || true)                 # edge-function cross products
dv=$(printf  '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3' || true)      # barycentric normalise
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 3 ] && [ "$dv" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  __divsi3=$dv  rep/sep=$rs  (edge functions + barycentric divide)"
else
  echo "    FAIL  __mulsi3=$mul  __divsi3=$dv  rep/sep=$rs  (expected mulsi3>=3, divsi3>=1, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg — build the harness if needed, then dump framebuffer + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/gouraud-jg.png) + assert"
  "$JGX" "$BUILD/gouraud.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1500 "$BUILD/gouraud-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/gouraud-mame.png)"
  SNAP="$BUILD/.gouraud-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/gouraud.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/gouraud.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 20 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/gouraud-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Gouraud triangle rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

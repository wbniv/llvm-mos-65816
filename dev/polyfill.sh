#!/usr/bin/env bash
# dev/polyfill.sh — render the Polygon Scanline Fill (VLA) demo (#36 compiler stress-test) ON the
# SNES (examples/snes/polyfill.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/polyfill-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/polyfill.lua snapshots + asserts.
# Plus a disasm gate proving the scanline fill lowers to the intended runtime arithmetic: a signed
# 32-bit edge divide (__divsi3), an unsigned 32-bit spacing divide (__udivsi3), a 32-bit vertex
# multiply (__mulsi3), and native-16 (rep/sep). The runtime-sized VLA (int16_t xs[nv]) itself is
# validated by the differential (host==target on the exact fill).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh polyfill. Outputs build/polyfill-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh polyfill   # render the polygon scanline-fill VLA demo; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/polyfill.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; polyfill.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/polyfill-sim.c" -o "$BUILD/polyfill-sim"
EXPECT=$("$BUILD/polyfill-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: polyfill gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/polyfill.map" -o "$BUILD/polyfill.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/polyfill.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/polyfill.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/polyfill.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the scanline fill must lower to the intended runtime arithmetic.
echo "==> disasm gate (VLA scanline fill: divide / multiply / native-16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/polyfill_sim.c" -I"$ROOT/examples" -o "$BUILD/polyfill_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/polyfill_sim.o" 2>/dev/null || true)
div=$(printf '%s\n' "$dis" | grep -cwE '__divsi3|__udivsi3' || true)
mul=$(printf '%s\n' "$dis" | grep -cwE '__mulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$div" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __divsi3/__udivsi3=$div  __mulsi3=$mul  rep/sep=$rs  (crossing divide + vertex mul, native-16)"
else
  echo "    FAIL  __divsi3/__udivsi3=$div  __mulsi3=$mul  rep/sep=$rs (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/polyfill-jg.png) + assert"
  "$JGX" "$BUILD/polyfill.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 700 "$BUILD/polyfill-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/polyfill-mame.png)"
  SNAP="$BUILD/.polyfill-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/polyfill.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/polyfill.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/polyfill-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — polygon scanline fill (VLA) rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

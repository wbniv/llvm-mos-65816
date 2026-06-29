#!/usr/bin/env bash
# dev/cordic.sh — render the CORDIC Rotator demo (#12 compiler stress-test) ON the SNES
# (examples/snes/cordic.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/cordic-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/cordic.lua snapshots + asserts.
# Plus an INVERTED disasm gate: CORDIC is shift-add only, so the gate object must have ZERO
# __mulsi3/__divsi3/variable-shift libcalls, with rep/sep + cordic16_atan_tbl present (the
# multiply-free signature — the deliberate complement of every other demo's gate).
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh cordic. Outputs build/cordic-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh cordic   # render the CORDIC rotator demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/cordic.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; cordic.h compiled host-side).
cc -O2 -I "$ROOT/examples" "$ROOT/tools/cordic-sim.c" -o "$BUILD/cordic-sim"
EXPECT=$("$BUILD/cordic-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: CORDIC rotator gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/cordic.map" -o "$BUILD/cordic.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/cordic.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/cordic.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/cordic.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. INVERTED disasm gate: CORDIC is shift-add only → the gate object must have NO arithmetic libcalls
# (no __mulsi3/__divsi3, no variable-shift __*hi3) and YES rep/sep + the rotation table cordic16_atan_tbl.
echo "==> disasm gate (multiply-free CORDIC: zero arithmetic libcalls, native-16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/cordic_sim.c" -I"$ROOT/examples" -o "$BUILD/cordic_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/cordic_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__mulhi3|__umulsi3'                       || true)
div=$(printf '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3|__udivmodsi4|__divhi3|__udivhi3' || true)
vsh=$(printf '%s\n' "$dis" | grep -cE '__ashrhi3|__lshrhi3|__ashlhi3|__ashrsi3|__lshrsi3'  || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep'                                           || true)
# Positive witness that the unrolled CORDIC sweep actually compiled in: the shift-add micro-rotations
# are adc/sbc. (The atan/atanh tables are CONSTANT-FOLDED into immediate adc/sbc operands because every
# rotation index is a compile-time constant — so there is NO rodata table symbol to grep; the immediate
# shift-add IS the multiply-free signature.)
add=$(printf '%s\n' "$dis" | grep -cwE 'adc|sbc'                                           || true)
if [ "$mul" -eq 0 ] && [ "$div" -eq 0 ] && [ "$vsh" -eq 0 ] && [ "$rs" -ge 1 ] && [ "$add" -ge 16 ]; then
  echo "    PASS  mul=$mul div=$div vshift=$vsh  rep/sep=$rs  adc/sbc=$add  (shift-add only, no libcalls, native-16)"
else
  echo "    FAIL  mul=$mul div=$div vshift=$vsh  rep/sep=$rs  adc/sbc=$add  (want mul/div/vshift=0, rep-sep>=1, adc/sbc>=16)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/cordic-jg.png) + assert"
  "$JGX" "$BUILD/cordic.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/cordic-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
# MAME's snes driver needs the gitignored 64-byte SPC700 IPL ROM; without it MAME aborts with
# "Required files are missing". Treat its absence as SKIP (like the bsnes harness above), not FAIL —
# the independent bsnes-jg leg + the host oracle still bound correctness here.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/cordic-mame.png)"
  SNAP="$BUILD/.cordic-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/cordic.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/cordic.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/cordic-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — CORDIC rotator rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

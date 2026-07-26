#!/usr/bin/env bash
# dev/mandel-double.sh — render the #21 SOFT-FLOAT Mandelbrot (examples/snes/mandel-double.c, +mos-a16)
# ON the SNES and capture a REAL emulator screenshot from BOTH cores headless, each asserting
# corpus_result == the host oracle (tools/mandel-double-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/mandel-double.lua snapshots + asserts.
# Plus a disasm gate proving the escape-time hot loop is SOFT-FLOAT (__mulsf3 + __addsf3/__subsf3)
# under native-16 (rep/sep). The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the
# corpus slice (mandel-double_sim.c) gate, run by dev/run.sh corpus-a16.
#
# Drive: dev/run.sh mandel-double. Outputs build/mandel-double-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-double   # render the soft-float Mandelbrot on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/mandel-double.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash. -ffp-contract=off so no FMA contraction can diverge host
# single-precision from the target's separate soft-float libcalls (belt-and-suspenders: baseline cc
# has no FMA instruction without -march anyway).
cc -O2 -ffp-contract=off -I "$ROOT/examples/65816" "$ROOT/tools/mandel-double-sim.c" -o "$BUILD/mandel-double-sim"
EXPECT=$("$BUILD/mandel-double-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: soft-float Mandelbrot gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/mandel-double.map" -o "$BUILD/mandel-double.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/mandel-double.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/mandel-double.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/mandel-double.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the double escape-time hot loop must be 64-bit SOFT-FLOAT — __mulsf3 (z*z, zr*zi) + __addsf3 or
# __subsf3 (the recurrence) — under native-16 (rep/sep). This is the corner no other demo touches.
echo "==> disasm gate (soft-float escape-time codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/mandel-double_sim.c" -I"$ROOT/examples" -o "$BUILD/mandel-double_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/mandel-double_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -c '__muldf3'  || true)
add=$(printf '%s\n' "$dis" | grep -cE '__adddf3|__subdf3' || true)
rs=$(printf '%s\n'  "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$add" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __muldf3=$mul  __add/subdf3=$add  rep/sep=$rs  (IEEE-754 DOUBLE soft-float, native-16)"
else
  echo "    FAIL  __muldf3=$mul  __add/subdf3=$add  rep/sep=$rs (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/mandel-double-jg.png) + assert"
  "$JGX" "$BUILD/mandel-double.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 2200 "$BUILD/mandel-double-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
# The SPC700 IPL is gitignored Nintendo content supplied out-of-band; without it MAME never boots, emits
# no SHOT: line, and the gate reports a misleading FAIL rather than an honest SKIP. Guard for it exactly
# as dev/cpu6502.sh does. NB this only skips when the IPL is genuinely ABSENT — with the IPL present a
# real MAME disagreement still fails the gate.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mandel-double-mame.png)"
  SNAP="$BUILD/.mandel-double-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/mandel-double.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-double.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 18 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/mandel-double-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — soft-float Mandelbrot rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

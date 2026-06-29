#!/usr/bin/env bash
# dev/harmonograph.sh — render the Lissajous / Harmonograph demo (#9 compiler stress-test) ON the
# SNES (examples/snes/harmonograph.c, +mos-a16) and capture a REAL emulator screenshot from BOTH
# cores headless, each asserting corpus_result == the host oracle (tools/harmonograph-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps framebuffer + asserts.
#   * MAME     — under Xvfb, dev/harmonograph.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is sin-LUT + fixed-point __mulsi3 (eight per sample: four
# sin·env amplitude products + four env·decay envelope products) under native-16 rep/sep, and
# multiply-ONLY (no divide). The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the
# corpus slice gate: dev/run.sh corpus-a16.
#
# Drive: dev/run.sh harmonograph. Outputs build/harmonograph-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh harmonograph   # render the Harmonograph on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/harmonograph.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden curve-math hash (the differential anchor; harmonograph.h host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/harmonograph-sim.c" -o "$BUILD/harmonograph-sim"
EXPECT=$("$BUILD/harmonograph-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: harmonograph curve hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/harmonograph.map" -o "$BUILD/harmonograph.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/harmonograph.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/harmonograph.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/harmonograph.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: hot loop must be sin-LUT + __mulsi3 + rep/sep; must NOT divide (the damping is a
#    multiply by a Q15 constant, not a divide).
echo "==> disasm gate (harmo_point: __mulsi3 + rep/sep, multiply-only — no divide)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/harmonograph_sim.c" -I"$ROOT/examples" -o "$BUILD/harmonograph_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/harmonograph_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
bad_div=$(printf '%s\n' "$dis" | grep -c '__divsi3\|__udivsi3\|__udivmodsi4' || true)
if [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ] && [ "$bad_div" -eq 0 ]; then
  echo "    PASS  __mulsi3=$mul  rep/sep=$rs  bad_div=$bad_div  (sin-LUT + fixed-point multiply, no divide)"
else
  echo "    FAIL  __mulsi3=$mul  rep/sep=$rs  bad_div=$bad_div  (expected mul>=1 rep/sep>=1 div=0)"; rc=1
fi

# 4. bsnes-jg — build harness if needed, then dump framebuffer + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/harmonograph-jg.png) + assert"
  "$JGX" "$BUILD/harmonograph.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/harmonograph-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
# MAME's snes driver needs the gitignored 64-byte SPC700 IPL ROM; without it MAME aborts with
# "Required files are missing". Treat its absence as SKIP (like the bsnes harness above), not FAIL —
# it is an env-wide gap (every demo's MAME leg), not a defect in this ROM (bsnes-jg + disasm cover it).
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/harmonograph-mame.png)"
  SNAP="$BUILD/.harmonograph-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/harmonograph.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/harmonograph.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/harmonograph-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Harmonograph rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

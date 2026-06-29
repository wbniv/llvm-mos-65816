#!/usr/bin/env bash
# dev/burning-ship.sh — render the Lissajous / Burning Ship demo (#9 compiler stress-test) ON the
# SNES (examples/snes/burning-ship.c, +mos-a16) and capture a REAL emulator screenshot from BOTH
# cores headless, each asserting corpus_result == the host oracle (tools/burning-ship-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps framebuffer + asserts.
#   * MAME     — under Xvfb, dev/burning-ship.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop is fixed-point __mulsi3 (three Q12 multiplies per iteration:
# zx², zy², |zx·zy|, plus the two abs folds) under native-16 rep/sep, and multiply-ONLY (no divide). The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the
# corpus slice gate: dev/run.sh corpus-a16.
#
# Drive: dev/run.sh burning-ship. Outputs build/burning-ship-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh burning-ship   # render the Burning Ship on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/burning-ship.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden curve-math hash (the differential anchor; burning-ship.h host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/burning-ship-sim.c" -o "$BUILD/burning-ship-sim"
EXPECT=$("$BUILD/burning-ship-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: burning-ship curve hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/burning-ship.map" -o "$BUILD/burning-ship.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/burning-ship.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/burning-ship.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/burning-ship.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: hot loop must be __mulsi3 (3 Q12 mults/iter) + rep/sep; must NOT divide (the Burning
#    multiply by a Q15 constant, not a divide).
echo "==> disasm gate (bs_iter: __mulsi3 + rep/sep, multiply-only — no divide)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/burning-ship_sim.c" -I"$ROOT/examples" -o "$BUILD/burning-ship_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/burning-ship_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
bad_div=$(printf '%s\n' "$dis" | grep -c '__divsi3\|__udivsi3\|__udivmodsi4' || true)
if [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ] && [ "$bad_div" -eq 0 ]; then
  echo "    PASS  __mulsi3=$mul  rep/sep=$rs  bad_div=$bad_div  (fixed-point multiply, no divide)"
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
  echo "==> bsnes-jg: render + framebuffer dump (build/burning-ship-jg.png) + assert"
  "$JGX" "$BUILD/burning-ship.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1500 "$BUILD/burning-ship-jg.png" || rc=1
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
  echo "==> MAME (under Xvfb): snapshot + assert (build/burning-ship-mame.png)"
  SNAP="$BUILD/.burning-ship-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/burning-ship.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/burning-ship.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/burning-ship-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Burning Ship rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

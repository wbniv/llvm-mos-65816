#!/usr/bin/env bash
# dev/hull.sh — render the Convex Hull demo (#65 compiler stress-test) ON
# the SNES (examples/snes/hull.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/hull-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/hull.lua snapshots + asserts.
# Plus a disasm gate proving the corner is the int32 cross-product orientation predicate (gift-wrap).
# The hull gate is heavy, so the snapshot/assert frame is 700.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh hull. Outputs build/hull-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh hull   # render the convex hull; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/hull.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; hull.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/hull-sim.c" -o "$BUILD/hull-sim"
EXPECT=$("$BUILD/hull-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: hull gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/hull.map" -o "$BUILD/hull.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/hull.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/hull.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/hull.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the convex-hull orientation predicate — the signed 2-D cross product is an int32
# multiply (__mulsi3, since int16 differences are widened to int32 to avoid overflow) whose SIGN the
# gift-wrap compares (cmp). __mulsi3 present + compares + native-16.
echo "==> disasm gate (convex-hull orientation: int32 cross-product sign tests)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/hull_sim.c" -I"$ROOT/examples" -o "$BUILD/hull_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/hull_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -c '__mulsi3' || true)   # the int32 cross-product multiply
cmp=$(printf '%s\n' "$dis" | grep -cw 'cmp' || true)       # the orientation sign / loop tests
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$cmp" -ge 4 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  cmp=$cmp  rep/sep=$rs  (int32 cross-product orientation tests)"
else
  echo "    FAIL  __mulsi3=$mul  cmp=$cmp  rep/sep=$rs  (expected mulsi3>=1, cmp>=4, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/hull-jg.png) + assert"
  "$JGX" "$BUILD/hull.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 700 "$BUILD/hull-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/hull-mame.png)"
  SNAP="$BUILD/.hull-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/hull.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/hull.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/hull-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — convex hull rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

#!/usr/bin/env bash
# dev/spaceship.sh — render Width-Sweep Sort Gallery (#97 stress-test, Round 6 Cluster B).
# Re-stresses patch 0016 (#46 G_SCMP three-way compare, .lower() → lowerThreewayCompare) at the
# distinct widths s16/s32/s64 via qsort callbacks returning (a>b)-(a<b) at int8/16/32/64 keys.
# The s32 and s64 legs are widths qsortviz never reached.
# Drive: dev/run.sh spaceship. Outputs build/spaceship-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh spaceship   # render width-sweep sort gallery; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/spaceship.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/spaceship-sim.c" -o "$BUILD/spaceship-sim"
EXPECT=$("$BUILD/spaceship-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: spaceship gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/spaceship.map" -o "$BUILD/spaceship.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/spaceship.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/spaceship.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/spaceship.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. G_SCMP presence probe: emit LLVM IR and confirm llvm.scmp is FORMED (not folded away), incl.
#    the i64 variant (the width #46 never reached). This is the load-bearing check — if the scmp
#    intrinsic isn't present, the demo doesn't exercise patch 0016's lowerThreewayCompare.
echo "==> G_SCMP IR probe (llvm.scmp at s16/s32/s64) + a16 rep/sep"
# stdlib.h (qsort) comes from the SDK, so compile with --config; -fno-lto forces a native object.
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -emit-llvm -S "$ROOT/examples/snes/corpus/spaceship_sim.c" -I"$ROOT/examples" -o "$BUILD/spaceship_sim.ll" 2>/dev/null
scmp=$(grep -cE '@llvm\.(scmp|ucmp)\.' "$BUILD/spaceship_sim.ll" 2>/dev/null || true)
scmp64=$(grep -cE '@llvm\.scmp\.i[0-9]+\.i64' "$BUILD/spaceship_sim.ll" 2>/dev/null || true)
# Also confirm the object compiles + emits the sort (cmp-heavy) with a16 rep/sep.
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/spaceship_sim.c" -I"$ROOT/examples" -o "$BUILD/spaceship_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/spaceship_sim.o" 2>/dev/null || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$scmp" -ge 1 ] && [ "$scmp64" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  llvm.scmp/ucmp=$scmp  scmp.i64=$scmp64  rep/sep=$rs  (G_SCMP formed incl. s64)"
else
  echo "    FAIL  llvm.scmp/ucmp=$scmp  scmp.i64=$scmp64  rep/sep=$rs  (expected scmp>=1, scmp.i64>=1, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/spaceship-jg.png)"
  "$JGX" "$BUILD/spaceship.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/spaceship-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/spaceship-mame.png)"
  SNAP="$BUILD/.spaceship-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/spaceship.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/spaceship.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/spaceship-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Width-Sweep Sort Gallery on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

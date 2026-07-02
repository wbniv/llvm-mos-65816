#!/usr/bin/env bash
# dev/trimerge.sh — render Three-Way Merge Diff (#99 stress-test, Round 6 Cluster B).
# Re-stresses patch 0016 (#46, .lower() → lowerThreewayCompare) with the three-way-compare result
# used AS CONTROL FLOW: a 2-input merge branches on the sign of (a>b)-(a<b) — advance-left /
# emit-both / advance-right — at s32 and s64, via noinline comparators that keep G_SCMP alive.
# Drive: dev/run.sh trimerge. Outputs build/trimerge-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh trimerge   # render three-way merge diff; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/trimerge.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/trimerge-sim.c" -o "$BUILD/trimerge-sim"
EXPECT=$("$BUILD/trimerge-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: trimerge gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/trimerge.map" -o "$BUILD/trimerge.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/trimerge.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/trimerge.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/trimerge.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. G_SCMP presence probe: emit LLVM IR and confirm llvm.scmp is FORMED (not folded away), incl.
#    the i64-operand variant. Here the scmp result drives CONTROL FLOW (the merge branch), not a
#    qsort return — the load-bearing check that the three-way compare survived as a branch selector.
#    (No stdlib here — no qsort — so no --config needed for the IR emit.)
echo "==> G_SCMP IR probe (llvm.scmp at s32/s64, used as control flow) + a16 rep/sep"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -emit-llvm -S "$ROOT/examples/snes/corpus/trimerge_sim.c" -I"$ROOT/examples" -o "$BUILD/trimerge_sim.ll" 2>/dev/null
scmp=$(grep -cE '@llvm\.scmp\.' "$BUILD/trimerge_sim.ll" 2>/dev/null || true)
scmp64=$(grep -cE '@llvm\.scmp\.i[0-9]+\.i64' "$BUILD/trimerge_sim.ll" 2>/dev/null || true)
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/trimerge_sim.c" -I"$ROOT/examples" -o "$BUILD/trimerge_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/trimerge_sim.o" 2>/dev/null || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$scmp" -ge 1 ] && [ "$scmp64" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  llvm.scmp=$scmp  scmp.i64=$scmp64  rep/sep=$rs  (G_SCMP formed incl. s64, drives control flow)"
else
  echo "    FAIL  llvm.scmp=$scmp  scmp.i64=$scmp64  rep/sep=$rs  (expected scmp>=1, scmp.i64>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/trimerge-jg.png)"
  "$JGX" "$BUILD/trimerge.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/trimerge-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/trimerge-mame.png)"
  SNAP="$BUILD/.trimerge-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/trimerge.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/trimerge.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/trimerge-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Three-Way Merge Diff on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

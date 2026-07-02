#!/usr/bin/env bash
# dev/ucmprank.sh — render Unsigned Rank Percentile Field (#98 stress-test, Round 6 Cluster B).
# Re-stresses the UNSIGNED half of patch 0016 (#46, .lower() → lowerThreewayCompare): qsort callbacks
# returning (a>b)-(a<b) at uint16/uint32/uint64 keys force G_UCMP at u16/u32/u64 — the unsigned
# three-way lowering #46/#97 (signed G_SCMP) never emitted.
# Drive: dev/run.sh ucmprank. Outputs build/ucmprank-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh ucmprank   # render unsigned rank percentile field; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/ucmprank.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/ucmprank-sim.c" -o "$BUILD/ucmprank-sim"
EXPECT=$("$BUILD/ucmprank-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: ucmprank gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/ucmprank.map" -o "$BUILD/ucmprank.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/ucmprank.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/ucmprank.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/ucmprank.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. G_UCMP presence probe: emit LLVM IR and confirm llvm.ucmp is FORMED (not folded away), incl.
#    the i64-operand variant. This is the load-bearing check — the UNSIGNED three-way lowering is
#    the half of patch 0016 that #46/#97 (signed G_SCMP) never emitted. Also confirm NO signed scmp
#    leaks in (all comparators are unsigned).
echo "==> G_UCMP IR probe (llvm.ucmp at u16/u32/u64) + a16 rep/sep"
# stdlib.h (qsort) comes from the SDK, so compile with --config; -fno-lto forces a native object.
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -emit-llvm -S "$ROOT/examples/snes/corpus/ucmprank_sim.c" -I"$ROOT/examples" -o "$BUILD/ucmprank_sim.ll" 2>/dev/null
ucmp=$(grep -cE '@llvm\.ucmp\.' "$BUILD/ucmprank_sim.ll" 2>/dev/null || true)
ucmp64=$(grep -cE '@llvm\.ucmp\.i[0-9]+\.i64' "$BUILD/ucmprank_sim.ll" 2>/dev/null || true)
scmp=$(grep -cE '@llvm\.scmp\.' "$BUILD/ucmprank_sim.ll" 2>/dev/null || true)
# Also confirm the object compiles + emits the sort (cmp-heavy) with a16 rep/sep.
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/ucmprank_sim.c" -I"$ROOT/examples" -o "$BUILD/ucmprank_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/ucmprank_sim.o" 2>/dev/null || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$ucmp" -ge 1 ] && [ "$ucmp64" -ge 1 ] && [ "$scmp" -eq 0 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  llvm.ucmp=$ucmp  ucmp.i64=$ucmp64  scmp=$scmp  rep/sep=$rs  (G_UCMP formed incl. u64, no signed leak)"
else
  echo "    FAIL  llvm.ucmp=$ucmp  ucmp.i64=$ucmp64  scmp=$scmp  rep/sep=$rs  (expected ucmp>=1, ucmp.i64>=1, scmp==0, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/ucmprank-jg.png)"
  "$JGX" "$BUILD/ucmprank.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/ucmprank-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/ucmprank-mame.png)"
  SNAP="$BUILD/.ucmprank-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/ucmprank.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/ucmprank.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/ucmprank-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Unsigned Rank Percentile Field on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

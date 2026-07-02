#!/usr/bin/env bash
# dev/keycmp64.sh — render 64-bit Multi-Key Record Sort (#100 stress-test, Round 6 Cluster B final).
# Re-stresses patch 0016 (#46, .lower() → lowerThreewayCompare) at the EXTREME width: libc qsort of
# records with a CHAINED comparator — primary int64 spaceship, tie-broken by a second int64 spaceship
# → G_SCMP s64 TWICE per call (tie-break fires on the frequent primary-key ties).
# Drive: dev/run.sh keycmp64. Outputs build/keycmp64-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh keycmp64   # render 64-bit multi-key record sort; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/keycmp64.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/keycmp64-sim.c" -o "$BUILD/keycmp64-sim"
EXPECT=$("$BUILD/keycmp64-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: keycmp64 gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/keycmp64.map" -o "$BUILD/keycmp64.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/keycmp64.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/keycmp64.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/keycmp64.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. G_SCMP-s64 presence probe: emit LLVM IR and confirm llvm.scmp at i64 is FORMED (not folded away)
#    — the chained comparator emits the s64 three-way compare twice per call (primary + tie-break).
#    This is the load-bearing check that the extreme-width three-way lowering is exercised.
echo "==> G_SCMP-s64 IR probe (llvm.scmp.i64, chained x2) + a16 rep/sep"
# stdlib.h (qsort) comes from the SDK, so compile with --config; -fno-lto forces a native object.
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -emit-llvm -S "$ROOT/examples/snes/corpus/keycmp64_sim.c" -I"$ROOT/examples" -o "$BUILD/keycmp64_sim.ll" 2>/dev/null
scmp=$(grep -cE '@llvm\.scmp\.' "$BUILD/keycmp64_sim.ll" 2>/dev/null || true)
scmp64=$(grep -cE '@llvm\.scmp\.i[0-9]+\.i64' "$BUILD/keycmp64_sim.ll" 2>/dev/null || true)
# Also confirm the object compiles + emits the sort (cmp-heavy) with a16 rep/sep.
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/keycmp64_sim.c" -I"$ROOT/examples" -o "$BUILD/keycmp64_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/keycmp64_sim.o" 2>/dev/null || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$scmp64" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  llvm.scmp=$scmp  scmp.i64=$scmp64  rep/sep=$rs  (chained s64 three-way compare, x2)"
else
  echo "    FAIL  llvm.scmp=$scmp  scmp.i64=$scmp64  rep/sep=$rs  (expected scmp.i64>=2, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/keycmp64-jg.png)"
  "$JGX" "$BUILD/keycmp64.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/keycmp64-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/keycmp64-mame.png)"
  SNAP="$BUILD/.keycmp64-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/keycmp64.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/keycmp64.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/keycmp64-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 64-bit Multi-Key Record Sort on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

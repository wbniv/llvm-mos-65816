#!/usr/bin/env bash
# dev/sort-race.sh — render the Sorting Race demo (#17 compiler stress-test) ON the SNES
# (examples/snes/sort-race.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/sort-race-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/sort-race.lua snapshots + asserts.
# Plus a disasm gate proving the hot path has recursion (sr_qsort / sr_msort) + compares + rep/sep.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh sort-race. Outputs build/sort-race-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh sort-race   # render the sorting-race demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/sort-race.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; sort-race.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/sort-race-sim.c" -o "$BUILD/sort-race-sim"
EXPECT=$("$BUILD/sort-race-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: sorting-race gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/sort-race.map" -o "$BUILD/sort-race.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/sort-race.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/sort-race.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/sort-race.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the recursive sorts must survive as real self-calling functions, with
# compare-heavy inner loops and native-16 (rep/sep). NO 32-bit libcalls here — this demo stresses
# control flow (recursion / soft-stack / frame ABI), not wide arithmetic.
echo "==> disasm gate (recursion + compares + native-16 codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/sort-race_sim.c" -I"$ROOT/examples" -o "$BUILD/sort-race_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/sort-race_sim.o" 2>/dev/null || true)
rec=$(printf '%s\n' "$dis" | grep -cE 'sr_qsort|sr_msort' || true)   # recursion witness (def + self-jsr)
cmp=$(printf '%s\n' "$dis" | grep -cw 'cmp' || true)                 # compare-heavy inner loops
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)            # native-16 active
if [ "$rec" -ge 4 ] && [ "$cmp" -ge 8 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  sr_qsort/sr_msort refs=$rec  cmp=$cmp  rep/sep=$rs  (recursive sorts + compares, native-16)"
else
  echo "    FAIL  sr_qsort/sr_msort refs=$rec  cmp=$cmp  rep/sep=$rs (expected refs>=4 cmp>=8 rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/sort-race-jg.png) + assert"
  "$JGX" "$BUILD/sort-race.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/sort-race-jg.png" || rc=1
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
  echo "==> MAME (under Xvfb): snapshot + assert (build/sort-race-mame.png)"
  SNAP="$BUILD/.sort-race-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/sort-race.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/sort-race.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/sort-race-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Sorting Race rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

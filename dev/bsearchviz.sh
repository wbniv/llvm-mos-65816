#!/usr/bin/env bash
# dev/bsearchviz.sh — render the Bisection Oracle (#147 stress-test, Round 8 Cluster B).
# The `bsearch` callback-ABI guard: a strictly increasing key table probed with a fixed query
# set of hits AND deliberate misses, where each call returns a void* INTO the array (or NULL)
# that the caller must difference back into an index — a wrong conversion yields a plausible
# in-range index, not a crash. `bsearch` is used ZERO times across demos #1-#141; qsort (15x)
# is the only comparator-callback libc the battery links, and its comparator drives a swap
# rather than an interval bisection.
# Drive: dev/run.sh bsearchviz. Outputs build/bsearchviz-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh bsearchviz   # run the bsearch bisection probe; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/bsearchviz.c"
SIM="$ROOT/examples/snes/corpus/bsearchviz_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/bsearchviz-sim.c" -o "$BUILD/bsearchviz-sim"
ORACLE=$("$BUILD/bsearchviz-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: bsearchviz gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/bsearchviz.map" -o "$BUILD/bsearchviz.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/bsearchviz.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/bsearchviz.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/bsearchviz.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. `bsearch` must actually be called, and the
#    comparator must be reached THROUGH ITS ADDRESS (a 16-bit function pointer materialized
#    into registers), not inlined — the indirect-callback ABI is the thing being exercised.
echo "==> structure gate (bsearch called + comparator taken by address; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
    -mllvm -verify-machineinstrs -S -o "$BUILD/bsearchviz_sim_$MODE.s" "$SIM" \
    -I"$ROOT/examples" 2>/dev/null
  call=$(grep -cE 'js[rl][[:space:]]+bsearch' "$BUILD/bsearchviz_sim_$MODE.s" || true)
  fptr=$(grep -cE 'mos16(lo|hi)\(bs_cmp\)' "$BUILD/bsearchviz_sim_$MODE.s" || true)
  qsrt=$(grep -cE 'js[rl][[:space:]]+qsort' "$BUILD/bsearchviz_sim_$MODE.s" || true)
  if [ "$call" -ge 1 ] && [ "$fptr" -ge 2 ] && [ "$qsrt" -eq 0 ]; then
    echo "    PASS  $MODE: jsr bsearch=$call  comparator-address refs=$fptr  qsort=$qsrt  (-verify clean)"
  else
    echo "    FAIL  $MODE: jsr bsearch=$call  comparator-address refs=$fptr  qsort=$qsrt  (want call>=1, fptr>=2, qsort=0)"; rc=1
  fi
done

# 3b. Both arms of the RESULT must be taken, and every recovered index must really name its
#     key. The second check is the one that matters: a wrong pointer->index conversion returns
#     a plausible in-range index rather than crashing, so nothing else would notice it.
HITS=$(printf '%s\n' "$ORACLE" | grep -oE 'hits=[0-9]+' | cut -d= -f2)
MISS=$(printf '%s\n' "$ORACLE" | grep -oE 'misses=[0-9]+' | cut -d= -f2)
BAD=$(printf '%s\n' "$ORACLE" | grep -oE 'bad_index=[0-9]+' | cut -d= -f2)
CALLS=$(printf '%s\n' "$ORACLE" | grep -oE 'cmp_calls=[0-9]+' | cut -d= -f2)
if [ "${HITS:-0}" -ge 1 ] && [ "${MISS:-0}" -ge 1 ] && [ "${BAD:-1}" -eq 0 ] && [ "${CALLS:-0}" -ge 1 ]; then
  echo "    PASS  both bsearch arms live and every index re-derives: hits=$HITS misses=$MISS bad_index=$BAD comparator_calls=$CALLS"
else
  echo "    FAIL  hits=${HITS:-?} misses=${MISS:-?} bad_index=${BAD:-?} comparator_calls=${CALLS:-?} (want hits>=1, misses>=1, bad_index=0)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/bsearchviz-jg.png, frame 600)"
  "$JGX" "$BUILD/bsearchviz.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/bsearchviz-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/bsearchviz-mame.png)"
  SNAP="$BUILD/.bsearchviz-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/bsearchviz.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/bsearchviz.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/bsearchviz-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Bisection Oracle on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

#!/usr/bin/env bash
# dev/dblbridge.sh — render the Precision Bridge (#146 stress-test, Round 8 Cluster B).
# The G_FPEXT S32->S64 / G_FPTRUNC S64->S32 guard (MOSLegalizerInfo.cpp:375 / :376, both
# .libcallFor -> __extendsfdf2 / __truncdfsf2): the same chaotic map iterated two ways over
# identical binary32 state — once wholly at float, once PROMOTED to double for the step and
# DEMOTED back each iteration — so the lanes differ only in where the rounding happens. ZERO
# corpus slices across demos #1-#141 link either conversion symbol.
# Drive: dev/run.sh dblbridge. Outputs build/dblbridge-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh dblbridge   # run the float<->double precision bridge; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
# The far platform: see the ROM-SIZE CONSTRAINT block in examples/snes/dblbridge.c.
# The double soft-float library + the float twin overflow the plain 32 KB LoROM near
# window by 5,299 bytes; mos-snes-far.cfg adds bank $01 for .far_rodata. Same contract
# #57 mandel-double already uses. The 5-way differential is unaffected — it runs on the
# HAL-free corpus slice, which needs no far pointers.
CFG="$BUILD/install/bin/mos-snes-far.cfg"
SRC="$ROOT/examples/snes/dblbridge.c"
SIM="$ROOT/examples/snes/corpus/dblbridge_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle. -ffp-contract=off is REQUIRED, not cosmetic: GCC at -O2 defaults to
#    -ffp-contract=fast and fuses a*b + c across statements, and MOS has no FMA — a contracted
#    host would silently disagree with the target. (The header also splits every operation
#    into its own statement, so there is nothing to contract; this is the second belt.)
cc -O2 -ffp-contract=off -I "$ROOT/examples/65816" "$ROOT/tools/dblbridge-sim.c" -o "$BUILD/dblbridge-sim"
ORACLE=$("$BUILD/dblbridge-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: dblbridge gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/dblbridge.map" -o "$BUILD/dblbridge.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/dblbridge.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/dblbridge.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/dblbridge.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. Both conversion libcalls must actually be
#    referenced in every mode. If the optimizer ever proved the double lane equivalent to the
#    float one and collapsed it, the demo would compile clean and cover nothing.
echo "==> structure gate (__extendsfdf2 + __truncdfsf2 referenced; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
    -mllvm -verify-machineinstrs -S -o "$BUILD/dblbridge_sim_$MODE.s" "$SIM" \
    -I"$ROOT/examples" 2>/dev/null
  ext=$(grep -c '__extendsfdf2' "$BUILD/dblbridge_sim_$MODE.s" || true)
  trc=$(grep -c '__truncdfsf2'  "$BUILD/dblbridge_sim_$MODE.s" || true)
  dbl=$(grep -cE '__(add|sub|mul)df3' "$BUILD/dblbridge_sim_$MODE.s" || true)
  if [ "$ext" -ge 1 ] && [ "$trc" -ge 1 ] && [ "$dbl" -ge 1 ]; then
    echo "    PASS  $MODE: __extendsfdf2=$ext  __truncdfsf2=$trc  double-arith=$dbl  (-verify clean)"
  else
    echo "    FAIL  $MODE: __extendsfdf2=$ext  __truncdfsf2=$trc  double-arith=$dbl  (want all >=1)"; rc=1
  fi
done

# 3b. The demo must be a PRECISION INSTRUMENT, not just a pair of libcalls. The two lanes must
#     start identical (divergence step > 0 — otherwise the seed, not the map, is being
#     measured) and must actually separate (divergence step < DB_STEPS — otherwise the two
#     lanes are the same computation and the conversions prove nothing).
DMIN=$(printf '%s\n' "$ORACLE" | grep -oE 'div_min=[0-9]+' | cut -d= -f2)
DMAX=$(printf '%s\n' "$ORACLE" | grep -oE 'div_max=[0-9]+' | cut -d= -f2)
STEPS=$(printf '%s\n' "$ORACLE" | grep -oE 'steps=[0-9]+' | cut -d= -f2)
if [ "${DMIN:-0}" -ge 1 ] && [ "${DMAX:-0}" -lt "${STEPS:-0}" ]; then
  echo "    PASS  precision instrument live: lanes agree then separate (div_min=$DMIN, div_max=$DMAX, steps=$STEPS)"
else
  echo "    FAIL  lanes never agreed or never separated: div_min=${DMIN:-?} div_max=${DMAX:-?} steps=${STEPS:-?}"; rc=1
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
# FRAME BUDGET — measured, not guessed. The gate runs 384 double-precision steps, and each
# one is __extendsfdf2 + __subdf3 + __muldf3 + __muldf3 + __truncdfsf2 in soft float on a
# 3.58 MHz 65816, on top of the float twin. At the battery's usual 600 frames both emulators
# read corpus_result = 0x0000 — the store simply had not happened yet. This is the same budget
# #57 mandel-double already needs for the same reason (dev/mandel-double.sh: SHOT_AT 2200,
# -seconds_to_run 45). NOT a correctness knob: the headless 5-way gate on the same code passes
# in dev/run.sh corpus and corpus-a16, which settle for 1000 frames.
FRAMES="${JG_FRAMES:-2200}"
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/dblbridge-jg.png, frame $FRAMES)"
  "$JGX" "$BUILD/dblbridge.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" "$FRAMES" \
    "$BUILD/dblbridge-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/dblbridge-mame.png)"
  SNAP="$BUILD/.dblbridge-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  # -seconds_to_run must OUTLAST the lua's SHOT_AT ($FRAMES periodic ticks); same reason and
  # the same numbers as dev/mandel-double.sh.
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$BUILD/dblbridge.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/dblbridge.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 45 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/dblbridge-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Precision Bridge on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

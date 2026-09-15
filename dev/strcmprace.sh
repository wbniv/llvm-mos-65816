#!/usr/bin/env bash
# dev/strcmprace.sh — render the Lexicographic Race (#148 stress-test, Round 8 Cluster B).
# The memcmp/strcmp/strncmp guard: fixed-width string lanes merged under a real lexicographic
# order (strcmp), then every adjacent pair re-compared by a SHORT-bounded strncmp and a
# full-width memcmp that runs past each terminator into deterministic filler, so the three
# functions genuinely disagree. All three symbols are used ZERO times tree-wide across #1-#141.
# Measured negative, recorded rather than hidden: MOS never inline-expands memcmp at any
# constant size (including the `== 0` form other targets specialise), so this covers three
# never-linked libcalls, not a second lowering.
# Drive: dev/run.sh strcmprace. Outputs build/strcmprace-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh strcmprace   # run the three-way lexicographic race; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/strcmprace.c"
SIM="$ROOT/examples/snes/corpus/strcmprace_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/strcmprace-sim.c" -o "$BUILD/strcmprace-sim"
ORACLE=$("$BUILD/strcmprace-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: strcmprace gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/strcmprace.map" -o "$BUILD/strcmprace.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/strcmprace.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/strcmprace.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/strcmprace.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. All three comparison libcalls must actually be
#    referenced in every mode. (They are libcalls on this target at every size — MOS does not
#    override enableMemCmpExpansion — so this asserts what is really there rather than an
#    inline expansion that cannot exist.)
echo "==> structure gate (memcmp + strcmp + strncmp all referenced; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
    -mllvm -verify-machineinstrs -S -o "$BUILD/strcmprace_sim_$MODE.s" "$SIM" \
    -I"$ROOT/examples" 2>/dev/null
  mc=$(grep -cE 'js[rl][[:space:]]+memcmp'  "$BUILD/strcmprace_sim_$MODE.s" || true)
  sc=$(grep -cE 'js[rl][[:space:]]+strcmp'  "$BUILD/strcmprace_sim_$MODE.s" || true)
  sn=$(grep -cE 'js[rl][[:space:]]+strncmp' "$BUILD/strcmprace_sim_$MODE.s" || true)
  if [ "$mc" -ge 1 ] && [ "$sc" -ge 1 ] && [ "$sn" -ge 1 ]; then
    echo "    PASS  $MODE: memcmp=$mc  strcmp=$sc  strncmp=$sn  (-verify clean)"
  else
    echo "    FAIL  $MODE: memcmp=$mc  strcmp=$sc  strncmp=$sn  (want all >=1)"; rc=1
  fi
done

# 3b. The three-way contract must be fully exercised: each of the three functions must have
#     produced each of the three signs. A lane set that only ever compared one way would
#     compile identical code and leave two thirds of the contract untested.
UNC=$(printf '%s\n' "$ORACLE" | grep -oE 'uncovered_cells=[0-9]+' | cut -d= -f2)
NCMP=$(printf '%s\n' "$ORACLE" | grep -oE 'comparisons=[0-9]+' | cut -d= -f2)
if [ "${UNC:-9}" -eq 0 ] && [ "${NCMP:-0}" -ge 1 ]; then
  echo "    PASS  all 9 (function, sign) cells fire over $NCMP comparisons:"
  printf '%s\n' "$ORACLE" | grep -E '^  (strcmp|strncmp|memcmp)' | sed 's/^/      /'
else
  echo "    FAIL  uncovered (function, sign) cells=${UNC:-?} over ${NCMP:-?} comparisons (want 0)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/strcmprace-jg.png, frame 600)"
  "$JGX" "$BUILD/strcmprace.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/strcmprace-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/strcmprace-mame.png)"
  SNAP="$BUILD/.strcmprace-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/strcmprace.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/strcmprace.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/strcmprace-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Lexicographic Race on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

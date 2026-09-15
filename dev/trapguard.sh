#!/usr/bin/env bash
# dev/trapguard.sh — render the Unreachable Sentinel (#150 stress-test, Round 8 Cluster B).
# The G_TRAP guard (MOSLegalizerInfo.cpp:448, `.custom()`; legalizeTrap emits an RTLIB::ABORT
# libcall, so it lands as `jsr abort`): a dense (state, event) machine with 20 legal pairs as
# case labels and 4 impossible ones falling to `default: __builtin_trap()`. The generator
# consults a per-state legality mask so an impossible pair never occurs, but tg_step is
# noinline and parameterised so the compiler cannot prove the default dead.
# HONEST FRAMING: a trap terminates, so it can never be TAKEN in a gate run. This is a
# PRESENCE-AND-INERTNESS probe — weaker than #142-#145 — and the gate says so in its own
# output rather than implying a behavioural test it does not perform.
# Drive: dev/run.sh trapguard. Outputs build/trapguard-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh trapguard   # run the guarded-arm state machine; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/trapguard.c"
SIM="$ROOT/examples/snes/corpus/trapguard_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/trapguard-sim.c" -o "$BUILD/trapguard-sim"
ORACLE=$("$BUILD/trapguard-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: trapguard gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/trapguard.map" -o "$BUILD/trapguard.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/trapguard.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/trapguard.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/trapguard.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. G_TRAP must be FORMED pre-legalizer and must
#    survive legalization into the ROM as `jsr abort`. If the optimizer ever proved the
#    default arm dead, the trap would vanish and the demo would cover nothing.
echo "==> structure gate (G_TRAP formed + jsr abort in the ROM; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  MIR=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
        -c -o /dev/null -mllvm -print-before=legalizer "$SIM" -I"$ROOT/examples" 2>&1 || true)
  g=$(printf '%s\n' "$MIR" | grep -c 'G_TRAP' || true)
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
    -mllvm -verify-machineinstrs -S -o "$BUILD/trapguard_sim_$MODE.s" "$SIM" \
    -I"$ROOT/examples" 2>/dev/null
  ab=$(grep -cE 'js[rl][[:space:]]+abort' "$BUILD/trapguard_sim_$MODE.s" || true)
  if [ "$g" -ge 1 ] && [ "$ab" -ge 1 ]; then
    echo "    PASS  $MODE: G_TRAP=$g (pre-legalizer)  jsr abort=$ab (emitted)  (-verify clean)"
  else
    echo "    FAIL  $MODE: G_TRAP=$g  jsr abort=$ab  (want both >=1)"; rc=1
  fi
done

# 3b. Inertness: the dispatch AROUND the trap must be fully exercised, every legal pair at
#     least once, and no impossible pair ever — the latter because if one had fired the run
#     would have aborted rather than produced a hash.
UNV=$(printf '%s\n' "$ORACLE" | grep -oE 'legal_unvisited=[0-9]+' | cut -d= -f2)
ILL=$(printf '%s\n' "$ORACLE" | grep -oE 'illegal_taken=[0-9]+' | cut -d= -f2)
GRD=$(printf '%s\n' "$ORACLE" | grep -oE 'guarded=[0-9]+' | cut -d= -f2)
if [ "${UNV:-1}" -eq 0 ] && [ "${ILL:-1}" -eq 0 ] && [ "${GRD:-0}" -ge 1 ]; then
  echo "    PASS  every legal (state, event) pair fired, no impossible pair did: unvisited=$UNV illegal=$ILL guarded_rerolls=$GRD"
else
  echo "    FAIL  legal_unvisited=${UNV:-?} illegal_taken=${ILL:-?} guarded_rerolls=${GRD:-?} (want 0 / 0 / >=1)"; rc=1
fi
echo "    NOTE  presence-and-inertness probe: the trap is NEVER taken in a gate run (it"
echo "          terminates), so this asserts it is PRESENT and that its presence leaves the"
echo "          surrounding dispatch bit-identical — weaker than #142-#145, stated as such."

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
  echo "==> bsnes-jg: render + assert (build/trapguard-jg.png, frame 600)"
  "$JGX" "$BUILD/trapguard.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/trapguard-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/trapguard-mame.png)"
  SNAP="$BUILD/.trapguard-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/trapguard.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/trapguard.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/trapguard-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Unreachable Sentinel on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

#!/usr/bin/env bash
# dev/retryjmp.sh — render the Retry-On-Fault Ladder (#118 stress-test, Round 6 Cluster G).
# The RE-ENTRY guard for the 65816-native platforms/snes/setjmp.S fix (bug #35): ONE setjmp site
# is re-armed and re-entered 24 times, each attempt jumping back from a different call depth over
# a different soft-stack high-water mark (rj_work is noinline + recursive with six 16-bit locals
# live across the recursive call). State that leaks across re-entries drifts the whole outcome
# sequence rather than corrupting one value.
#
# This slice is ALSO the standing guard for the +mos-xy16 A16-preservation invariant
# (docs/investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md): an X16/Y16
# soft-stack spill must stage through the accumulator without destroying a live 16-bit value,
# which MOSRegisterInfo::expandLDSTStk enforces with a PHA16/PLA16 bracket. Step 3 below pins it
# by running -verify-machineinstrs under +mos-xy16 at every level where this slice spills X16.
# Drive: dev/run.sh retryjmp. Outputs build/retryjmp-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh retryjmp   # render the retry ladder; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/retryjmp.c"
SIM="$ROOT/examples/snes/corpus/retryjmp_sim.c"
VENDOR="$ROOT/vendor/bsnes-jg"

source "$ROOT/dev/_emu.sh"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/retryjmp-sim.c" -o "$BUILD/retryjmp-sim"
EXPECT=$("$BUILD/retryjmp-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: retryjmp gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/retryjmp.map" -o "$BUILD/retryjmp.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/retryjmp.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/retryjmp.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/retryjmp.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. REGRESSION GATE on the A16-preservation invariant: -verify-machineinstrs must be clean
#    under +mos-xy16 at every level where this slice spills X16 across a live accumulator.
#    -O0 does not spill; -O1/-Os/-Oz/-O2 all do, so all four must verify clean.
echo "==> xy16 verifier gate (the A16-clobber regression guard)"
for O in -O1 -Os -Oz -O2; do
  if "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 \
        -Xclang -target-feature -Xclang +mos-xy16 "$O" -mllvm -verify-machineinstrs \
        -I "$ROOT/examples" -c "$SIM" -o "$BUILD/retryjmp_sim.vo" 2>"$BUILD/retryjmp-verify$O.log"; then
    echo "    PASS  +mos-xy16 $O -verify-machineinstrs clean"
  else
    echo "    FAIL  +mos-xy16 $O -verify-machineinstrs:"
    grep -m4 -E 'Bad machine code|^- (instruction|operand)' "$BUILD/retryjmp-verify$O.log" || true
    rc=1
  fi
done

# 4. Structure gate: the retry really does re-enter one setjmp site out of real recursive jsr
#    frames, and the 16-bit locals really do live in the soft stack / imaginary registers.
echo "==> structure gate (setjmp + longjmp present, rj_work a real recursive jsr frame)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$SIM" -I"$ROOT/examples" -o "$BUILD/retryjmp_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/retryjmp_sim.o" 2>/dev/null || true)
sj=$(printf '%s\n' "$dis" | grep -cE '\bsetjmp\b' || true)
lj=$(printf '%s\n' "$dis" | grep -cE '\blongjmp\b' || true)
wk=$(printf '%s\n' "$dis" | grep -cE 'jsr.*rj_work|rj_work' || true)
rs=$(printf '%s\n' "$dis" | grep -cE 'rep[[:space:]]+#(32|\$20)' || true)
if [ "$sj" -ge 1 ] && [ "$lj" -ge 1 ] && [ "$wk" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  setjmp=$sj  longjmp=$lj  rj_work refs=$wk  rep#\$20=$rs"
else
  echo "    FAIL  setjmp=$sj  longjmp=$lj  rj_work refs=$wk  rep#\$20=$rs  (expected setjmp>=1, longjmp>=1, rj_work>=2, rep>=1)"; rc=1
fi

# 5. bsnes-jg.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + assert (build/retryjmp-jg.png, frame 600)"
  "$JGX" "$BUILD/retryjmp.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/retryjmp-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 6. MAME.
if [ "${JG_ONLY:-}" = "1" ]; then
  echo "    SKIP MAME (JG_ONLY)"
elif [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/retryjmp-mame.png)"
  SNAP="$BUILD/.retryjmp-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/retryjmp.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/retryjmp.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/retryjmp-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
emu_verdict "$rc" "Retry-On-Fault Ladder on SNES; corpus hash $EXPECT host == +mos-a16, both emulators agree; +mos-xy16 -verify clean at -O1/-Os/-Oz/-O2"
exit $rc

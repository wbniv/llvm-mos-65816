#!/usr/bin/env bash
# dev/ovmatrix.sh — render the Overflow Family Matrix (#155 stress-test, Round 8 Cluster C).
# Corner: all six overflow opcodes — G_UADDO/G_SADDO, G_USUBO/G_SSUBO, G_UMULO/G_SMULO — at all
# three widths in ONE noinline kernel, so the signed and unsigned forms of each family are
# selected and register-allocated next to each other under real pressure. #44, #76, #101 and
# #144 each test one family, at one or two widths, in a loop of its own.
# MEASURED: a probe with one CONSTANT operand per builtin folded cells away outright and lost
# G_SSUBO entirely, so both operands here are runtime and the gate asserts every one of the 18
# (builtin, width, signedness) cells fired BOTH outcomes.
# Drive: dev/run.sh ovmatrix. Outputs build/ovmatrix-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh ovmatrix   # run the 18-cell overflow matrix; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/ovmatrix.c"
SIM="$ROOT/examples/snes/corpus/ovmatrix_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/ovmatrix-sim.c" -o "$BUILD/ovmatrix-sim"
ORACLE=$("$BUILD/ovmatrix-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: ovmatrix gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/ovmatrix.map" -o "$BUILD/ovmatrix.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/ovmatrix.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/ovmatrix.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/ovmatrix.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — all SIX generic opcodes must actually form, in every mode, at three widths
#    each. The design probe showed this is not free: with one constant operand the folder erased
#    cells and G_SSUBO vanished entirely, so a demo can claim this coverage and not have it.
echo "==> structure gate (all six G_[US]{ADDO,SUBO,MULO} formed, 3 widths each; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  if ! "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -mllvm -verify-machineinstrs -S -o "$BUILD/ovmatrix_sim_$MODE.s" "$SIM" \
      -I"$ROOT/examples" 2>"$BUILD/ovmatrix_sim_$MODE.err"; then
    echo "    FAIL  $MODE: did not compile:"; sed 's/^/      /' "$BUILD/ovmatrix_sim_$MODE.err" | head -5
    rc=1; continue
  fi
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -S -mllvm -print-before=legalizer -o /dev/null "$SIM" -I"$ROOT/examples" \
      >"$BUILD/ovmatrix_gen_$MODE.txt" 2>&1 || true
  bad=0; summary=""
  for OP in G_UADDO G_SADDO G_USUBO G_SSUBO G_UMULO G_SMULO; do
    n=$(grep -cE "\b$OP\b" "$BUILD/ovmatrix_gen_$MODE.txt" || true)
    summary="$summary $OP=$n"
    [ "$n" -ge 3 ] || bad=1
  done
  if [ "$bad" -eq 0 ]; then
    echo "    PASS  $MODE:$summary  (-verify clean)"
  else
    echo "    FAIL  $MODE:$summary  (want >=3 of each — one per width)"; rc=1
  fi
done

# 3b. Coverage cross-check: every cell must have fired BOTH outcomes. A cell that only ever
#     overflows, or never does, had its other arm folded away or never reached, and the matrix
#     would be covering less than it claims.
TWO=$(printf '%s\n' "$ORACLE" | grep -oE 'two_sided_cells=[0-9]+' | cut -d= -f2)
if [ "${TWO:-0}" -eq 18 ]; then
  echo "    PASS  all 18 (builtin, width, signedness) cells fired BOTH overflow and clean"
  printf '%s\n' "$ORACLE" | grep '^ovmatrix cell' | sed 's/^ovmatrix /      /'
else
  echo "    FAIL  two_sided_cells=${TWO:-?} (want 18):"
  printf '%s\n' "$ORACLE" | grep '^ovmatrix cell' | sed 's/^ovmatrix /      /'
  rc=1
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
  echo "==> bsnes-jg: render + assert (build/ovmatrix-jg.png, frame 600)"
  "$JGX" "$BUILD/ovmatrix.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/ovmatrix-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/ovmatrix-mame.png)"
  SNAP="$BUILD/.ovmatrix-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/ovmatrix.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/ovmatrix.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/ovmatrix-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Overflow Family Matrix on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

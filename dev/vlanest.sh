#!/usr/bin/env bash
# dev/vlanest.sh — render the Nested VLA Pyramid (#151 stress-test, Round 8 Cluster C).
# Corner: TWO nested G_STACKSAVE/G_STACKRESTORE brackets around two G_DYN_STACKALLOCs with
# independent runtime lengths — the depth axis #143 vlastack does not touch. Measured: the
# nesting only survives when both VLA scopes are re-entered per loop iteration; the obvious
# shapes collapse to a single bracket because the outer restore coincides with the return.
# Drive: dev/run.sh vlanest. Outputs build/vlanest-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh vlanest   # run the nested-VLA reduction; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/vlanest.c"
SIM="$ROOT/examples/snes/corpus/vlanest_sim.c"
SDKINC="$BUILD/install/mos-platform/common/include"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/vlanest-sim.c" -o "$BUILD/vlanest-sim"
ORACLE=$("$BUILD/vlanest-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: vlanest gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/vlanest.map" -o "$BUILD/vlanest.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/vlanest.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/vlanest.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/vlanest.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — the NESTING must actually be there. Two dynamic allocations is not enough:
#    #143's shape already has one, and the naive nestings measured during design produce TWO
#    G_DYN_STACKALLOC but only ONE save/restore pair, which is a single bracket and covers
#    nothing new. The assertion is 2 / 2 / 2, in all three modes, -verify clean.
echo "==> structure gate (2 nested G_STACKSAVE/RESTORE brackets over 2 G_DYN_STACKALLOC; all modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  if ! "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -mllvm -verify-machineinstrs -S -o "$BUILD/vlanest_sim_$MODE.s" "$SIM" \
      -I"$ROOT/examples" 2>"$BUILD/vlanest_sim_$MODE.err"; then
    echo "    FAIL  $MODE: did not compile:"; sed 's/^/      /' "$BUILD/vlanest_sim_$MODE.err" | head -5
    rc=1; continue
  fi
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -isystem "$SDKINC" -Os \
      -S -mllvm -print-before=legalizer -o /dev/null "$SIM" -I"$ROOT/examples" \
      >"$BUILD/vlanest_gen_$MODE.txt" 2>&1 || true
  dyn=$(grep -cE 'G_DYN_STACKALLOC' "$BUILD/vlanest_gen_$MODE.txt" || true)
  sav=$(grep -cE 'G_STACKSAVE' "$BUILD/vlanest_gen_$MODE.txt" || true)
  res=$(grep -cE 'G_STACKRESTORE' "$BUILD/vlanest_gen_$MODE.txt" || true)
  if [ "$dyn" -eq 2 ] && [ "$sav" -eq 2 ] && [ "$res" -eq 2 ]; then
    echo "    PASS  $MODE: G_DYN_STACKALLOC=$dyn  G_STACKSAVE=$sav  G_STACKRESTORE=$res  (-verify clean)"
  else
    echo "    FAIL  $MODE: G_DYN_STACKALLOC=$dyn  G_STACKSAVE=$sav  G_STACKRESTORE=$res  (want 2/2/2 — the nesting collapsed)"
    rc=1
  fi
done

# 3b. Runtime cross-checks: the nest must have used several DIFFERENT lengths at both levels (a
#     constant length would be a fixed alloca in disguise) and every outer re-read must have
#     matched — a non-zero bad count is an overshooting unwind, which is the defect under guard.
NOUT=$(printf '%s\n' "$ORACLE" | grep -oE 'distinct_outer_len=[0-9]+' | cut -d= -f2)
NIN=$(printf '%s\n' "$ORACLE" | grep -oE 'distinct_inner_len=[0-9]+' | cut -d= -f2)
BAD=$(printf '%s\n' "$ORACLE" | grep -oE 'reread_bad=[0-9]+' | cut -d= -f2)
NBR=$(printf '%s\n' "$ORACLE" | grep -oE 'inner_brackets=[0-9]+' | cut -d= -f2)
if [ "${NOUT:-0}" -ge 3 ] && [ "${NIN:-0}" -ge 3 ] && [ "${BAD:-1}" -eq 0 ] && [ "${NBR:-0}" -ge 100 ]; then
  echo "    PASS  distinct outer lengths=$NOUT  distinct inner lengths=$NIN  inner brackets=$NBR  outer re-read failures=$BAD"
else
  echo "    FAIL  outer_len=${NOUT:-?} inner_len=${NIN:-?} brackets=${NBR:-?} reread_bad=${BAD:-?} (want >=3 / >=3 / >=100 / 0)"
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
  echo "==> bsnes-jg: render + assert (build/vlanest-jg.png, frame 600)"
  "$JGX" "$BUILD/vlanest.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/vlanest-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/vlanest-mame.png)"
  SNAP="$BUILD/.vlanest-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/vlanest.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/vlanest.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/vlanest-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Nested VLA Pyramid on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

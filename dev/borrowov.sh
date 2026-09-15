#!/usr/bin/env bash
# dev/borrowov.sh — render the Reservoir Ladder (#144 stress-test, Round 8 Cluster A).
# The G_USUBO/G_SSUBO guard (MOSLegalizerInfo.cpp:296; custom cases :2031/:2034): every
# transfer in a reservoir cascade is a checked subtract via __builtin_sub_overflow at uint16
# (borrow out), int16 (native-width signed) and int32 (double-width signed), with a detected
# underflow rejecting the transfer. `__builtin_sub_overflow` appears ZERO times across demos
# #1-#141 — only the add (#44) and mul (#76/#101) forms.
# Drive: dev/run.sh borrowov. Outputs build/borrowov-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh borrowov   # run the checked-subtract cascade; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/borrowov.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/borrowov-sim.c" -o "$BUILD/borrowov-sim"
ORACLE=$("$BUILD/borrowov-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: borrowov gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/borrowov.map" -o "$BUILD/borrowov.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/borrowov.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/borrowov.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/borrowov.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. Both G_USUBO and G_SSUBO must actually be formed
#    in every mode; if either ever folded to a plain compare the demo would silently stop
#    testing the path it exists for.
echo "==> structure gate (G_USUBO + G_SSUBO formed; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  MIR=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -c -o /dev/null \
        -mllvm -print-before=legalizer "$ROOT/examples/snes/corpus/borrowov_sim.c" \
        -I"$ROOT/examples" 2>&1 || true)
  u=$(printf '%s\n' "$MIR" | grep -c 'G_USUBO' || true)
  s=$(printf '%s\n' "$MIR" | grep -c 'G_SSUBO' || true)
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -mllvm -verify-machineinstrs \
    -S -o "$BUILD/borrowov_sim_$MODE.s" "$ROOT/examples/snes/corpus/borrowov_sim.c" \
    -I"$ROOT/examples" 2>/dev/null
  if [ "$u" -ge 1 ] && [ "$s" -ge 2 ]; then
    echo "    PASS  $MODE: G_USUBO=$u  G_SSUBO=$s  (-verify clean)"
  else
    echo "    FAIL  $MODE: G_USUBO=$u  G_SSUBO=$s  (want usubo>=1, ssubo>=2)"; rc=1
  fi
done

# 3b. Both arms of every predicate must be TAKEN at run time. A schedule that never overflows
#     compiles identical code and proves nothing, so assert each width actually rejected.
RU=$(printf '%s\n' "$ORACLE" | grep -oE 'u16 acc/rej=[0-9]+/[0-9]+' | awk -F/ '{print $NF}')
RS=$(printf '%s\n' "$ORACLE" | grep -oE 's16 acc/rej=[0-9]+/[0-9]+' | awk -F/ '{print $NF}')
RL=$(printf '%s\n' "$ORACLE" | grep -oE 's32 acc/rej=[0-9]+/[0-9]+' | awk -F/ '{print $NF}')
if [ "${RU:-0}" -ge 1 ] && [ "${RS:-0}" -ge 1 ] && [ "${RL:-0}" -ge 1 ]; then
  echo "    PASS  overflow predicate fires in every width: u16=$RU s16=$RS s32=$RL rejections"
else
  echo "    FAIL  a width never overflowed: u16=${RU:-?} s16=${RS:-?} s32=${RL:-?}"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/borrowov-jg.png, frame 600)"
  "$JGX" "$BUILD/borrowov.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/borrowov-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/borrowov-mame.png)"
  SNAP="$BUILD/.borrowov-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/borrowov.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/borrowov.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/borrowov-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Reservoir Ladder on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

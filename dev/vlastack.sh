#!/usr/bin/env bash
# dev/vlastack.sh — render the Run-Length Scanline Decoder (#143, Round 8 Cluster A).
# The G_DYN_STACKALLOC guard (MOSLegalizerInfo.cpp:456, `.custom()`): each row's scratch array
# is a VLA sized by the run count read out of the compressed stream and declared in the loop
# body, so the soft SP is adjusted and restored once per row with a different delta. Zero of
# demos #1-#141 form G_DYN_STACKALLOC — #68 polyfill's VLA const-folds to a fixed alloca.
# Drive: dev/run.sh vlastack. Outputs build/vlastack-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh vlastack   # decode through runtime-sized VLAs; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/vlastack.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/vlastack-sim.c" -o "$BUILD/vlastack-sim"
ORACLE=$("$BUILD/vlastack-sim")
EXPECT=$(printf '%s\n' "$ORACLE" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: vlastack gate hash = $EXPECT"
printf '    %s\n' "$(printf '%s\n' "$ORACLE" | head -1)"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/vlastack.map" -o "$BUILD/vlastack.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/vlastack.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/vlastack.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/vlastack.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate — THE CORNER UNDER TEST. A G_DYN_STACKALLOC must actually be formed in
#    every mode (if the VLA length ever const-folds, this becomes #68 polyfill's already-
#    covered fixed alloca and the demo would be silently testing nothing), and the soft stack
#    pointer must be written more than once (the runtime adjust plus the restore).
echo "==> structure gate (G_DYN_STACKALLOC formed + soft-SP adjusted; all three modes)"
for MODE in default a16 xy16; do
  case "$MODE" in
    default) FEAT=() ;;
    a16)     FEAT=(-Xclang -target-feature -Xclang +mos-a16) ;;
    xy16)    FEAT=(-Xclang -target-feature -Xclang +mos-xy16) ;;
  esac
  MIR=$("$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -c -o /dev/null \
        -mllvm -print-before=legalizer "$ROOT/examples/snes/corpus/vlastack_sim.c" \
        -I"$ROOT/examples" 2>&1 || true)
  dyn=$(printf '%s\n' "$MIR" | grep -c 'G_DYN_STACKALLOC' || true)
  sav=$(printf '%s\n' "$MIR" | grep -c 'G_STACKSAVE' || true)
  res=$(printf '%s\n' "$MIR" | grep -c 'G_STACKRESTORE' || true)
  ASM="$BUILD/vlastack_sim_$MODE.s"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${FEAT[@]}" -Os -mllvm -verify-machineinstrs \
    -S -o "$ASM" "$ROOT/examples/snes/corpus/vlastack_sim.c" -I"$ROOT/examples" 2>/dev/null
  sp=$(grep -cE '^[[:space:]]*st[axy][[:space:]]+__rc[01]$' "$ASM" || true)
  if [ "$dyn" -ge 1 ] && [ "$sav" -ge 1 ] && [ "$res" -ge 1 ] && [ "$sp" -ge 2 ]; then
    echo "    PASS  $MODE: G_DYN_STACKALLOC=$dyn  G_STACKSAVE=$sav  G_STACKRESTORE=$res  soft-SP writes=$sp"
  else
    echo "    FAIL  $MODE: G_DYN_STACKALLOC=$dyn  G_STACKSAVE=$sav  G_STACKRESTORE=$res  soft-SP writes=$sp"
    echo "          (want dyn>=1, save>=1, restore>=1, soft-SP writes>=2)"
    rc=1
  fi
done

# 3b. The allocation sizes must genuinely VARY across rows — a constant width would mean the
#     lengths folded and the dynamic path is not really being swept.
LO=$(printf '%s\n' "$ORACLE" | grep -oE 'runs_min=[0-9]+' | cut -d= -f2)
HI=$(printf '%s\n' "$ORACLE" | grep -oE 'runs_max=[0-9]+' | cut -d= -f2)
if [ "${LO:-0}" -ge 1 ] && [ "${HI:-0}" -gt "${LO:-0}" ]; then
  echo "    PASS  allocation sizes vary: runs_min=$LO runs_max=$HI"
else
  echo "    FAIL  allocation sizes do not vary: runs_min=${LO:-?} runs_max=${HI:-?}"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/vlastack-jg.png, frame 600)"
  "$JGX" "$BUILD/vlastack.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/vlastack-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/vlastack-mame.png)"
  SNAP="$BUILD/.vlastack-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/vlastack.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/vlastack.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/vlastack-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Run-Length Scanline Decoder on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

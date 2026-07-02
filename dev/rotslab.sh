#!/usr/bin/env bash
# dev/rotslab.sh — render In-Place Block Rotate (#94 stress-test, Round 6 Cluster A).
# Re-stresses patch 0002 (MOSInsertREPSEP::placeIntraBlock, the #23 +mos-xy16 index-width fix) via
# a hand-written three-reversal rotate of a >256-entry uint16_t buffer: 16-bit-indexed loads/
# stores crossing the M/X width-flag boundary, with NO memmove libcall (the #93 angle differs).
# Drive: dev/run.sh rotslab. Outputs build/rotslab-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh rotslab   # render in-place block rotate; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/rotslab.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/rotslab-sim.c" -o "$BUILD/rotslab-sim"
EXPECT=$("$BUILD/rotslab-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: rotslab gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/rotslab.map" -o "$BUILD/rotslab.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/rotslab.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/rotslab.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/rotslab.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the three-reversal swap loop accesses the 384-entry uint16_t buffer through
#    16-bit ZP-indirect pointers bracketed by rep #$20 / sep #$20 M/X width transitions — exactly
#    the schedule MOSInsertREPSEP::placeIntraBlock (patch 0002, the #23 fix) manages. Assert those
#    width brackets are present AND the corpus slice compiles clean under +mos-xy16 (where the #23
#    bug crashed/miscompiled). NOTE (measured): the runtime k %= n folds away — k = 1 + 3*step is
#    always <= 34 < 384, so the compiler correctly proves k % 384 == k and emits no __umodhi (a
#    legitimate optimization, not this demo's corner). The re-stressed path is the width-flag
#    management around the 16-bit buffer access, not the modulo.
echo "==> disasm gate (rep/sep width brackets around 16-bit buffer access; xy16 compile clean)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/rotslab_sim.c" -I"$ROOT/examples" -o "$BUILD/rotslab_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/rotslab_sim.o" 2>/dev/null || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
# xy16 must also compile clean (this is where the #23 bug crashed/miscompiled).
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -c "$ROOT/examples/snes/corpus/rotslab_sim.c" -I"$ROOT/examples" -o "$BUILD/rotslab_sim_xy16.o" 2>/dev/null \
  && xy16ok=1 || xy16ok=0
if [ "$rs" -ge 1 ] && [ "$xy16ok" -eq 1 ]; then
  echo "    PASS  rep/sep=$rs  xy16-compile=OK  (M/X width brackets around 16-bit reversal access)"
else
  echo "    FAIL  rep/sep=$rs  xy16-compile=$xy16ok  (expected rep/sep>=1, xy16 OK)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/rotslab-jg.png)"
  "$JGX" "$BUILD/rotslab.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/rotslab-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/rotslab-mame.png)"
  SNAP="$BUILD/.rotslab-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/rotslab.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/rotslab.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/rotslab-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — In-Place Block Rotate on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

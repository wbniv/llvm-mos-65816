#!/usr/bin/env bash
# dev/satcomet.sh — render Saturating Palette Comet Trails (#75 compiler stress-test).
# Codegen: G_UADDSAT/G_USUBSAT (uint8 glow) + G_SADDSAT/G_SSUBSAT (int16 velocity) all via
# lowerAddSubSatToMinMax at MOSLegalizerInfo.cpp:246.
# Drive: dev/run.sh satcomet. Outputs build/satcomet-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh satcomet   # render saturating comet trails; assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/satcomet.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/satcomet-sim.c" -o "$BUILD/satcomet-sim"
EXPECT=$("$BUILD/satcomet-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: satcomet gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/satcomet.map" -o "$BUILD/satcomet.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/satcomet.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/satcomet.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/satcomet.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: G_UADDSAT/USUBSAT/SADDSAT/SSUBSAT -> lowerAddSubSatToMinMax.
# The expansion uses compare+select (cmp+branch on 65816) and rep/sep.
echo "==> disasm gate (G_*ADDSAT/*SUBSAT branchless min/max clamp: cmp+rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/satcomet_sim.c" -I"$ROOT/examples" -o "$BUILD/satcomet_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/satcomet_sim.o" 2>/dev/null || true)
cmp=$(printf '%s\n' "$dis" | grep -cwE '\bcmp\b|\bcpx\b|\bcpy\b' || true)  # sat compare
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$cmp" -ge 4 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  cmp/cpx/cpy=$cmp  rep/sep=$rs  (sat clamp comparisons + a16 mode)"
else
  echo "    FAIL  cmp/cpx/cpy=$cmp  rep/sep=$rs  (expected cmp>=4, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/satcomet-jg.png)"
  "$JGX" "$BUILD/satcomet.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/satcomet-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/satcomet-mame.png)"
  SNAP="$BUILD/.satcomet-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/satcomet.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/satcomet.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/satcomet-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Saturating Comet Trails on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

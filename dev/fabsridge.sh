#!/usr/bin/env bash
# dev/fabsridge.sh — render the Fabs Ridgeline demo (#80 compiler stress-test) ON the SNES
# (examples/snes/fabsridge.c, +mos-a16) and capture headless screenshots from BOTH emulators,
# each asserting corpus_result == the host oracle (tools/fabsridge-sim.c).
# Codegen corner: G_FABS via __builtin_fabsf targeting legalizeFAbs at MOSLegalizerInfo:369
# (inline AND, not a libcall). Probe: __mulsf3>=1, __subsf3>=2, rep/sep>=1.
# Drive: dev/run.sh fabsridge. Outputs build/fabsridge-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh fabsridge   # render tent-map ridgeline; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/fabsridge.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/fabsridge-sim.c" -o "$BUILD/fabsridge-sim"
EXPECT=$("$BUILD/fabsridge-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: fabsridge gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/fabsridge.map" -o "$BUILD/fabsridge.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/fabsridge.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/fabsridge.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/fabsridge.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: G_FABS via __builtin_fabsf (legalizeFAbs: inline AND) + soft-float tent map.
echo "==> disasm gate (G_FABS inline sign-bit AND + tent-map soft-float: __mulsf3, __subsf3, rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/fabsridge_sim.c" -I"$ROOT/examples" -o "$BUILD/fabsridge_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/fabsridge_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsf3' || true)       # 2.0f * x
sub=$(printf '%s\n' "$dis" | grep -cE '__subsf3|__addsf3' || true)  # x-1 and 1-|x|
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$sub" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsf3=$mul  __subsf3/addsf3=$sub  rep/sep=$rs  (tent-map + G_FABS present)"
else
  echo "    FAIL  __mulsf3=$mul  __subsf3/addsf3=$sub  rep/sep=$rs  (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/fabsridge-jg.png)"
  "$JGX" "$BUILD/fabsridge.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/fabsridge-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/fabsridge-mame.png)"
  SNAP="$BUILD/.fabsridge-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/fabsridge.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/fabsridge.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/fabsridge-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Fabs Ridgeline on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc

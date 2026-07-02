#!/usr/bin/env bash
# dev/compass.sh — render Copysign Compass (#81 compiler stress-test) on SNES.
# Exercises G_FCOPYSIGN (__builtin_copysignf) and G_IS_FPCLASS (__builtin_signbitf);
# both inline sign-bit operations (no libcall). First demo to use copysignf.
# Full 5-way differential (host==default==+mos-a16==+mos-xy16).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh compass   # render copysign compass; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/compass.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/compass-sim.c" -lm -o "$BUILD/compass-sim"
EXPECT=$("$BUILD/compass-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: compass gate hash = $EXPECT"

# 2. Build ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/compass.map" -o "$BUILD/compass.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/compass.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/compass.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/compass.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: G_FCOPYSIGN (inline AND/OR) and G_IS_FPCLASS (inline sign test).
# Copysignf: inline bit-manipulation, visible as AND+OR sequences in disasm.
# No fabs/copysign libcall — the entire expansion is inline.
echo "==> disasm gate (G_FCOPYSIGN inline AND/OR + G_IS_FPCLASS + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/compass_sim.c" -I"$ROOT/examples" -o "$BUILD/compass_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/compass_sim.o" 2>/dev/null || true)
# G_FCOPYSIGN expands to AND mask ops; __floatsisf for int→float.
fsi=$(printf '%s\n' "$dis" | grep -c '__floatsisf' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
echo "    __floatsisf=$fsi  rep/sep=$rs"
if [ "$fsi" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  copysign path confirmed (__floatsisf=$fsi >= 2, rep/sep=$rs >= 1)"
else
  echo "    FAIL  __floatsisf=$fsi (expected >=2) rep/sep=$rs (expected >=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/compass-jg.png)"
  "$JGX" "$BUILD/compass.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/compass-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/compass-mame.png)"
  SNAP="$BUILD/.compass-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/compass.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/compass.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/compass-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Copysign Compass on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

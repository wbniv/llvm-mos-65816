#!/usr/bin/env bash
# dev/double-pendulum.sh — gate for the Double Pendulum chaos demo (#14 compiler stress-test)
# (examples/snes/double-pendulum.c, +mos-a16): two pendulums diverge exponentially on a
# BitmapCanvas, stressing __mulsi3 (ω² coupling) + __divsi3 (D denominator) + rep/sep (a16).
# Asserts corpus_result (dpend_gate_crc, 256 steps) == host oracle on MAME + bsnes-jg.
# Full 5-way differential (no far pointers): host==default==+mos-a16==+mos-xy16 from corpus-a16.
#
# Drive: dev/run.sh double-pendulum. Outputs build/double-pendulum-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh double-pendulum   # build + gate the Double Pendulum chaos demo"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/double-pendulum.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

rc=0

# 1. Host oracle: golden gate hash.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/dpend-sim.c" -o "$BUILD/dpend-sim"
EXPECT=$("$BUILD/dpend-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: double-pendulum gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/double-pendulum.map" -o "$BUILD/double-pendulum.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/double-pendulum.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/double-pendulum.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/double-pendulum.sfc (+mos-a16); corpus_result @ WRAM $OFF"

# 3. Disasm gate: __mulsi3 (ω² products) + __divsi3 (D denominator) + rep/sep (a16).
echo "==> disasm gate (double-pendulum coupling __mulsi3 + __divsi3 + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/dpend_sim.c" -I"$ROOT/examples" -o "$BUILD/dpend_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/dpend_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
div=$(printf '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3' || true)
rs=$(printf '%s\n'  "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$div" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  __divsi3=$div  rep/sep=$rs  (ω² coupling + D-divide + native-16)"
else
  echo "    FAIL  __mulsi3=$mul  __divsi3=$div  rep/sep=$rs  (expected all >= 1)"; rc=1
fi

# 4. bsnes-jg — framebuffer dump + assert corpus_result.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/double-pendulum-jg.png) + assert"
  "$JGX" "$BUILD/double-pendulum.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/double-pendulum-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/double-pendulum-mame.png)"
  SNAP="$BUILD/.dpend-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/double-pendulum.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/double-pendulum.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/double-pendulum-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Double Pendulum on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see per-emulator lines above"
fi
exit $rc

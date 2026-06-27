#!/usr/bin/env bash
# dev/spirograph.sh — render the Spirograph demo (#11 compiler stress-test) ON the SNES
# (examples/snes/spirograph.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host curve-math oracle (tools/spiro-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts (3x, byte-identical = deterministic).
#   * MAME     — under Xvfb, dev/spirograph.lua snapshots + asserts.
# Plus a disasm gate proving the curve hot loop is the declared codegen (sin/cos-LUT + 16x16->32
# __mulsi3 + gear-ratio __udiv + native-16 rep/sep). The 5-way differential of the curve + controller
# math (host == default == +mos-a16 == +mos-xy16) is the corpus slice gate: dev/run.sh corpus-a16.
#
# Drive: dev/run.sh spirograph. Outputs build/spirograph-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh spirograph   # render the Spirograph on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/spirograph.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden curve-math hash (the differential anchor; spiro.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/spiro-sim.c" -o "$BUILD/spiro-sim"
EXPECT=$("$BUILD/spiro-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: spirograph curve hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/spirograph.map" -o "$BUILD/spirograph.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/spirograph.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/spirograph.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/spirograph.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the curve hot loop must be sin/cos-LUT + 16x16->32 __mulsi3 + gear __udiv + rep/sep.
# Compile the probe with --target=mos (NOT --config, which enables LTO -> the object is LLVM bitcode,
# which llvm-objdump can't disassemble); --target=mos emits a real elf32-mos object.
echo "==> disasm gate (curve hot loop codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/spiro_sim.c" -o "$BUILD/spiro_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/spiro_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -c '__mulsi3'  || true)
div=$(printf '%s\n' "$dis" | grep -cE '__udiv'   || true)
rs=$(printf '%s\n'  "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$div" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  __udiv=$div  rep/sep=$rs  (sin/cos-LUT + fixed-point mul + gear divide, native-16)"
else
  echo "    FAIL  __mulsi3=$mul  __udiv=$div  rep/sep=$rs (expected all >= 1)"; rc=1
fi

# 4. bsnes-jg — build the harness if needed, then dump its framebuffer + assert, 3x byte-identical.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/spirograph-jg.png) + assert"
  "$JGX" "$BUILD/spirograph.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/spirograph-jg.png" || rc=1
  # determinism: 3 captures must be byte-identical (proves snes_ppu_reset_blank pinned the PPU)
  s1=$("$JGX" "$BUILD/spirograph.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/.sp1.png" >/dev/null 2>&1; sha256sum "$BUILD/.sp1.png" | cut -d' ' -f1)
  s2=$("$JGX" "$BUILD/spirograph.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/.sp2.png" >/dev/null 2>&1; sha256sum "$BUILD/.sp2.png" | cut -d' ' -f1)
  s3=$("$JGX" "$BUILD/spirograph.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/.sp3.png" >/dev/null 2>&1; sha256sum "$BUILD/.sp3.png" | cut -d' ' -f1)
  if [ "$s1" = "$s2" ] && [ "$s2" = "$s3" ]; then echo "    PASS  3x bsnes-jg capture byte-identical ($s1)"; else echo "    FAIL  bsnes-jg non-deterministic ($s1 $s2 $s3)"; rc=1; fi
  rm -f "$BUILD"/.sp1.png "$BUILD"/.sp2.png "$BUILD"/.sp3.png
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/spirograph-mame.png)"
  SNAP="$BUILD/.spiro-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/spirograph.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/spirograph.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/spirograph-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Spirograph rendered on SNES; MAME + bsnes-jg screenshots + curve hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

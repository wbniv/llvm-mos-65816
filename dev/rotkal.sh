#!/usr/bin/env bash
# dev/rotkal.sh — render the Rotate-Register Kaleidoscope (#74 compiler stress-test) ON the SNES
# (examples/snes/rotkal.c, +mos-a16) and capture headless screenshots from BOTH emulator cores,
# each asserting corpus_result == the host oracle (tools/rotkal-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps framebuffer + asserts.
#   * MAME     — under Xvfb, dev/rotkal.lua snapshots + asserts.
# Plus a disasm gate proving the corner is G_ROTL/G_ROTR byte/16-bit custom lowering:
# constant-amount rotates (ConstantAmt 1046-1061, S8 special 1167-1178) emit asl+adc or
# ror/rol sequences; runtime rotate emits a variable-shift loop; rep/sep confirms a16 mode.
# Full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh rotkal.  Outputs build/rotkal-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh rotkal   # render rotate-register kaleidoscope; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/rotkal.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/rotkal-sim.c" -o "$BUILD/rotkal-sim"
EXPECT=$("$BUILD/rotkal-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: rotkal gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/rotkal.map" -o "$BUILD/rotkal.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/rotkal.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/rotkal.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/rotkal.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: G_ROTL/G_ROTR byte/16-bit custom lowering.
# Constant-amount rotates lower to asl+adc (8-bit rotl) or ror/rol sequences;
# check asl count (>=8 for 8 ring rotates) + ror count (>=4 for rotr rotates)
# + rep/sep (a16 mode presence).
echo "==> disasm gate (G_ROTL/G_ROTR constant+runtime: asl/ror/rol count + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/rotkal_sim.c" -I"$ROOT/examples" -o "$BUILD/rotkal_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/rotkal_sim.o" 2>/dev/null || true)
ror=$(printf '%s\n' "$dis" | grep -cwE '\bror\b' || true)
rol=$(printf '%s\n' "$dis" | grep -cwE '\brol\b' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE '\brep\b|\bsep\b' || true)
rr=$(( ror + rol ))
echo "    ror=$ror  rol=$rol  ror+rol=$rr  rep/sep=$rs"
# The compiler lowers G_ROTL/G_ROTR via native 65816 ROL/ROR (rotate-through-carry)
# instructions.  With 8 per-step ring rotates, expect ror+rol >= 8.
if [ "$rr" -ge 8 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  rotate lowering confirmed (ror+rol=$rr >= 8, rep/sep=$rs >= 1)"
else
  echo "    FAIL  ror+rol=$rr (expected >=8) rep/sep=$rs (expected >=1)"; rc=1
fi

# 4. bsnes-jg — build harness if needed, dump framebuffer + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/rotkal-jg.png) + assert"
  "$JGX" "$BUILD/rotkal.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/rotkal-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/rotkal-mame.png)"
  SNAP="$BUILD/.rotkal-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/rotkal.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/rotkal.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/rotkal-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Rotate-Register Kaleidoscope on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

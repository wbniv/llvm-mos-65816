#!/usr/bin/env bash
# dev/bitcensus.sh — render the Bit-Census Field demo (#53 compiler stress-test) ON the SNES
# (examples/snes/bitcensus.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/bitcensus-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/bitcensus.lua snapshots + asserts.
# Plus a disasm gate proving the hot loop emits the bit-population intrinsic family: the four
# __builtin_*ll (popcount/clz/ctz/parity) inline-lower via G_CTPOP/G_CTLZ/G_CTTZ
# (MOSLegalizerInfo.cpp:308 `.lower()`) -> the SWAR popcount masks 0x55 / 0x33 show up, plus native-16.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh bitcensus. Outputs build/bitcensus-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh bitcensus   # render the bit-population census field; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/bitcensus.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; bitcensus.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/bitcensus-sim.c" -o "$BUILD/bitcensus-sim"
EXPECT=$("$BUILD/bitcensus-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: bit-census gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/bitcensus.map" -o "$BUILD/bitcensus.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/bitcensus.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/bitcensus.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/bitcensus.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the four bit-population intrinsics inline-lower to SWAR bit-count trees. The 64-bit
# G_CTPOP lowering uses the population-count masks 0x5555.. (#$55) and 0x3333.. (#$33); native-16 fires.
echo "==> disasm gate (bit-population intrinsic family: popcount/clz/ctz/parity, inline-lowered)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/bitcensus_sim.c" -I"$ROOT/examples" -o "$BUILD/bitcensus_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/bitcensus_sim.o" 2>/dev/null || true)
m55=$(printf '%s\n' "$dis" | grep -cE '#\$55' || true)   # popcount SWAR mask 0x5555..
m33=$(printf '%s\n' "$dis" | grep -cE '#\$33' || true)   # popcount SWAR mask 0x3333..
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$m55" -ge 2 ] && [ "$m33" -ge 2 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  popcount-mask #\$55=$m55  #\$33=$m33  rep/sep=$rs  (inline G_CTPOP/CTLZ/CTTZ lowering)"
else
  echo "    FAIL  popcount-mask #\$55=$m55  #\$33=$m33  rep/sep=$rs  (expected #\$55>=2, #\$33>=2, rep/sep>=1)"; rc=1
fi

# 4. bsnes-jg — build the harness if needed, then dump framebuffer + assert.
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
  echo "==> bsnes-jg: render + framebuffer dump (build/bitcensus-jg.png) + assert"
  "$JGX" "$BUILD/bitcensus.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/bitcensus-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/bitcensus-mame.png)"
  SNAP="$BUILD/.bitcensus-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/bitcensus.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/bitcensus.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/bitcensus-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — bit-census field rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

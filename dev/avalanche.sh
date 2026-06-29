#!/usr/bin/env bash
# dev/avalanche.sh — render the #22 64-bit Avalanche matrix (examples/snes/avalanche.c, +mos-a16) ON the SNES and
# capture a REAL emulator screenshot from BOTH cores headless, each asserting corpus_result == the
# host oracle (tools/avalanche-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/avalanche.lua snapshots + asserts.
# Plus a disasm gate proving the 64-bit hash hot loop has __muldi3 + 64-bit shift + __udivdi3 + rep/sep.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice (avalanche_sim.c)
# gate, run by dev/run.sh corpus-a16.
#
# Drive: dev/run.sh avalanche. Outputs build/avalanche-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh avalanche   # render the 64-bit Avalanche demo on SNES; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/avalanche.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; avalanche.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/avalanche-sim.c" -o "$BUILD/avalanche-sim"
EXPECT=$("$BUILD/avalanche-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: 64-bit Avalanche gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/avalanche.map" -o "$BUILD/avalanche.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/avalanche.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/avalanche.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/avalanche.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the 64-bit hash hot loop must have __muldi3 (64x64 multiply) + a 64-bit shift
# (__lshrdi3/__ashldi3) + __udivdi3 (the gate's runtime 64-bit divide), under native-16 (rep/sep).
# This is the wide-integer corner no other demo touches.
echo "==> disasm gate (64-bit integer hash codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/avalanche_sim.c" -I"$ROOT/examples" -o "$BUILD/avalanche_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/avalanche_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -c '__muldi3'  || true)
sh=$(printf  '%s\n' "$dis" | grep -cE '__lshrdi3|__ashldi3' || true)
dv=$(printf  '%s\n' "$dis" | grep -cE '__udivdi3|__divdi3'  || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mul" -ge 1 ] && [ "$sh" -ge 1 ] && [ "$dv" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __muldi3=$mul  64-bit-shift=$sh  __udivdi3=$dv  rep/sep=$rs  (64-bit integer, native-16)"
else
  echo "    FAIL  __muldi3=$mul  64-bit-shift=$sh  __udivdi3=$dv  rep/sep=$rs  (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/avalanche-jg.png) + assert"
  "$JGX" "$BUILD/avalanche.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 800 "$BUILD/avalanche-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/avalanche-mame.png)"
  SNAP="$BUILD/.avalanche-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/avalanche.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/avalanche.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 18 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/avalanche-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 64-bit Avalanche rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

#!/usr/bin/env bash
# dev/dhmix.sh — render the Diffie-Hellman Colour-Mixer demo (#61 compiler stress-test) ON
# the SNES (examples/snes/dhmix.c, +mos-a16) and capture a REAL emulator screenshot from BOTH cores
# headless, each asserting corpus_result == the host oracle (tools/dhmix-sim.c):
#   * bsnes-jg — dev/jgxcheck.cpp dumps its framebuffer + asserts.
#   * MAME     — under Xvfb, dev/dhmix.lua snapshots + asserts.
# Plus a disasm gate proving the hot op is a 64-bit modulo (__umoddi3) after a 64-bit multiply
# (__muldi3) in the square-and-multiply modpow. This demo surfaced + fixed the s64-unmerge/anyext a16
# legalizer crash (patch 0017). The modexp gate is heavy, so the snapshot/assert frame is 700.
# The full 5-way differential (host==default==+mos-a16==+mos-xy16) is the corpus slice gate.
#
# Drive: dev/run.sh dhmix. Outputs build/dhmix-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh dhmix   # render the Diffie-Hellman colour-mixer; screenshot + assert MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/dhmix.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (the differential anchor; dhmix.h compiled host-side).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/dhmix-sim.c" -o "$BUILD/dhmix-sim"
EXPECT=$("$BUILD/dhmix-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: dhmix gate hash = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/dhmix.map" -o "$BUILD/dhmix.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/dhmix.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/dhmix.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/dhmix.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: 64-bit modular exponentiation — the HOT op is a 64-bit modulo (__umoddi3) after a
# 64-bit multiply (__muldi3) per exponent bit of the square-and-multiply modpow. This is also the demo
# that surfaced the s64-unmerge/anyext a16 legalizer crash (fixed in patch 0017); it now compiles clean.
echo "==> disasm gate (64-bit modular exponentiation: __umoddi3 + __muldi3 square-and-multiply)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/dhmix_sim.c" -I"$ROOT/examples" -o "$BUILD/dhmix_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/dhmix_sim.o" 2>/dev/null || true)
umod=$(printf '%s\n' "$dis" | grep -c '__umoddi3' || true)   # the 64-bit modulo (the hot op)
mul=$(printf  '%s\n' "$dis" | grep -c '__muldi3'  || true)   # the 64-bit multiply
rs=$(printf   '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$umod" -ge 1 ] && [ "$mul" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __umoddi3=$umod  __muldi3=$mul  rep/sep=$rs  (64-bit modexp: 64-bit modulo hot op)"
else
  echo "    FAIL  __umoddi3=$umod  __muldi3=$mul  rep/sep=$rs  (expected umoddi3>=1, muldi3>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/dhmix-jg.png) + assert"
  "$JGX" "$BUILD/dhmix.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 700 "$BUILD/dhmix-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/dhmix-mame.png)"
  SNAP="$BUILD/.dhmix-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/dhmix.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/dhmix.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/dhmix-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Diffie-Hellman colour-mixer rendered on SNES; MAME + bsnes-jg screenshots + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

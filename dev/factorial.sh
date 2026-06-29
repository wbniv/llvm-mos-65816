#!/usr/bin/env bash
# dev/factorial.sh — gate for the Bignum Factorial demo (#20 compiler stress-test)
# (examples/snes/factorial.c, +mos-a16): render on SNES, assert corpus_result == host oracle
# on bsnes-jg and MAME, and verify the hot loops have __mulsi3 + __udivmodsi4 + rep/sep.
#
# Drive: dev/run.sh factorial.  Outputs build/factorial-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh factorial   # bignum factorial SNES demo gate (build + assert + screenshots)"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/factorial.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# 1. Host oracle: the golden gate hash (factorial_gate_crc computing 100!).
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/factorial-sim.c" -o "$BUILD/factorial-sim"
EXPECT=$("$BUILD/factorial-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: factorial gate hash (50!) = $EXPECT"

# 2. Build the on-console demo ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/factorial.map" -o "$BUILD/factorial.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/factorial.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/factorial.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/factorial.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the bignum mul loop must have __mulsi3 + __udivmodsi4 + rep/sep.
# __udivmodsi4: clang emits this (not separate __udivsi3/__umodsi3) because both
# quot and rem of the same division are used within bignum_mul_n's inner loop.
echo "==> disasm gate (bignum carry-mul codegen)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/factorial_sim.c" \
  -I"$ROOT/examples" -o "$BUILD/factorial_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/factorial_sim.o" 2>/dev/null || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__umulsi3' || true)
div=$(printf '%s\n' "$dis" | grep -c  '__udivmodsi4'       || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep'           || true)
if [ "$mul" -ge 1 ] && [ "$div" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mul  __udivmodsi4=$div  rep/sep=$rs  (schoolbook carry-mul + native-16)"
else
  echo "    FAIL  __mulsi3=$mul  __udivmodsi4=$div  rep/sep=$rs  (expected all >= 1)"; rc=1
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
  echo "==> bsnes-jg: render + framebuffer dump (build/factorial-jg.png) + assert"
  "$JGX" "$BUILD/factorial.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 "$BUILD/factorial-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 5. MAME under Xvfb — snapshot the real PPU output + assert.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content; supply out-of-band)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/factorial-mame.png)"
  SNAP="$BUILD/.factorial-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/factorial.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/factorial.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/factorial-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — bignum factorial rendered on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

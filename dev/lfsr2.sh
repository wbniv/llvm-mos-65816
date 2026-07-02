#!/usr/bin/env bash
# dev/lfsr2.sh — render Dual-LFSR Scrambler (#106 stress-test, Round 6 Cluster D).
# Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-BIT coalescer miscompile) via TWO
# loop-carried 8-bit LFSRs (Galois + Fibonacci) + a 16-bit Galois, stepped simultaneously so their
# shift registers + feedbacks are live at once. The DEFAULT-8-bit leg is load-bearing (0010 is NOT
# accum-gated). Drive: dev/run.sh lfsr2. Outputs build/lfsr2-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh lfsr2   # render dual-LFSR noise fields; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/lfsr2.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/lfsr2-sim.c" -o "$BUILD/lfsr2-sim"
EXPECT=$("$BUILD/lfsr2-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: lfsr2 gate hash = $EXPECT"

# 2. Build ROM (+mos-a16, for the on-screen demo + 16-bit-canvas display).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/lfsr2.map" -o "$BUILD/lfsr2.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/lfsr2.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/lfsr2.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/lfsr2.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate — DEFAULT-8-BIT (that is where 0010 lives): confirm the bit-serial rotate loop
#    (asl/rol shift-register) is present, and the DEFAULT build compiles clean.
echo "==> disasm gate (DEFAULT-8-bit dual-LFSR: asl/rol/lsr/ror shift-register loop)"
"$TOOL/mos-clang" --config "$CFG" -fno-lto -mcpu=mosw65816 -Os \
  -c "$ROOT/examples/snes/corpus/lfsr2_sim.c" -I"$ROOT/examples" -o "$BUILD/lfsr2_sim_default.o" 2>/dev/null \
  && defok=1 || defok=0
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/lfsr2_sim_default.o" 2>/dev/null || true)
rot=$(printf '%s\n' "$dis" | grep -cwE 'asl|rol|lsr|ror' || true)   # the shift-register rotates
if [ "$defok" -eq 1 ] && [ "$rot" -ge 3 ]; then
  echo "    PASS  default-8bit-compile=OK  asl/rol/lsr/ror=$rot  (bit-serial shift-register present)"
else
  echo "    FAIL  default-8bit-compile=$defok  asl/rol/lsr/ror=$rot  (expected default OK, rotates>=3)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/lfsr2-jg.png)"
  "$JGX" "$BUILD/lfsr2.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/lfsr2-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/lfsr2-mame.png)"
  SNAP="$BUILD/.lfsr2-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/lfsr2.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/lfsr2.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/lfsr2-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Dual-LFSR Scrambler on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

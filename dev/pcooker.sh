#!/usr/bin/env bash
# dev/pcooker.sh — render Pressure-Cooker Fixed-Point Evaluator (#109 stress-test, Round 6 Cluster E).
# Re-stresses patch 0011 (scavenger-$p): a giant straight-line 32-bit fixed-point expression per pixel
# whose compare's N/Z is consumed AFTER several __mulsi3/__divsi3 calls (compare forced live across the
# call-clobber) under a dozen live 32-bit temps. The a16/xy16 legs are load-bearing (0011 accum-gated).
# Drive: dev/run.sh pcooker. Outputs build/pcooker-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh pcooker   # render pressure-cooker implicit surface; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/pcooker.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/pcooker-sim.c" -o "$BUILD/pcooker-sim"
EXPECT=$("$BUILD/pcooker-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: pcooker gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/pcooker.map" -o "$BUILD/pcooker.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/pcooker.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/pcooker.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/pcooker.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate (a16): the straight-line evaluator emits several __mulsi3 + __divsi3 that the
#    compare's N/Z must survive across (the 0011 scavenger-$p shape), under a16 rep/sep pressure.
echo "==> disasm gate (a16: __mulsi3 + __divsi3 the compare lives across; rep/sep pressure)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/pcooker_sim.c" -I"$ROOT/examples" -o "$BUILD/pcooker_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/pcooker_sim.o" 2>/dev/null || true)
mulsi=$(printf '%s\n' "$dis" | grep -cE '__mulsi3' || true)
divsi=$(printf '%s\n' "$dis" | grep -cE '__divsi3|__udivsi3' || true)
rs=$(printf    '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$mulsi" -ge 1 ] && [ "$divsi" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __mulsi3=$mulsi  __divsi3=$divsi  rep/sep=$rs  (compare-live-across-calls pressure)"
else
  echo "    FAIL  __mulsi3=$mulsi  __divsi3=$divsi  rep/sep=$rs  (expected mulsi3>=1, divsi3>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/pcooker-jg.png, frame 1500 for developed field)"
  "$JGX" "$BUILD/pcooker.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1500 \
    "$BUILD/pcooker-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/pcooker-mame.png)"
  SNAP="$BUILD/.pcooker-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/pcooker.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/pcooker.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 32 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/pcooker-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Pressure-Cooker Fixed-Point Evaluator on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

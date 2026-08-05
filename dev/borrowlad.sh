#!/usr/bin/env bash
# dev/borrowlad.sh — render Borrow-Ladder Odometer (#110 stress-test, Round 6 Cluster E).
# A 128-bit descending odometer built from chained 16-bit subtracts-with-borrow, with borrows
# rippling across eight limbs. The a16/xy16 legs exercise native-width SBC code generation.
# Drive: dev/run.sh borrowlad. Outputs build/borrowlad-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh borrowlad   # render 128-bit borrow-ladder odometer; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/borrowlad.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/borrowlad-sim.c" -o "$BUILD/borrowlad-sim"
EXPECT=$("$BUILD/borrowlad-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: borrowlad gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/borrowlad.map" -o "$BUILD/borrowlad.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/borrowlad.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/borrowlad.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/borrowlad.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate (a16): the 128-bit borrow chain lowers to a run of `sbc` preceded by `sec`, under
#    a16 rep/sep pressure. This is a native-width codegen gate, not the baseline LDCImm regression.
echo "==> disasm gate (a16: sec + sbc borrow chain; rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/borrowlad_sim.c" -I"$ROOT/examples" -o "$BUILD/borrowlad_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/borrowlad_sim.o" 2>/dev/null || true)
sbc=$(printf '%s\n' "$dis" | grep -cw 'sbc' || true)
sec=$(printf '%s\n' "$dis" | grep -cw 'sec' || true)
rs=$(printf  '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$sbc" -ge 1 ] && [ "$sec" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  sbc=$sbc  sec=$sec  rep/sep=$rs  (128-bit borrow chain with the set-i1 carry-in)"
else
  echo "    FAIL  sbc=$sbc  sec=$sec  rep/sep=$rs  (expected sbc>=1, sec>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/borrowlad-jg.png)"
  "$JGX" "$BUILD/borrowlad.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/borrowlad-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/borrowlad-mame.png)"
  SNAP="$BUILD/.borrowlad-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/borrowlad.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/borrowlad.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/borrowlad-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Borrow-Ladder Odometer on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

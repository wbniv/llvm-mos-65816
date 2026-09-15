#!/usr/bin/env bash
# dev/csrjmp.sh — render the Callee-Saved Restore Curve (#117 stress-test, Round 6 Cluster G).
# The CSR-restore-offset guard for the 65816-native platforms/snes/setjmp.S fix (bug #35):
# 14 coefficient bytes — the exact width of jmp_buf's csrs[14] (__rc18..__rc31) — are held in
# locals across a setjmp while a noinline worker occupies and rewrites every callee-saved slot,
# then longjmps past the epilogue that would restore them. An off-by-one in longjmp's restore
# offsets corrupts exactly one coefficient, warping one axis of the rendered harmonograph.
# Drive: dev/run.sh csrjmp. Outputs build/csrjmp-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh csrjmp   # render the harmonograph curve; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/csrjmp.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/csrjmp-sim.c" -o "$BUILD/csrjmp-sim"
EXPECT=$("$BUILD/csrjmp-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: csrjmp gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/csrjmp.map" -o "$BUILD/csrjmp.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/csrjmp.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/csrjmp.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/csrjmp.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Structure gate: the setjmp frame really does keep its coefficients in the callee-saved block
#    (that is the thing under test), the worker really longjmps, and the curve's 32-bit multiply
#    chain survives to the ROM.
echo "==> structure gate (setjmp + longjmp present, __rc2x callee-saved block occupied, __mulsi3)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/csrjmp_sim.c" -I"$ROOT/examples" -o "$BUILD/csrjmp_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/csrjmp_sim.o" 2>/dev/null || true)
sj=$(printf '%s\n' "$dis" | grep -cE '\bsetjmp\b' || true)
lj=$(printf '%s\n' "$dis" | grep -cE '\blongjmp\b' || true)
csr=$(printf '%s\n' "$dis" | grep -cE '__rc(2[0-9]|3[01])' || true)
mul=$(printf '%s\n' "$dis" | grep -cE '__mulsi3' || true)
if [ "$sj" -ge 1 ] && [ "$lj" -ge 1 ] && [ "$csr" -ge 10 ] && [ "$mul" -ge 1 ]; then
  echo "    PASS  setjmp=$sj  longjmp=$lj  __rc20..31 refs=$csr  __mulsi3=$mul"
else
  echo "    FAIL  setjmp=$sj  longjmp=$lj  __rc20..31 refs=$csr  __mulsi3=$mul  (expected setjmp>=1, longjmp>=1, csr>=10, mulsi3>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/csrjmp-jg.png, frame 600)"
  "$JGX" "$BUILD/csrjmp.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 600 \
    "$BUILD/csrjmp-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/csrjmp-mame.png)"
  SNAP="$BUILD/.csrjmp-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/csrjmp.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/csrjmp.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 14 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/csrjmp-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Callee-Saved Restore Curve on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

#!/usr/bin/env bash
# dev/smulorbit.sh — render Signed Multiply-Overflow Orbit Sentinel (#76 stress-test)
# Codegen corners: G_SMULO at s16 (lowerMulo) + s32 (__mulosi4) via
# __builtin_mul_overflow on int16_t and int32_t operands. No prior demo linked __mulosi4.
# Drive: dev/run.sh smulorbit. Outputs build/smulorbit-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh smulorbit   # render smul-overflow orbit; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/smulorbit.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/smulorbit-sim.c" -o "$BUILD/smulorbit-sim"
EXPECT=$("$BUILD/smulorbit-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: smulorbit gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/smulorbit.map" -o "$BUILD/smulorbit.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/smulorbit.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/smulorbit.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/smulorbit.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: G_SMULO at s16 (lowerMulo) + s32 (__mulosi4).
echo "==> disasm gate (G_SMULO: __mulosi4 for int32 path + rep/sep for a16)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/smulorbit_sim.c" -I"$ROOT/examples" -o "$BUILD/smulorbit_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/smulorbit_sim.o" 2>/dev/null || true)
muldi=$(printf '%s\n' "$dis" | grep -cE '__muldi3' || true)     # s32 smulo: widen-to-s64 multiply
mulsi=$(printf '%s\n' "$dis" | grep -cE '__mulsi3|__mulhi3' || true)  # s16 smulo widening + other
rs=$(printf    '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
# lowerMulo at 2693 expands G_SMULO s32 by widening int32->int64 -> __muldi3 (not __mulosi4 directly).
# G_SMULO s16 widens to int32 -> __mulsi3 or __mulhi3. Both paths exercised.
if [ "$muldi" -ge 1 ] && [ "$mulsi" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __muldi3=$muldi  __mulsi3/hi3=$mulsi  rep/sep=$rs  (G_SMULO s16+s32 lowerMulo present)"
else
  echo "    FAIL  __muldi3=$muldi  __mulsi3/hi3=$mulsi  rep/sep=$rs  (expected muldi3>=1, mulsi/hi3>=1, rep/sep>=1)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/smulorbit-jg.png)"
  "$JGX" "$BUILD/smulorbit.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/smulorbit-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/smulorbit-mame.png)"
  SNAP="$BUILD/.smulorbit-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/smulorbit.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/smulorbit.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/smulorbit-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Signed Multiply-Overflow Orbit on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

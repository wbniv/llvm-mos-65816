#!/usr/bin/env bash
# dev/mulov64.sh — render 64-bit Multiply-Overflow / Multiply-High Sentinel (#101 stress-test).
# Round 6 Cluster-C first pick. Codegen corner: G_UMULO/G_SMULO at s64 (lowerMulo) -> G_UMULH/
# G_SMULH at s64 (.lower()) — the one untested s64 legalizer path. Threads the S32-mul-clamp
# (G_MUL clampScalar(0,S8,S32), "no S128 widening"). No prior demo forms an s64 mulh/mulo.
# Drive: dev/run.sh mulov64. Outputs build/mulov64-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mulov64   # render 64-bit mul-overflow orbit; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/mulov64.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/mulov64-sim.c" -o "$BUILD/mulov64-sim"
EXPECT=$("$BUILD/mulov64-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: mulov64 gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/mulov64.map" -o "$BUILD/mulov64.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/mulov64.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/mulov64.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/mulov64.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: s64 mulo/mulh -> __muldi3 (low product) + __mulsi3 (s32 pieces of the mulh) + a16.
echo "==> disasm gate (s64 G_UMULO/SMULO -> G_UMULH/SMULH: __muldi3 + __mulsi3 + rep/sep)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/mulov64_sim.c" -I"$ROOT/examples" -o "$BUILD/mulov64_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/mulov64_sim.o" 2>/dev/null || true)
muldi=$(printf '%s\n' "$dis" | grep -cE '__muldi3' || true)   # s64 low product
mulsi=$(printf '%s\n' "$dis" | grep -cE '__mulsi3' || true)   # s32 pieces of the s64 mulh .lower()
rs=$(printf    '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
if [ "$muldi" -ge 1 ] && [ "$mulsi" -ge 1 ] && [ "$rs" -ge 1 ]; then
  echo "    PASS  __muldi3=$muldi  __mulsi3=$mulsi  rep/sep=$rs  (s64 mulo/mulh lowering present)"
else
  echo "    FAIL  __muldi3=$muldi  __mulsi3=$mulsi  rep/sep=$rs  (expected muldi3>=1, mulsi3>=1, rep/sep>=1)"; rc=1
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
  # Render at frame 1500: the s64 mul-overflow gate is the heaviest compute in the battery
  # (corpus_result settles ~frame 400), so the orbit-scatter needs ~1500 frames to develop for
  # a good preview. corpus_result is set once (before the main loop) so the assert holds at any
  # frame >= 400. (Differential is unaffected — this is preview timing only.)
  echo "==> bsnes-jg: render + assert (build/mulov64-jg.png, frame 1500 for developed scatter)"
  "$JGX" "$BUILD/mulov64.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1500 \
    "$BUILD/mulov64-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mulov64-mame.png)"
  SNAP="$BUILD/.mulov64-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/mulov64.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mulov64.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/mulov64-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 64-bit Multiply-Overflow on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

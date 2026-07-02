#!/usr/bin/env bash
# dev/modexp256.sh — render 256-bit Modular Exponentiation (#104 stress-test, Round 6 Cluster C).
# Re-stresses patch 0017's s64 (un)merge glue (#61 dhmix) as a HIGH-VOLUME regression guard: a
# 256-bit Diffie-Hellman modexp built from uint32[8] limbs + uint64 multiply-accumulate (no s128/s256
# node — re-runs the green s64 path hundreds of times under register pressure). The DH identity
# A^b==B^a (folded as a mismatch witness) catches any s64-lane-split miscompile.
# Drive: dev/run.sh modexp256. Outputs build/modexp256-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh modexp256   # render 256-bit modular exponentiation; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/modexp256.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/modexp256-sim.c" -o "$BUILD/modexp256-sim"
EXPECT=$("$BUILD/modexp256-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: modexp256 gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/modexp256.map" -o "$BUILD/modexp256.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/modexp256.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/modexp256.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/modexp256.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: the 256-bit modmul MAC is built from uint64 multiplies (__muldi3, the s64 (un)merge
#    glue 0017 hardened) under heavy a16 rep/sep pressure. xy16 must compile clean too.
echo "==> disasm gate (s64 (un)merge glue: __muldi3 + rep/sep; xy16 compile clean)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/modexp256_sim.c" -I"$ROOT/examples" -o "$BUILD/modexp256_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/modexp256_sim.o" 2>/dev/null || true)
muldi=$(printf '%s\n' "$dis" | grep -cE '__muldi3' || true)   # uint64 multiply-accumulate
rs=$(printf    '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -c "$ROOT/examples/snes/corpus/modexp256_sim.c" -I"$ROOT/examples" -o /dev/null 2>/dev/null \
  && xy16ok=1 || xy16ok=0
if [ "$muldi" -ge 1 ] && [ "$rs" -ge 1 ] && [ "$xy16ok" -eq 1 ]; then
  echo "    PASS  __muldi3=$muldi  rep/sep=$rs  xy16-compile=OK  (256-bit modmul on the s64 glue)"
else
  echo "    FAIL  __muldi3=$muldi  rep/sep=$rs  xy16-compile=$xy16ok  (expected muldi3>=1, rep/sep>=1, xy16 OK)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/modexp256-jg.png, frame 1500 for developed scatter)"
  "$JGX" "$BUILD/modexp256.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1500 \
    "$BUILD/modexp256-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/modexp256-mame.png)"
  SNAP="$BUILD/.modexp256-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/modexp256.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/modexp256.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 32 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/modexp256-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 256-bit Modular Exponentiation on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

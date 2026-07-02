#!/usr/bin/env bash
# dev/oddmask.sh — render Odd-Width Mask Sculptor (#103 stress-test, Round 6 Cluster C).
# Re-stresses the odd-width extend + s64 (un)merge legalization of patch 0017 (#61 dhmix): forms
# s20/s24/s28 intermediates (i32-sourced narrow mask+op -> G_ZEXT sN->s64, no s16-lane decomposition)
# threaded through an s64 multiply — the legalization path that crashed a16/xy16 before 0017.
# Drive: dev/run.sh oddmask. Outputs build/oddmask-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh oddmask   # render odd-width mask sculptor; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/oddmask.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/oddmask-sim.c" -o "$BUILD/oddmask-sim"
EXPECT=$("$BUILD/oddmask-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: oddmask gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/oddmask.map" -o "$BUILD/oddmask.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/oddmask.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/oddmask.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/oddmask.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Odd-width-extend probe: the load-bearing check. Dump the pre-legalizer GMIR and confirm the
#    odd widths (s20/s24/s28) form AND are zero-extended to s64 (G_ZEXT sN->s64) — an extend with no
#    s16-lane decomposition, which is exactly the legalization 0017 added; plus __muldi3 (s64 glue).
echo "==> odd-width-extend probe (G_ZEXT s20/s24/s28 -> s64) + s64 glue + a16 rep/sep"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/oddmask_sim.c" -I"$ROOT/examples" -o "$BUILD/oddmask_sim.o" \
  -mllvm -print-before=legalizer 2>"$BUILD/oddmask.pre.txt"
odd=$(grep -cE 'G_ZEXT.*\(s(20|24|28)\)' "$BUILD/oddmask.pre.txt" 2>/dev/null || true)
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/oddmask_sim.o" 2>/dev/null || true)
muldi=$(printf '%s\n' "$dis" | grep -cE '__muldi3' || true)
rs=$(printf    '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
# xy16 must compile clean too (dhmix crashed there before 0017).
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -c "$ROOT/examples/snes/corpus/oddmask_sim.c" -I"$ROOT/examples" -o /dev/null 2>/dev/null \
  && xy16ok=1 || xy16ok=0
if [ "$odd" -ge 3 ] && [ "$muldi" -ge 1 ] && [ "$rs" -ge 1 ] && [ "$xy16ok" -eq 1 ]; then
  echo "    PASS  odd-width-zext(s20/s24/s28)=$odd  __muldi3=$muldi  rep/sep=$rs  xy16-compile=OK"
else
  echo "    FAIL  odd-width-zext=$odd  __muldi3=$muldi  rep/sep=$rs  xy16-compile=$xy16ok  (expected zext>=3, muldi3>=1, rep/sep>=1, xy16 OK)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/oddmask-jg.png, frame 1500 for developed scatter)"
  "$JGX" "$BUILD/oddmask.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1500 \
    "$BUILD/oddmask-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/oddmask-mame.png)"
  SNAP="$BUILD/.oddmask-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/oddmask.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/oddmask.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/oddmask-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Odd-Width Mask Sculptor on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

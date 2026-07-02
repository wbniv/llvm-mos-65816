#!/usr/bin/env bash
# dev/ovmove.sh — render Overlap-Move Mosaic (#93 stress-test, Round 6 Cluster A).
# Re-stresses #23/patch-0002 (+mos-xy16 in-place-memmove REP/SEP index-width fix) + #79
# (G_MEMMOVE both overlap directions), escalated to a >256-byte buffer so the SDK memmove
# indexes with a 16-bit X — the exact width-flag boundary the #23 bug lived at.
# Drive: dev/run.sh ovmove. Outputs build/ovmove-{jg,mame}.png.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh ovmove   # render overlap-move mosaic; screenshot + assert"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/ovmove.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK not built"; exit 1; }

# 1. Host oracle.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/ovmove-sim.c" -o "$BUILD/ovmove-sim"
EXPECT=$("$BUILD/ovmove-sim" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host oracle: ovmove gate hash = $EXPECT"

# 2. Build ROM (+mos-a16).
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/ovmove.map" -o "$BUILD/ovmove.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/ovmove.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/ovmove.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/ovmove.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. Disasm gate: overlapping memmoves -> SDK memmove call + a16 rep/sep. Build the corpus slice
#    in +mos-xy16 too (the #23 bug is an xy16-index bug) and confirm it compiles + emits memmove.
echo "==> disasm gate (G_MEMMOVE -> memmove call; rep/sep for a16; xy16 compile clean)"
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -c "$ROOT/examples/snes/corpus/ovmove_sim.c" -I"$ROOT/examples" -o "$BUILD/ovmove_sim.o" 2>/dev/null
dis=$("$TOOL/llvm-objdump" -dr --mcpu=mosw65816 "$BUILD/ovmove_sim.o" 2>/dev/null || true)
mm=$(printf '%s\n' "$dis" | grep -cE 'memmove' || true)
rs=$(printf '%s\n' "$dis" | grep -cwE 'rep|sep' || true)
# xy16 must also compile clean (this is where the #23 bug crashed/miscompiled).
"$TOOL/mos-clang" --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-xy16 -Os \
  -c "$ROOT/examples/snes/corpus/ovmove_sim.c" -I"$ROOT/examples" -o "$BUILD/ovmove_sim_xy16.o" 2>/dev/null \
  && xy16ok=1 || xy16ok=0
if [ "$mm" -ge 1 ] && [ "$rs" -ge 1 ] && [ "$xy16ok" -eq 1 ]; then
  echo "    PASS  memmove-refs=$mm  rep/sep=$rs  xy16-compile=OK  (both overlap dirs, 16-bit index)"
else
  echo "    FAIL  memmove-refs=$mm  rep/sep=$rs  xy16-compile=$xy16ok  (expected memmove>=1, rep/sep>=1, xy16 OK)"; rc=1
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
  echo "==> bsnes-jg: render + assert (build/ovmove-jg.png)"
  "$JGX" "$BUILD/ovmove.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 500 \
    "$BUILD/ovmove-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness absent)"
fi

# 5. MAME.
if [ ! -f "$ROOT/dev/roms/s_smp/spc700.rom" ]; then
  echo "    SKIP MAME (no SPC700 IPL)"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/ovmove-mame.png)"
  SNAP="$BUILD/.ovmove-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/ovmove.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/ovmove.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 12 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/ovmove-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME (no xvfb-run)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Overlap-Move Mosaic on SNES; MAME + bsnes-jg + corpus hash $EXPECT host == +mos-a16"
else
  echo "RESULT: FAIL"
fi
exit $rc

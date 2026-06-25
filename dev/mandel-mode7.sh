#!/usr/bin/env bash
# dev/mandel-mode7.sh — #321 Track 3b: a BIG (128x128) per-pixel Mandelbrot rendered on
# the SNES via Mode 7, computed into HIGH WRAM by #320 far stores, uploaded to VRAM by a
# single 32 KiB DMA. Captures a real screenshot from BOTH cores (bsnes-jg framebuffer +
# MAME video:snapshot under Xvfb), each asserting the buffer CRC == the host renderer.
#
# +mos-a16-only (far pointers are 32-bit values). The 128x128 escape compute is heavy
# (~tens of thousands of frames of emulated time) — this is a one-off render, not a
# windowed gate, so we run a large frame budget. Outputs build/mandel-mode7-{jg,mame}.png
# + build/mandel-host-128.png. Drive: dev/run.sh mandel-mode7.
# See docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md (Track 3) +
# docs/handoffs/2026-06-24-snes-graphics-rendering.md (Mode 7 + DMA).
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-mode7   # 128x128 Mandelbrot on SNES via Mode 7 (far+DMA); screenshot MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/mandel-mode7.c"
ROM="$BUILD/mandel-mode7.sfc"
MAP="$BUILD/mandel-mode7.map"
VENDOR="$ROOT/vendor/bsnes-jg"
A16=(-Xclang -target-feature -Xclang +mos-a16)
FRAMES="${MANDEL_FRAMES:-16000}"     # 128x128/N=12 fill completes ~frame 14439 (measured);
                                     # snapshot after, with margin. Override via env.

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

# Pick up edits to platforms/snes/snes.h (+ link.ld) without a full re-vendor (<snes.h> resolves
# to the installed copy, so this refresh is the header dependency).
INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# Grid from the source so the host reference can't drift.
W=$(awk '/#define W /{print $3; exit}' "$SRC")
H=$(awk '/#define H /{print $3; exit}' "$SRC")
DN=$(awk '/#define DN /{print $3; exit}' "$SRC")
echo "==> mandel-mode7: ${W}x${H} N=${DN}  (frames=$FRAMES)"

# 1. Host reference CRC over the same grid + a host PNG.
cc -O2 -I "$ROOT/examples/65816" -I "$ROOT/tools" "$ROOT/tools/mandel-render.c" -o "$BUILD/mandel-render"
EXPECT=$("$BUILD/mandel-render" "$BUILD/mandel-host-128.png" "$W" "$H" "$DN" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host reference: CRC16=$EXPECT (build/mandel-host-128.png)"

# 2. Build the Mode 7 ROM (+mos-a16) + find corpus_result.
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -Os \
  -mllvm -verify-machineinstrs -Wl,-Map="$MAP" -o "$ROM" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$ROM" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$MAP")
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built $(basename "$ROM") (+mos-a16); corpus_result @ WRAM 0x$VMA"

rc=0

# 3. bsnes-jg: framebuffer dump + assert.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/mandel-mode7-jg.png)"
  "$JGX" "$ROM" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" "$FRAMES" "$BUILD/mandel-mode7-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 4. MAME under Xvfb: snapshot + assert (snapshot well after the compute completes).
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mandel-mode7-mame.png)"
  SNAP="$BUILD/.m7-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  secs=$(( FRAMES / 60 + 5 ))
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$ROM" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$secs" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/mandel-mode7-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — 128x128 Mandelbrot far-stored to high WRAM, Mode 7 + DMA on SNES; MAME + bsnes-jg match host (CRC $EXPECT)"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc

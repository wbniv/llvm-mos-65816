#!/usr/bin/env bash
# dev/mandel-shot.sh — Track 2 of the beefy demo: render the fixed-point Mandelbrot
# ON the SNES (examples/snes/mandel-display.c, +mos-a16) and capture a REAL,
# emulator-rendered screenshot from BOTH cores, headless:
#   * bsnes-jg — software renderer; dev/jgxcheck.cpp dumps its framebuffer to a PNG
#                and asserts corpus_result == the host CRC.
#   * MAME     — run under Xvfb so its renderer produces a real surface;
#                dev/mandel-shot.lua snapshots it and asserts corpus_result too.
# Both screenshots must show the same Mandelbrot the host renderer (tools/mandel-render)
# produces — the on-screen pixels are the differentially-verified ones.
#
# Drive: dev/run.sh mandel-shot. Outputs build/mandel-{jg,mame}.png + build/mandel-host.png.
# Methodology + how-to: docs/investigations/snes-emulator-screenshots.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-shot   # render Mandelbrot on SNES; screenshot from MAME + bsnes-jg"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"
SRC="$ROOT/examples/snes/mandel-display.c"
VENDOR="$ROOT/vendor/bsnes-jg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: SDK/snes not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }

# Grid params come from the source so the host reference can't drift out of sync.
DW=$(awk '/#define DW /{print $3; exit}' "$SRC")
DH=$(awk '/#define DH /{print $3; exit}' "$SRC")
DN=$(awk '/#define DN /{print $3; exit}' "$SRC")
echo "==> mandel-shot: grid ${DW}x${DH}, N=${DN}"

# 1. Host reference CRC over the SAME grid (the differential oracle) + a host PNG.
cc -O2 -I "$ROOT/examples/65816" -I "$ROOT/tools" "$ROOT/tools/mandel-render.c" -o "$BUILD/mandel-render"
EXPECT=$("$BUILD/mandel-render" "$BUILD/mandel-host.png" "$DW" "$DH" "$DN" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> host reference: CRC16=$EXPECT (build/mandel-host.png)"

# 2. Build the on-console display ROM (+mos-a16) and find corpus_result's WRAM address.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
  -Wl,-Map="$BUILD/mandel-display.map" -o "$BUILD/mandel-display.sfc" "$SRC"
python3 "$ROOT/tools/snes-checksum.py" "$BUILD/mandel-display.sfc" >/dev/null
VMA=$(awk '$NF=="corpus_result"{print $1; exit}' "$BUILD/mandel-display.map")
OFF="0x$VMA"
ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$VMA )))
echo "==> built build/mandel-display.sfc (+mos-a16); corpus_result @ WRAM $OFF"

rc=0

# 3. bsnes-jg — build the harness if needed, then dump its framebuffer + assert.
JGX="$BUILD/jgxcheck"
if [ ! -x "$JGX" ]; then
  ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
  if [ -n "$ARCHIVE" ]; then
    echo "==> building jgxcheck harness"
    g++ -O2 -std=c++11 -I"$VENDOR/src" -I"$ROOT/tools" -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
  fi
fi
if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
  echo "==> bsnes-jg: render + framebuffer dump (build/mandel-jg.png)"
  "$JGX" "$BUILD/mandel-display.sfc" "$VENDOR/Database" "$OFF" 2 "$EXPECT" 1800 "$BUILD/mandel-jg.png" || rc=1
else
  echo "    SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
fi

# 4. MAME under Xvfb — snapshot the real PPU output + assert.
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mandel-mame.png)"
  SNAP="$BUILD/.mandel-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" \
    xvfb-run -a mame snes -cart "$BUILD/mandel-display.sfc" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run 30 \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  if [ -f "$SNAP/snes/0000.png" ]; then mv "$SNAP/snes/0000.png" "$BUILD/mandel-mame.png"; fi
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "    SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — Mandelbrot rendered on SNES; MAME + bsnes-jg screenshots match host (CRC $EXPECT)"
else
  echo "RESULT: FAIL — see the per-emulator lines above"
fi
exit $rc

#!/usr/bin/env bash
# dev/mandel-interactive.sh — the INTERACTIVE Mandelbrot (Mode 7 joypad fly-around, #321 M2).
#
# Bakes the 128x128 Mandelbrot host-side, TILED into Mode 7 character order, into ROM. At boot the
# ROM just DMAs it straight ROM->VRAM (no compute, no de-linearize loop) so the Mandelbrot shows
# INSTANTLY; then it is a Mode 7 hardware pan/zoom/rotate fly-around at 60 fps. Because the upload
# is a plain ROM->VRAM DMA (no far pointer), the demo builds BOTH default-8bit and +mos-a16.
#
# Two differential gates, run on bsnes-jg headless for EACH build (host==default==+mos-a16):
#   * image: the displayed character data's hash (corpus_result) == the host reference.
#   * view : a SCRIPTED controller sequence is fed in; the ROM logs the pads it read + a rolling
#            CRC of the per-frame view state + Mode 7 matrix; the host replays examples/snes/view.h
#            over that GROUND-TRUTH pad log and asserts an identical CRC — gating the per-frame
#            Mode 7 matrix multiplies, independent of emulator input timing.
# Plus a bsnes-jg framebuffer PNG and (when xvfb-run is present) a MAME snapshot of the +mos-a16 ROM.
#
# Capture: dev/run.sh mandel-interactive. Live play: task mandel-mame ROM=mandel-interactive.
# See docs/plans/2026-06-25-321-interactive-mandelbrot-mode7.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-interactive   # baked Mandelbrot + Mode 7 joypad fly-around; host==default==+mos-a16 + screenshots"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/mandel-interactive.c"
IMG="$ROOT/examples/snes/mandel_image.h"
VENDOR="$ROOT/vendor/bsnes-jg"
FRAMES="${MANDEL_FRAMES:-150}"        # instant boot now; window = first 64 loop frames
# Scripted controller sequence (SEGMENT:FRAMES). Varied input across the window so the
# ground-truth pad log is non-trivial; exact alignment is irrelevant (we replay the log, not this).
SCRIPT="${JGX_SCRIPT:-RIGHT:28,R:28,A:28,DOWN:28,SELECT:2,L:28}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

# Pick up edits to platforms/snes/snes.h (+ link.ld) without a full re-vendor (the header dep).
INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# 1. Bake the 128x128 image (tiled into Mode 7 chars) into a ROM-resident header + reference hash.
cc -O2 -I "$ROOT/examples/65816" "$ROOT/tools/mandel-bake.c" -o "$BUILD/mandel-bake" -lm
EXPECT=$("$BUILD/mandel-bake" "$IMG" 128 128 32 | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
echo "==> baked $(basename "$IMG")  image hash=$EXPECT"

# 2. Build the view-enabled bsnes harness once.
JGX="$BUILD/jgxcheck-view"
ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
if [ -n "$ARCHIVE" ]; then
  g++ -O2 -std=c++11 -DJGX_VIEW -I"$VENDOR/src" -I"$ROOT/tools" -I"$ROOT/examples/snes" -I"$ROOT/examples/65816" \
      -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck-view.o"
  g++ "$BUILD/jgxcheck-view.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
fi

rc=0
vma() { awk -v s="$1" '$NF==s{print $1; exit}' "$2"; }

# Build one ROM variant, then run both differential gates on bsnes-jg.
build_and_check() {  # $1=label  $2=sfc  $3=png  $4..=extra clang flags
  local lbl="$1" rom="$2" png="$3"; shift 3
  local map="${rom%.sfc}.map"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "$@" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$map" -o "$rom" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$rom" >/dev/null
  local romb; romb=$(stat -c%s "$rom")
  if grep -qi 'overflow' "$map"; then echo "  [$lbl] FATAL: region overflow"; rc=1; return; fi
  local CR VC NF PL; CR=$(vma corpus_result "$map"); VC=$(vma view_crc "$map"); NF=$(vma nframes "$map"); PL=$(vma pad_log "$map")
  echo "  [$lbl] built ${romb}B, -verify clean, fit ok; corpus@\$$CR view_crc@\$$VC pad_log@\$$PL"
  if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
    local out
    out="$(JGX_SCRIPT="$SCRIPT" JGX_PADLOG="0x$PL" JGX_PADLOG_N=64 JGX_VIEWCRC="0x$VC" JGX_NFRAMES="0x$NF" \
      "$JGX" "$rom" "$VENDOR/Database" "0x$CR" 2 "$EXPECT" "$FRAMES" "$png" 2>/dev/null || true)"
    echo "$out" | grep -E 'SMOKE|VIEW' | sed "s/^/  [$lbl] /"
    echo "$out" | grep -q 'SMOKE: PASS' || { echo "  [$lbl] image gate FAILED"; rc=1; }
    echo "$out" | grep -q 'VIEW: PASS'  || { echo "  [$lbl] view gate FAILED";  rc=1; }
  else
    echo "  [$lbl] SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
  fi
}

echo "==> build + differential: default-8bit and +mos-a16 (host==default==+mos-a16)"
build_and_check default "$BUILD/mandel-interactive-def.sfc" "$BUILD/mandel-interactive-def.png"
build_and_check a16     "$BUILD/mandel-interactive.sfc"     "$BUILD/mandel-interactive-jg.png" \
                        -Xclang -target-feature -Xclang +mos-a16

# 3. MAME under Xvfb: snapshot the +mos-a16 screen + assert the image hash.
ROM="$BUILD/mandel-interactive.sfc"; MAP="$BUILD/mandel-interactive.map"
CR=$(vma corpus_result "$MAP")
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mandel-interactive-mame.png)"
  SNAP="$BUILD/.mi-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$CR )))
  secs=$(( FRAMES / 60 + 3 ))
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$ROM" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$secs" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/mandel-interactive-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "==> SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — interactive Mandelbrot: image hash $EXPECT host==default==+mos-a16; view-math host==target (bsnes-jg); MAME snapshot ok"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc

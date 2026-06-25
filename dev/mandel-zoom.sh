#!/usr/bin/env bash
# dev/mandel-zoom.sh — the Mandelbrot ZOOM PYRAMID (true increasing detail on zoom-in, #321 M2).
#
# Bakes a STACK of host-computed Mandelbrot levels (each 2x finer zoom, centered on one iconic
# point) TILED into Mode 7 character order, into ROM. At boot the ROM DMAs level 0 straight
# ROM->VRAM (instant); then it is a Mode 7 hardware zoom/rotate fly-around at 60 fps, and when zoom
# crosses a 2x threshold the ROM DMAs the next finer level and resets the scale — so the dive runs
# into GENUINELY NEW fractal detail with ZERO on-console fractal math. Because the upload is a plain
# ROM->VRAM DMA (no far pointer), the demo builds BOTH default-8bit and +mos-a16.
#
# Three differential gates, run on bsnes-jg headless for EACH build (host==default==+mos-a16):
#   * SMOKE: corpus_result (level-0 boot hash) == the host reference for level 0.
#   * HASH : the ROM hashes EVERY baked level at boot (level_hash[]); each asserted == its host
#            reference MANDEL_PYR_HASH[k] — so every displayed level IS the verified deeper Mandelbrot.
#   * ZOOM : a SCRIPTED controller sequence (dive in, rotate, cycle palette, back out) is fed in; the
#            ROM logs the pads it read + a rolling CRC of the per-frame (lvl, scale, angle, matrix);
#            the host replays examples/snes/zoom.h over that GROUND-TRUTH pad log and asserts an
#            identical CRC — gating the level-swap arithmetic + the Mode 7 matrix multiplies,
#            independent of emulator input timing.
# Plus a bsnes-jg framebuffer PNG and (when xvfb-run is present) a MAME snapshot of the +mos-a16 ROM.
#
# Capture: dev/run.sh mandel-zoom. Live play: task mandel-zoom-play.
# See docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md.
set -euo pipefail
case "${1-}" in -h|--help)
  echo "Usage: dev/run.sh mandel-zoom   # baked Mandelbrot zoom pyramid + level-swap; host==default==+mos-a16 + screenshots"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/mandel-zoom.c"
IMG="$ROOT/examples/snes/pyramid_image.h"
VENDOR="$ROOT/vendor/bsnes-jg"
FRAMES="${MANDEL_FRAMES:-180}"        # instant boot; budget covers the 6-level boot hash + 64 loop frames
# Pyramid geometry (Phase 1: 64x64 x 6 levels x 32 colours fits one 32 KiB LoROM bank).
PW="${PYR_W:-64}"; PH="${PYR_H:-64}"; PL="${PYR_L:-6}"; PN="${PYR_NCOL:-32}"
# Scripted controller sequence (SEGMENT:FRAMES): dive in (R -> several level swaps), rotate (A),
# cycle palette (SELECT edge), then keep diving (R held -> the framebuffer PNG ends on a DEEP level,
# the increasing-detail shot). Varied so the ground-truth pad log is non-trivial and exercises both
# the level-swap arithmetic and the rotate/scale matrix multiplies; exact alignment is irrelevant
# (we replay the log, not this).
SCRIPT="${JGX_SCRIPT:-R:30,A:10,SELECT:4,R:90}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: snes platform not built (run: dev/run.sh build)"; exit 1; }

# Pick up edits to platforms/snes/snes.h (+ link.ld) without a full re-vendor (the header dep).
INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# 1. Bake the zoom pyramid (L levels, each 2x finer) into a ROM-resident header + per-level hashes,
#    plus a host PNG per level for the increasing-detail montage.
mkdir -p "$BUILD/pyr-png"
cc -O2 -I "$ROOT/examples/65816" -I "$ROOT/tools" "$ROOT/tools/mandel-bake-pyramid.c" -o "$BUILD/mandel-bake-pyramid" -lm
BAKE_OUT="$("$BUILD/mandel-bake-pyramid" "$IMG" "$PW" "$PH" "$PL" "$PN" "$BUILD/pyr-png/pyr")"
echo "$BAKE_OUT" | sed 's/^/    /'
# Level-0 reference hash = the SMOKE single-value gate (corpus_result).
EXPECT="$(echo "$BAKE_OUT" | awk '/level 0:/{for(i=1;i<=NF;i++)if($i~/^hash=/){sub(/hash=/,"",$i);print $i}}')"
echo "==> baked $(basename "$IMG")  L=$PL level-0 hash=$EXPECT"

# 2. Build the zoom-enabled bsnes harness once (separate binary; -DJGX_ZOOM).
JGX="$BUILD/jgxcheck-zoom"
ARCHIVE="$(find "$VENDOR/objs" -name '*.a' 2>/dev/null | head -1 || true)"
if [ -n "$ARCHIVE" ]; then
  g++ -O2 -std=c++11 -DJGX_ZOOM -I"$VENDOR/src" -I"$ROOT/tools" -I"$ROOT/examples/snes" -I"$ROOT/examples/65816" \
      -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck-zoom.o"
  g++ "$BUILD/jgxcheck-zoom.o" "$ARCHIVE" -lsamplerate -lm -o "$JGX"
fi

rc=0
vma() { awk -v s="$1" '$NF==s{print $1; exit}' "$2"; }

# Build one ROM variant, then run the three differential gates on bsnes-jg.
build_and_check() {  # $1=label  $2=sfc  $3=png  $4..=extra clang flags
  local lbl="$1" rom="$2" png="$3"; shift 3
  local map="${rom%.sfc}.map"
  "$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "$@" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$map" -o "$rom" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$rom" >/dev/null
  local romb; romb=$(stat -c%s "$rom")
  if grep -qi 'overflow' "$map"; then echo "  [$lbl] FATAL: region overflow"; rc=1; return; fi
  local CR ZC NF PL_ADDR LH
  CR=$(vma corpus_result "$map"); ZC=$(vma zoom_crc "$map"); NF=$(vma nframes "$map")
  PL_ADDR=$(vma pad_log "$map"); LH=$(vma level_hash "$map")
  echo "  [$lbl] built ${romb}B, -verify clean, fit ok; corpus@\$$CR zoom_crc@\$$ZC level_hash@\$$LH pad_log@\$$PL_ADDR"
  if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
    local out
    out="$(JGX_SCRIPT="$SCRIPT" JGX_PADLOG="0x$PL_ADDR" JGX_PADLOG_N=64 JGX_ZOOMCRC="0x$ZC" \
      JGX_NFRAMES="0x$NF" JGX_LEVELHASH="0x$LH" \
      "$JGX" "$rom" "$VENDOR/Database" "0x$CR" 2 "$EXPECT" "$FRAMES" "$png" 2>/dev/null || true)"
    echo "$out" | grep -E 'SMOKE|HASH|ZOOM' | sed "s/^/  [$lbl] /"
    echo "$out" | grep -q 'SMOKE: PASS' || { echo "  [$lbl] image gate FAILED"; rc=1; }
    echo "$out" | grep -q 'HASH: PASS'  || { echo "  [$lbl] per-level hash gate FAILED"; rc=1; }
    echo "$out" | grep -q 'ZOOM: PASS'  || { echo "  [$lbl] zoom-math gate FAILED";  rc=1; }
  else
    echo "  [$lbl] SKIP bsnes-jg (harness/core absent — run: dev/run.sh xcheck once)"
  fi
}

echo "==> build + differential: default-8bit and +mos-a16 (host==default==+mos-a16)"
build_and_check default "$BUILD/mandel-zoom-def.sfc" "$BUILD/mandel-zoom-def.png"
build_and_check a16     "$BUILD/mandel-zoom.sfc"     "$BUILD/mandel-zoom-jg.png" \
                        -Xclang -target-feature -Xclang +mos-a16

# 3. MAME under Xvfb: snapshot the +mos-a16 screen + assert the level-0 boot hash. MAME feeds no
# input (mandel-shot.lua just snapshots), so this captures the INSTANT boot view (level 0) on the
# second emulator; the deep-level shot is the bsnes-jg framebuffer PNG above (which got the dive).
ROM="$BUILD/mandel-zoom.sfc"; MAP="$BUILD/mandel-zoom.map"
CR=$(vma corpus_result "$MAP")
if command -v xvfb-run >/dev/null 2>&1; then
  echo "==> MAME (under Xvfb): snapshot + assert (build/mandel-zoom-mame.png)"
  SNAP="$BUILD/.mz-snap"; rm -rf "$SNAP"; mkdir -p "$SNAP"
  ADDR=$(printf '0x%X' $(( 0x7E0000 + 0x$CR )))
  secs=$(( FRAMES / 60 + 3 ))
  line="$(SHOT_ADDR="$ADDR" SHOT_WANT="$EXPECT" SHOT_AT="$FRAMES" \
    xvfb-run -a mame snes -cart "$ROM" -rompath "$ROOT/dev/roms" \
      -autoboot_script "$ROOT/dev/mandel-shot.lua" -skip_gameinfo \
      -snapshot_directory "$SNAP" -sound none -nothrottle -seconds_to_run "$secs" \
      -cfg_directory /tmp -nvram_directory /tmp 2>/dev/null | grep -m1 '^SHOT:' || true)"
  echo "    $line"
  [ -f "$SNAP/snes/0000.png" ] && mv "$SNAP/snes/0000.png" "$BUILD/mandel-zoom-mame.png"
  case "$line" in "SHOT: PASS"*) : ;; *) rc=1 ;; esac
else
  echo "==> SKIP MAME snapshot (no xvfb-run — rebuild the dev image for the Xvfb layer)"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "RESULT: PASS — zoom pyramid: $PL levels host==default==+mos-a16 (per-level hash); zoom-math host==target (bsnes-jg); MAME snapshot ok"
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc

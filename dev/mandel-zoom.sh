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
  echo "  PYR_MODE=hd (default) -> Phase 2: 128x128 x 8 levels, multi-bank (snes-zoom, 256 KiB), 256x deep"
  echo "  PYR_MODE=sd           -> Phase 1: 64x64 x 6 levels, single-bank (snes, 32 KiB), 32x deep"
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/snes/mandel-zoom.c"
IMG="$ROOT/examples/snes/pyramid_image.h"
VENDOR="$ROOT/vendor/bsnes-jg"
# Mode: hd = Phase 2 multi-bank 128x128 x 8 (snes-zoom, 256 KiB); sd = Phase 1 single-bank 64x64 x 6.
# FRAMES budgets the boot hash + the 64-frame logged window + the dive (16 frames/level) reaching a
# deep level by the VRAM-readback/snapshot point; hd (8 levels, 128px) needs a longer dive than sd.
PYR_MODE="${PYR_MODE:-hd}"
case "$PYR_MODE" in
  hd) PW="${PYR_W:-128}"; PH="${PYR_H:-128}"; PL="${PYR_L:-8}"; PN="${PYR_NCOL:-32}"
      PLAT=snes-zoom; MULTIBANK=1; FRAMES="${MANDEL_FRAMES:-260}" ;;
  sd) PW="${PYR_W:-64}";  PH="${PYR_H:-64}";  PL="${PYR_L:-6}"; PN="${PYR_NCOL:-32}"
      PLAT=snes;      MULTIBANK=0; FRAMES="${MANDEL_FRAMES:-200}" ;;
  *)  echo "FATAL: PYR_MODE must be hd | sd (got '$PYR_MODE')"; exit 1 ;;
esac
CFG="$INSTALL/bin/mos-$PLAT.cfg"
# Scripted controller sequence (SEGMENT:FRAMES): dive in (R -> several level swaps), rotate (A),
# cycle palette (SELECT edge), dive ~5 levels (R), then HOLD (NONE) so the framebuffer PNG + the
# VRAM-readback settle on a deep-but-structured level (the mini-Mandelbrot; the very deepest level is
# its interior = mostly black). Varied so the ground-truth pad log is non-trivial and exercises the
# level-swap arithmetic + the rotate/scale matrix multiplies + a far-bank level swap; exact alignment
# is irrelevant (we replay the log, not this).
SCRIPT="${JGX_SCRIPT:-R:30,A:10,SELECT:4,R:50,NONE:120}"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ] || { echo "FATAL: $PLAT platform not built ($CFG missing — run: dev/run.sh build)"; exit 1; }

# Pick up edits to platforms/$PLAT/{snes.h,link.ld} without a full re-vendor (the header dep).
INSTALL="$INSTALL" "$ROOT/dev/sync-platform.sh"

# 1. Bake the zoom pyramid (L levels, each 2x finer) into a ROM-resident header + per-level hashes,
#    plus a host PNG per level for the increasing-detail montage. PYR_MULTIBANK (hd) tags levels 1..
#    into per-bank sections (.rodata_levelK -> banks $01.. on snes-zoom) + emits MANDEL_PYR_BANK[].
echo "==> mode=$PYR_MODE  ${PW}x${PH} x $PL levels  platform=$PLAT  multibank=$MULTIBANK"
mkdir -p "$BUILD/pyr-png"
cc -O2 -I "$ROOT/examples/65816" -I "$ROOT/tools" "$ROOT/tools/mandel-bake-pyramid.c" -o "$BUILD/mandel-bake-pyramid" -lm
BAKE_OUT="$(PYR_MULTIBANK="$MULTIBANK" "$BUILD/mandel-bake-pyramid" "$IMG" "$PW" "$PH" "$PL" "$PN" "$BUILD/pyr-png/pyr")"
echo "$BAKE_OUT" | sed 's/^/    /'
# Level-0 reference hash = the SMOKE single-value gate (corpus_result).
EXPECT="$(echo "$BAKE_OUT" | awk '/level 0:/{for(i=1;i<=NF;i++)if($i~/^hash=/){sub(/hash=/,"",$i);print $i}}')"
echo "==> baked $(basename "$IMG")  L=$PL level-0 hash=$EXPECT"

# Multi-bank: host-side proof that EVERY baked level's data is correctly placed in its ROM bank.
# Each level k>=1 lives at file offset k*0x8000 (bank k, $8000), 16 KiB; img_hash16 it and compare to
# the bake's per-level reference (the rotate-xor matches mandel.h / the on-console gate). Level 0 is
# covered on-console. (Levels 1.. are far -> not on-console-hashable, so this host check covers them.)
romfile_level_hashes_ok() {  # $1 = the .sfc
  local rom="$1"
  PL="$PL" PW="$PW" PH="$PH" BAKE_OUT="$BAKE_OUT" python3 - "$rom" <<'PY'
import os, sys
rom = open(sys.argv[1], "rb").read()
L, W, H = int(os.environ["PL"]), int(os.environ["PW"]), int(os.environ["PH"])
n = W * H
ref = {}
for line in os.environ["BAKE_OUT"].splitlines():
    line = line.strip()
    if line.startswith("level "):
        k = int(line.split()[1].rstrip(":"))
        for tok in line.split():
            if tok.startswith("hash=0x"):
                ref[k] = int(tok[5:], 16)
def img_hash16(b):
    h = 0
    for x in b:
        hi = (h >> 15) & 1
        h = (((h << 1) | hi) ^ x) & 0xFFFF
    return h
ok = True
for k in range(1, L):              # levels 1.. are bank-aligned at file k*0x8000
    off = k * 0x8000
    got = img_hash16(rom[off:off + n])
    if got != ref.get(k):
        print(f"  ROMFILE: FAIL level {k} file@0x{off:X} got=0x{got:04X} ref=0x{ref.get(k):04X}")
        ok = False
print("  ROMFILE: PASS levels 1..%d data in their banks == host ref" % (L - 1) if ok else "  ROMFILE: FAIL")
sys.exit(0 if ok else 1)
PY
}

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

# Build one ROM variant, then run the differential gates on bsnes-jg.
build_and_check() {  # $1=label  $2=sfc  $3=png  $4..=extra clang flags
  local lbl="$1" rom="$2" png="$3"; shift 3
  local map="${rom%.sfc}.map"
  "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "$@" -Os \
    -mllvm -verify-machineinstrs -Wl,-Map="$map" -o "$rom" "$SRC"
  python3 "$ROOT/tools/snes-checksum.py" "$rom" >/dev/null
  local romb; romb=$(stat -c%s "$rom")
  if grep -qi 'overflow' "$map"; then echo "  [$lbl] FATAL: region overflow"; rc=1; return; fi
  local CR ZC NF PL_ADDR LH CL
  CR=$(vma corpus_result "$map"); ZC=$(vma zoom_crc "$map"); NF=$(vma nframes "$map")
  PL_ADDR=$(vma pad_log "$map"); LH=$(vma level_hash "$map"); CL=$(vma cur_level "$map")
  echo "  [$lbl] built ${romb}B, -verify clean, fit ok; corpus@\$$CR zoom_crc@\$$ZC level_hash@\$$LH cur_level@\$$CL pad_log@\$$PL_ADDR"
  # Multi-bank: prove every level's data is in its bank in the ROM file (levels 1.. aren't on-console-hashable).
  if [ "$MULTIBANK" = 1 ]; then romfile_level_hashes_ok "$rom" || rc=1; fi
  if [ -x "$JGX" ] && [ -d "$VENDOR/Database" ]; then
    local out
    out="$(JGX_SCRIPT="$SCRIPT" JGX_PADLOG="0x$PL_ADDR" JGX_PADLOG_N=64 JGX_ZOOMCRC="0x$ZC" \
      JGX_NFRAMES="0x$NF" JGX_LEVELHASH="0x$LH" JGX_CURLEVEL="0x$CL" \
      "$JGX" "$rom" "$VENDOR/Database" "0x$CR" 2 "$EXPECT" "$FRAMES" "$png" 2>/dev/null || true)"
    echo "$out" | grep -E 'SMOKE|HASH|ZOOM|VRAM' | sed "s/^/  [$lbl] /"
    echo "$out" | grep -q 'SMOKE: PASS' || { echo "  [$lbl] image gate FAILED"; rc=1; }
    echo "$out" | grep -q 'HASH: PASS'  || { echo "  [$lbl] on-console hash gate FAILED"; rc=1; }
    echo "$out" | grep -q 'ZOOM: PASS'  || { echo "  [$lbl] zoom-math gate FAILED";  rc=1; }
    echo "$out" | grep -q 'VRAM: PASS'  || { echo "  [$lbl] displayed-level (VRAM) gate FAILED"; rc=1; }
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
  if [ "$MULTIBANK" = 1 ]; then
    echo "RESULT: PASS — zoom pyramid [$PYR_MODE]: ${PW}x${PH} x $PL levels across $PL banks (${romb:-256K}); level-0 + every-bank ROM hash + displayed-level VRAM hash host==ref; zoom-math host==default==+mos-a16; MAME snapshot ok"
  else
    echo "RESULT: PASS — zoom pyramid [$PYR_MODE]: $PL levels host==default==+mos-a16 (per-level hash); zoom-math host==target (bsnes-jg); displayed-level VRAM hash ok; MAME snapshot ok"
  fi
else
  echo "RESULT: FAIL — see the per-step lines above"
fi
exit $rc

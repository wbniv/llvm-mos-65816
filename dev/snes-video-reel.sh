#!/usr/bin/env bash
# Build and exercise the bounded animated SVX2 LoROM cartridge.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
CC="$BUILD/llvm-mos-install/bin/mos-clang"
CONFIG="$BUILD/install/bin/mos-snes.cfg"
TILES=${VIDEO_REEL_TILES:-$BUILD/real-video-floyd.tiles}
PALETTE=${VIDEO_REEL_PALETTE:-$BUILD/real-video-floyd.pal}
FRAMES=${VIDEO_REEL_FRAMES:-300}
CADENCE=${VIDEO_REEL_VBLANKS_PER_FRAME:-2}
HEADER="$BUILD/snes-video-reel-assets.h"
ASSET_INCLUDE="$BUILD"
ROM="$BUILD/svx2-video-reel.sfc"
MAP="$BUILD/svx2-video-reel.map"
SCREENSHOT="$BUILD/svx2-video-reel.png"
STREAM="$BUILD/snes-video-reel-stream.bin"

[ -x "$CC" ] || { echo "FATAL: missing compiler $CC"; exit 1; }
if [ -f "$TILES" ] && [ -f "$PALETTE" ]; then
  if [ "$FRAMES" -gt 4 ]; then
    python3 "$ROOT/tools/snes-video-reel-assets.py" --frames "$FRAMES" --packed-far \
      --stream-output "$STREAM" "$TILES" "$PALETTE" "$HEADER"
  else
    python3 "$ROOT/tools/snes-video-reel-assets.py" --frames "$FRAMES" \
      "$TILES" "$PALETTE" "$HEADER"
  fi
else
  HEADER="$ROOT/examples/snes/snes-video-reel-assets.h"
  ASSET_INCLUDE="$ROOT/examples/snes"
  if [ "$FRAMES" -gt 4 ]; then
    STREAM="$ROOT/assets/snes/video/svx2-full-reel.bin"
    [ -f "$STREAM" ] || { echo "FATAL: missing checked-in full reel stream"; exit 1; }
    echo "using checked-in full reel asset"
  else
    echo "using checked-in four-frame reel asset"
  fi
fi

if [ "$FRAMES" -gt 4 ]; then
  CONFIG="$BUILD/install/bin/mos-snes-hirom.cfg"
fi

"$CC" --config "$CONFIG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os -DSVC_USE_ASM \
  -DVIDEO_REEL_VBLANKS_PER_FRAME="$CADENCE" -I"$ASSET_INCLUDE" \
  -Wl,-Map="$MAP" -o "$ROM" \
  "$ROOT/examples/snes/snes-video-reel.c" \
  "$ROOT/examples/snes/snes-video-reel-fast.s" \
  "$ROOT/examples/snes/snes-video-codec.c" \
  "$ROOT/examples/snes/snes-video-dma.c" \
  "$ROOT/examples/snes/snes-video-codec-fast.s"
if [ "$FRAMES" -gt 4 ]; then
  python3 "$ROOT/tools/snes-video-pack-hirom.py" "$ROM" "$STREAM"
  python3 "$ROOT/tools/snes-checksum.py" --hirom --fastrom "$ROM" >/dev/null
else
  python3 "$ROOT/tools/snes-checksum.py" --fastrom "$ROM" >/dev/null
fi

result_vma=$(awk '$NF=="video_reel_result" {print $1; exit}' "$MAP")
loop_gate_vma=$(awk '$NF=="video_reel_loop_gate" {print $1; exit}' "$MAP")
crc_failures_vma=$(awk '$NF=="video_reel_crc_failures" {print $1; exit}' "$MAP")
deadline_slips_vma=$(awk '$NF=="video_reel_deadline_slips" {print $1; exit}' "$MAP")
presented_vma=$(awk '$NF=="video_reel_presented_total" {print $1; exit}' "$MAP")
[ -n "$result_vma" ] && [ -n "$loop_gate_vma" ] && [ -n "$crc_failures_vma" ] && \
  [ -n "$deadline_slips_vma" ] && [ -n "$presented_vma" ] || \
  { echo "FATAL: diagnostic symbols missing"; exit 1; }
result_off=$(printf '%x' "$((16#$result_vma))")
loop_gate_off=$(printf '%x' "$((16#$loop_gate_vma))")
crc_failures_off=$(printf '%x' "$((16#$crc_failures_vma))")
deadline_slips_off=$(printf '%x' "$((16#$deadline_slips_vma))")
presented_off=$(printf '%x' "$((16#$presented_vma))")
case "$CADENCE" in
  3) default_presented=109 ;;
  2) default_presented=18d ;;
  1) default_presented=319 ;;
  *) echo "FATAL: VIDEO_REEL_VBLANKS_PER_FRAME must be 1, 2, or 3"; exit 1 ;;
esac
expected_presented=${VIDEO_REEL_EXPECTED_PRESENTED:-$default_presented}
gate_frames=1200
screenshot_frame=0
if [ "$FRAMES" -gt 4 ]; then
  gate_frames=2400
  expected_presented=2cc
  screenshot_frame=115
fi
# These four contiguous bytes are result, two-loop gate, and the 16-bit
# deadline-slip count. A single emulator run therefore proves all three; CRC
# failures stop with a nonzero result before playback can satisfy the loop gate.
result_line=$($BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" "$result_off" 4 0 "$gate_frames" "$SCREENSHOT" || true)
case "$result_line" in *"got=0x00000000"*) ;; *) echo "FAIL: composite health gate: $result_line"; exit 1;; esac
presented_line=$($BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" "$presented_off" 2 "$expected_presented" "$gate_frames" || true)
case "$presented_line" in *"PASS"*) ;; *) echo "FAIL: cadence gate: $presented_line"; exit 1;; esac
if [ -f "$TILES" ] && [ -f "$PALETTE" ]; then
  python3 "$ROOT/tools/snes-video-screenshot-check.py" --frame "$screenshot_frame" \
    --video-height 192 \
    --matrix-d 75 \
    --minimum-exact 0.68 --maximum-mae 4.0 \
    "$SCREENSHOT" "$TILES" "$PALETTE"
fi
echo "$result_line"
echo "$presented_line"
echo "ROM=$ROM"

#!/usr/bin/env bash
# Build and gate the 4-frame SVX2 LoROM "first cartridge" integration fixture
# (docs/plans/2026-07-31-svx2-animated-video-cartridge.md) from tracked assets only.
#
# The fixture's input tiles have no other in-tree source: this script recovers
# the four consecutive press-site-camera frames (600..603 of the 900-frame reel)
# from the checked-in header + packed stream with
# tools/snes-video-reel-extract.py, then runs the standard dev/snes-video-reel.sh
# gate in its FRAMES<=4 LoROM configuration (32 KiB, mos-snes.cfg, bank $80
# reel_packets[] staging). Host-side: uses build/llvm-mos-install + build/jgxcheck.
#
# Usage: dev/snes-video-lorom-fixture.sh [-h|--help]
#   VIDEO_REEL_VBLANKS_PER_FRAME (default 2 = 30 fps) and VIDEO_REEL_START
#   (default 600, first reel frame of the fixture) pass through.
set -euo pipefail

case "${1-}" in
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
HEADER="$ROOT/examples/snes/snes-video-reel-assets.h"
STREAM="$ROOT/assets/snes/video/svx2-full-reel.bin"
START=${VIDEO_REEL_START:-600}
FRAMES=4
TILES="$BUILD/lorom-fixture.tiles"
PALETTE="$BUILD/lorom-fixture.pal"

[ -f "$HEADER" ] || { echo "FATAL: missing checked-in reel header $HEADER" >&2; exit 1; }
[ -f "$STREAM" ] || { echo "FATAL: missing checked-in reel stream $STREAM" >&2; exit 1; }
mkdir -p "$BUILD"

echo "==> recover fixture frames $START..$((START + FRAMES - 1)) from the checked-in reel"
PYTHONPATH="$ROOT/tools" python3 "$ROOT/tools/snes-video-reel-extract.py" \
  "$HEADER" "$STREAM" --start "$START" --frames "$FRAMES" \
  --tiles-output "$TILES" --palette-output "$PALETTE"

echo "==> build + gate the 4-frame LoROM fixture"
VIDEO_REEL_TILES="$TILES" \
VIDEO_REEL_PALETTE="$PALETTE" \
VIDEO_REEL_FRAMES="$FRAMES" \
VIDEO_REEL_FIRST_FRAMES=0 \
  "$ROOT/dev/snes-video-reel.sh"

echo "==> LoROM header + checksum"
python3 "$ROOT/tools/snes-checksum.py" --fastrom --inspect "$BUILD/svx2-video-reel.sfc"

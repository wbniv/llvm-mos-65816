#!/usr/bin/env bash
# Bake the example battery's synthetic video corpus: build/battery/corpus.{tiles,pal}.
#
# The two video demos include a *generated* asset header, so they need a tile
# corpus before they can compile. Their behavioural gates (dev/apollo-reel.sh,
# dev/snes-video-codec-bench.sh) use the recorded real-camera corpus and assert
# its SHA-256; this corpus exists only so dev/build.sh's battery keeps both demos
# COMPILING and LINKING on every `task package`. It is synthetic and seeded, so it
# needs no source video and no ffmpeg, and is identical on every machine.
#
# Idempotent: re-bakes only when an output is missing or older than its inputs.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: gen-battery-video-corpus.sh [-h|--help]

Bake the example battery's synthetic video corpus into $BUILD/battery/:
  corpus.rgb    12 frames of 80x56 RGB24  (tools/gen-battery-video-corpus.py)
  corpus.tiles  quantized tile-major frames
  corpus.pal    448-byte SNES palette

Env:
  ROOT   repo root   (default: the parent of this script's directory)
  BUILD  build tree  (default: $ROOT/build)
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; echo >&2; echo "FATAL: unexpected argument '$1'" >&2; exit 2 ;;
esac

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BUILD="${BUILD:-$ROOT/build}"
OUT="$BUILD/battery"
RGB="$OUT/corpus.rgb"
TILES="$OUT/corpus.tiles"
PAL="$OUT/corpus.pal"
GEN="$ROOT/tools/gen-battery-video-corpus.py"
PACK="$ROOT/tools/snes-video-pack.py"
FRAMES="${BATTERY_CORPUS_FRAMES:-12}"

mkdir -p "$OUT"

if [ ! -s "$RGB" ] || [ "$GEN" -nt "$RGB" ]; then
  python3 "$GEN" --frames "$FRAMES" "$RGB" >/dev/null
fi
if [ ! -s "$TILES" ] || [ ! -s "$PAL" ] || [ "$RGB" -nt "$TILES" ] || [ "$PACK" -nt "$TILES" ]; then
  python3 "$PACK" --rgb24 --tiles-output "$TILES" --palette-output "$PAL" "$RGB" >/dev/null
fi
echo "    battery video corpus: $TILES ($(stat -c%s "$TILES") bytes), $PAL"

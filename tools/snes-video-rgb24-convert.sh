#!/usr/bin/env bash
# Convert one source-video interval to the codec-corpus RGB24 format, exactly per
# docs/plans/2026-07-31-real-video-codec-corpus.md's Method step 2: retime to 30 fps
# (no optical flow), Lanczos-scale to 80x45, pad 5 black rows above + 6 below to the
# 80x56 raster, concatenated raw RGB24. Every corpus in that plan (and its successors)
# used this exact filter chain by hand; this script exists so the next one is
# reproducible instead of re-derived from prose. Feed the output straight into
# `tools/snes-video-pack.py --rgb24`.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: snes-video-rgb24-convert.sh --start SECONDS --duration SECONDS INPUT OUTPUT.rgb

  --start SECONDS     interval start, in seconds, within INPUT
  --duration SECONDS  interval length, in seconds (frame count = duration * 30)
  INPUT               source video (any ffmpeg-readable container/codec)
  OUTPUT.rgb           concatenated 80x56 row-major RGB24 frames

Frame count sanity: duration * 30 must be an integer frame count; the script
verifies the output size is an exact multiple of 80*56*3 = 13,440 bytes.
EOF
}

start=""
duration=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --start) start=$2; shift 2 ;;
    --duration) duration=$2; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

[ -n "$start" ] || { echo "FATAL: --start is required" >&2; exit 1; }
[ -n "$duration" ] || { echo "FATAL: --duration is required" >&2; exit 1; }
[ "${#args[@]}" -eq 2 ] || { echo "FATAL: expected INPUT and OUTPUT.rgb" >&2; usage >&2; exit 1; }
input=${args[0]}
output=${args[1]}
[ -f "$input" ] || { echo "FATAL: missing input $input" >&2; exit 1; }

ffmpeg -y -v error -ss "$start" -i "$input" -t "$duration" \
  -vf "fps=30,scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24" \
  -f rawvideo -pix_fmt rgb24 "$output"

size=$(stat -c%s "$output")
raster_size=$((80 * 56 * 3))
if [ $((size % raster_size)) -ne 0 ] || [ "$size" -eq 0 ]; then
  echo "FATAL: $output size $size is not a non-zero multiple of $raster_size" >&2
  exit 1
fi
echo "wrote $output: $((size / raster_size)) frames, $size bytes"

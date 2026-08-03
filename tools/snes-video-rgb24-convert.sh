#!/usr/bin/env bash
# Convert one source-video interval to the codec-corpus RGB24 format, exactly per
# docs/plans/2026-07-31-real-video-codec-corpus.md's Method step 2: select an explicit
# frame rate (no optical flow), Lanczos-scale to 80x45, pad 5 black rows above + 6 below to the
# 80x56 raster, concatenated raw RGB24. Every corpus in that plan (and its successors)
# used this exact filter chain by hand; this script exists so the next one is
# reproducible instead of re-derived from prose. Feed the output straight into
# `tools/snes-video-pack.py --rgb24`.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: snes-video-rgb24-convert.sh --start SECONDS --duration SECONDS
                                  [--fps RATE] [--crop W:H:X:Y] INPUT OUTPUT.rgb

  --start SECONDS     interval start, in seconds, within INPUT
  --duration SECONDS  interval length, in seconds (frame count = duration × rate)
  --fps RATE          output rate (default: 30); frame selection only, never interpolation.
                      Any ffmpeg rate expression works, including exact NTSC
                      fractions -- `--fps 60000/1001` (59.94) and `--fps 30000/1001`
                      (29.97) decimate a 59.94 fps master cleanly 1:1 and 2:1,
                      where a plain `--fps 30` would drop a frame every ~1000.
  --crop W:H:X:Y      ffmpeg crop spec applied BEFORE the Lanczos scale, so the
                      kept region fills the 80x45 raster instead of being shrunk
                      into it. Accepts ffmpeg expressions (iw, ih). Default: none.
  INPUT               source video (any ffmpeg-readable container/codec)
  OUTPUT.rgb          concatenated 80x56 row-major RGB24 frames

--duration also accepts a fractional value, so an exact frame count is reachable
without post-trimming: `--duration 20.02 --fps 30000/1001` yields exactly 600.

Sampling below the source rate is deliberate and is how a clip is sped up: 20 s
at --fps 15 yields 300 frames, which played back at 30 fps is 2x speed. This
matters for the SNES corpora because at 80x56 a *tracking* shot barely changes
frame to frame -- crop to the action and raise the effective speed to put real
motion in the delta stream.

Frame count sanity: the script verifies the output size is an exact multiple of
80*56*3 = 13,440 bytes.
EOF
}

start=""
duration=""
fps=30
crop=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --start) start=$2; shift 2 ;;
    --duration) duration=$2; shift 2 ;;
    --fps) fps=$2; shift 2 ;;
    --crop) crop=$2; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

[ -n "$start" ] || { echo "FATAL: --start is required" >&2; exit 1; }
[ -n "$duration" ] || { echo "FATAL: --duration is required" >&2; exit 1; }
[ "${#args[@]}" -eq 2 ] || { echo "FATAL: expected INPUT and OUTPUT.rgb" >&2; usage >&2; exit 1; }
input=${args[0]}
output=${args[1]}
[ -f "$input" ] || { echo "FATAL: missing input $input" >&2; exit 1; }

# Crop sits between the frame-rate selection and the scale: cropping first means
# the kept region is what Lanczos resamples to 80x45, rather than the whole frame
# being shrunk and the subject occupying a handful of pixels.
filter="fps=$fps"
[ -n "$crop" ] && filter="$filter,crop=$crop"
filter="$filter,scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24"
echo "filter: $filter" >&2

ffmpeg -y -v error -ss "$start" -i "$input" -t "$duration" \
  -vf "$filter" \
  -f rawvideo -pix_fmt rgb24 "$output"

size=$(stat -c%s "$output")
raster_size=$((80 * 56 * 3))
if [ $((size % raster_size)) -ne 0 ] || [ "$size" -eq 0 ]; then
  echo "FATAL: $output size $size is not a non-zero multiple of $raster_size" >&2
  exit 1
fi
echo "wrote $output: $((size / raster_size)) frames, $size bytes"

#!/usr/bin/env bash
# Reproduce and gate the mixed-cadence Artemis 2x + Apollo 59.94p ExHiROM reel.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
LAUNCH="$ROOT/assets/snes/video/Pre-launch_through_launch.webm"
RETURN="$ROOT/assets/snes/video/Return_to_Earth.webm"
APOLLO="$ROOT/assets/snes/video/apollo11-daylight-5994p.mp4"
RGB="$BUILD/artemis-apollo-60.rgb"
TILES="$BUILD/artemis-apollo-60.tiles"
PALETTE="$BUILD/artemis-apollo-60.pal"

verify() {
  local file=$1 sha=$2 rate=$3 frames=${4:-}
  [ -f "$file" ] || { echo "FATAL: missing source $file" >&2; exit 1; }
  local have actual_rate actual_frames
  have=$(sha256sum "$file" | cut -d' ' -f1)
  [ "$have" = "$sha" ] || { echo "FATAL: $file SHA-256 $have != $sha" >&2; exit 1; }
  actual_rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
    -of default=nw=1:nk=1 "$file")
  [ "$actual_rate" = "$rate" ] || { echo "FATAL: $file rate $actual_rate != $rate" >&2; exit 1; }
  if [ -n "$frames" ]; then
    actual_frames=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames \
      -of default=nw=1:nk=1 "$file")
    [ "$actual_frames" = "$frames" ] || { echo "FATAL: $file frames $actual_frames != $frames" >&2; exit 1; }
  fi
}

verify "$LAUNCH" 28f9e843111466b3ce1869975283d71a1779f593974f49d76a6da9683c769a3d 30000/1001
verify "$RETURN" bc0d89e9cf9ca33a3faa2fed6d653c9eddede0458d0ab010c228535621516dc8 30000/1001
verify "$APOLLO" 0691dda94cd0ffc9da557a3a3e5855118b8b616765f43cd470dd204eae43758f 220999/3687 600

echo "==> 1,200-frame mixed reel: Artemis source frames at 2x, Apollo source frames at 59.94p"
ffmpeg -y -v error -i "$LAUNCH" -i "$RETURN" -i "$APOLLO" -filter_complex \
  "[0:v]trim=start_frame=1049:end_frame=1349,setpts=N/(60*TB),scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24[a];\
   [1:v]trim=start_frame=1678:end_frame=1978,setpts=N/(60*TB),scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24[b];\
   [2:v]trim=start_frame=0:end_frame=600,setpts=N/(60*TB),scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24[c];\
   [a][b][c]concat=n=3:v=1:a=0[out]" \
  -map '[out]' -frames:v 1200 -fps_mode passthrough -f rawvideo -pix_fmt rgb24 "$RGB"

bytes=$(stat -c %s "$RGB")
[ "$bytes" -eq $((1200 * 80 * 56 * 3)) ] || { echo "FATAL: RGB byte count $bytes" >&2; exit 1; }

echo "==> shared 222-colour content palette; entries 0/1 reserved for HUD"
PYTHONPATH="$ROOT/tools" python3 "$ROOT/tools/snes-video-pack.py" \
  --rgb24 --dither floyd --keyframe-interval 60 \
  --tiles-output "$TILES" --palette-output "$PALETTE" \
  "$RGB" "$BUILD/artemis-apollo-60-length-prefixed.bin"

python3 -c 'from pathlib import Path
n=4480
d=Path("'"$TILES"'").read_bytes()
frames=[d[i:i+n] for i in range(0,len(d),n)]
same=[i for i in range(1,len(frames)) if frames[i] == frames[i-1]]
if len(frames) != 1200:
    raise SystemExit(f"FATAL: frames={len(frames)}")
print(f"  PASS: 1200 quantized frames; {len(set(frames))} unique; adjacent holds={same}")'

VIDEO_REEL_TILES="$TILES" \
VIDEO_REEL_PALETTE="$PALETTE" \
VIDEO_REEL_FRAMES=1200 \
VIDEO_REEL_FIRST_FRAMES=0 \
VIDEO_REEL_VBLANKS_PER_FRAME=1 \
VIDEO_REEL_KEYFRAME_INTERVAL=60 \
VIDEO_REEL_EXHIROM=1 \
VIDEO_REEL_EXHIROM_SEAM_FRAME=600 \
VIDEO_REEL_SEGMENTS='0:SVS LAUNCH / 2X|300:SVS RETURN / 2X|600:APOLLO 11 / 60P' \
VIDEO_REEL_GATE_FRAMES=3000 \
VIDEO_REEL_EXPECTED_PRESENTED=b06 \
VIDEO_REEL_MINIMUM_EXACT=0.48 \
VIDEO_REEL_MAXIMUM_MAE=12.0 \
  "$ROOT/dev/snes-video-reel.sh"

ROM="$BUILD/svx2-video-reel.sfc"
MAP="$BUILD/svx2-video-reel.map"
JGX="$BUILD/jgxcheck"
DATABASE="$ROOT/vendor/bsnes-jg/Database"
sym() {
  local value
  value=$(awk -v wanted="$1" '$NF == wanted { print $1; exit }' "$MAP")
  [ -n "$value" ] || { echo "FATAL: missing symbol $1" >&2; exit 1; }
  printf '%x' "$((16#$value))"
}
frame_off=$(sym video_reel_frame)
presented_off=$(sym video_reel_presented_total)
slips_off=$(sym video_reel_deadline_slips)
health_off=$(sym video_reel_composite_health)

python3 -c 'import re
from pathlib import Path
h=Path("'"$BUILD"'/snes-video-reel-assets.h").read_text()
m=re.search(r"reel_packet_offsets\[1201\].*?\{(.*?)\};", h, re.S)
assert m
o=[int(x) for x in re.findall(r"(\d+)ul", m.group(1))]
assert o[599] < 0x3f0000 and o[600] == 0x3f0000 and o[601] > 0x3f0000, \
       (hex(o[599]), hex(o[600]), hex(o[601]))
print(f"  PASS: ExHiROM cut offsets {o[599]:#x}, {o[600]:#x}, {o[601]:#x}")'

echo "==> exact ExHiROM cut frames"
for frame in 599 600; do
  png="$BUILD/svx2-mixed60-seam-frame${frame}.png"
  JGX_POLL=1 "$JGX" "$ROM" "$DATABASE" "$frame_off" 2 "$(printf '%x' "$frame")" 1600 "$png"
  python3 "$ROOT/tools/snes-video-screenshot-check.py" --frame "$frame" \
    --video-height 192 --matrix-d 75 --require-dashboard \
    --minimum-exact 0.40 --maximum-mae 21.0 "$png" "$TILES" "$PALETTE"
done

echo "==> deterministic transport and bidirectional seam crossings"
archive=$(find "$ROOT/vendor/bsnes-jg/objs" -name '*.a' | head -1)
[ -n "$archive" ] || { echo "FATAL: missing cached bsnes-jg archive" >&2; exit 1; }
NAV_JGX="$BUILD/jgxcheck-nav"
g++ -O2 -std=c++11 -DJGX_NAV -I"$ROOT/vendor/bsnes-jg/src" -I"$ROOT/tools" \
  -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck-nav.o"
g++ "$BUILD/jgxcheck-nav.o" "$archive" -lsamplerate -lm -o "$NAV_JGX"
JGX_SCRIPT='NONE:300,START:4,NONE:30,R:4,NONE:4,A:4,NONE:30' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$(sym video_reel_seek_decode_count)" 1 04 376
JGX_SCRIPT='NONE:300,START:4,NONE:30,R:4,NONE:4,A:4,NONE:30' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$(sym video_reel_transport_state)" 1 00 376
JGX_SCRIPT='NONE:745,RIGHT:10,NONE:20' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$frame_off" 2 027d 775
JGX_SCRIPT='NONE:795,LEFT:10,NONE:20' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$frame_off" 2 0239 825

echo "==> 9,000 exact presentations after the 178-field title"
"$JGX" "$ROM" "$DATABASE" "$presented_off" 2 2327 9177
"$JGX" "$ROM" "$DATABASE" "$slips_off" 2 0000 9177
"$JGX" "$ROM" "$DATABASE" "$health_off" 4 00000000 9177

echo "ROM=$BUILD/svx2-video-reel.sfc"

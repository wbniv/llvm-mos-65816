#!/usr/bin/env bash
# Reproduce and gate the native-60-fps XRISM ExHiROM reel.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
SOURCE="$ROOT/assets/snes/video/XRISM_360_4k_60fps_h264.mp4"
SOURCE_SHA=ce09abd9d0cea0a82bc32b53f32862e7e09dbd992178b454b3ed44d62143abd2
RGB="$BUILD/xrism-60.rgb"
TILES="$BUILD/xrism-60.tiles"
PALETTE="$BUILD/xrism-60.pal"

[ -f "$SOURCE" ] || { echo "FATAL: missing native-60 source $SOURCE" >&2; exit 1; }
have=$(sha256sum "$SOURCE" | cut -d' ' -f1)
[ "$have" = "$SOURCE_SHA" ] || {
  echo "FATAL: source SHA-256 $have != $SOURCE_SHA" >&2
  exit 1
}
rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
  -of default=nw=1:nk=1 "$SOURCE")
[ "$rate" = 60/1 ] || { echo "FATAL: source rate $rate is not 60/1" >&2; exit 1; }

echo "==> native 60 fps RGB24: three ten-second source excerpts"
ffmpeg -y -v error -i "$SOURCE" \
  -vf "select='between(n,0,599)+between(n,1200,1799)+between(n,2400,2999)',setpts=N/(60*TB),scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24" \
  -frames:v 1800 -f rawvideo -pix_fmt rgb24 "$RGB"

echo "==> shared 222-colour content palette; entries 0/1 reserved for HUD"
PYTHONPATH="$ROOT/tools" python3 "$ROOT/tools/snes-video-pack.py" \
  --rgb24 --dither floyd --keyframe-interval 60 \
  --tiles-output "$TILES" --palette-output "$PALETTE" \
  "$RGB" "$BUILD/xrism-60-length-prefixed.bin"

python3 -c 'from pathlib import Path
n=4480
d=Path("'"$TILES"'").read_bytes()
frames=[d[i:i+n] for i in range(0,len(d),n)]
same=[i for i in range(1,len(frames)) if frames[i] == frames[i-1]]
if len(frames) != 1800 or len(set(frames)) != 1800 or same:
    raise SystemExit(f"FATAL: frames={len(frames)} unique={len(set(frames))} adjacent={same[:20]}")
print("  PASS: 1800/1800 quantized frames unique; zero adjacent duplicates")'

VIDEO_REEL_TILES="$TILES" \
VIDEO_REEL_PALETTE="$PALETTE" \
VIDEO_REEL_FRAMES=1800 \
VIDEO_REEL_FIRST_FRAMES=0 \
VIDEO_REEL_VBLANKS_PER_FRAME=1 \
VIDEO_REEL_KEYFRAME_INTERVAL=60 \
VIDEO_REEL_EXHIROM=1 \
VIDEO_REEL_EXHIROM_SEAM_FRAME=1200 \
VIDEO_REEL_SEGMENTS='0:XRISM / ORBIT|600:XRISM / RESOLVE|1200:XRISM / XTEND' \
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

echo "==> exact ExHiROM seam frames"
for frame in 1199 1200; do
  want=$(printf '%x' "$frame")
  png="$BUILD/svx2-native60-seam-frame${frame}.png"
  JGX_POLL=1 "$JGX" "$ROM" "$DATABASE" "$frame_off" 2 "$want" 1600 "$png"
  python3 "$ROOT/tools/snes-video-screenshot-check.py" --frame "$frame" \
    --video-height 192 --matrix-d 75 --require-dashboard \
    --minimum-exact 0.68 --maximum-mae 4.0 "$png" "$TILES" "$PALETTE"
done

echo "==> 9,000 exact presentations after the 177-field title"
"$JGX" "$ROM" "$DATABASE" "$presented_off" 2 2328 9177
"$JGX" "$ROM" "$DATABASE" "$slips_off" 2 0000 9177
"$JGX" "$ROM" "$DATABASE" "$health_off" 4 00000000 9177

echo "==> transport replay, including both ExHiROM seam directions"
archive=$(find "$ROOT/vendor/bsnes-jg/objs" -name '*.a' | head -1)
[ -n "$archive" ] || { echo "FATAL: missing cached bsnes-jg archive" >&2; exit 1; }
NAV_JGX="$BUILD/jgxcheck-nav"
g++ -O2 -std=c++11 -DJGX_NAV -I"$ROOT/vendor/bsnes-jg/src" -I"$ROOT/tools" \
  -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck-nav.o"
g++ "$BUILD/jgxcheck-nav.o" "$archive" -lsamplerate -lm -o "$NAV_JGX"

# Pause, single-frame step, and resume: five seek-decoded frames are the exact
# result of this deterministic sequence, and the final transport state is PLAY.
JGX_SCRIPT='NONE:300,START:4,NONE:30,R:4,NONE:4,A:4,NONE:30' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$(sym video_reel_seek_decode_count)" 1 05 376
JGX_SCRIPT='NONE:300,START:4,NONE:30,R:4,NONE:4,A:4,NONE:30' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$(sym video_reel_transport_state)" 1 00 376

# The forward hold crosses frame 1200 into region B; the reverse hold crosses
# back into region A. Both must land on their exact deterministic frame with
# no deadline damage.
JGX_SCRIPT='NONE:1345,RIGHT:10,NONE:2' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$frame_off" 2 04cc 1357
JGX_SCRIPT='NONE:1345,RIGHT:10,NONE:2' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$slips_off" 2 0000 1357
JGX_SCRIPT='NONE:1395,LEFT:10,NONE:2' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$frame_off" 2 0486 1407
JGX_SCRIPT='NONE:1395,LEFT:10,NONE:2' \
  "$NAV_JGX" "$ROM" "$DATABASE" "$slips_off" 2 0000 1407

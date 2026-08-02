#!/usr/bin/env bash
# Build and exercise the bounded animated SVX2 LoROM cartridge.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
CC="$BUILD/llvm-mos-install/bin/mos-clang"
CONFIG="$BUILD/install/bin/mos-snes.cfg"
TILES=${VIDEO_REEL_TILES:-/tmp/real-shared.tiles}
PALETTE=${VIDEO_REEL_PALETTE:-/tmp/artemis-shared.pal}
FRAMES=${VIDEO_REEL_FRAMES:-300}
FIRST_TILES=${VIDEO_REEL_FIRST_TILES:-/tmp/animation-shared.tiles}
FIRST_PALETTE=${VIDEO_REEL_FIRST_PALETTE:-/tmp/artemis-shared.pal}
FIRST_FRAMES=${VIDEO_REEL_FIRST_FRAMES:-600}
CADENCE=${VIDEO_REEL_VBLANKS_PER_FRAME:-2}
KEYFRAME_INTERVAL=${VIDEO_REEL_KEYFRAME_INTERVAL:-$((60 / CADENCE))}
PROFILE=${VIDEO_REEL_PROFILE:-0}
EXHIROM=${VIDEO_REEL_EXHIROM:-0}
EXHIROM_SEAM_FRAME=${VIDEO_REEL_EXHIROM_SEAM_FRAME:-0}
SEGMENTS=${VIDEO_REEL_SEGMENTS:-}
HEADER="$BUILD/snes-video-reel-assets.h"
ASSET_INCLUDE="$BUILD"
ROM="$BUILD/svx2-video-reel.sfc"
MAP="$BUILD/svx2-video-reel.map"
SCREENSHOT="$BUILD/svx2-video-reel.png"
TRANSITION_SCREENSHOT="$BUILD/svx2-video-reel-transition.png"
CUT_ONE_SCREENSHOT="$BUILD/svx2-video-reel-cut-one.png"
CUT_TWO_SCREENSHOT="$BUILD/svx2-video-reel-cut-two.png"
STREAM="$BUILD/snes-video-reel-stream.bin"

[ -x "$CC" ] || { echo "FATAL: missing compiler $CC"; exit 1; }
combined=0
if [ -f "$TILES" ] && [ -f "$PALETTE" ] && \
   { [ "$FIRST_FRAMES" -eq 0 ] || { [ -f "$FIRST_TILES" ] && [ -f "$FIRST_PALETTE" ]; }; }; then
  if [ "$FRAMES" -gt 4 ]; then
    first_args=()
    if [ -f "$FIRST_TILES" ] && [ -f "$FIRST_PALETTE" ] && [ "$FIRST_FRAMES" -gt 0 ]; then
      first_args=(--first-tiles "$FIRST_TILES" --first-palette "$FIRST_PALETTE" --first-frames "$FIRST_FRAMES")
      combined=1
    fi
    exhirom_args=()
    if [ "$EXHIROM" = 1 ]; then
      exhirom_args=(--exhirom)
      [ "$EXHIROM_SEAM_FRAME" -gt 0 ] && \
        exhirom_args+=(--exhirom-seam-frame "$EXHIROM_SEAM_FRAME")
    fi
    segment_args=()
    if [ -z "$SEGMENTS" ] && [ "$FIRST_FRAMES" -eq 600 ] && [ "$FRAMES" -eq 300 ]; then
      SEGMENTS='0:NASA SVS / LAUNCH|300:NASA SVS / RETURN|600:PRESS-SITE CAMERA'
    elif [ -z "$SEGMENTS" ] && [ "$CADENCE" -eq 1 ] && \
         [ "$FIRST_FRAMES" -eq 1200 ] && [ "$FRAMES" -eq 600 ]; then
      SEGMENTS='0:NASA SVS / LAUNCH|600:NASA SVS / RETURN|1200:PRESS-SITE CAMERA'
    fi
    if [ -n "$SEGMENTS" ]; then
      while IFS= read -r segment; do segment_args+=(--segment "$segment"); done \
        < <(printf '%s\n' "$SEGMENTS" | tr '|' '\n')
    fi
    python3 "$ROOT/tools/snes-video-reel-assets.py" --frames "$FRAMES" --packed-far \
      --keyframe-interval "$KEYFRAME_INTERVAL" "${first_args[@]}" \
      "${exhirom_args[@]}" "${segment_args[@]}" \
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
if [ "$EXHIROM" = 1 ]; then
  CONFIG="$BUILD/install/bin/mos-snes-video-exhirom.cfg"
  if [ ! -f "$CONFIG" ]; then
    python3 "$ROOT/tools/snes-cartcanary.py" emit-platform --mapping exhirom --size 8M \
      --name snes-video-exhirom --install "$BUILD/install"
  fi
fi

profile_flags=()
if [ "$PROFILE" = 1 ]; then
  profile_flags=(-DVIDEO_REEL_PROFILE)
fi

"$CC" --config "$CONFIG" -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os -DSVC_USE_ASM \
  -DVIDEO_REEL_VBLANKS_PER_FRAME="$CADENCE" "${profile_flags[@]}" -I"$ASSET_INCLUDE" \
  -Wl,-Map="$MAP" -o "$ROM" \
  "$ROOT/examples/snes/snes-video-reel.c" \
  "$ROOT/examples/snes/snes-video-reel-fast.s" \
  "$ROOT/examples/snes/snes-video-codec.c" \
  "$ROOT/examples/snes/snes-video-dma.c" \
  "$ROOT/examples/snes/snes-video-codec-fast.s"
if [ "$EXHIROM" = 1 ]; then
  python3 "$ROOT/tools/snes-video-pack-exhirom.py" "$ROM" "$STREAM"
  python3 "$ROOT/tools/snes-checksum.py" --exhirom --fastrom "$ROM" >/dev/null
elif [ "$FRAMES" -gt 4 ]; then
  python3 "$ROOT/tools/snes-video-pack-hirom.py" "$ROM" "$STREAM"
  python3 "$ROOT/tools/snes-checksum.py" --hirom --fastrom "$ROM" >/dev/null
else
  python3 "$ROOT/tools/snes-checksum.py" --fastrom "$ROM" >/dev/null
fi

result_vma=$(awk '$NF=="video_reel_result" {print $1; exit}' "$MAP")
composite_health_vma=$(awk '$NF=="video_reel_composite_health" {print $1; exit}' "$MAP")
loop_gate_vma=$(awk '$NF=="video_reel_loop_gate" {print $1; exit}' "$MAP")
deadline_slips_vma=$(awk '$NF=="video_reel_deadline_slips" {print $1; exit}' "$MAP")
presented_vma=$(awk '$NF=="video_reel_presented_total" {print $1; exit}' "$MAP")
frame_vma=$(awk '$NF=="video_reel_frame" {print $1; exit}' "$MAP")
segment_gate_vma=$(awk '$NF=="video_reel_segment_gate" {print $1; exit}' "$MAP")
segment_vma=$(awk '$NF=="video_reel_segment" {print $1; exit}' "$MAP")
time_reset_gate_vma=$(awk '$NF=="video_reel_time_reset_gate" {print $1; exit}' "$MAP")
[ -n "$result_vma" ] && [ -n "$composite_health_vma" ] && [ -n "$loop_gate_vma" ] && \
  [ -n "$deadline_slips_vma" ] && [ -n "$presented_vma" ] && [ -n "$frame_vma" ] && \
  [ -n "$segment_gate_vma" ] && [ -n "$segment_vma" ] && [ -n "$time_reset_gate_vma" ] || \
  { echo "FATAL: diagnostic symbols missing"; exit 1; }
result_off=$(printf '%x' "$((16#$result_vma))")
composite_health_off=$(printf '%x' "$((16#$composite_health_vma))")
loop_gate_off=$(printf '%x' "$((16#$loop_gate_vma))")
deadline_slips_off=$(printf '%x' "$((16#$deadline_slips_vma))")
presented_off=$(printf '%x' "$((16#$presented_vma))")
frame_off=$(printf '%x' "$((16#$frame_vma))")
segment_gate_off=$(printf '%x' "$((16#$segment_gate_vma))")
segment_off=$(printf '%x' "$((16#$segment_vma))")
time_reset_gate_off=$(printf '%x' "$((16#$time_reset_gate_vma))")

if [ "$PROFILE" = 1 ]; then
  profile_vma=$(awk '$NF=="video_reel_profile" {print $1; exit}' "$MAP")
  [ -n "$profile_vma" ] || { echo "FATAL: profiling symbol missing"; exit 1; }
  profile_off=$(printf '%x' "$((16#$profile_vma))")
  profile_frames=$(awk '/^#define VIDEO_REEL_FRAME_COUNT / {gsub(/u/, "", $3); print $3; exit}' "$HEADER")
  profile_bytes=$((profile_frames * 3))
  profile_bin="$BUILD/svx2-video-reel-profile.bin"
  profile_json="$BUILD/svx2-video-reel-profile.json"
  vendor="$ROOT/vendor/bsnes-jg"
  if [ ! -x "$BUILD/jgxcheck" ] || [ "$ROOT/dev/jgxcheck.cpp" -nt "$BUILD/jgxcheck" ]; then
    archive=$(find "$vendor/objs" -name '*.a' | head -1)
    [ -n "$archive" ] || { echo "FATAL: missing cached bsnes-jg archive"; exit 1; }
    g++ -O2 -std=c++11 -I"$vendor/src" -I"$ROOT/tools" \
      -c "$ROOT/dev/jgxcheck.cpp" -o "$BUILD/jgxcheck.o"
    g++ "$BUILD/jgxcheck.o" "$archive" -lsamplerate -lm -o "$BUILD/jgxcheck"
  fi
fi
case "$CADENCE" in
  3) default_presented=109 ;;
  2) default_presented=18d ;;
  1) default_presented=319 ;;
  *) echo "FATAL: VIDEO_REEL_VBLANKS_PER_FRAME must be 1, 2, or 3"; exit 1 ;;
esac
expected_presented=$default_presented
gate_frames=1200
screenshot_frame=0
if [ "$FRAMES" -gt 4 ]; then
  gate_frames=2400
  expected_presented=2cc
  screenshot_frame=115
fi
if [ "$CADENCE" -eq 1 ] && [ "$FRAMES" -ge 1800 ]; then
  # Animated title plus two complete 1,800-frame loops.
  gate_frames=4000
  expected_presented=eef
fi
check_tiles=$TILES
check_palette=$PALETTE
minimum_exact=0.68
maximum_mae=4.0
if [ "$combined" = 1 ] || { [ "$FRAMES" -gt 4 ] && grep -q VIDEO_REEL_SECOND_START "$HEADER"; }; then
  gate_frames=4000
  case "$CADENCE" in
    1) expected_presented=eee ;;
    2) expected_presented=776 ;;
  esac
  screenshot_frame=108
  check_tiles=$FIRST_TILES
  check_palette=$FIRST_PALETTE
  minimum_exact=0.35
  maximum_mae=55.0
fi
expected_presented=${VIDEO_REEL_EXPECTED_PRESENTED:-$expected_presented}
# This explicit oracle replaces the old accidental adjacency of three globals.
# It becomes zero only after two loops with no result, CRC, or deadline failure.
health_off=$composite_health_off
health_bytes=4
if [ "$PROFILE" = 1 ]; then health_off=$result_off; health_bytes=1; fi
result_line=$($BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" "$health_off" "$health_bytes" 0 "$gate_frames" "$SCREENSHOT" || true)
case "$result_line" in *"PASS"*) ;; *) echo "FAIL: composite health gate: $result_line"; exit 1;; esac
if [ "$PROFILE" = 1 ]; then
  JGX_WRAM_DUMP="$profile_off" JGX_WRAM_DUMP_LEN="$profile_bytes" \
    JGX_WRAM_DUMP_FILE="$profile_bin" \
    "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" "$result_off" 1 0 \
      "$gate_frames" >/dev/null
  python3 "$ROOT/tools/snes-video-profile-report.py" "$profile_bin" \
    --frames "$profile_frames" --json "$profile_json"
  echo "PROFILE=$profile_json"
  echo "ROM=$ROM"
  exit 0
fi
presented_line=$($BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" "$presented_off" 2 "$expected_presented" "$gate_frames" || true)
case "$presented_line" in *"PASS"*) ;; *) echo "FAIL: cadence gate: $presented_line"; exit 1;; esac
time_reset_line=$(JGX_POLL=1 $BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
  "$time_reset_gate_off" 1 a5 "$gate_frames" || true)
case "$time_reset_line" in *"PASS"*) ;; *) echo "FAIL: dashboard loop-time reset: $time_reset_line"; exit 1;; esac
if grep -q VIDEO_REEL_SEGMENT_COUNT "$HEADER"; then
  segment_line=$(JGX_POLL=1 $BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
    "$segment_gate_off" 1 a5 "$gate_frames" || true)
  case "$segment_line" in *"PASS"*) ;; *) echo "FAIL: dashboard segment gate: $segment_line"; exit 1;; esac
  segment_starts=$(sed -n '/reel_segment_starts/,/};/p' "$HEADER" | tr -cd '0-9u,\n ' | \
    tail -n +2 | head -n 1 | tr -d 'u ')
  cut_one_frame=$(printf '%x' "$(($(printf '%s' "$segment_starts" | cut -d, -f2) + 10))")
  cut_two_frame=$(printf '%x' "$(($(printf '%s' "$segment_starts" | cut -d, -f3) + 10))")
  # The WRAM state is committed during NMI after the PPU has rendered that
  # field. Give the capture ten source frames of settling room so the PNG
  # contains the matching video raster and completed dashboard DMA; the WRAM
  # transition gate above remains the exact-boundary assertion.
  cut_one_line=$(JGX_POLL=1 $BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
    "$frame_off" 2 "$cut_one_frame" "$gate_frames" "$CUT_ONE_SCREENSHOT" || true)
  case "$cut_one_line" in *"PASS"*) ;; *) echo "FAIL: first dashboard cut: $cut_one_line"; exit 1;; esac
  cut_two_line=$(JGX_POLL=1 $BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
    "$frame_off" 2 "$cut_two_frame" "$gate_frames" "$CUT_TWO_SCREENSHOT" || true)
  case "$cut_two_line" in *"PASS"*) ;; *) echo "FAIL: second dashboard cut: $cut_two_line"; exit 1;; esac
fi
if [ "$combined" = 1 ]; then
  screenshot_line=$(JGX_POLL=1 "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
    "$frame_off" 2 6c 4000 "$SCREENSHOT" || true)
  case "$screenshot_line" in *"PASS"*) ;; *) echo "FAIL: screenshot rendezvous: $screenshot_line"; exit 1;; esac
elif [ "$FRAMES" -gt 4 ]; then
  screenshot_want=$(printf '%x' "$screenshot_frame")
  screenshot_line=$(JGX_POLL=1 "$BUILD/jgxcheck" "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
    "$frame_off" 2 "$screenshot_want" "$gate_frames" "$SCREENSHOT" || true)
  case "$screenshot_line" in *"PASS"*) ;; *) echo "FAIL: screenshot rendezvous: $screenshot_line"; exit 1;; esac
fi
if [ -f "$check_tiles" ] && [ -f "$check_palette" ]; then
  python3 "$ROOT/tools/snes-video-screenshot-check.py" --frame "$screenshot_frame" \
    --video-height 192 \
    --matrix-d 75 \
    --require-dashboard \
    --minimum-exact "$minimum_exact" --maximum-mae "$maximum_mae" \
    "$SCREENSHOT" "$check_tiles" "$check_palette"
fi
if [ "$combined" = 1 ]; then
  transition_target=$((FIRST_FRAMES + 100))
  transition_want=$(printf '%x' "$transition_target")
  transition_line=$(JGX_POLL=1 $BUILD/jgxcheck "$ROM" "$ROOT/vendor/bsnes-jg/Database" \
    "$frame_off" 2 "$transition_want" 3000 "$TRANSITION_SCREENSHOT" || true)
  case "$transition_line" in *"PASS"*) ;; *) echo "FAIL: real-video transition: $transition_line"; exit 1;; esac
  python3 "$ROOT/tools/snes-video-screenshot-check.py" --frame 100 --video-height 192 \
    --matrix-d 75 --require-dashboard --minimum-exact 0.65 --maximum-mae 3.0 \
    "$TRANSITION_SCREENSHOT" "$TILES" "$PALETTE"
  echo "$transition_line"
fi
echo "$result_line"
echo "$presented_line"
echo "ROM=$ROM"

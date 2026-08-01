#!/usr/bin/env bash
# Measure representative codec throughput in a fixed 120-frame bsnes-jg window.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
CC="$BUILD/llvm-mos-install/bin/mos-clang"
CONFIG="$INSTALL/bin/mos-snes.cfg"
JGX="$BUILD/jgxcheck"
DATABASE="$ROOT/vendor/bsnes-jg/Database"
TILES=${VIDEO_BENCH_TILES:-$BUILD/real-video-floyd.tiles}
FRAMES=${VIDEO_BENCH_FRAMES:-120}
HEADER="$BUILD/snes-video-bench-assets.h"
PALETTE=${VIDEO_BENCH_PALETTE:-}
ASM_DEFINE=()
[ "${VIDEO_BENCH_ASM:-0}" = 1 ] && ASM_DEFINE=(-DSVC_USE_ASM)
PIPELINE_DEFINE=()
[ "${VIDEO_BENCH_PIPELINE:-0}" = 1 ] && PIPELINE_DEFINE=(-DVIDEO_BENCH_PIPELINE)
FASTROM_DEFINE=()
[ "${VIDEO_BENCH_FASTROM:-0}" = 1 ] && FASTROM_DEFINE=(-DVIDEO_BENCH_FASTROM)
STREAM_FRAMES=${VIDEO_BENCH_STREAM_FRAMES:-120}
STREAM_START=${VIDEO_BENCH_STREAM_START:-0}
STREAM_BIN="$BUILD/snes-video-bench-stream.bin"
# Warmup VBlanks skipped before the timed window opens. In stream mode this
# covers the whole-loop byte-correctness pass, so the reported count is pure
# steady state rather than steady state diluted by validation.
WARMUP=${VIDEO_BENCH_WARMUP:-1200}
STREAM_DEFINE=()
[ "${VIDEO_BENCH_STREAM:-0}" = 1 ] && STREAM_DEFINE=(-DVIDEO_BENCH_STREAM)
VISIBLE_DEFINE=()
if [ "${VIDEO_BENCH_VISIBLE:-0}" = 1 ]; then
  [ -n "$PALETTE" ] && [ -f "$PALETTE" ] || {
    echo "FATAL: VIDEO_BENCH_VISIBLE=1 requires VIDEO_BENCH_PALETTE=<448-byte .pal>"; exit 1;
  }
  VISIBLE_DEFINE=(-DVIDEO_BENCH_VISIBLE)
fi

[ -x "$CC" ] || { echo "FATAL: missing $CC"; exit 1; }
[ -f "$CONFIG" ] || { echo "FATAL: missing $CONFIG"; exit 1; }
[ -x "$JGX" ] || { echo "FATAL: missing $JGX"; exit 1; }
[ -f "$TILES" ] || { echo "FATAL: missing tile corpus $TILES"; exit 1; }

asset_args=()
[ -n "$PALETTE" ] && asset_args=(--palette "$PALETTE")
if [ "${VIDEO_BENCH_STREAM:-0}" = 1 ]; then
  asset_args+=(--stream-frames "$STREAM_FRAMES" --stream-start "$STREAM_START" \
               --stream-output "$STREAM_BIN")
  # The packed stream lives at HiROM bank $C1, so the runtime must be linked
  # for HiROM. FastROM is orthogonal and still selected by VIDEO_BENCH_FASTROM.
  CONFIG="$INSTALL/bin/mos-snes-hirom.cfg"
  [ -f "$CONFIG" ] || { echo "FATAL: missing $CONFIG"; exit 1; }
fi
python3 "$ROOT/tools/snes-video-bench-assets.py" "${asset_args[@]}" "$TILES" "$HEADER"

names=(svx-median svx-worst svc-median svc-worst lzss-median lzss-worst raw-copy svx-keyframe)
if [ "${VIDEO_BENCH_STREAM:-0}" = 1 ]; then
  names=(svx-stream)
  cases=${VIDEO_BENCH_CASES:-0}
  printf '%-13s %10s %12s\n' case frames "decodes/$FRAMES"
else
  printf '%-13s %10s %12s\n' case packet_B decodes
  cases=${VIDEO_BENCH_CASES:-"0 1 2 3 4 5 6 7"}
fi
for case_id in $cases; do
  name=${names[$case_id]}
  rom="$BUILD/video-bench-$name.sfc"
  map="$BUILD/video-bench-$name.map"
  "$CC" --config "$CONFIG" -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Os \
    "${ASM_DEFINE[@]}" "${PIPELINE_DEFINE[@]}" "${FASTROM_DEFINE[@]}" \
    "${VISIBLE_DEFINE[@]}" \
    "${STREAM_DEFINE[@]}" -DVIDEO_BENCH_CASE="$case_id" -I"$BUILD" \
    -Wl,-Map="$map" -o "$rom" \
    "$ROOT/examples/snes/snes-video-codec-bench.c" \
    "$ROOT/examples/snes/snes-video-codec.c" \
    "$ROOT/examples/snes/snes-video-stream.c" \
    "$ROOT/examples/snes/snes-video-dma.c" \
    "$ROOT/examples/snes/snes-video-codec-bench-fast.s" \
    "$ROOT/examples/snes/snes-video-codec-fast.s"
  checksum_args=()
  [ "${VIDEO_BENCH_FASTROM:-0}" = 1 ] && checksum_args=(--fastrom)
  if [ "${VIDEO_BENCH_STREAM:-0}" = 1 ]; then
    python3 "$ROOT/tools/snes-video-pack-hirom.py" "$rom" "$STREAM_BIN" >/dev/null
    checksum_args+=(--hirom)
  fi
  python3 "$ROOT/tools/snes-checksum.py" "${checksum_args[@]}" "$rom" >/dev/null

  status_vma=$(awk '$NF=="corpus_result" {print $1; exit}' "$map")
  iters_vma=$(awk '$NF=="video_bench_iters" {print $1; exit}' "$map")
  [ -n "$status_vma" ] && [ -n "$iters_vma" ] || { echo "FATAL: benchmark symbols missing"; exit 1; }
  status_off=$(printf '%x' "$((16#$status_vma))")
  iters_off=$(printf '%x' "$((16#$iters_vma))")
  read_iters() { # frame_budget -> decimal iteration count
    local line hex
    line=$($JGX "$rom" "$DATABASE" "$iters_off" 4 0 "$1" || true)
    hex=$(printf '%s\n' "$line" | sed -n 's/.*got=0x\([0-9A-Fa-f]*\).*/\1/p')
    [ -n "$hex" ] || { echo "FAIL $name: cannot parse iterations: $line" >&2; return 1; }
    printf '%d\n' "$((16#$hex))"
  }

  if [ "${VIDEO_BENCH_STREAM:-0}" = 1 ]; then
    # corpus_result is only cleared once the whole-loop byte-correctness pass has
    # run, so checking it at the warmup mark also proves validation completed.
    status_line=$($JGX "$rom" "$DATABASE" "$status_off" 1 0 "$WARMUP" || true)
    case "$status_line" in
      *"got=0x00"*) ;;
      *) echo "FAIL $name: correctness gate at $WARMUP VBlanks: $status_line"; exit 1;;
    esac
    warm=$(read_iters "$WARMUP") || exit 1
    total=$(read_iters "$((WARMUP + FRAMES))") || exit 1
    printf '%-13s %10s %12d\n' "$name" "$STREAM_FRAMES" "$((total - warm))"
  else
    status_line=$($JGX "$rom" "$DATABASE" "$status_off" 1 0 "$FRAMES" || true)
    case "$status_line" in *"got=0x00"*) ;; *) echo "FAIL $name: $status_line"; exit 1;; esac
    iters=$(read_iters "$FRAMES") || exit 1
    packet_size=$(awk '/#define VIDEO_BENCH_PACKET_SIZE/ {print $3; exit}' <(cpp -dM -DVIDEO_BENCH_CASE="$case_id" "$HEADER" 2>/dev/null))
    packet_size=${packet_size%u}
    printf '%-13s %10s %12d\n' "$name" "$packet_size" "$iters"
  fi
done

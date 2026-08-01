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
python3 "$ROOT/tools/snes-video-bench-assets.py" "${asset_args[@]}" "$TILES" "$HEADER"

names=(svx-median svx-worst svc-median svc-worst lzss-median lzss-worst raw-copy)
printf '%-13s %10s %12s\n' case packet_B decodes
cases=${VIDEO_BENCH_CASES:-"0 1 2 3 4 5 6"}
for case_id in $cases; do
  name=${names[$case_id]}
  rom="$BUILD/video-bench-$name.sfc"
  map="$BUILD/video-bench-$name.map"
  "$CC" --config "$CONFIG" -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Os \
    "${ASM_DEFINE[@]}" "${PIPELINE_DEFINE[@]}" "${FASTROM_DEFINE[@]}" \
    "${VISIBLE_DEFINE[@]}" \
    -DVIDEO_BENCH_CASE="$case_id" -I"$BUILD" \
    -Wl,-Map="$map" -o "$rom" \
    "$ROOT/examples/snes/snes-video-codec-bench.c" \
    "$ROOT/examples/snes/snes-video-codec.c" \
    "$ROOT/examples/snes/snes-video-stream.c" \
    "$ROOT/examples/snes/snes-video-dma.c" \
    "$ROOT/examples/snes/snes-video-codec-bench-fast.s" \
    "$ROOT/examples/snes/snes-video-codec-fast.s"
  checksum_args=()
  [ "${VIDEO_BENCH_FASTROM:-0}" = 1 ] && checksum_args=(--fastrom)
  python3 "$ROOT/tools/snes-checksum.py" "${checksum_args[@]}" "$rom" >/dev/null

  status_vma=$(awk '$NF=="corpus_result" {print $1; exit}' "$map")
  iters_vma=$(awk '$NF=="video_bench_iters" {print $1; exit}' "$map")
  [ -n "$status_vma" ] && [ -n "$iters_vma" ] || { echo "FATAL: benchmark symbols missing"; exit 1; }
  status_off=$(printf '%x' "$((16#$status_vma))")
  iters_off=$(printf '%x' "$((16#$iters_vma))")
  status_line=$($JGX "$rom" "$DATABASE" "$status_off" 1 0 "$FRAMES" || true)
  case "$status_line" in *"got=0x00"*) ;; *) echo "FAIL $name: $status_line"; exit 1;; esac
  iter_line=$($JGX "$rom" "$DATABASE" "$iters_off" 4 0 "$FRAMES" || true)
  iter_hex=$(printf '%s\n' "$iter_line" | sed -n 's/.*got=0x\([0-9A-Fa-f]*\).*/\1/p')
  [ -n "$iter_hex" ] || { echo "FAIL $name: cannot parse iterations: $iter_line"; exit 1; }
  packet_size=$(awk '/#define VIDEO_BENCH_PACKET_SIZE/ {print $3; exit}' <(cpp -dM -DVIDEO_BENCH_CASE="$case_id" "$HEADER" 2>/dev/null))
  packet_size=${packet_size%u}
  printf '%-13s %10s %12d\n' "$name" "$packet_size" "$((16#$iter_hex))"
done

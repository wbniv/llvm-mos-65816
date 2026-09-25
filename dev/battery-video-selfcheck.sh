#!/usr/bin/env bash
# dev/battery-video-selfcheck.sh — do the example battery's two VIDEO ROMs actually play?
#
# The battery-post markers pack each decoder's SVX2 stream into the ROM after
# linking. Playback requires those bytes at the bank named by the asset header.
# Check their presence separately from the title and playback entropy checks.
#
# WHAT IT ASSERTS, per ROM (host-side):
#   1. stream present — the ROM's bytes at the stream's HiROM file offset (derived from the header's
#      VIDEO_REEL_HIROM_BASE_BANK) equal the packed stream the header was generated with. Deterministic,
#      and the leg that pins the actual defect. (The ROMs' own playback-health words are NOT used: with
#      no boot-time self-test they mean "looped twice", which a stream-less a16 build also satisfies.)
#   2. unless --no-entropy, dev/title-entropy.sh at frames 60,100,200 (title, handoff, playback) — the
#      behavioural symptom, via bsnes-jg / build/jgxcheck.
#
# Usage: dev/battery-video-selfcheck.sh [--build DIR] [--runs N] [--no-entropy] [-h|--help]
#   --build DIR    where the battery wrote <demo>.sfc and battery/<demo>/ (default: <repo>/build)
#   --runs N       entropy-1 runs per frame for the title-entropy leg (default 8)
#   --no-entropy   stream leg only
set -euo pipefail

usage() { sed -n '2,/^set -euo pipefail/{ /^#/s/^# \{0,1\}//p; }' "$0"; }

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
RUNS=8
ENTROPY=1
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0;;
    --build)      BUILD=$2; shift 2;;
    --runs)       RUNS=$2; shift 2;;
    --no-entropy) ENTROPY=0; shift;;
    *) echo "battery-video-selfcheck: unknown argument $1" >&2; exit 2;;
  esac
done

# demo | asset header | packed stream — the same pair each demo's battery-prep/battery-post uses.
DEMOS=(
  "apollo-reel|$BUILD/battery/apollo-reel/apollo-reel-assets.h|$BUILD/battery/apollo-reel/apollo-reel-stream.bin"
  "snes-video-reel|$ROOT/examples/snes/snes-video-reel-assets.h|$ROOT/assets/snes/video/svx2-full-reel.bin"
)

fail=0
for spec in "${DEMOS[@]}"; do
  IFS='|' read -r demo header stream <<<"$spec"
  rom="$BUILD/$demo.sfc"
  for f in "$rom" "$header" "$stream"; do
    [ -f "$f" ] || { echo "  $demo: FAIL — missing $f (run the battery: dev/run.sh build)"; fail=1; continue 2; }
  done
  bank=$(sed -n 's/^#define VIDEO_REEL_HIROM_BASE_BANK \(0x[0-9a-fA-F]*\)u*$/\1/p' "$header" | head -1 || true)
  [ -n "$bank" ] || { echo "  $demo: FAIL — no VIDEO_REEL_HIROM_BASE_BANK in $header"; fail=1; continue; }
  foff=$(( (bank - 0xc0) << 16 ))
  size=$(stat -c%s "$stream")
  if cmp -s -n "$size" -i "$foff:0" "$rom" "$stream"; then
    printf '  %s: PASS  stream present — %d bytes at file $%06X == %s\n' "$demo" "$size" "$foff" "${stream#"$ROOT"/}"
  else
    printf '  %s: FAIL  stream ABSENT — file $%06X (+%d bytes) != %s (ROM is %d bytes)\n' \
      "$demo" "$foff" "$size" "${stream#"$ROOT"/}" "$(stat -c%s "$rom")"
    fail=1
  fi
  if [ "$ENTROPY" = 1 ]; then
    if "$ROOT/dev/title-entropy.sh" "$rom" --runs "$RUNS" --frames 60,100,200 | sed 's/^/    /'; then :
    else fail=1; fi
  fi
done

[ "$fail" -eq 0 ] && echo "BATTERY-VIDEO-SELFCHECK: PASS" || echo "BATTERY-VIDEO-SELFCHECK: FAIL"
exit "$fail"

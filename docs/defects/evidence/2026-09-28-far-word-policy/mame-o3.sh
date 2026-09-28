#!/usr/bin/env bash
set -euo pipefail
source /work/dev/_emu.sh
require_bios
export SMOKE_SETTLE=600 SMOKE_SECONDS=15
cd /work/.scratch/far-word-policy/runs
for variant in baseline default; do
  for mode in a16 xy16; do
    stem="$variant-farblit-$mode-O3"
    run_assert "$PWD/$stem.sfc" "$PWD/$stem.map" corpus_result 0x1E56EE65 > "$stem-mame.log"
    cat "$stem-mame.log"
    cp "/tmp/mame-scratch/assert-$stem.sfc.log" "$stem-mame-raw.log"
  done
done

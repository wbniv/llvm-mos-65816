#!/usr/bin/env bash
set -euo pipefail
source /work/dev/_emu.sh
require_bios
export SMOKE_SETTLE=600 SMOKE_SECONDS=15
cd /work/.scratch/farblit-payoff/runs
mame -version > mame-version.log
for mode in a16 xy16; do
  for variant in baseline range both; do
    stem="$variant-$mode"
    run_assert "$PWD/$stem.sfc" "$PWD/$stem.map" corpus_result 0x1E56EE65 > "$stem-mame.log"
    cat "$stem-mame.log"
    cp "/tmp/mame-scratch/assert-$stem.sfc.log" "$stem-mame-raw.log"
  done
  for variant in baseline both; do
    for fixture in bounds pressure; do
      stem="$fixture-$variant-$mode"
      expected=0xC9276F1E
      if [ "$fixture" = pressure ]; then expected=0xD695; fi
      run_assert "$PWD/$stem.sfc" "$PWD/$stem.map" corpus_result "$expected" > "$stem-mame.log"
      cat "$stem-mame.log"
      cp "/tmp/mame-scratch/assert-$stem.sfc.log" "$stem-mame-raw.log"
    done
  done
done

#!/usr/bin/env bash
set -euo pipefail
source /work/dev/_emu.sh
require_bios
export SMOKE_SETTLE=600 SMOKE_SECONDS=15
cd /work/.scratch/farblit-range-integration/runs
mame -version > mame-version.log
for variant in baseline candidate; do
  for fixture in farblit farblit_press bounds; do
    case "$fixture" in
      farblit) expected=0x1E56EE65 ;;
      farblit_press) expected=0xD695 ;;
      bounds) expected=0xC9276F1E ;;
    esac
    for mode in a16 xy16; do
      for opt in Os Oz O2; do
        stem="$variant-$fixture-$mode-$opt"
        run_assert "$PWD/$stem.sfc" "$PWD/$stem.map" corpus_result "$expected" > "$stem-mame.log"
        echo "$stem $(cat "$stem-mame.log")"
        cp "/tmp/mame-scratch/assert-$stem.sfc.log" "$stem-mame-raw.log"
      done
    done
  done
done

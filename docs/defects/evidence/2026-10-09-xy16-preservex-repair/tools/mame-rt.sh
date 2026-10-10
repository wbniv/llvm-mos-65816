#!/usr/bin/env bash
# Run before/after ROMs of a program through the MAME leg (dev/_emu.sh run_assert).
# usage (inside wrap.sh): mame-rt.sh DIR NAME WANT FRAMES
set -uo pipefail
case "${1-}" in -h|--help|"") sed -n 2,3p "$0"; exit 0;; esac
ulimit -c 0
export PATH=/usr/games:$PATH
ROOT=/work
. /work/dev/_emu.sh
require_bios || exit 2
for v in before after; do
  echo "== $2 $v $(sha256sum $1/$2-$v.sfc | cut -c1-16)"
  SMOKE_SETTLE=$4 SMOKE_SECONDS=30 run_assert $1/$2-$v.sfc $1/$2-$v.map corpus_result $3
  echo "run_assert rc=$?"
done

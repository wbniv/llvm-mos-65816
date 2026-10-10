#!/usr/bin/env bash
# Run each before/after truchet ROM through the MAME leg (dev/_emu.sh run_assert).
# Run inside wrap.sh so /work is the repository.
set -uo pipefail
case "${1-}" in -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ulimit -c 0
export PATH=/usr/games:$PATH
ROOT=/work
. /work/dev/_emu.sh
require_bios || exit 2
for v in before after; do
  echo "== $v $(sha256sum /work/build/xy16px/truchet/$v.sfc | cut -c1-16)"
  SMOKE_SETTLE=800 SMOKE_SECONDS=20 run_assert /work/build/xy16px/truchet/$v.sfc /work/build/xy16px/truchet/$v.map corpus_result 0xB3E6
  echo "run_assert rc=$?"
done

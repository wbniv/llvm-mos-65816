#!/usr/bin/env bash
# dev/smoke.sh — quick liveness check: boot build/hello.sfc in MAME headless and assert
# `sentinel == 0x42` in WRAM. The full corpus (dev/run.sh corpus) is the correctness
# baseline; this is the fast single-ROM check. Runs INSIDE the dev container
# (/work = repo root); drive from the host with: dev/run.sh smoke.
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh smoke   # boots build/hello.sfc in MAME, asserts sentinel==0x42"
  echo "Env: SMOKE_WANT (default 0x42), SMOKE_SETTLE (frames before sampling, default 60)"
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
. "$ROOT/dev/_emu.sh"

ROM="$ROOT/build/hello.sfc"
MAP="$ROOT/build/hello.map"
[ -f "$ROM" ] || { echo "no $ROM — run 'dev/run.sh build' first"; exit 1; }
[ -f "$MAP" ] || { echo "no $MAP — run 'dev/run.sh build' first"; exit 1; }

require_bios || exit $?

echo "==> MAME version: $(mame -version 2>/dev/null | head -1 || echo '?')"
echo "==> smoke: $(basename "$ROM")  symbol=sentinel  expect=${SMOKE_WANT:-0x42}"

if run_assert "$ROM" "$MAP" sentinel "${SMOKE_WANT:-0x42}"; then
  echo "==> smoke PASS"
  exit 0
fi
echo "==> smoke FAIL"
exit 1

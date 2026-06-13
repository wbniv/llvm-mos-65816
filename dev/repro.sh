#!/usr/bin/env bash
# dev/repro.sh — clean-room reproducibility gate (HOST side; not run in-container).
#
# Proves the bench rebuilds from a fresh checkout with NO local machine state. It
# exports the committed HEAD into a temp dir (so build/, vendor/, dev/roms/, and any
# uncommitted edits are excluded), supplies the gitignored SPC700 IPL, then runs the
# full build + corpus from there. This catches "works on my machine" drift that
# `dev/run.sh corpus` can hide — that reuses your existing build/ artifacts and Docker
# image cache, this does not. It's the local stand-in for CI; the GitHub workflow is
# parked at manual-only until the repo goes public/upstream.
#
# Usage: dev/run.sh repro
# Env:   SNES_SPC700_ROM  source path of the IPL (default: dev/roms/s_smp/spc700.rom)
set -euo pipefail

usage() { echo "Usage: dev/run.sh repro   # clean-room: export HEAD, build + smoke from scratch"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
BIOS_SRC="${SNES_SPC700_ROM:-$ROOT/dev/roms/s_smp/spc700.rom}"

if [ ! -f "$BIOS_SRC" ]; then
  echo "need the SPC700 IPL at $BIOS_SRC (gitignored; see README). Override with SNES_SPC700_ROM=<path>."
  exit 2
fi

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "==> clean checkout: git archive HEAD -> $WORK (committed files only)"
git -C "$ROOT" archive --format=tar HEAD | tar -x -C "$WORK"

echo "==> supply the gitignored SPC700 IPL into the clean tree"
mkdir -p "$WORK/dev/roms/s_smp"
cp "$BIOS_SRC" "$WORK/dev/roms/s_smp/spc700.rom"

echo "==> build from the clean checkout (vendors llvm-mos-sdk fresh)"
"$WORK/dev/run.sh" build

echo "==> corpus from the clean checkout"
"$WORK/dev/run.sh" corpus

echo "==> repro OK — bench rebuilt + corpus green from a clean HEAD checkout, no local state"

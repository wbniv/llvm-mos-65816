#!/usr/bin/env bash
# dev/fuzz.sh — #321 Tier-1 differential +mos-a16 fuzzer (runs INSIDE the dev container).
#
# Generates N random, strictly-well-defined C programs (seeded for reproducibility)
# over a handful of 16/8-bit volatile + local variables and the +mos-a16 operator
# set, compiles each DEFAULT (trusted 8-bit reference) and +mos-a16, and asserts:
#     host-expected == default@MAME == a16@MAME == a16@bsnes-jg
# plus a clean `-mllvm -verify-machineinstrs` on the +mos-a16 build (the
# register-coalescer-crash detector that gates Tier-2 A16-threading). Mismatches /
# crashes are saved to build/fuzz-triage/ with a minimal repro line.
#
# The generator + driver live in tools/a16_fuzz.py. Drive from host:
#   dev/run.sh fuzz [N] [seed]      # default: 25 programs from seed 1
#   dev/run.sh fuzz 1 1234          # reproduce a single failing seed
# Prereqs: from-source toolchain (dev/run.sh toolchain) + SDK; bsnes-jg leg reuses
# build/jgxcheck (dev/run.sh xcheck) when present, else SKIPs that one emulator.
# See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh fuzz [N] [seed]   # N differential programs from seed; host==default==a16 on both emulators"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$ROOT/build/install/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$ROOT/build/llvm-mos-install dev/run.sh build)"; exit 1; }

# MAME's snes driver needs the SPC700 IPL ROM; reuse the shared prereq check.
source "$ROOT/dev/_emu.sh"
require_bios || exit $?

N="${1:-25}"
SEED="${2:-1}"
EXTRA=()
[ -x "$ROOT/build/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ] || EXTRA+=(--no-bsnes)

exec python3 "$ROOT/tools/a16_fuzz.py" run --count "$N" --seed "$SEED" "${EXTRA[@]}"

#!/usr/bin/env bash
# dev/known-issues.sh — XPASS guard for the deferred KNOWN_ISSUES defects.
#
# Asserts every tools/a16_fuzz.py KNOWN_ISSUE_REPROS file STILL crashes -verify-machineinstrs
# under BOTH +mos-a16 and +mos-xy16 with its expected signature. The instant a repro verifies
# CLEAN (the upstream/RA bug got fixed) the guard FAILS loudly with the exact follow-up: drop the
# KNOWN_ISSUES entry (so the signature hard-FAILs again, not silently XFAILs a future regression)
# and promote the repro to a positive differential gate.
#
# Pure host verify — needs ONLY the from-source toolchain (no SDK, no emulator, no SPC700 IPL),
# so it runs unconditionally (CI: no secret gate). Runs INSIDE the dev container; drive from the
# host: dev/run.sh known-issues. Build the toolchain first (dev/run.sh toolchain).
set -euo pipefail

usage() { echo "Usage: dev/run.sh known-issues   # assert each KNOWN_ISSUES repro still crashes verify (XPASS guard)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }

exec env FUZZ_ROOT="$ROOT" python3 "$ROOT/tools/a16_fuzz.py" known-issues

#!/usr/bin/env bash
# dev/torture.sh — run in-scope gcc c-torture/execute tests through the +mos-a16/+mos-xy16
# differential gate (Phase 1). DEFAULT build is the oracle: default == +mos-a16 == +mos-xy16
# on MAME (+ +mos-a16 on bsnes-jg); a test whose DEFAULT build doesn't self-check PASS is
# SKIP'd (target-inappropriate), so any FAIL is a real #321 defect. Runs INSIDE the dev
# container; drive from host: dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--no-bsnes].
# Prereqs: dev/fetch-torture.sh + tools/torture_filter.py (inscope.tsv) on the host, plus a
# built toolchain + SDK. See docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md.
set -euo pipefail

usage() {
  echo "Usage: dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--sample N [--sample-seed S]] [--no-bsnes]"
  echo "  Differential-test in-scope c-torture tests (default: first N=30)."
  echo "  --sample N picks a seeded pseudo-random subset of N tests (reproducible; overrides N/--start)."
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
INSCOPE="$ROOT/examples/65816/torture/inscope.tsv"
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$ROOT/build/install/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: dev/run.sh build)"; exit 1; }
[ -f "$INSCOPE" ] || { echo "FATAL: no $INSCOPE (run on host: dev/fetch-torture.sh && python3 tools/torture_filter.py)"; exit 1; }
[ -d "$ROOT/vendor/c-torture/execute" ] || { echo "FATAL: no vendor/c-torture/execute (run on host: dev/fetch-torture.sh)"; exit 1; }

source "$ROOT/dev/_emu.sh"
require_bios || exit $?

NOBSNES=(); { [ -x "$ROOT/build/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; } || NOBSNES=(--no-bsnes)
exec python3 "$ROOT/tools/torture_run.py" "$@" "${NOBSNES[@]}"

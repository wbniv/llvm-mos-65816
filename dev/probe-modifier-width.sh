#!/usr/bin/env bash
# dev/probe-modifier-width.sh — sweep every (cpu x instruction-shape x modifier x
# operand) combination through llvm-mc and record the chosen encoding as JSON.
#
# Evidence tool for the "explicit mos16(constant) selects a zero-page opcode"
# defect (MOSOperand::isImmInRange). Run it once against the pre-fix assembler
# and once against the fixed one, then `--diff` the two JSON files: every row
# whose encoding changed is a row the fix is responsible for.
#
# Usage:
#   dev/probe-modifier-width.sh OUT.json [--mc PATH_TO_LLVM_MC]
#   dev/probe-modifier-width.sh --diff BASELINE.json FIXED.json
#
# Runs on the HOST against an already-built llvm-mc (default:
# build/llvm-mos-install/bin/llvm-mc). No container needed.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: dev/probe-modifier-width.sh OUT.json [--mc PATH]
       dev/probe-modifier-width.sh --diff BASELINE.json FIXED.json

Sweep llvm-mc over every (cpu x instruction shape x modifier x operand)
combination and record the selected encoding, so a parser width change can be
measured instead of predicted.

  OUT.json   where to write the sweep
  --mc PATH  llvm-mc to probe (default build/llvm-mos-install/bin/llvm-mc)
  --diff     compare two sweeps; prints only the rows whose encoding changed
USAGE
  exit 0
}

[ $# -eq 0 ] && usage
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1-}" = "--diff" ]; then
  [ $# -eq 3 ] || { echo "FATAL: --diff needs BASELINE.json FIXED.json" >&2; exit 2; }
  exec python3 "$ROOT/tools/probe_modifier_width.py" --diff "$2" "$3"
fi

OUT="$1"; shift
MC="$ROOT/build/llvm-mos-install/bin/llvm-mc"
while [ $# -gt 0 ]; do
  case "$1" in
    --mc) MC="$2"; shift 2 ;;
    *) echo "FATAL: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -x "$MC" ] || { echo "FATAL: no llvm-mc at $MC" >&2; exit 1; }

exec python3 "$ROOT/tools/probe_modifier_width.py" --mc "$MC" --out "$OUT"

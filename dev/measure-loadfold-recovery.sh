#!/usr/bin/env bash
# dev/measure-loadfold-recovery.sh — Phase-1 GATE for
#   docs/plans/2026-06-20-321-unify-loadfold-gate-aa-volatile.md
#
# Counts the load-folds the proposed UNIFIED gate would RECOVER vs today's two split
# gates, using a throwaway INSTRUMENTED mos-clang (probe-patched MOSInstructionSelector
# on a throwaway worktree — see the plan §Phase 1):
#
#   Probe A (LOADFOLD-PROBE-A) — noStoreBetween bails on an intervening store that AA
#       proves does NOT alias the load: a fold AA-precision would recover
#       (16-bit value-side: foldableAbsLoad16 / foldableIndirLoad16).
#   Probe B (LOADFOLD-PROBE-B) — shouldFoldMemAccess bails on a SINGLE-USE volatile
#       load that otherwise passes the whole gate: a fold the volatile-drop would
#       recover (upstream 8-bit folds + the 16-bit store-side loadStoreValueIntoA16).
#
# Compile-only on the host (no emulator, no QUIET-box rule). The probes LOG-AND-BAIL,
# so codegen is unchanged — this only counts. Decision gate (per the plan): both
# totals ~0 across the corpora => unification DEFER-confirmed (nothing to recover).
#
# Usage: CLANG=<instrumented mos-clang> [CTORTURE_DIR=...] dev/measure-loadfold-recovery.sh [N_TORTURE]
set -euo pipefail

usage() {
  cat <<'U'
Usage: CLANG=<instrumented mos-clang> dev/measure-loadfold-recovery.sh [N_TORTURE]
  N_TORTURE   cap in-scope c-torture tests (default: all)
Env:
  CLANG         (required) the throwaway instrumented mos-clang
  CTORTURE_DIR  gcc c-torture/execute dir   (default: <repo>/vendor/c-torture/execute)
  INSCOPE       in-scope test list          (default: <repo>/examples/65816/torture/inscope.tsv)
  EXAMPLES      a16 micro-test dir           (default: <repo>/examples/65816)
  JOBS          parallel compiles            (default: 8)
U
  exit 0
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

CLANG="${CLANG:?set CLANG to the instrumented mos-clang (worktree build)}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES="${EXAMPLES:-$HERE/examples/65816}"
CTORTURE_DIR="${CTORTURE_DIR:-$HERE/vendor/c-torture/execute}"
INSCOPE="${INSCOPE:-$HERE/examples/65816/torture/inscope.tsv}"
JOBS="${JOBS:-8}"
NCAP="${1:-0}"

# Fail loud if the compiler isn't actually instrumented (else "0 hits" is ambiguous).
REAL="$(dirname "$CLANG")/clang-23"
if ! grep -aq 'LOADFOLD-PROBE-A' "$REAL" 2>/dev/null; then
  echo "FATAL: $REAL has no LOADFOLD-PROBE strings — not an instrumented build." >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HERE/build/loadfold-measure-$TS"; mkdir -p "$OUT"
LOG="$OUT/probe.log"; : > "$LOG"

# worker: compile one file, emit only its probe lines (tagged with the pass).
worker() {
  IFS='|' read -r label mode opt f <<<"$1"
  [ -f "$f" ] || { echo "MISSING|$f" ; return 0; }
  local fl=(--target=mos -mcpu=mosw65816 -mllvm -verify-machineinstrs -Wno-everything "$opt" -c -o /dev/null)
  [ "$mode" = a16 ] && fl+=(-Xclang -target-feature -Xclang +mos-a16)
  [ "$label" = torture ] && fl+=(-Dmain=torture_test_main -Dabort=__torture_abort -Dexit=__torture_exit)
  local err rc=0
  err="$("$CLANG" "${fl[@]}" "$f" 2>&1 1>/dev/null)" || rc=$?
  # one short atomic append block per file: status + any probe lines
  { printf 'FILE|%s|%s|%s|rc=%s\n' "$label" "$mode" "$(basename "$f")" "$rc"
    printf '%s\n' "$err" | grep '^LOADFOLD-PROBE' || true
  }
}
export -f worker; export CLANG

# Build the job list: "label|mode|opt|file" per line.
jobs_file="$OUT/jobs.txt"; : > "$jobs_file"
for f in "$EXAMPLES"/a16*.c; do
  [ -f "$f" ] || continue
  printf 'a16-tests|a16|-Os|%s\n'     "$f" >> "$jobs_file"
  printf 'a16-tests|a16|-O1|%s\n'     "$f" >> "$jobs_file"
  printf 'a16-tests|default|-Os|%s\n' "$f" >> "$jobs_file"
done
mapfile -t NAMES < <(grep -v '^#' "$INSCOPE" | awk 'NF{print $1}')
[ "$NCAP" -gt 0 ] && NAMES=("${NAMES[@]:0:$NCAP}")
for nm in "${NAMES[@]}"; do
  printf 'torture|a16|-Os|%s\n'     "$CTORTURE_DIR/$nm" >> "$jobs_file"
  printf 'torture|default|-Os|%s\n' "$CTORTURE_DIR/$nm" >> "$jobs_file"
done

NJOBS=$(wc -l < "$jobs_file")
echo "==> measure-loadfold-recovery $TS"
echo "    CLANG=$CLANG"
echo "    a16 micro-tests=$(ls "$EXAMPLES"/a16*.c 2>/dev/null | wc -l)  c-torture=${#NAMES[@]}  jobs=$NJOBS  -j$JOBS"
echo "    log=$LOG"

xargs -P"$JOBS" -d'\n' -I{} bash -c 'worker "$@"' _ {} < "$jobs_file" >> "$LOG"

# ---- tally ----
A=$(grep -c '^LOADFOLD-PROBE-A' "$LOG" || true)
B=$(grep -c '^LOADFOLD-PROBE-B' "$LOG" || true)
AU=$(grep '^LOADFOLD-PROBE-A' "$LOG" | sort -u | wc -l)
BU=$(grep '^LOADFOLD-PROBE-B' "$LOG" | sort -u | wc -l)
COMPILED=$(grep -c '^FILE|' "$LOG" || true)
FAILED=$(grep '^FILE|' "$LOG" | grep -vc 'rc=0' || true)
echo
echo "============================ RESULT ============================"
printf '  compiles attempted: %s   (rc!=0: %s — compile-fails contribute 0 probes)\n' "$COMPILED" "$FAILED"
printf '  Probe A  (AA-precision recovers a 16-bit fold) : %s hits, %s unique fn|op\n' "$A" "$AU"
printf '  Probe B  (single-use-volatile recovers a fold) : %s hits, %s unique fn|op\n' "$B" "$BU"
echo "----------------------------------------------------------------"
if [ "$A" -gt 0 ]; then echo "  Probe-A sites:"; grep '^LOADFOLD-PROBE-A' "$LOG" | sort | uniq -c | sort -rn | head -20; fi
if [ "$B" -gt 0 ]; then echo "  Probe-B sites:"; grep '^LOADFOLD-PROBE-B' "$LOG" | sort | uniq -c | sort -rn | head -20; fi
[ "$A" = 0 ] && [ "$B" = 0 ] && echo "  => BOTH ZERO: unification DEFER-confirmed (nothing to recover)."
echo "================================================================"

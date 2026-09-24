#!/usr/bin/env bash
# dev/roundtrip.sh — committed round-trip REGRESSION gate.
#
# Wraps dev/probe-far-roundtrip.sh (see that script's header for the full mechanism:
# compile each fixture `-c` (reference) vs `-S`+`llvm-mc` (round trip) with the SAME
# clang, diff the .text bytes — any divergence is a printer/parser asymmetry). This
# wrapper runs the probe once per compile mode this project ships and aggregates a
# single PASS/FAIL, so the two AsmPrinter gaps it was written to catch
# (long-address printing, a16-immediate printing — see the audit doc below) can
# never regress silently again.
#
# Scope defaults to --all (the FULL 117-fixture examples/65816/*.c corpus), not the
# narrow far/packed24 subset the underlying probe defaults to on its own: during the
# 2026-09-24 #320 completeness audit, the far/packed24 subset caught only 2 of the 32
# fixtures that diverged under the a16-immediate defect (patch 0045) — a narrow
# default here would have missed that whole regression class. --far-only opts into
# the fast subset for quick iteration; it is not a substitute for the default when
# deciding whether a change is clean.
#
# Host-side, compile-only: no container, no emulator, no SDK platform needed (same
# as the probe it wraps). Needs `dev/run.sh toolchain` first.
#
# Usage: dev/run.sh roundtrip [--far-only] [-v]
# See docs/investigations/2026-09-24-mos24-far-addressing-completeness-audit.md §6.4.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: dev/run.sh roundtrip [--far-only] [-v]

  Round-trip regression gate: for every fixture, compile `-c` (reference) and
  `-S`+`llvm-mc` (round trip) with the SAME clang, diff the .text bytes. Runs in
  all three modes this project ships -- default 8-bit, +mos-a16, +mos-a16
  +mos-xy16 -- over the full 117-fixture examples/65816/*.c corpus by default.
  The far/packed24-only subset missed 30 of 32 divergent fixtures in the last
  real regression this gate exists to catch (see dev/probe-far-roundtrip.sh,
  audit doc §6.4) -- do not narrow the default further.

  --far-only  narrow to the far/packed24 subset (fast; misses non-far
              divergences -- use only for a quick check while iterating on a
              far/packed24-specific change, never as the release gate)
  -v          print diverging bytes per mismatch (forwarded to the probe)

Needs `dev/run.sh toolchain` first. Exit 0 iff all three modes report 0
divergent (SKIPped fixtures -- e.g. far constructs that don't legalize at all
without +mos-a16 -- do not fail the gate; see the probe's own SKIP handling).
USAGE
  exit 0
}

SCOPE="--all"
VERBOSE=()
for a in "$@"; do
  case "$a" in
    -h|--help) usage ;;
    --far-only) SCOPE="" ;;
    -v) VERBOSE=(-v) ;;
    *) echo "FATAL: dev/run.sh roundtrip: unknown arg '$a' (see -h)" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$HERE/probe-far-roundtrip.sh"
[ -x "$PROBE" ] || { echo "FATAL: not executable: $PROBE" >&2; exit 2; }

A16_FLAG="-Xclang -target-feature -Xclang +mos-a16"
XY16_FLAG="-Xclang -target-feature -Xclang +mos-xy16"

MODE_ORDER=(default a16 xy16)
declare -A MODE_LABEL=(
  [default]="default (8-bit)"
  [a16]="+mos-a16"
  [xy16]="+mos-a16 +mos-xy16"
)
declare -A MODE_FLAGS=(
  [default]="-Os"
  [a16]="-Os $A16_FLAG"
  [xy16]="-Os $A16_FLAG $XY16_FLAG"
)
declare -A MODE_RESULT

overall=0
for mode in "${MODE_ORDER[@]}"; do
  echo "==> round-trip: ${MODE_LABEL[$mode]}"
  # Guard: the probe exits 1 on divergence (expected, not a script bug) and this
  # loop must keep going to run the remaining modes before reporting -- so the
  # sweep runs under a temporary `set +e`, same idiom as dev/test-release.sh.
  set +e
  # shellcheck disable=SC2086  # SCOPE is a single flag word or empty, by construction above
  out="$("$PROBE" $SCOPE --flags "${MODE_FLAGS[$mode]}" "${VERBOSE[@]}" 2>&1)"
  rc=$?
  set -e
  echo "$out"
  summary="$(echo "$out" | grep '^round-trip:' || true)"
  MODE_RESULT[$mode]="${summary:-<no summary line -- see output above>} (exit $rc)"
  [ "$rc" -eq 0 ] || overall=1
  echo
done

echo "== dev/run.sh roundtrip summary =="
for mode in "${MODE_ORDER[@]}"; do
  printf '  %-18s %s\n' "${MODE_LABEL[$mode]}" "${MODE_RESULT[$mode]}"
done

if [ "$overall" -eq 0 ]; then
  echo "PASS  round-trip: 0 divergent in all 3 modes"
else
  echo "FAIL  round-trip: divergence found -- see per-mode output above"
fi
exit "$overall"

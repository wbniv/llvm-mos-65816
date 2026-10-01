#!/usr/bin/env bash
# Build, test and hash every commit of the third-round series, one at a time.
#
# usage: r3-stages.sh LIST
#   LIST  lines "LABEL COMMIT"; each commit is checked out in
#         build/split-320-321/source, built and tested with carry-gate.sh LABEL
#         (MOS CodeGen+MC), and its llc hashed on every MOS CPU at O2 with
#         default-hashes-cpus.sh into evidence/LABEL/cpus-O2.tsv.
# Appends "LABEL COMMIT build/lit summary" to evidence/r3-stages.tsv. Continues
# after a failing commit so the table shows every result. Heavy steps follow
# carry-gate.sh (flock, -j3); hashing runs after lit, so at most 3 llc run.
set -uo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
S=$ROOT/build/split-320-321
while read -r label commit; do
  [ -n "$label" ] || continue
  git -C "$S/source" checkout -q --detach "$commit" || { printf '%s\t%s\tcheckout-failed\n' "$label" "$commit" >> "$S/evidence/r3-stages.tsv"; continue; }
  "$S/spec/carry-gate.sh" "$label" both > "$S/evidence/$label.run.log" 2>&1; rc=$?
  sum=$(head -n1 "$S/evidence/$label/lit-summary.txt" 2>/dev/null || echo none)
  if [ -e "$S/llc/$label" ] && grep -q "build rc=0" "$S/evidence/$label/build.log"; then
    "$S/spec/default-hashes-cpus.sh" "$S/llc/$label" "$S/evidence/$label/cpus-O2.tsv" O2 > "$S/evidence/$label/cpus.log" 2>&1; hrc=$?
  else hrc=skipped; fi
  printf '%s\t%s\tgate_rc=%s\t%s\thash_rc=%s\t%s\n' "$label" "$(git -C "$S/source" rev-parse --short=12 HEAD)" "$rc" "$sum" "$hrc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$S/evidence/r3-stages.tsv"
done < "$1"

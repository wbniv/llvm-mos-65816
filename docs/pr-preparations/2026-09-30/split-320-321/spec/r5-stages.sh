#!/usr/bin/env bash
# Build and test each commit of the round-five series and compare its llc with
# the earlier round's llc for the same code (test-only change: they must match).
#
# usage: r5-stages.sh LIST   (lines "LABEL COMMIT PREVIOUS_LABEL")
# Writes evidence/r5-stages.tsv: label, commit, gate rc, lit summary, llc sha256
# equal to PREVIOUS_LABEL's (yes/no).
set -uo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
S=/home/will/llvm-mos-65816/build/split-320-321
while read -r label commit prev; do
  git -C "$S/source" checkout -q --detach "$commit" || continue
  "$S/spec/carry-gate.sh" "$label" both > "$S/evidence/$label.run.log" 2>&1; rc=$?
  same=no; [ "$(cat "$S/evidence/$label/llc.sha256" 2>/dev/null)" = "$(cat "$S/evidence/$prev/llc.sha256" 2>/dev/null)" ] && same=yes
  printf '%s\t%s\tgate_rc=%s\t%s\tllc_equal_to_%s=%s\n' "$label" "$commit" "$rc" "$(head -n1 "$S/evidence/$label/lit-summary.txt" 2>/dev/null)" "$prev" "$same" >> "$S/evidence/r5-stages.tsv"
done < "$1"

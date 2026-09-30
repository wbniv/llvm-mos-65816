#!/usr/bin/env bash
# Gate each carried commit: build, suites, frozen llc, default-mode hashes.
#
# usage: carry-stages.sh LABEL=COMMIT[:PARENT_LABEL] ...
#   LABEL         evidence label (evidence/LABEL, llc/LABEL)
#   COMMIT        commit to check out (detached) in build/split-320-321/source
#   PARENT_LABEL  optional: compare default-mode hashes with evidence/PARENT_LABEL
# Builds run under the shared heavy-build lock (carry-gate.sh). Stops at the
# first failing build; a failing lit run is recorded and the next stage runs.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
for spec in "$@"; do
  label=${spec%%=*}; rest=${spec#*=}; commit=${rest%%:*}; parent=
  [ "$rest" != "$commit" ] && parent=${rest#*:}
  git -C "$SPLIT/source" checkout -q --detach "$commit"
  mkdir -p "$SPLIT/evidence/$label"
  git -C "$SPLIT/source" rev-parse HEAD^{tree} > "$SPLIT/evidence/$label/tree"
  echo "$(ts) stage $label $(git -C "$SPLIT/source" log -1 --format='%h %s')"
  bash "$SPLIT/spec/carry-gate.sh" "$label" build || { echo "$(ts) $label BUILD FAILED"; exit 1; }
  set +e; bash "$SPLIT/spec/carry-gate.sh" "$label" lit > /dev/null; set -e
  echo "$(ts) $label lit: $(head -1 "$SPLIT/evidence/$label/lit-summary.txt") $(tail -n +2 "$SPLIT/evidence/$label/lit-summary.txt" | tr '\n' ' ')"
  if [ -n "$parent" ]; then
    bash "$SPLIT/spec/default-hashes.sh" "$SPLIT/llc/$label" "$SPLIT/evidence/$label/default-hashes.tsv" > /dev/null
    python3 "$SPLIT/spec/compare-hashes.py" "$SPLIT/evidence/$parent/default-hashes.tsv" \
      "$SPLIT/evidence/$label/default-hashes.tsv" > "$SPLIT/evidence/$label/default-compare.txt"
    echo "$(ts) $label default vs $parent:"; sed 's/^/    /' "$SPLIT/evidence/$label/default-compare.txt" | head -6
  fi
done
echo "$(ts) done"

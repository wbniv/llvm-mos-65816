#!/usr/bin/env bash
# Check out, build, test and hash a range of stages in order.
#
# usage: run-stages.sh SERIES LIST FROM TO
#   SERIES  321 or 320 (label prefix; probe dir probe-SERIES)
#   LIST    build-series.sh output (stage<TAB>commit<TAB>tree lines)
#   FROM/TO inclusive stage range
# Per stage: evidence/SERIES-NN/{build.log,lit.*,probe-*,default-hashes.tsv},
# frozen llc at llc/SERIES-NN (hard link). Stops at the first failing build.
# Env: PROBE_DIR (tests to probe), LABEL_PREFIX (evidence label prefix),
# SKIP_HASH=1 (skip llc freezing and default-mode hashing).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
SERIES=$1 LIST=$2 FROM=$3 TO=$4
ROOT=/home/will/llvm-mos-65816
SPLIT=$ROOT/build/split-320-321
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
for k in $(seq "$FROM" "$TO"); do
  label=${LABEL_PREFIX:-}$SERIES-$(printf %02d "$k")
  commit=$(awk -F'\t' -v k="$k" '$1==k {print $2}' "$LIST")
  [ -n "$commit" ] || { echo "no commit for stage $k" >&2; exit 1; }
  echo "$(ts) stage $label $commit df=$(df -h / | awk 'NR==2{print $4}')"
  git -C "$SPLIT/source" checkout -q -B split-320-321 "$commit"
  set +e
  PROBE_DIR=${PROBE_DIR:-$SPLIT/probe-$SERIES} bash "$SPLIT/spec/build-and-test.sh" "$label" > "$SPLIT/evidence/$label.run.log" 2>&1
  rc=$?
  set -e
  echo "$(ts) $label build/test rc=$rc: $(head -1 "$SPLIT/evidence/$label/lit-summary.txt" 2>/dev/null)"
  if ! grep -q 'build rc=0' "$SPLIT/evidence/$label/build.log"; then
    echo "$(ts) $label BUILD FAILED"; exit 1
  fi
  [ -n "${SKIP_HASH:-}" ] && continue
  rm -f "$SPLIT/llc/$label"; ln "$SPLIT/build/bin/llc" "$SPLIT/llc/$label"
  bash "$SPLIT/spec/default-hashes.sh" "$SPLIT/llc/$label" "$SPLIT/evidence/$label/default-hashes.tsv" > /dev/null
  prev=${LABEL_PREFIX:-}$SERIES-$(printf %02d $((k-1)))
  # The unchanged base (321-00) has no prefixed run; fall back to it.
  [ -f "$SPLIT/evidence/$prev/default-hashes.tsv" ] || prev=$SERIES-$(printf %02d $((k-1)))
  if [ -f "$SPLIT/evidence/$prev/default-hashes.tsv" ]; then
    python3 "$SPLIT/spec/compare-hashes.py" "$SPLIT/evidence/$prev/default-hashes.tsv" \
      "$SPLIT/evidence/$label/default-hashes.tsv" > "$SPLIT/evidence/$label/default-compare.txt"
    sed 's/^/    /' "$SPLIT/evidence/$label/default-compare.txt" | head -8
  fi
done
echo "$(ts) done $FROM..$TO"

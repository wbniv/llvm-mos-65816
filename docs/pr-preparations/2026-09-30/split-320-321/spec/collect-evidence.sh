#!/usr/bin/env bash
# Copy the small split evidence into a packet directory and hash the large logs.
#
# usage: collect-evidence.sh DEST
#   DEST  packet evidence directory (created). Large logs stay in
#         build/split-320-321/evidence; their sha256 go to DEST/large-logs.sha256.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
DEST=$1
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
EV=$SPLIT/evidence
mkdir -p "$DEST/per-commit"
python3 "$SPLIT/spec/red-green.py" "$EV" t- > "$DEST/red-green.tsv"
# One row per split commit: final commit, tree, suite result of the tests run
# (t- labels), and the default-mode comparison from the first run, whose llc
# binaries are byte-identical to the tests run (llc.sha256 compared per row).
{
  printf 'label\tcommit\ttree\tlit\tllc_sha256_same_as_default_run\tdefault_mos6502\tdefault_mosw65816\n'
  for s in 321 320; do
    grep -v TREE "$SPLIT/spec/$s.list" | while IFS=$'\t' read -r k c t; do
      l=$s-$(printf %02d "$k")
      same=$([ "$(cat "$EV/t-$l/llc.sha256")" = "$(cat "$EV/$l/llc.sha256")" ] && echo yes || echo NO)
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$l" "$c" "$t" "$(head -1 "$EV/t-$l/lit-summary.txt")" "$same" \
        "$(sed -n 1p "$EV/$l/default-compare.txt" | sed 's/^mos6502: //')" \
        "$(sed -n 2p "$EV/$l/default-compare.txt" | sed 's/^mosw65816: //')"
    done
  done
} > "$DEST/series-evidence.tsv"
: > "$DEST/large-logs.sha256"
for d in "$EV"/321-?? "$EV"/320-?? "$EV"/t-32?-?? "$EV"/pkt-*; do
  [ -d "$d" ] || continue
  l=$(basename "$d"); mkdir -p "$DEST/per-commit/$l"
  for f in lit-summary.txt llc.sha256 default-compare.txt pressure-sets.txt objdiff-boids.txt \
           probe-summary.txt commit applied.txt tree size-vs-base.txt size-vs-00.txt size-vs-11.txt \
           size-vs-12.txt size-vs-15.txt mos-warnings.txt; do
    [ -f "$d/$f" ] && cp "$d/$f" "$DEST/per-commit/$l/"
  done
  for f in build.log lit.log lit.json probe-lit.log default-hashes.tsv am.log; do
    [ -f "$d/$f" ] && (cd "$EV" && sha256sum "$l/$f") >> "$DEST/large-logs.sha256"
  done
done
cp "$SPLIT/spec/321.invariant.txt" "$SPLIT/spec/320.invariant.txt" "$DEST/"
cp "$EV/history-tag-lines.txt" "$EV/format-321.txt" "$EV/format-320.txt" "$DEST/"
echo "collected into $DEST: $(find "$DEST" -type f | wc -l) files, $(du -sh "$DEST" | cut -f1)"

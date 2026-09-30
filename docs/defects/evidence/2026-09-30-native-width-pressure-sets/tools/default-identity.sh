#!/usr/bin/env bash
# Regression runner: default-mode output of a candidate llc must be
# byte-identical to upstream llvm-mos 06bc967d2668 on the fixed input set.
#
# usage: default-identity.sh LLC_REF LLC_CAND OUTDIR
#   LLC_REF   reference llc (upstream 06bc967d2668 build)
#   LLC_CAND  llc under test
#   OUTDIR    receives ref.tsv, cand.tsv and compare.txt
#   All three paths under /home/will/llvm-mos-65816.
# Modes: -mcpu=mos6502 and plain -mcpu=mosw65816 at -O2, asm and object.
# Exit 0 when every input/mode result is identical; 1 when any differs
# (compare.txt then ends "RESULT: DIFFER (...)"); 2 on usage errors.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
[ $# -eq 3 ] || { echo "need LLC_REF LLC_CAND OUTDIR" >&2; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
REF=$1; CAND=$2; OUT=$3
mkdir -p "$OUT"
sha256sum "$REF" "$CAND" > "$OUT/llc.sha256"
bash "$HERE/mode-hashes.sh" "$REF" "$OUT/ref.tsv" >/dev/null
bash "$HERE/mode-hashes.sh" "$CAND" "$OUT/cand.tsv" >/dev/null
set +e
python3 "$HERE/compare-hashes.py" "$OUT/ref.tsv" "$OUT/cand.tsv" --names > "$OUT/compare.txt"
rc=$?
set -e
cat "$OUT/compare.txt"
exit $rc

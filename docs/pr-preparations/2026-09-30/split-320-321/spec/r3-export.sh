#!/usr/bin/env bash
# Export the third-round split as patch directories and check the round trip.
#
# usage: r3-export.sh OUT_DIR
#   OUT_DIR  the split-320-321 packet directory; rewrites patches-321/,
#            patches-mc/, patches-584/ and patches-320/ and writes
#            evidence/r3/roundtrip.txt
# Applies every patch in order (321, mc, 584, 320) to 06bc967d2668 in a
# temporary index and compares each intermediate tree with its commit's tree.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
OUT=$(realpath "$1"); R=/home/will/llvm-mos-65816/build/split-320-321/source
T321=$(git -C "$R" log --format=%H --fixed-strings --grep='[MOS] Preserve interrupted M/X state in 65816 interrupt handlers' 06bc967d2668..split-320-321-r3 | head -1)
TMC=$(git -C "$R" log --format=%H --fixed-strings --grep='Preserve long address widths in printed assembly' 06bc967d2668..split-320-321-r3 | head -1)
T584=$(git -C "$R" log --format=%H --fixed-strings --grep='[MOS] Fix non-GPR immediate loads in mos-late-opt' 06bc967d2668..split-320-321-r3 | head -1)
TOP=$(git -C "$R" rev-parse split-320-321-r3)
for d in 321 mc 584 320; do rm -rf "$OUT/patches-$d"; done
git -C "$R" format-patch -q -o "$OUT/patches-321" 06bc967d2668.."$T321"
git -C "$R" format-patch -q -o "$OUT/patches-mc" "$T321".."$TMC"
git -C "$R" format-patch -q -o "$OUT/patches-584" "$TMC".."$T584"
git -C "$R" format-patch -q -o "$OUT/patches-320" "$T584".."$TOP"
mkdir -p "$OUT/evidence/r3"
IDX=$(mktemp); rm -f "$IDX"; export GIT_INDEX_FILE=$IDX
git -C "$R" read-tree 06bc967d2668
commits=$(git -C "$R" rev-list --reverse 06bc967d2668.."$TOP")
ok=0; bad=0; i=0
set -- $commits
{ for p in "$OUT"/patches-321/*.patch "$OUT"/patches-mc/*.patch "$OUT"/patches-584/*.patch "$OUT"/patches-320/*.patch; do
    c=$1; shift
    git -C "$R" apply --cached "$p"
    t=$(git -C "$R" write-tree); want=$(git -C "$R" rev-parse "$c^{tree}")
    if [ "$t" = "$want" ]; then ok=$((ok+1)); r=match; else bad=$((bad+1)); r=MISMATCH; fi
    printf '%s\t%s\t%s\t%s\n' "${p#$OUT/}" "${c:0:12}" "${t:0:12}" "$r"
  done
  echo "patches=$((ok+bad)) matching=$ok mismatching=$bad final_tree=$(git -C "$R" write-tree | cut -c1-12) top=${TOP:0:12}"
} > "$OUT/evidence/r3/roundtrip.txt"
rm -f "$IDX"
tail -1 "$OUT/evidence/r3/roundtrip.txt"

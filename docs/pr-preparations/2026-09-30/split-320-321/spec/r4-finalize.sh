#!/usr/bin/env bash
# Re-create the fourth-round series with final messages; trees stay unchanged.
#
# usage: r4-finalize.sh TOP
#   TOP  top of the gated series (pkt-r4-far-word)
# Walks 06bc967d2668..TOP and rebuilds every commit with `git commit-tree`:
# same tree, author, author date and committer date; message from
# spec/msgs-r3/<key>.txt when one exists for the commit's subject, otherwise its
# own. Commits whose message does not change keep their hash. Moves
# split-320-321-r4 (#320 top) and pkt-r4-far-word, and writes
# evidence/r4-message-update.tsv (run commit, final commit, tree).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
TOP=$1
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
R=$SPLIT/source; M=$SPLIT/spec/msgs-r3
out=$SPLIT/evidence/r4-message-update.tsv
printf 'run_commit\tfinal_commit\ttree\n' > "$out"
declare -A MSG=(
  ["[MOS] Define 16-bit index instruction forms and X-width requirements"]=321-03.txt
  ["[MOS] Select native 16-bit compares and fused branches"]=321-11.txt
  ["[MOS] Keep byte indexes byte-wide in absolute indexed addressing"]=321-12.txt
  ["[MOS] Fix non-GPR immediate loads in mos-late-opt"]=584.txt
  ["[MOS] Reserve Imag32 quads that overlap reserved pairs"]=320-1b-resv.txt
  ["[MOS] Add the far address space and allocate Imag32 quads on the 65816"]=320-1c-far.txt
  ["[MOS] Spill and reload Imag32 quads as four bytes"]=320-1d.txt
  ["[MOS] Legalize and select far pointer values and memory accesses"]=320-2.txt
  ["[MOS] Route far memory intrinsics to the far runtime"]=320-3.txt
  ["[MOS] Select bounded runtime [dp],Y indexing for far byte accesses"]=320-4.txt
  ["Cost native index copies to imaginary register pairs"]=fw-9.txt
  ["Select far absolute indexed byte accesses"]=fw-5.txt
  ["Select native accumulator far word accesses"]=fw-6.txt
  ["Select far extending-load addresses within the legalizer worklist"]=fw-7.txt
  ["Prove bounded byte-loop ranges for far runtime indexing"]=fw-8.txt
  ["Preserve undefined lane definitions in identity copies"]=fw-11.txt
  ["Fold bounded native far word loads in speed-optimized functions"]=fw-12.txt
  ["Check far-word boundaries, operands, and loop-proof limits"]=fw-13.txt
  ["Assert shared base and index for mixed far loads"]=fw-14.txt
)
parent=06bc967d2668c7c11c4d6eb43a6aed1f99ad258b
tmp=$(mktemp)
for c in $(git -C "$R" rev-list --reverse 06bc967d2668.."$TOP"); do
  subj=$(git -C "$R" log -1 --format=%s "$c")
  if [ -n "${MSG[$subj]:-}" ]; then git stripspace < "$M/${MSG[$subj]}" > "$tmp"; else git -C "$R" cat-file commit "$c" | sed '1,/^$/d' > "$tmp"; fi
  new=$(GIT_AUTHOR_NAME="$(git -C "$R" log -1 --format=%an "$c")" \
        GIT_AUTHOR_EMAIL="$(git -C "$R" log -1 --format=%ae "$c")" \
        GIT_AUTHOR_DATE="$(git -C "$R" log -1 --format=%aI "$c")" \
        GIT_COMMITTER_NAME="$(git -C "$R" log -1 --format=%cn "$c")" \
        GIT_COMMITTER_EMAIL="$(git -C "$R" log -1 --format=%ce "$c")" \
        GIT_COMMITTER_DATE="$(git -C "$R" log -1 --format=%cI "$c")" \
        git -C "$R" commit-tree "$c^{tree}" -p "$parent" -F "$tmp")
  printf '%s\t%s\t%s\n' "$(git -C "$R" rev-parse "$c")" "$new" "$(git -C "$R" rev-parse "$c^{tree}")" >> "$out"
  [ "$subj" = "[MOS] Select bounded runtime [dp],Y indexing for far byte accesses" ] && git -C "$R" branch -f split-320-321-r4 "$new"
  parent=$new
done
rm -f "$tmp"
git -C "$R" branch -f pkt-r4-far-word "$parent"
awk -F'\t' 'NR>1 && $1!=$2' "$out" | wc -l | sed 's/^/changed commits: /'

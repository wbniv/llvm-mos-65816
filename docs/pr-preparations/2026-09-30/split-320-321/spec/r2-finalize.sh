#!/usr/bin/env bash
# Re-create the second-round series with final messages and fixed committer data.
#
# usage: r2-finalize.sh TOP
#   TOP  run commit at the top of the far-word packet (pkt-r2-far-word)
# Walks 25c40909b44a..TOP and rebuilds every commit with `git commit-tree` in
# build/split-320-321/source: same tree and author, message from
# spec/msgs-r2/<key>.txt when one exists for the commit's subject, otherwise
# its own message. Committer: Will Norris <will@biohack.net>, dated
# 2026-10-01T12:00:00Z for the #320 commits and the author date for far-word
# commits. Sets split-320-321-r2 (#320 top) and pkt-r2-far-word, and writes
# evidence/r2-message-update.tsv (run commit, final commit, tree).
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
TOP=$1
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
R=$SPLIT/source; M=$SPLIT/spec/msgs-r2
export GIT_COMMITTER_NAME="Will Norris" GIT_COMMITTER_EMAIL="will@biohack.net"
out=$SPLIT/evidence/r2-message-update.tsv
printf 'run_commit\tfinal_commit\ttree\n' > "$out"
declare -A MSG=(
  ["[MOS] Add nonallocatable 32-bit imaginary registers"]=320-1a-iii.txt
  ["[MOS] Reserve Imag32 quads that overlap reserved pairs"]=320-1b-resv.txt
  ["[MOS] Add the far address space and allocate Imag32 quads on the 65816"]=320-1c-far.txt
  ["[MOS] Spill and reload Imag32 quads as four bytes"]=320-1c.txt
  ["[MOS] Legalize and select far pointer values and memory accesses"]=320-2.txt
  ["[MOS] Route far memory intrinsics to the far runtime"]=320-3.txt
  ["[MOS] Select bounded runtime [dp],Y indexing for far byte accesses"]=320-4.txt
  ["Select far absolute indexed byte accesses"]=fw-5.txt
  ["Fold bounded native far word loads in speed-optimized functions"]=../msgs-carry/fw-12.txt
)
parent=25c40909b44aa7b9c908e844612d2eb4b6e36596
tmp=$(mktemp)
for c in $(git -C "$R" rev-list --reverse 25c40909b44a.."$TOP"); do
  subj=$(git -C "$R" log -1 --format=%s "$c")
  if [ -n "${MSG[$subj]:-}" ]; then cp "$M/${MSG[$subj]}" "$tmp"; else git -C "$R" log -1 --format=%B "$c" > "$tmp"; fi
  case "$subj" in "[MOS] "*) cd=2026-10-01T12:00:00Z;; *) cd=$(git -C "$R" log -1 --format=%aI "$c");; esac
  new=$(GIT_AUTHOR_NAME="$(git -C "$R" log -1 --format=%an "$c")" \
        GIT_AUTHOR_EMAIL="$(git -C "$R" log -1 --format=%ae "$c")" \
        GIT_AUTHOR_DATE="$(git -C "$R" log -1 --format=%aI "$c")" \
        GIT_COMMITTER_DATE="$cd" \
        git -C "$R" commit-tree "$c^{tree}" -p "$parent" -F "$tmp")
  printf '%s\t%s\t%s\n' "$(git -C "$R" rev-parse "$c")" "$new" "$(git -C "$R" rev-parse "$c^{tree}")" >> "$out"
  [ "$subj" = "[MOS] Select bounded runtime [dp],Y indexing for far byte accesses" ] && git -C "$R" branch -f split-320-321-r2 "$new"
  parent=$new
done
rm -f "$tmp"
git -C "$R" branch -f pkt-r2-far-word "$parent"
column -t -s$'\t' "$out"

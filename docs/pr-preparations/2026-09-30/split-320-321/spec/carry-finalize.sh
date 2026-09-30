#!/usr/bin/env bash
# Re-create the carried commits with final messages and fixed committer data.
#
# usage: carry-finalize.sh
# Rebuilds, with `git commit-tree` in build/split-320-321/source, the four
# carried #320 commits on the MC top 25c40909b44a (branch split-320-321-carry)
# and far-word patches 5-14 on top of them (branch pkt-c-far-word). Each new
# commit keeps its run commit's tree and author. Messages: spec/msgs-carry/
# 320-0N.txt and fw-12.txt; the other far-word commits keep theirs. Committer:
# Will Norris <will@biohack.net>, dated 2026-10-01T00:00:00Z for #320 and the
# author date for far-word, so the hashes are reproducible. Writes
# evidence/c-message-update.tsv (run commit, final commit, tree).
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
R=$SPLIT/source; M=$SPLIT/spec/msgs-carry
RUN320=(abfb29168fca 3eafc8a41001 a56574564f44 4410ecfce5f9)
RUNFW=$(git -C "$R" rev-list --reverse 4410ecfce5f9..97c7edbbc2d2)
export GIT_COMMITTER_NAME="Will Norris" GIT_COMMITTER_EMAIL="will@biohack.net"
out=$SPLIT/evidence/c-message-update.tsv
printf 'run_commit\tfinal_commit\ttree\n' > "$out"
mk() { # run-commit parent message-file committer-date
  local c=$1 p=$2 msg=$3 cd=$4
  GIT_AUTHOR_NAME="$(git -C "$R" log -1 --format=%an "$c")" \
  GIT_AUTHOR_EMAIL="$(git -C "$R" log -1 --format=%ae "$c")" \
  GIT_AUTHOR_DATE="$(git -C "$R" log -1 --format=%aI "$c")" \
  GIT_COMMITTER_DATE="$cd" \
    git -C "$R" commit-tree "$c^{tree}" -p "$p" -F "$msg"
}
parent=25c40909b44aa7b9c908e844612d2eb4b6e36596
for i in 0 1 2 3; do
  c=${RUN320[$i]}
  new=$(mk "$c" "$parent" "$M/320-0$((i+1)).txt" 2026-10-01T00:00:00Z)
  printf '%s\t%s\t%s\n' "$(git -C "$R" rev-parse "$c")" "$new" "$(git -C "$R" rev-parse "$c^{tree}")" >> "$out"
  parent=$new
done
git -C "$R" branch -f split-320-321-carry "$parent"
tmp=$(mktemp)
for c in $RUNFW; do
  if [ "$(git -C "$R" log -1 --format=%s "$c")" = "Fold bounded native far word loads in speed-optimized functions" ]; then
    cp "$M/fw-12.txt" "$tmp"
  else
    git -C "$R" log -1 --format=%B "$c" > "$tmp"
  fi
  new=$(mk "$c" "$parent" "$tmp" "$(git -C "$R" log -1 --format=%aI "$c")")
  printf '%s\t%s\t%s\n' "$(git -C "$R" rev-parse "$c")" "$new" "$(git -C "$R" rev-parse "$c^{tree}")" >> "$out"
  parent=$new
done
rm -f "$tmp"
git -C "$R" branch -f pkt-c-far-word "$parent"
column -t -s$'\t' "$out"

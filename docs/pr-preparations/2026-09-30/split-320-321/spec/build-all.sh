#!/usr/bin/env bash
# Build the whole split chain: #321 series on 06bc967d2668, the two unchanged
# MC address-width commits re-parented on it, then the #320 series.
#
# usage: build-all.sh
# Writes spec/321.list and spec/320.list and checks both tree invariants
# against the monolithic trees plus the pressure-set change (pressure-targets.sh).
# Does not move any branch; run-stages.sh checks out each commit.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO=/home/will/llvm-mos-65816/build/split-320-321/source
# Monolithic reference trees with the native-width pressure-set change (and
# 321.diff/320.diff regenerated from them); see pressure-targets.sh.
bash "$HERE/pressure-targets.sh" > /dev/null
T321=$(awk '$1=="T321"{print $2}' "$HERE/pressure-targets.txt")
T320=$(awk '$1=="T320"{print $2}' "$HERE/pressure-targets.txt")
bash "$HERE/build-series.sh" 321 06bc967d2668 06bc967d2668 16 "$T321" > "$HERE/321.list"
tail -1 "$HERE/321.list"
top=$(awk -F'\t' '$1==16{print $2}' "$HERE/321.list")
# Replay the MC commits unchanged (diff, author, dates, message) on the #321 top.
for mc in 36f5994b5d46 0c77988b2e0b; do
  f() { git -C "$REPO" log -1 --format="$1" "$mc"; }
  export GIT_INDEX_FILE=$(mktemp -u)
  git -C "$REPO" read-tree "$top"
  git -C "$REPO" diff "$mc^" "$mc" | git -C "$REPO" apply --cached
  t=$(git -C "$REPO" write-tree); rm -f "$GIT_INDEX_FILE"; unset GIT_INDEX_FILE
  export GIT_AUTHOR_NAME="$(f %an)" GIT_AUTHOR_EMAIL="$(f %ae)" GIT_AUTHOR_DATE="$(f %aI)"
  export GIT_COMMITTER_NAME="$(f %cn)" GIT_COMMITTER_EMAIL="$(f %ce)" GIT_COMMITTER_DATE="$(f %cI)"
  top=$(git -C "$REPO" log -1 --format=%B "$mc" | git -C "$REPO" commit-tree "$t" -p "$top")
  echo "MC $mc -> $top"
done
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
echo "$top" > "$HERE/mc.top"
bash "$HERE/build-series.sh" 320 "$top" "$top" 4 "$T320" > "$HERE/320.list"
tail -1 "$HERE/320.list"
final=$(awk -F'\t' '$1==4{print $2}' "$HERE/320.list")
echo "series head: $final"

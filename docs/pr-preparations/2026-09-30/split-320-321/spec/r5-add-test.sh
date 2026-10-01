#!/usr/bin/env bash
# Add one test file to a series commit and replay every later commit with it.
#
# usage: r5-add-test.sh TARGET TOP FILE TESTPATH MSGFILE [EXTRA_TOP...]
#   TARGET    commit that gets the file (message replaced by MSGFILE)
#   TOP       series top; every commit in TARGET..TOP is rebuilt with the file
#   FILE      source file; TESTPATH its path in the tree
#   EXTRA_TOP further branches whose commits above TARGET's descendants are
#             rebuilt the same way (packets on the #321 top)
# Rebuilds by `git commit-tree` with a temporary index: each tree is the old
# tree plus the file; author, dates and messages are kept. Prints old->new.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
R=/home/will/llvm-mos-65816/build/split-320-321/source
T=$(git -C "$R" rev-parse "$1"); TOP=$2; FILE=$3; TP=$4; MSG=$5; shift 5
BLOB=$(git -C "$R" hash-object -w "$FILE")
declare -A MAP
rebuild() { # commit newparent [msgfile]
  local c=$1 p=$2 m=${3:-} idx; idx=$(mktemp); rm -f "$idx"
  GIT_INDEX_FILE=$idx git -C "$R" read-tree "$c"
  GIT_INDEX_FILE=$idx git -C "$R" update-index --add --cacheinfo 100644,"$BLOB","$TP"
  local tree; tree=$(GIT_INDEX_FILE=$idx git -C "$R" write-tree); rm -f "$idx"
  local mf; mf=$(mktemp)
  if [ -n "$m" ]; then git stripspace < "$m" > "$mf"; else git -C "$R" cat-file commit "$c" | sed '1,/^$/d' > "$mf"; fi
  GIT_AUTHOR_NAME="$(git -C "$R" log -1 --format=%an "$c")" GIT_AUTHOR_EMAIL="$(git -C "$R" log -1 --format=%ae "$c")" \
  GIT_AUTHOR_DATE="$(git -C "$R" log -1 --format=%aI "$c")" GIT_COMMITTER_NAME="$(git -C "$R" log -1 --format=%cn "$c")" \
  GIT_COMMITTER_EMAIL="$(git -C "$R" log -1 --format=%ce "$c")" GIT_COMMITTER_DATE="$(git -C "$R" log -1 --format=%cI "$c")" \
  git -C "$R" commit-tree "$tree" -p "$p" -F "$mf"; rm -f "$mf"
}
new=$(rebuild "$T" "$(git -C "$R" rev-parse "$T^")" "$MSG"); MAP[$T]=$new; echo "$T $new"
for top in "$TOP" "$@"; do
  for c in $(git -C "$R" rev-list --reverse --topo-order "$T..$top"); do
    [ -n "${MAP[$c]:-}" ] && continue
    p=$(git -C "$R" rev-parse "$c^"); np=${MAP[$p]:-}
    [ -n "$np" ] || { echo "parent of $c not rebuilt" >&2; exit 1; }
    n=$(rebuild "$c" "$np"); MAP[$c]=$n; echo "$c $n"
  done
done

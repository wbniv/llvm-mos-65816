#!/usr/bin/env bash
# Build a split commit series from a monolithic diff and a stage spec.
#
# usage: build-series.sh SERIES BASE PARENT N [TARGET]
#   SERIES  321 or 320 (reads SERIES.diff, SERIES.spec, msgs/SERIES-NN.txt)
#   BASE    commit the diff applies to (every stage patch is BASE-relative)
#   PARENT  commit the first split commit is parented on
#   N       number of stages
#   TARGET  optional commit: the last stage must equal its tree plus added llvm/test files
# Prints one "stage<TAB>commit<TAB>tree" line per stage; the last line is HEAD.
# Works only through a temporary index: the worktree and its files are untouched.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
SERIES=$1 BASE=$2 PARENT=$3 N=$4 TARGET=${5:-}
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO=/home/will/llvm-mos-65816/build/split-320-321/source
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME="Will Norris" GIT_AUTHOR_EMAIL="will@biohack.net"
export GIT_COMMITTER_NAME="Will Norris" GIT_COMMITTER_EMAIL="will@biohack.net"
# Fixed dates keep regenerated commits reproducible.
export GIT_AUTHOR_DATE="2026-09-30T00:00:00Z" GIT_COMMITTER_DATE="2026-09-30T00:00:00Z"
prev=$PARENT
for k in $(seq 1 "$N"); do
  python3 "$HERE/stage.py" "$HERE/$SERIES.diff" "$HERE/$SERIES.spec" "$k" > "$TMP/p$k.patch"
  export GIT_INDEX_FILE="$TMP/index"
  git -C "$REPO" read-tree "$BASE"
  git -C "$REPO" apply --cached --recount "$TMP/p$k.patch"
  tree=$(git -C "$REPO" write-tree)
  unset GIT_INDEX_FILE
  msg="$HERE/msgs/$SERIES-$(printf %02d "$k").txt"
  [ -f "$msg" ] || { echo "missing $msg" >&2; exit 1; }
  prev=$(git -C "$REPO" commit-tree "$tree" -p "$prev" -F "$msg")
  printf '%s\t%s\t%s\n' "$k" "$prev" "$tree"
done
if [ -n "$TARGET" ]; then
  # Invariant: the last stage equals TARGET plus files added under llvm/test/.
  git -C "$REPO" diff --name-status "$TARGET" "$tree" > "$TMP/delta"
  bad=$(grep -v -E $'^A\tllvm/test/' "$TMP/delta" || true)
  if [ -z "$bad" ]; then
    cp "$TMP/delta" "$HERE/$SERIES.invariant.txt"
    echo "TREE-INVARIANT OK: $TARGET^{tree} + $(wc -l < "$TMP/delta") added llvm/test files (list: $SERIES.invariant.txt)"
  else
    echo "TREE-INVARIANT VIOLATED ($TARGET):"; echo "$bad"; exit 1
  fi
fi

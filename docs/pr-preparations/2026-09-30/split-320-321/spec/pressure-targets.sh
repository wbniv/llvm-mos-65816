#!/usr/bin/env bash
# Build the monolithic reference trees with the native-width pressure-set
# change, and regenerate 321.diff and 320.diff from them.
#
# usage: pressure-targets.sh
# The change is pressure-321.diff (on the monolithic #321 tree 340c8ee25d5c and
# the MC top 0c77988b2e0b) and pressure-320.diff (the same change on the
# monolithic #320 tree 11044c53d5fc, whose MOSRegisterInfo.td comment differs).
# Writes pressure-targets.txt ("T321 <commit>", "B320 <commit>", "T320 <commit>"),
# 321.diff (git diff 06bc967d2668 T321 + 321.tests.diff) and 320.diff
# (git diff B320 T320 + 320.tests.diff). Commits are created with fixed
# identities and dates, so reruns give the same hashes. No branch moves.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO=/home/will/llvm-mos-65816/build/split-320-321/source
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME="Will Norris" GIT_AUTHOR_EMAIL="will@biohack.net"
export GIT_COMMITTER_NAME="Will Norris" GIT_COMMITTER_EMAIL="will@biohack.net"
export GIT_AUTHOR_DATE="2026-09-30T00:00:00Z" GIT_COMMITTER_DATE="2026-09-30T00:00:00Z"
mk() { # BASE PATCH LABEL -> commit
  GIT_INDEX_FILE="$TMP/index" git -C "$REPO" read-tree "$1"
  GIT_INDEX_FILE="$TMP/index" git -C "$REPO" apply --cached "$2"
  local t; t=$(GIT_INDEX_FILE="$TMP/index" git -C "$REPO" write-tree)
  echo "Reference: $3 with the native-width pressure-set change" |
    git -C "$REPO" commit-tree "$t" -p "$1"
}
T321=$(mk 340c8ee25d5c "$HERE/pressure-321.diff" "monolithic #321")
B320=$(mk 0c77988b2e0b "$HERE/pressure-321.diff" "MC top")
T320=$(mk 11044c53d5fc "$HERE/pressure-320.diff" "monolithic #320")
printf 'T321 %s\nB320 %s\nT320 %s\n' "$T321" "$B320" "$T320" | tee "$HERE/pressure-targets.txt"
git -C "$REPO" diff 06bc967d2668 "$T321" | cat - "$HERE/321.tests.diff" > "$HERE/321.diff"
git -C "$REPO" diff "$B320" "$T320" | cat - "$HERE/320.tests.diff" > "$HERE/320.diff"
wc -l "$HERE/321.diff" "$HERE/320.diff"

#!/usr/bin/env bash
# Rebuild the 16 #321 commits with history tags removed and clang-format applied
# (review N3/N4), without re-resolving any later commit by hand.
#
# usage: r3-rebuild-321.sh OLD_BASE OLD_TOP
#   For each commit C in OLD_BASE..OLD_TOP: check out C's tree, run r3-untag.py,
#   run clang-format-diff.py -i over `git diff -U0 OLD_BASE` (the cumulative
#   #321 lines, C++ only), and commit the result on the previous new commit with
#   C's author, date and message. Prints "old new" per commit; the new top last.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
SRC=$ROOT/build/split-320-321/source
SPEC=$ROOT/build/split-320-321/spec
BASE=$1; TOP=$2
cd "$SRC"
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "source tree is dirty" >&2; exit 1; }
prev=$(git rev-parse "$BASE")
for c in $(git rev-list --reverse "$BASE..$TOP"); do
  git checkout -q --detach "$c"
  python3 "$SPEC/r3-untag.py" . > /dev/null
  git diff -U0 "$BASE" -- '*.cpp' '*.h' > .r3-format.patch
  (cd "$ROOT" && dev/container.sh -- bash -c 'set -euo pipefail; cd /work/build/split-320-321/source && python3 /opt/llvm-mos/share/clang/clang-format-diff.py -p1 -i -binary /opt/llvm-mos/bin/clang-format < .r3-format.patch' </dev/null)
  rm -f .r3-format.patch
  git add -u
  tree=$(git write-tree)
  new=$(GIT_AUTHOR_NAME="$(git log -1 --format=%an "$c")" GIT_AUTHOR_EMAIL="$(git log -1 --format=%ae "$c")" \
        GIT_AUTHOR_DATE="$(git log -1 --format=%aD "$c")" \
        git commit-tree "$tree" -p "$prev" -F <(git log -1 --format=%B "$c"))
  git reset -q --hard "$c"
  echo "$c $new"
  prev=$new
done
git checkout -q --detach "$prev"

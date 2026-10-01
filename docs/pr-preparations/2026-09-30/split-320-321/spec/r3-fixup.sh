#!/usr/bin/env bash
# Fold a working-tree fix into an earlier series commit and replay the rest.
#
# usage: r3-fixup.sh TARGET [TOP]
#   TARGET  commit (hash or unique subject substring) that the fix belongs to
#   TOP     series top to replay onto (default: branch pkt-r3-far-word)
# Takes `git diff HEAD` of build/split-320-321/source (must be checked out at
# TOP), applies it to TARGET with --3way, amends TARGET (author, date and
# message kept), cherry-picks TARGET..TOP on top, and moves pkt-r3-far-word
# (and split-320-321-r3 when TARGET is at or below the #320 top) to the result.
# Stops on the first conflict and leaves the repository in that state.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
SRC=/home/will/llvm-mos-65816/build/split-320-321/source
cd "$SRC"
TOP=$(git rev-parse "${2:-pkt-r3-far-word}")
[ "$(git rev-parse HEAD)" = "$TOP" ] || { echo "checkout is not at TOP" >&2; exit 1; }
if git rev-parse -q --verify "$1^{commit}" >/dev/null; then T=$(git rev-parse "$1")
else T=$(git log --format=%H --fixed-strings --grep="$1" 06bc967d2668..$TOP | head -n1); fi
[ -n "$T" ] || { echo "no commit matches $1" >&2; exit 1; }
P=$(mktemp); git diff HEAD > "$P"; [ -s "$P" ] || { echo "no working-tree change" >&2; exit 1; }
REST=$(git rev-list --reverse "$T..$TOP")
git reset -q --hard
git checkout -q --detach "$T"
git apply --3way --index "$P"
GIT_COMMITTER_DATE="$(git log -1 --format=%cI "$T")" git commit -q --amend --no-edit
echo "amended $(git log -1 --format='%h %s')"
for c in $REST; do
  GIT_COMMITTER_DATE="$(git log -1 --format=%cI "$c")" git cherry-pick "$c" >/dev/null 2>&1 || { echo "conflict replaying $c: $(git log -1 --format=%s "$c")" >&2; git diff --name-only --diff-filter=U >&2; exit 2; }
done
git branch -f pkt-r3-far-word HEAD
N320=$(git log --format=%H --fixed-strings --grep='[MOS] Select bounded runtime [dp],Y indexing for far byte accesses' 06bc967d2668..HEAD | head -n1)
[ -n "$N320" ] && git branch -f split-320-321-r3 "$N320"
git checkout -q pkt-r3-far-word
rm -f "$P"
echo "top $(git rev-parse --short=12 HEAD); #320 top $(git rev-parse --short=12 split-320-321-r3)"

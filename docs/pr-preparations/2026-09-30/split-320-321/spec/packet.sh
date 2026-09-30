#!/usr/bin/env bash
# Rebuild a downstream packet on the split series, then build and test it.
#
# usage: packet.sh NAME BASE_COMMIT PATCH...
#   NAME         label (evidence/pkt-NAME, branch pkt-NAME in the split worktree)
#   BASE_COMMIT  split commit the packet's later patches apply to
#   PATCH        format-patch files, applied in order with `git am -3`
# Records applied commits, the final tree, the build/lit logs and the lit
# summary under evidence/pkt-NAME. Leaves the worktree on branch pkt-NAME.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
NAME=$1 BASE=$2; shift 2
SPLIT=/home/will/llvm-mos-65816/build/split-320-321
REPO=$SPLIT/source
EV=$SPLIT/evidence/pkt-$NAME
mkdir -p "$EV"
git -C "$REPO" checkout -q -B "pkt-$NAME" "$BASE"
# Committer identity and date are fixed so the recorded hashes are reproducible;
# git am keeps each patch's author and author date.
GIT_COMMITTER_NAME="Will Norris" GIT_COMMITTER_EMAIL="will@biohack.net" \
GIT_COMMITTER_DATE="2026-09-30T00:00:00Z" \
  git -C "$REPO" am -q -3 --committer-date-is-author-date "$@" > "$EV/am.log" 2>&1 || {
    echo "git am failed; see $EV/am.log"; git -C "$REPO" am --abort || true; exit 1; }
git -C "$REPO" log --format='%H %s' "$BASE..HEAD" > "$EV/applied.txt"
git -C "$REPO" rev-parse HEAD^{tree} > "$EV/tree"
cat "$EV/applied.txt"; echo "tree $(cat "$EV/tree")"
bash "$SPLIT/spec/build-and-test.sh" "pkt-$NAME" > "$EV.run.log" 2>&1 || true
cat "$EV/lit-summary.txt"

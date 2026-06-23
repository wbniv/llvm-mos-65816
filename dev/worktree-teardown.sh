#!/usr/bin/env bash
# dev/worktree-teardown.sh — the BLESSED way to tear down a feature worktree.
#
# Enforces the worktree-teardown-keep-durable-artifacts policy: reclaim the 95%+
# vendor/+build/ dupes, but NEVER lose the durable tracked work (measure scripts,
# plans/verdicts). It hard-aborts if anything durable isn't already on `main`, then
# `git worktree remove --force` + `git branch -D` and reports the reclaimed space.
#
# Raw `git worktree remove` / `git branch -D wt/…` is blocked by the PreToolUse guard
# (.claude/hooks/guard-worktree-teardown.sh) — use this wrapper instead. This wrapper's
# own internal git removes are a subprocess of a non-matching Bash call, so the guard
# does not fire on them (no bypass flag needed).
#
# Companion policy (feature worktrees): retain until the work merges UPSTREAM — so
# teardown requires an explicit --yes acknowledging it's time (no auto "is it upstream?"
# guess). throwaway/<slug> worktrees (disposable measurements / spikes) are exempt from
# retain-until-upstream, but --yes is still required because teardown is irreversible.
#
# Usage:
#   dev/worktree-teardown.sh <slug|branch> [--dry-run] [--yes]
#     <slug|branch>   bare slug → wt/<slug> (feature); an explicit branch is used
#                     verbatim, e.g. 321-track-a · wt/321-track-a · throwaway/verify-rebuild
#     --dry-run       show what would happen (checks + reclaim figure), remove nothing
#     --yes           confirm it's time + proceed with the (irreversible) removal
set -euo pipefail

usage() {
  # the leading comment block (line 2 to the first code line), '# ' prefix stripped
  awk 'NR>=2 && /^#/ {sub(/^# ?/, ""); print; next} NR>=2 {exit}' "$0"
  exit "${1:-0}"
}
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage 0

ARG=""; DRY=0; YES=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --yes)     YES=1 ;;
    -*)        echo "unknown flag: $a" >&2; usage 1 ;;
    *)         ARG="$a" ;;
  esac
done
[ -n "$ARG" ] || { echo "FATAL: need a worktree slug or branch (e.g. 321-track-a)" >&2; usage 1; }

# Resolve BRANCH + the registered worktree PATH from `git worktree list`. A bare slug
# (no '/') defaults to wt/<slug> (feature worktree); an explicit branch with a prefix
# (wt/<slug>, throwaway/<slug>, …) is used verbatim — so disposable investigation /
# measurement worktrees on throwaway/<slug> tear down via this blessed path too.
case "$ARG" in
  */*) BRANCH="$ARG" ;;
  *)   BRANCH="wt/$ARG" ;;
esac
case "$BRANCH" in throwaway/*) IS_THROWAWAY=1 ;; *) IS_THROWAWAY=0 ;; esac
WT="$(git worktree list --porcelain | awk -v b="refs/heads/$BRANCH" '
  /^worktree /{p=substr($0,10)} $0=="branch "b{print p; exit}')"
[ -n "$WT" ] || { echo "FATAL: no worktree is checked out on branch '$BRANCH'." >&2
                  echo "Registered worktrees:" >&2; git worktree list >&2; exit 1; }
[ -d "$WT" ] || { echo "FATAL: worktree path '$WT' does not exist." >&2; exit 1; }

echo "==> teardown target: $WT  (branch $BRANCH)"

# ── Durability gate 1: unmerged commits on the branch ──────────────────────────
UNMERGED="$(git log --oneline "main..$BRANCH" 2>/dev/null || true)"
if [ -n "$UNMERGED" ]; then
  if [ "$IS_THROWAWAY" -eq 1 ]; then
    echo "WARN: throwaway $BRANCH has commits not on main — teardown will DISCARD them:" >&2
    echo "$UNMERGED" | sed 's/^/    /' >&2
    if [ "$YES" -ne 1 ] && [ "$DRY" -ne 1 ]; then
      echo "  → re-run with --yes to confirm they're disposable (or cherry-pick durable ones to main first)." >&2
      exit 2
    fi
  else
    echo "ABORT: $BRANCH has commits not on main — durable work would be lost:" >&2
    echo "$UNMERGED" | sed 's/^/    /' >&2
    echo "  → cherry-pick / merge them to main first (git cherry-pick … or git merge $BRANCH)." >&2
    exit 2
  fi
fi

# ── Durability gate 2: tracked changes whose content is NOT already on main ────
# A file modified vs the worktree's (possibly stale) HEAD is NOT a loss if its content
# already matches main — e.g. a 0002 regenerated here then copied to main, or any
# durable artifact committed straight to main (this project's workflow). Compare each
# modified tracked file against `main` and flag only the ones that genuinely differ.
LOST=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  git -C "$WT" diff --quiet main -- "$f" 2>/dev/null || LOST="$LOST    $f"$'\n'
done < <(git -C "$WT" status --porcelain=v1 --untracked-files=no 2>/dev/null | cut -c4-)
if [ -n "$LOST" ]; then
  if [ "$IS_THROWAWAY" -eq 1 ]; then
    echo "WARN: throwaway $WT has tracked content not on main — teardown will DISCARD it:" >&2
    printf '%s' "$LOST" >&2
    if [ "$YES" -ne 1 ] && [ "$DRY" -ne 1 ]; then
      echo "  → re-run with --yes to confirm it's disposable (or commit + land it on main first)." >&2
      exit 2
    fi
  else
    echo "ABORT: $WT has tracked content not on main — durable work would be lost:" >&2
    printf '%s' "$LOST" >&2
    echo "  → commit + land it on main first." >&2
    exit 2
  fi
fi

# ── Durability warn: untracked, non-gitignored files under dev/ or docs/ ───────
# (a possibly-durable measure script / verdict not yet `git add`ed). gitignored
# vendor/ + build/ never appear here, so this only flags genuine new content.
UNTRACKED="$(git -C "$WT" status --porcelain=v1 --untracked-files=all 2>/dev/null \
              | sed -n 's/^?? //p' | grep -E '^(dev/|docs/)' || true)"
if [ -n "$UNTRACKED" ]; then
  echo "WARN: untracked files under dev/ or docs/ (rescue them to main if durable):" >&2
  echo "$UNTRACKED" | sed 's/^/    /' >&2
  if [ "$YES" -ne 1 ] && [ "$DRY" -ne 1 ]; then
    echo "  → re-run with --yes to confirm they are disposable, or git add + land them first." >&2
    exit 2
  fi
fi

RECLAIM="$(du -sh "$WT" 2>/dev/null | cut -f1 || echo '?')"
KEPT="$(git -C "$WT" ls-files 'dev/*.sh' 'docs/plans/*.md' 2>/dev/null | wc -l | tr -d ' ')"
echo "==> durability check PASSED — all tracked work is on main."
echo "    reclaimable (vendor/+build/ dupes etc.): $RECLAIM"
echo "    durable keepers retained on main (dev scripts + plans): $KEPT files"

if [ "$DRY" -eq 1 ]; then
  echo "==> --dry-run: would 'git worktree remove --force $WT' + 'git branch -D $BRANCH'. Nothing removed."
  exit 0
fi
if [ "$YES" -ne 1 ]; then
  if [ "$IS_THROWAWAY" -eq 1 ]; then
    echo "POLICY: throwaway worktrees are disposable, but teardown is irreversible." >&2
    echo "  → re-run with --yes to confirm and proceed with the teardown." >&2
  else
    echo "POLICY: retain worktrees until the work merges UPSTREAM." >&2
    echo "  → re-run with --yes to confirm it's time and proceed with the (irreversible) teardown." >&2
  fi
  exit 2
fi

echo "==> removing worktree + branch (reclaims $RECLAIM) ..."
git worktree remove --force "$WT"
git branch -D "$BRANCH"
echo "==> DONE: reclaimed $RECLAIM; durable artifacts remain on main."

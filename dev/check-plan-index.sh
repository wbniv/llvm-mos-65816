#!/usr/bin/env bash
# check-plan-index.sh — drift check for docs/investigations/plan-index.md.
#
# The plan index is one row per docs/plans/*.md, keyed by each plan's *creation
# commit*, with HAND-AUTHORED summaries/categories (see the index footer). This
# script can't write those summaries — it detects when a *committed* plan has no
# row yet and emits the mechanical columns (creation sha + full commit list) plus
# a paste-ready stub, so closing the gap is trivial while the prose stays human.
#
# Exit status: 0 = in sync (or only uncommitted plans), 1 = drift (rows missing).
# It is non-blocking by design — the commit hook surfaces this as a reminder.
#
# Usage:
#   dev/check-plan-index.sh          # report drift (paste-ready stub rows)
#   dev/check-plan-index.sh --quiet  # just the exit status + a one-line summary
set -euo pipefail

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
QUIET=0
for a in "${@:-}"; do
    case "$a" in
        -h|--help) usage ;;
        -q|--quiet) QUIET=1 ;;
        "") ;;
        *) echo "unknown arg: $a" >&2; exit 2 ;;
    esac
done

root=$(git rev-parse --show-toplevel)
cd "$root"

INDEX="docs/investigations/plan-index.md"
PLANS_DIR="docs/plans"
COMMIT_BASE="https://github.com/wbniv/llvm-mos-65816/commit"

[[ -f "$INDEX" ]] || { echo "no $INDEX — nothing to check" >&2; exit 0; }

# Plans already referenced by the index (the ../plans/NAME.md link targets).
indexed=$(grep -oE '\.\./plans/[0-9][^)]*\.md' "$INDEX" | sed 's#\.\./plans/##' | sort -u || true)

missing=()
for f in "$PLANS_DIR"/*.md; do
    base=$(basename "$f")
    # already indexed?
    grep -qxF "$base" <<<"$indexed" && continue
    # only flag COMMITTED plans — an uncommitted draft has no creation sha yet,
    # so it can't be slotted into the commit-keyed index. It'll surface on the
    # commit that introduces it.
    git log --follow --format='%h' -- "$f" 2>/dev/null | grep -q . || continue
    missing+=("$f")
done

if [[ ${#missing[@]} -eq 0 ]]; then
    [[ $QUIET -eq 1 ]] || echo "plan-index.md is in sync ($(grep -cE '^\| \[' "$INDEX") rows)."
    exit 0
fi

echo "plan-index drift: ${#missing[@]} committed plan(s) missing a row in $INDEX"
if [[ $QUIET -eq 1 ]]; then exit 1; fi
echo

for f in "${missing[@]}"; do
    base=$(basename "$f")
    title=$(grep -m1 -E '^# ' "$f" | sed 's/^# //' || true)
    [[ -n "$title" ]] || title="(no H1 title — check $base)"
    # full commit set oldest -> newest, as the index records it
    shas=$(git log --follow --format='%h' -- "$f" | tac)
    links=$(while read -r s; do printf '[`%s`](%s/%s), ' "$s" "$COMMIT_BASE" "$s"; done <<<"$shas")
    links=${links%, }
    printf '  %s\n' "$f"
    printf '  paste-ready row — fill _SUMMARY_ + _CATEGORY_:\n'
    printf '| [%s](../plans/%s) | _SUMMARY_ | %s | _CATEGORY_ |\n\n' "$title" "$base" "$links"
done

cat <<EOF
Add the row(s) to $INDEX in creation-commit order (oldest first; sort key:
'git log --follow --format=%cI -- <plan> | tail -1'), write the one-sentence
summary by hand from each plan's TL;DR, pick a category from the legend, and bump
the footer count/date. Categories are hand-authored — do not auto-fill them.
EOF
exit 1

#!/usr/bin/env bash
# dev/upstream-status.sh — live status of this fork's upstream PRs/issues.
#
# Re-derives the review guide's "Upstream bug fixes & status" appendix (§D) and the
# upstream-contribution-status.md snapshot from GitHub. Read-only (gh queries only).
# On a merge: drop the matching patches/llvm-mos/000N-*.patch and bump the vendor pin.
set -euo pipefail

usage() { echo "Usage: dev/upstream-status.sh   # live state of wbniv's upstream PRs/issues (read-only)"; exit 0; }
if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then usage; fi

command -v gh >/dev/null 2>&1 || { echo "error: gh CLI not found (https://cli.github.com)" >&2; exit 1; }

REPO=llvm-mos/llvm-mos

# Bug-fix PRs that carry a fork patch: PR# -> the patch to drop once it merges.
declare -A PATCH=(
  [562]=0003-late-opt-txy-dead-flag
  [563]=0008-mos-dp-arg-cc
  [586]=0024-mos-brk-signature-operand
  [587]=0025-llvm-mc-preserve-motorola-default
)

echo "== upstream bug-fix PRs (on merge: drop the patch + bump the vendor pin) =="
for pr in "${!PATCH[@]}"; do
  line=$(gh pr view "$pr" --repo "$REPO" --json number,state,title,mergedAt \
           -q '"#\(.number) [\(.state)] \(.title)\(if .mergedAt then "  merged \(.mergedAt)" else "" end)"' \
         2>/dev/null || echo "#$pr (query failed)")
  printf '  %s\n      -> patches/llvm-mos/%s.patch\n' "$line" "${PATCH[$pr]}"
done

echo
echo "== all wbniv upstream PRs =="
gh pr list --repo "$REPO" --author wbniv --state all 2>/dev/null || echo "  (query failed)"
echo "== all wbniv upstream issues =="
gh issue list --repo "$REPO" --author wbniv --state all 2>/dev/null || echo "  (query failed)"

echo
echo "Source of truth (drafted/blocked items + the gh post commands): docs/upstream-contribution-status.md"

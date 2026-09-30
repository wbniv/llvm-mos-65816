#!/usr/bin/env bash
# Count clang-format-diff lines each split commit adds (C++ files only).
#
# usage: format-count.sh LIST_FILE PARENT
#   LIST_FILE  build-series.sh output; PARENT is the first commit's parent.
# Uses the dev container's /opt/llvm-mos/bin/clang-format and
# clang-format-diff.py on `git diff -U0 parent commit`.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
ROOT=/home/will/llvm-mos-65816
REPO=$ROOT/build/split-320-321/source
W=$ROOT/build/split-320-321/fmt
prev=$2
while IFS=$'\t' read -r k c t; do
  case "$k" in TREE*|MC*) continue;; esac
  rm -rf "$W"; mkdir -p "$W"
  files=$(git -C "$REPO" diff --name-only "$prev" "$c" -- '*.cpp' '*.h' || true)
  if [ -z "$files" ]; then echo "$k 0"; prev=$c; continue; fi
  git -C "$REPO" archive "$c" $files .clang-format llvm/.clang-format 2>/dev/null | tar -x -C "$W" || \
    git -C "$REPO" archive "$c" $files | tar -x -C "$W"
  git -C "$REPO" diff -U0 "$prev" "$c" -- $files > "$W/d.patch"
  n=$(cd "$ROOT" && dev/container.sh -- bash -c 'cd /work/build/split-320-321/fmt && python3 /opt/llvm-mos/share/clang/clang-format-diff.py -p1 -binary /opt/llvm-mos/bin/clang-format < d.patch | grep -c "^+[^+]" || true')
  echo "$k $n"
  prev=$c
done < "$1"
rm -rf "$W"

#!/usr/bin/env bash
# Reformat the C++ lines one split commit adds (review finding N3).
#
# usage: carry-format.sh [BASE]
#   BASE  revision whose diff to the working tree is formatted (default HEAD~1)
# Pipes `git diff -U0 BASE -- '*.cpp' '*.h'` of build/split-320-321/source into
# the dev container's clang-format-diff.py -i (with /opt/llvm-mos/bin/clang-format),
# so only lines the commit adds or changes are rewritten, in place. Prints the
# number of changed lines afterwards.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
BASE=${1:-HEAD~1}
ROOT=/home/will/llvm-mos-65816
SRC=$ROOT/build/split-320-321/source
git -C "$SRC" diff -U0 "$BASE" -- '*.cpp' '*.h' > "$SRC/.carry-format.patch"
cd "$ROOT"
dev/container.sh -- bash -c 'set -euo pipefail; cd /work/build/split-320-321/source && python3 /opt/llvm-mos/share/clang/clang-format-diff.py -p1 -i -binary /opt/llvm-mos/bin/clang-format < .carry-format.patch' </dev/null
rm -f "$SRC/.carry-format.patch"
git -C "$SRC" diff --shortstat

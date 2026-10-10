#!/usr/bin/env bash
# usage: newfile-section.sh REL_PATH CONTENT_FILE  -> git new-file diff section on stdout
set -euo pipefail
case "${1-}" in -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
rel=$1; src=$2
tmp=$(mktemp -d -p /home/will/llvm-mos-65816/build/xy16px)
git -C "$tmp" init -q
mkdir -p "$tmp/$(dirname "$rel")"
cp "$src" "$tmp/$rel"
git -C "$tmp" add "$rel"
git -C "$tmp" diff --cached --abbrev=12 -- "$rel"
rm -r "$tmp"

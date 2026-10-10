#!/usr/bin/env bash
# Interesting when the 06bc967d llc aborts with the hint-order assertion.
set -uo pipefail
ulimit -c 0; ulimit -v 2000000
out=$(/home/will/llvm-mos-65816/build/spc700-hint/llc/up-06bc967d -mtriple=mos -mcpu=mosspc700 -O2 "$1" -o /dev/null 2>&1)
[[ "$out" == *'Target hint is outside allocation order'* ]]

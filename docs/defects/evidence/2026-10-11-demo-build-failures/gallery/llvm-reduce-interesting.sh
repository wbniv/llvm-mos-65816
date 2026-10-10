#!/usr/bin/env bash
# Interesting = greedy fails AND the failed vreg is the single-instruction Ac16 transit feeding STAbs16
# (its use is rewritten to `undef $a16`), AND the function still returns its low byte in $a.
ulimit -c 0; ulimit -v 2000000
grep -q 'RTS implicit \$a' "$1" || exit 1
out=$(/home/will/llvm-mos-65816/build/llvm-mos-install/bin/llc -O2 -run-pass=greedy -o - "$1" 2>&1) || true
grep -q "ran out of registers during register allocation" <<<"$out" || exit 1
grep -q 'STAbs16 undef \$a16' <<<"$out" || exit 1
grep -q 'IMPLICIT_DEF' "$1" && exit 1
exit 0

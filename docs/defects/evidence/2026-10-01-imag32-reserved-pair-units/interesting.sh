#!/usr/bin/env bash
# Interesting: base+#594 aborts with "Invalid global physical register" and
# base+#594+quad reservation compiles the same input.
ulimit -c 0; ulimit -v 2000000
L=/work/build/split-320-321/llc
timeout 60 $L/u594 -mtriple=mos -mcpu=mosw65816 -O2 "$1" -o /dev/null 2>&1 | grep -q 'Invalid global physical register' || exit 1
timeout 60 $L/u594-resv -mtriple=mos -mcpu=mosw65816 -O2 "$1" -o /dev/null >/dev/null 2>&1 || exit 1
exit 0

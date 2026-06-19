#!/usr/bin/env bash
# dev/a16loadcall.sh — #321 regression (gcc c-torture pr34768 class): a 16-bit
# abs/indirect load live ACROSS a memory-clobbering call must not be folded into the
# post-call ALU/compare operand (foldableAbsLoad16 / foldableIndirLoad16). Before the
# fix, `tmp = g; clobber(); use(tmp, g)` folded g's load into the post-call use and
# re-read the mutated g -> wrong value (a16@MAME=0xDEAD on pr34768-1/-2 at -Os).
#
# Asserts host == default == +mos-a16 (0x0100) on MAME + bsnes-jg, -verify-machineinstrs
# clean. Host oracle 0x0100 reproducible by host-compiling the shape.
# Drive: dev/run.sh a16loadcall.
# See docs/plans/2026-06-20-321-abs-load-fold-across-call-miscompile.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh a16loadcall   # load-fold-across-call regression (host==default==a16, 0x0100)"; exit 0;; esac
source /work/dev/_check.sh
diff_check a16loadcall 0x0100

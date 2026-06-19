#!/usr/bin/env bash
# dev/a16cmpaudit.sh — #321 Phase-3 differential-audit of the WHOLE native 16-bit
# compare surface (the "harden" half of the indexed-compares plan): 8 predicates x
# {as-value, as-branch} x RHS operand shapes {reg, imm, global, global-array[k],
# pointer[k], stack-array[k]} + the LHS-indexed control, swept over boundary values.
# The RHS-indexed shapes fold to `cmp (zp)` (CMPIndir16); the harness proves the
# whole surface — old + new — agrees 4-way.
#
# Asserts host == default(8-bit) == +mos-a16 (0x5EE0) on MAME + bsnes-jg, with a
# clean -verify-machineinstrs on the +mos-a16 build. The host oracle 0x5EE0 is
# reproducible by host-compiling the harness:
#     cc -DHOST_ORACLE -o /tmp/o examples/65816/a16cmpaudit.c && /tmp/o
# Drive: dev/run.sh a16cmpaudit.
# See docs/plans/2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh a16cmpaudit   # whole-compare-surface differential audit (host==default==a16, 0x5EE0)"; exit 0;; esac
source /work/dev/_check.sh
diff_check a16cmpaudit 0x5EE0

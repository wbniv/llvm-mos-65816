#!/usr/bin/env bash
# dev/a16mix2.sh — #321 Tier-1 combinatorial mixing test. bitwise chain + add-chain + loop shift/xor + signed compare + call
# Asserts host==default==+mos-a16 (0xF0C0) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh a16mix2. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh a16mix2   # bitwise chain + add-chain + loop shift/xor + signed compare + call (differential, 0xF0C0)"; exit 0;; esac
source /work/dev/_check.sh
diff_check a16mix2 0xF0C0

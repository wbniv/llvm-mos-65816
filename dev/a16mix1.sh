#!/usr/bin/env bash
# dev/a16mix1.sh — #321 Tier-1 combinatorial mixing test. add-chain + shift + signed/unsigned compares + call + loop
# Asserts host==default==+mos-a16 (0xE50D) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh a16mix1. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh a16mix1   # add-chain + shift + signed/unsigned compares + call + loop (differential, 0xE50D)"; exit 0;; esac
source /work/dev/_check.sh
diff_check a16mix1 0xE50D

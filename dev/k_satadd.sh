#!/usr/bin/env bash
# dev/k_satadd.sh — #321 Tier-1 realistic kernel. unsigned 16-bit saturating accumulate
# Asserts host==default==+mos-a16 (0xFFFF) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh k_satadd. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_satadd   # unsigned 16-bit saturating accumulate (differential, 0xFFFF)"; exit 0;; esac
source /work/dev/_check.sh
diff_check k_satadd 0xFFFF

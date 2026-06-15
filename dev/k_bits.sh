#!/usr/bin/env bash
# dev/k_bits.sh — #321 Tier-1 realistic kernel. popcount + bit-reverse accumulate
# Asserts host==default==+mos-a16 (0x4223) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh k_bits. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_bits   # popcount + bit-reverse accumulate (differential, 0x4223)"; exit 0;; esac
source /work/dev/_check.sh
diff_check k_bits 0x4223

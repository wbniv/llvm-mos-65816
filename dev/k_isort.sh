#!/usr/bin/env bash
# dev/k_isort.sh — #321 Tier-1 realistic kernel. memcpy + insertion sort + rotate-xor checksum
# Asserts host==default==+mos-a16 (0xF47A) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh k_isort. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_isort   # memcpy + insertion sort + rotate-xor checksum (differential, 0xF47A)"; exit 0;; esac
source /work/dev/_check.sh
diff_check k_isort 0xF47A

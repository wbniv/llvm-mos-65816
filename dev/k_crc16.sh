#!/usr/bin/env bash
# dev/k_crc16.sh — #321 Tier-1 realistic kernel. CRC16-CCITT over 123456789
# Asserts host==default==+mos-a16 (0x29B1) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh k_crc16. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_crc16   # CRC16-CCITT over 123456789 (differential, 0x29B1)"; exit 0;; esac
source /work/dev/_check.sh
diff_check k_crc16 0x29B1

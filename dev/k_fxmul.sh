#!/usr/bin/env bash
# dev/k_fxmul.sh — #321 Tier-1 realistic kernel. Q8.8 fixed-point multiply via 16x16 shift-add
# Asserts host==default==+mos-a16 (0x0020) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh k_fxmul. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_fxmul   # Q8.8 fixed-point multiply via 16x16 shift-add (differential, 0x0020)"; exit 0;; esac
source /work/dev/_check.sh
diff_check k_fxmul 0x0020

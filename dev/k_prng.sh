#!/usr/bin/env bash
# dev/k_prng.sh — #321 Tier-1 realistic kernel. xorshift16 PRNG iterated across a noinline call boundary
# Asserts host==default==+mos-a16 (0xE00F) on MAME + bsnes-jg, -verify-machineinstrs clean.
# Drive: dev/run.sh k_prng. See docs/plans/2026-06-15-321-tier1-broaden-corpus.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_prng   # xorshift16 PRNG iterated across a noinline call boundary (differential, 0xE00F)"; exit 0;; esac
source /work/dev/_check.sh
diff_check k_prng 0xE00F

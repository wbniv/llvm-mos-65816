#!/usr/bin/env bash
# dev/a16ashift8.sh — #321 regression: signed (arithmetic) >> by amount >= 8.
# This shape HUNG the +mos-a16 backend (the >=8 byte path computed its sign-fill with
# an s16 ICMP_SLT that re-entered the native signed-compare legalization and looped);
# fixed by an 8-bit sign broadcast. Found + minimized by the Tier-1 differential fuzzer.
# Asserts host==default==+mos-a16 (0x001F) on MAME + bsnes-jg, -verify-machineinstrs clean.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh a16ashift8   # signed >>8/>>13 regression (no compile hang), 0x001F"; exit 0;; esac
source /work/dev/_check.sh
diff_check a16ashift8 0x001F

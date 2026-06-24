#!/usr/bin/env bash
# dev/k_mandel.sh — #321 beefy demo (gate slice). Fixed-point Mandelbrot escape-time
# over a small GATE grid (examples/65816/k_mandel.c), CRC16-CCITT'd into corpus_result.
# Asserts host(baked)==default==+mos-a16 (0x820B) on MAME + bsnes-jg, -verify clean.
#
# The fill must COMPLETE before corpus_result is sampled, so bump SMOKE_SETTLE to 170
# frames (just under MAME's hardcoded 180-frame `-seconds_to_run 3` backstop; bsnes-jg
# settles at 180). If the gate ever reads a wrong/partial CRC, the grid is too big for
# the window — shrink GATE_W/H/N in k_mandel.c (and re-bake via `mandel-render --gate`).
#
# Baked 0x820B is the INDEPENDENT host oracle: tools/mandel-render --gate at the same
# GATE_W/GATE_H/GATE_N (24x16, N=12). Re-derive after any kernel/grid change.
# Drive: dev/run.sh k_mandel. See docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md.
set -euo pipefail
case "${1-}" in -h|--help) echo "Usage: dev/run.sh k_mandel   # fixed-point Mandelbrot escape-time (differential, 0x820B)"; exit 0;; esac
export SMOKE_SETTLE="${SMOKE_SETTLE:-170}"
source /work/dev/_check.sh
diff_check k_mandel 0x820B

// #321 beefy demo (gate slice) — fixed-point Mandelbrot under the differential gate.
//
// Fills a small GATE grid with escape counts (Q5.10 fixed point; see mandel.h),
// CRC16-CCITT's the whole buffer, and parks the CRC in corpus_result. The grid is
// kept SMALL on purpose: the differential harness (tools/a16_fuzz.py) boots MAME
// with `-seconds_to_run 3` (~180 frames, a shared hang-backstop), so the fill must
// COMPLETE before corpus_result is sampled. This still exercises the identical
// multiply-heavy inner loop (3x 16x16->32 per iter, zr/zi live across the loop) —
// "beefy" is the loop shape, not the pixel count. The full-resolution pretty image
// is rendered host-side (tools/mandel-render.c) and on-console (mandel-display.c)
// from the SAME mandel.h, at a larger grid with no time bound.
//
// Differential bar: host(baked) == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg,
// -verify-machineinstrs clean. The baked --expected comes from tools/mandel-render.c
// run at the SAME GATE_W/GATE_H/GATE_N (its `--gate` mode), not hand-derived.
//
// Drive: dev/run.sh k_mandel
#include "mandel.h"

// Gate grid — sized to finish inside the harness window (MEASURED, not assumed): the
// default-8bit SNES build completes the fill at frame ~125, comfortably before the
// harness samples corpus_result (SMOKE_SETTLE=170; MAME -seconds_to_run 3 == 180
// frames; bsnes-jg settles at 180). +mos-a16 finishes earlier (16-bit ops are fewer).
// 24x16 N=12 took frame 311 -> overran the window -> read 0 -> shrunk to 16x10.
#define GATE_W 16
#define GATE_H 10
#define GATE_N 12

static uint8_t fb[GATE_W * GATE_H];          // .bss, 160 B (low WRAM)
volatile uint16_t corpus_result;

int main(void) {
  mandel_fill(fb, GATE_W, GATE_H, GATE_N);
  corpus_result = mandel_crc(fb, (uint16_t)(GATE_W * GATE_H));
  for (;;) {}
}

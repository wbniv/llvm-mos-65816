// #3 Blossom — Stage 1: the headless far read-modify-write GRID gate (no display).
//
// This is "mandel-far for Blossom": it proves the NEW +mos-a16 codegen customer the on-screen
// renderer depends on, with zero display risk. It plots K_GATE Hopalong orbit points (classic
// params, from (0,0)) into a HIGH-WRAM hit-count grid via the far path — each point does a far
// read-modify-write (lda [dp] / saturate-compare / inc / sta [dp]) at a RUNTIME-computed index
// (the coordinate map output, so the 24-bit pointer cannot fold to absolute-long) — then rolls a
// hash over the whole grid via far loads and parks it in NEAR corpus_result (which the harness
// samples). A correct hash proves every far RMW carried, host == +mos-a16.
//
// The grid is "Rung A": 128x128 = 16 KiB at $7E2000 (the mandel-mode7 buffer slot), 1:1 with the
// eventual Mode 7 display. A far pointer is a 32-bit value ⇒ +mos-a16-only (default-8bit legitimately
// can't compile it), so the differential is host == +mos-a16 on MAME + bsnes-jg.
//
// Drive: dev/run.sh blossom-grid.  Plan: docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md.
#define HOP_GRID 128                              // Rung A: 16 KiB grid in $7E2000
#define HOP_NOINLINE __attribute__((noinline))    // bound +mos-a16 pressure on the far-RMW path
#include "hopalong.h"

#define K_GATE 4000        // deterministic plotted-point count — independent of emulator frame
                          // timing (sampled after it completes). Tuned to finish in the window
                          // AND drive some hot-pixel saturation (see the host oracle's report).

// Classic params, VOLATILE so the optimizer can't fold the whole orbit to a constant grid.
volatile short pa = HOP_A_CLASSIC, pb = HOP_B_CLASSIC, pc = HOP_C_CLASSIC;

#ifdef HOST
#include <stdio.h>
long g_hop_maxabs = 0;
int  g_hop_clamps = 0;
static uint8_t host_grid[HOP_GRID * HOP_GRID];
HOP_DEFINE_CLEAR(grid_clear, /*near*/)
HOP_DEFINE_PLOT (grid_plot,  /*near*/)
HOP_DEFINE_HASH (grid_hash,  /*near*/)
int main(void) {
  grid_clear(host_grid);
  grid_plot(host_grid, pa, pb, pc, K_GATE);
  long hits = 0, sat = 0;
  for (long i = 0; i < HOP_GRID * HOP_GRID; i++) { if (host_grid[i]) hits++; if (host_grid[i] == 255) sat++; }
  fprintf(stderr, "host grid: maxabs=%ld clamps=%d  cells_hit=%ld/%d  saturated=%ld\n",
          g_hop_maxabs, g_hop_clamps, hits, HOP_GRID * HOP_GRID, sat);
  printf("0x%04X\n", grid_hash(host_grid));        // the golden grid hash
  return 0;
}
#else
#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 16 KiB far grid (Rung A)
HOP_DEFINE_CLEAR(grid_clear, FAR)
HOP_DEFINE_PLOT (grid_plot,  FAR)
HOP_DEFINE_HASH (grid_hash,  FAR)
volatile uint16_t corpus_result;                  // near (low WRAM) — the harness reads this
int main(void) {
  grid_clear(grid);                               // WRAM is not zeroed at boot (bsnes randomises)
  grid_plot(grid, pa, pb, pc, K_GATE);            // far RMW accumulation
  corpus_result = grid_hash(grid);                // far-load hash == host reference
  for (;;) {}
}
#endif

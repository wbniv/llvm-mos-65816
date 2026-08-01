// #4 Buddhabrot — the headless far SCATTER-WRITE density-grid gate (no display).
//
// "mandel-far / blossom-grid for Buddhabrot": it proves the +mos-a16 far codegen customer the
// on-screen renderer depends on, with zero display risk. It draws K_GATE random complex samples
// (deterministic xorshift16, fixed seed), iterates z^2+c, and for the ESCAPING orbits replays the
// orbit into a HIGH-WRAM 128x128 hit-count grid via the far path — each visited point is a far
// read-modify-write (lda [dp] / saturate-compare / inc / sta [dp]) at a RUNTIME-computed index (the
// orbit-coordinate map output, so the 24-bit pointer cannot fold to absolute-long) — then rolls a
// hash over the whole grid via far loads and parks it in NEAR corpus_result (which the harness
// samples). A correct hash proves every far scatter-write carried, host == +mos-a16.
//
// The grid is 128x128 = 16 KiB at $7E2000 (the mandel/blossom buffer slot), 1:1 with the eventual
// Mode 7 display. A far pointer is a 32-bit value => +mos-a16-only (default-8bit legitimately can't
// compile it), so the differential is host == +mos-a16 on MAME + bsnes-jg.
//
// Drive: dev/run.sh buddha-grid.  Plan: docs/plans/2026-06-28-4-snes-buddhabrot.md.
#define BUD_GRID 128                              // 16 KiB grid in $7E2000
#include "buddha.h"

#ifndef K_GATE
#define K_GATE 2000        // deterministic sample count — independent of emulator frame timing
                          // (sampled after it completes). Overridable so this same file is the HOST
                          // ORACLE for examples/snes/buddha.c (build -DK_GATE=K_BLOOM -DHOST).
#endif

#ifndef BUD_SEED
#define BUD_SEED 0xC0DEu   // fixed PRNG seed -> a single golden grid both sides reproduce
#endif

#ifdef HOST
#include <stdio.h>
static uint8_t host_grid[BUD_GRID * BUD_GRID];
BUD_DEFINE_CLEAR(grid_clear, /*near*/)
BUD_DEFINE_PLOT (grid_plot,  /*near*/)
BUD_DEFINE_ACCUM(grid_accum, /*near*/, grid_plot)
BUD_DEFINE_HASH (grid_hash,  /*near*/)
int main(void) {
  bud_rng rng; bud_rng_init(&rng, BUD_SEED);
  grid_clear(host_grid);
  grid_accum(host_grid, &rng, (uint16_t)K_GATE);
  long hits = 0, sat = 0, mx = 0;
  for (long i = 0; i < BUD_GRID * BUD_GRID; i++) {
    if (host_grid[i]) hits++;
    if (host_grid[i] == 255) sat++;
    if (host_grid[i] > mx) mx = host_grid[i];
  }
  fprintf(stderr, "host grid: K_GATE=%d  cells_hit=%ld/%d  max=%ld  saturated=%ld\n",
          (int)K_GATE, hits, BUD_GRID * BUD_GRID, mx, sat);
  printf("0x%04X\n", grid_hash(host_grid));        // the golden grid hash
  return 0;
}
#else
#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 16 KiB far density grid
BUD_DEFINE_CLEAR(grid_clear, FAR)
BUD_DEFINE_PLOT (grid_plot,  FAR)
BUD_DEFINE_ACCUM(grid_accum, FAR, grid_plot)
BUD_DEFINE_HASH (grid_hash,  FAR)
volatile uint16_t corpus_result;                  // near (low WRAM) — the harness reads this
int main(void) {
  bud_rng rng; bud_rng_init(&rng, BUD_SEED);
  grid_clear(grid);                               // WRAM is not zeroed at boot (bsnes randomises)
  grid_accum(grid, &rng, (uint16_t)K_GATE);       // far scatter-write accumulation
  corpus_result = grid_hash(grid);                // far-load hash == host reference
  for (;;) __asm__ volatile("wai");
  return 0;
}
#endif

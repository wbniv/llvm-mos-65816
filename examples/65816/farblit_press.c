// #321 Phase 2 inc 2 — the 16-bit-Y `[dp],Y` fold UNDER REGISTER PRESSURE (dev/run.sh farblit, step 6).
//
// Under +mos-xy16 the fold loads a 16-bit index into Y and dereferences `[dp],y` inside a
// rep #$10 / sep #$10 bracket. If ANY 8-bit X/Y instruction lands between that `ldy` and its use,
// MOSInsertREPSEP gives it a `sep #$10`, which ZEROES Y's high byte: the access silently hits the
// wrong address. A spill reload of the far base quad (`ldx spill / stx __rcN`) is exactly such an
// instruction. The fused pseudo keeps `ldy` and the access together until emission,
// so the reload must precede the pair.
//
// This fixture forces that situation: a far base passed as a RUNTIME pointer, live across a
// noinline hop_step() CALL in every iteration (so it is spilled), then ONE far load at a 16-bit
// index computed after the call — a single access with no call between the index and the access,
// which the fold's gates (e)/(f) accept. The grid is first filled through the same pointer (a
// call-free single-store loop, also a 16-bit-Y fold). corpus_result is a rolling hash of the
// sampled cells; the host oracle runs the same shared hopalong.h orbit.
//
// Under +mos-a16 alone the 16-bit index does not fold (a correctness probe only).
#define HOP_GRID 128
#define HOP_NOINLINE __attribute__((noinline))
#include "hopalong.h"
#include <stdint.h>

#define K_PTS 1500
volatile short pa = HOP_A_CLASSIC, pb = HOP_B_CLASSIC, pc = HOP_C_CLASSIC;
volatile uint32_t gbase = 0x7E2000u; // runtime far grid pointer (high WRAM, 16 KiB)

#ifdef HOST
long g_hop_maxabs = 0;
int g_hop_clamps = 0;
#define GQ /* near */
#else
#define GQ __attribute__((address_space(2)))
#endif

__attribute__((noinline)) static void fill(GQ uint8_t *g) {
  uint16_t i = 0;
  do {
    g[i] = (uint8_t)(i ^ (i >> 7));
  } while (++i != HOP_NCELLS);
}

__attribute__((noinline)) static uint16_t sample(GQ uint8_t *g, short a, short b, short c) {
  hop_pt p = {0, 0};
  uint16_t h = 0;
  for (uint16_t n = 0; n < K_PTS; n++) {
    hop_step(&p, a, b, c); // CALL: the far base is live across it
    int16_t px = hop_map(p.x), py = hop_map(p.y);
    if ((uint16_t)px < (uint16_t)HOP_GRID && (uint16_t)py < (uint16_t)HOP_GRID) {
      uint16_t idx = (uint16_t)((unsigned)py * HOP_GRID + (unsigned)px);
      h = (uint16_t)((((unsigned)h << 1) | ((unsigned)h >> 15)) ^ (unsigned)g[idx]); // ONE far load
    }
  }
  return h;
}

#ifdef HOST
#include <stdio.h>
static uint8_t host_grid[HOP_NCELLS];
int main(void) {
  fill(host_grid);
  printf("0x%04X\n", sample(host_grid, pa, pb, pc));
  return 0;
}
#else
volatile uint16_t corpus_result;
int main(void) {
  GQ uint8_t *g = (GQ uint8_t *)gbase;
  fill(g);
  corpus_result = sample(g, pa, pb, pc);
  for (;;) __asm__ volatile("wai");
}
#endif

// #321 realistic kernel — Barry Martin's "Hopalong" strange attractor in Q8.8
// fixed point. This is the math heart of Blossom (the 1989 Turbo Pascal "wallpaper
// for the mind" shareware, and its 2026 web recreation), ported to the 65816 the way
// the original ran on a 286: no FPU, fixed-point integer math, and a precomputed
// square-root table (BLOSSOM.TBL). Phase 1 of the SNES port is HEADLESS — it runs the
// orbit and folds it to a checksum; the on-screen Mode-7 renderer is #3.
// Plans: docs/plans/2026-06-24-blossom-snes.md (Phase 1),
//        docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md (renderer).
//
//   x' = y - sign(x) * sqrt(|b*x - c|)      y' = a - x        (iterate from 0,0)
//
// The orbit math is the SHARED examples/65816/hopalong.h (hop_step), so the headless
// kernel and the on-screen renderer fold the SAME source of truth through the
// differential. a,b,c are VOLATILE so the whole loop can't be constant-folded away.
//
// Differential: host == default(8-bit) == +mos-a16, on MAME and bsnes-jg.
// Driven by dev/run.sh k_hopalong.
#include "hopalong.h"

#define ITERS 1024              // codegen is identical for any N>=1; N only sets runtime
                               // + how well the checksum mixes. 1024 finishes well inside
                               // the MAME settle window (~1 s) with headroom.

// Classic Hopalong parameters (Blossom's default), as Q8.8 constants. Volatile so the
// optimizer must actually run the orbit instead of folding it to a literal.
volatile short pa = HOP_A_CLASSIC;    // a = 7.17
volatile short pb = HOP_B_CLASSIC;    // b = 8.44
volatile short pc = HOP_C_CLASSIC;    // c = 2.56

#ifdef HOST
long g_hop_maxabs = 0;         // host-only: largest |x|,|y| seen (must stay < 32768)
int  g_hop_clamps = 0;         // host-only: times the LUT index saturated (want 0)
#endif

static unsigned short hopalong_run(void) {
  hop_pt p = { 0, 0 };
  unsigned short acc = 0xACE1;                     // checksum seed (cf. k_isort.c)
  for (unsigned short i = 0; i < ITERS; i++) {
    short a = pa, b = pb, c = pc;                  // volatile reads each iteration
    hop_step(&p, a, b, c);                         // shared orbit step (hopalong.h)
    // rotate-left-1 then xor in the new point (x, and y<<1) — the k_isort rotate-xor
    // idiom; sensitive to any single-bit arithmetic divergence between builds.
    acc = (unsigned short)(((unsigned)acc << 1) | ((unsigned)acc >> 15));
    acc = (unsigned short)(acc ^ (unsigned short)p.x ^
                           (unsigned short)((unsigned)(unsigned short)p.y << 1));
  }
  return acc;
}

#ifdef HOST
#include <stdio.h>
int main(void) {
  unsigned short r = hopalong_run();
  fprintf(stderr, "host oracle: maxabs=%ld (Q8.8 ~ %.2f world units), clamps=%d\n",
          g_hop_maxabs, g_hop_maxabs / 256.0, g_hop_clamps);
  printf("0x%04X\n", r);                           // the golden corpus_result
  return 0;
}
#else
volatile unsigned short corpus_result;
int main(void) {
  corpus_result = hopalong_run();
  for (;;) __asm__ volatile("wai");
}
#endif

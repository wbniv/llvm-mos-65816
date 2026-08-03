/* nmitally.h — #123 VBlank Interrupt Tally: the logic shared by the NMI handler, the SNES main
 * loop, the HAL-free corpus slice and the host oracle.
 *
 * Portable C99, <stdint.h> only, no bare `int` (32-bit on host, 16-bit on the 65816).
 *
 * OWNERSHIP IS THE DETERMINISM CONTRACT (see docs/plans/2026-08-03-123-snes-nmitally.md):
 *   NmiTallyState  is written ONLY by the interrupt handler; main reads it only at the fence.
 *   NmiWorkState   is written ONLY by the main loop; the handler never touches it.
 * Because neither side reads the other's state while it is mutating, the pair after tick i is a
 * function of i alone — independent of where inside work_step() the NMI happened to land. That is
 * what lets the host oracle run the same steps sequentially and still be exact.
 *
 * NmiTallyState is qualified `volatile` at every use site: it is shared with an asynchronous
 * handler, so C requires the accesses to be volatile (nothing else forces a reload across the
 * arm/spin fence — the compiler can prove nmi() is never *called* from main). The work state is
 * deliberately NOT volatile so main's arithmetic keeps register residency and long `rep #$20`
 * brackets — the wide window the NMI needs to land inside for this demo to mean anything. */
#ifndef NMITALLY_H
#define NMITALLY_H

#include <stdint.h>

/* Gate length: number of fenced tally ticks folded into corpus_result. One tick = one v-blank on
 * the console, so 240 ticks ≈ 4 s NTSC — comfortably inside the frame-500 snapshot after the
 * ~110-frame title card. */
#define NMITALLY_TICKS 240u

/* ISR-owned counters. 16-bit tick count + 32-bit accumulator + the handler's own xorshift16. */
typedef struct {
  uint16_t ticks;
  uint32_t accum;
  uint16_t lfsr;
} NmiTallyState;

/* Main-loop-owned workload state. 16-bit LCG feeding a 16x16->32 multiply accumulator. */
typedef struct {
  uint16_t wa;
  uint16_t wb;
  uint32_t wacc;
} NmiWorkState;

static inline void nmitally_tally_init(volatile NmiTallyState *t) {
  t->ticks = 0u;
  t->accum = 0uL;
  t->lfsr  = 0xACE1u;
}

static inline void nmitally_work_init(NmiWorkState *w) {
  w->wa   = 0x1234u;
  w->wb   = 0x89ABu;
  w->wacc = 0uL;
}

/* One tally step — this is the body that runs INSIDE the NMI handler.
 * xorshift16 (three native 16-bit shifts under +mos-a16) + a 16-bit increment + a 32-bit add.
 * Every access is volatile, so each one is a real load/store through the Imag ZP file — which is
 * precisely the register set the handler's prologue has to save and restore. */
static inline void nmitally_isr_step(volatile NmiTallyState *t) {
  uint16_t r = t->lfsr;
  r ^= (uint16_t)(r << 7);
  r ^= (uint16_t)(r >> 9);
  r ^= (uint16_t)(r << 8);
  t->lfsr = r;
  uint16_t n = (uint16_t)(t->ticks + 1u);
  t->ticks = n;
  t->accum = (uint32_t)(t->accum + (uint32_t)r + ((uint32_t)n << 3));
}

/* One main-loop workload step. 16-bit multiply-add + a 16x16->32 multiply accumulate (__mulsi3):
 * a long `rep #$20` bracket for the NMI to land in the middle of. */
static inline void nmitally_work_step(NmiWorkState *w) {
  uint16_t a = (uint16_t)((uint16_t)(w->wa * 25173u) + 13849u);
  uint16_t b = (uint16_t)(w->wb ^ (uint16_t)(a >> 3));
  w->wa = a;
  w->wb = b;
  w->wacc = (uint32_t)(w->wacc + (uint32_t)((uint32_t)a * (uint32_t)b));
}

/* Fold one tick's state into the rolling CRC: four rotate-left-1 + XOR rounds so that a wrong
 * tick COUNT (not just a wrong value) changes the result. */
static inline uint16_t nmitally_fold(uint16_t h, volatile const NmiTallyState *t,
                                     const NmiWorkState *w) {
  uint32_t acc = t->accum;
  h = (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15)) ^ t->ticks);
  h = (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15)) ^ (uint16_t)acc);
  h = (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15)) ^ (uint16_t)(acc >> 16));
  h = (uint16_t)((uint16_t)((uint16_t)(h << 1) | (uint16_t)(h >> 15)) ^
                 (uint16_t)((uint16_t)w->wacc ^ (uint16_t)(w->wacc >> 16) ^ w->wa ^ w->wb));
  return h;
}

/* The oracle: the identical sequence the fenced console loop performs — work_step, then isr_step,
 * then fold — run sequentially. Exact, not an approximation (see the plan's determinism review). */
static inline uint16_t nmitally_gate_crc(void) {
  NmiTallyState t;
  NmiWorkState  w;
  uint16_t h = 0u;
  nmitally_tally_init(&t);
  nmitally_work_init(&w);
  for (uint16_t i = 0u; i < (uint16_t)NMITALLY_TICKS; i++) {
    nmitally_work_step(&w);
    nmitally_isr_step(&t);
    h = nmitally_fold(h, &t, &w);
  }
  return h;
}

#endif /* NMITALLY_H */

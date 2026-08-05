// VBlank Interrupt Tally (#123) — shared deterministic model.
#ifndef NMITALLY_H
#define NMITALLY_H

#include <stdint.h>

#define NMITALLY_FRAMES 120u

static inline uint32_t nmitally_step32(uint32_t v, uint16_t frame) {
    return (uint32_t)(v + (uint32_t)0x00010001u + (uint32_t)frame);
}

static inline uint16_t nmitally_fold(uint16_t h, uint8_t v) {
    return (uint16_t)((uint16_t)((h << 5) | (h >> 11)) ^ (uint16_t)v);
}

static uint16_t nmitally_model(uint16_t frames, uint32_t *wide_out) {
    uint16_t tally = 0u;
    uint32_t wide = (uint32_t)0x13579BDFu;
    for (uint16_t frame = 1u; frame <= frames; frame++) {
        tally = (uint16_t)(tally + 1u);
        wide = nmitally_step32(wide, frame);
    }
    uint16_t h = (uint16_t)0x4E4Du;
    h = nmitally_fold(h, (uint8_t)tally);
    h = nmitally_fold(h, (uint8_t)(tally >> 8));
    h = nmitally_fold(h, (uint8_t)wide);
    h = nmitally_fold(h, (uint8_t)(wide >> 8));
    h = nmitally_fold(h, (uint8_t)(wide >> 16));
    h = nmitally_fold(h, (uint8_t)(wide >> 24));
    if (wide_out) *wide_out = wide;
    return h;
}

/* ---- 240-tick oracle form (the corpus slice's gate) --------------------------------------------
 * Restored 2026-08-05 from 5b80b02: commit c9e0f12 ("record the published demo files + review
 * hardening") replaced this header with the simplified demo model above and silently dropped
 * everything below, while examples/snes/corpus/nmitally_sim.c and expected.tsv (0xBCE6, "240
 * fenced ticks") still depended on it. The original 3-arg fold is renamed nmitally_gate_fold to
 * coexist with the 2-arg nmitally_fold above. */

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
static inline uint16_t nmitally_gate_fold(uint16_t h, volatile const NmiTallyState *t,
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
    h = nmitally_gate_fold(h, &t, &w);
  }
  return h;
}

#endif

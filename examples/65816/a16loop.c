// #321 native s16 — cross-block REP/SEP mode-tracking: the must-win loop case.
//
// A natural loop whose body is genuinely, entirely 16-bit. The bounds are read
// from volatile globals ONCE into 16-bit zero-page locals before the loop (the
// only byte-wise loads, and they sit in the preheader); inside the loop the
// accumulate `acc += s` and the test `acc < lim` are pure 16-bit-accumulator ops
// on those locals (lda/adc/sta and lda/cmp — the forms proven by a16local /
// a16cmp) with NO byte-wise copies.
//
// This formulation matters: a 16-bit value reloaded from a *volatile* each
// iteration is fetched byte-wise (ldx/ldy) and an 8-bit loop counter lives in the
// X/Y pair (inx/iny) — either injects a genuine 8-bit op mid-loop. Hoisting the
// volatile reads out and looping on plain 16-bit locals keeps the body one width.
//
// With per-block 8-bit anchoring the old pass re-ran `rep … sep` every iteration.
// With cross-block mode propagation the body holds 16-bit mode across iterations:
// the `rep` hoists to the preheader and the `sep` sinks to the loop exit, with NO
// rep/sep inside the loop body.
//
// `step` and `limit` are volatile so the trip count can't be folded. acc adds
// step until acc >= limit (0x2340): the multiples of 0x0234 reach exactly 0x2340
// at the 16th, so corpus_result == 0x2340. The low byte carries into the high
// byte, so a broken 8-bit-only accumulate would read wrong.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 -mattr=+mos-a16 -Os a16loop.c
// See docs/plans/2026-06-15-321-cross-block-repsep-mode-tracking.md.

volatile unsigned short step = 0x0234;
volatile unsigned short limit = 0x2340;
volatile unsigned short corpus_result;

int main(void) {
  unsigned short s = step;    // bring the bounds into 16-bit zp locals ONCE,
  unsigned short lim = limit; // outside the loop (the only byte-wise loads)
  unsigned short acc = s;
  while (acc < lim) // 16-bit compare on zp locals (M16, no byte copies)
    acc += s;       // 16-bit accumulate on zp locals (M16)
  corpus_result = acc; // 0x2340 (16 * 0x0234)
  for (;;) __asm__ volatile("wai");
}

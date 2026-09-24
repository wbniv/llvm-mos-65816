// #321 Phase 2 inc 1 GATE — `lda [dp],y` (b7) ACROSS A BANK BOUNDARY.
//
// The whole increment rests on one hardware claim: `[dp],Y` forms its effective address as
// (the 24-bit pointer at dp) + Y and the carry propagates INTO THE BANK BYTE — it does not
// wrap within the bank the way `(dp),Y` does. That is what makes it an exact replacement for
// the 32-bit pointer add + `lda [dp]` it supersedes
// (docs/plans/2026-09-25-dpy-indexed-phase2-increment1.md §3.3).
//
// `dev/run.sh farindex` cannot test it. Its `tbl` is `uint16_t` based at $C10000, so element i
// sits at the EVEN byte offset 2i and its high byte at 2i+1 — a 16-bit element read can never
// straddle $xxFFFF. This fixture reads `tbl` through a BYTE pointer as an unaligned 32-bit
// value at offsets chosen so the bank boundary falls INSIDE the four bytes, i.e. the Y=2 and
// Y=3 displacements are exactly the carry into the next bank:
//
//   byteoff 65534  -> $C1FFFE $C1FFFF | $C20000 $C20001     (bank $C1 -> $C2)
//   byteoff 131070 -> $C2FFFE $C2FFFF | $C30000 $C30001     (bank $C2 -> $C3)
//
// Reading four bytes also exercises the whole Y window the increment folds, Y ∈ {1,2,3}, in
// one access — `lda [dp]` for byte 0 then `lda [dp],y` three times off the SAME Imag32 quad.
//
// THE OFFSETS ARE CHOSEN SO A BANK-WRAP IS DETECTED. A `[dp],Y` that wrapped inside the bank
// would read $C10000/$C10001 for probe A instead of $C20000/$C20001. Those two bank-base LOW
// bytes are both 0x00 under the value contract below — so a 16-bit read straddling the
// boundary would ALIAS and pass a broken compiler. The bank-base HIGH bytes differ (0x00 vs
// 0x80 vs 0x00-at-$C3-with-low-0x01), which is why the read is 4 bytes wide, not 2.
//
// Reuses `farindex`'s generated table (tools/gen-farindex-lut-asm.py) and its snes-hirom
// platform, so it shares that fixture's VALUE CONTRACT: tbl[i] = (i + (i >> 16)) & 0xFFFF,
// little-endian in .far_rodata based at $C10000. The host oracle recomputes the expected bytes
// from that closed form rather than hardcoding them twice.
//
// a16-only, like every other far_* test: a runtime far pointer is a 32-bit value, so the far
// load needs +mos-a16. The differential is host == +mos-a16 on MAME + bsnes-jg.
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// VOLATILE so the offsets are runtime values: the far pointer must be computed at run time
// (-> Imag32 quad + `lda [dp]`), never constant-folded into an absolute-long address.
volatile uint32_t b0 = 65534;  // $C1FFFE .. $C20001
volatile uint32_t b1 = 131070; // $C2FFFE .. $C30001

#ifndef HOST
extern const FAR uint16_t tbl[];

// Four adjacent BYTES off ONE runtime far pointer — the zero-proof sub-case at every
// displacement it folds. p[0] keeps `lda [dp]` (displacement 0 needs no Y); p[1], p[2], p[3]
// fold to `lda [dp],y` with Y = 1, 2, 3.
static uint32_t read32(uint32_t byteoff) {
  const FAR uint8_t *p = (const FAR uint8_t *)tbl + byteoff;
  return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
         ((uint32_t)p[3] << 24);
}
#else
// Host has no addrspace 2; reproduce the generator's closed form byte-wise.
static uint16_t tblv(uint32_t i) { return (uint16_t)((i + (i >> 16)) & 0xFFFFu); }
static uint8_t byteat(uint32_t b) {
  uint16_t v = tblv(b >> 1);
  return (b & 1u) ? (uint8_t)(v >> 8) : (uint8_t)v;
}
static uint32_t read32(uint32_t byteoff) {
  return (uint32_t)byteat(byteoff) | ((uint32_t)byteat(byteoff + 1u) << 8) |
         ((uint32_t)byteat(byteoff + 2u) << 16) |
         ((uint32_t)byteat(byteoff + 3u) << 24);
}
#endif

static inline uint32_t fold(uint32_t acc, uint32_t v) {
  acc = (acc << 1) | (acc >> 31); // rotate-left-1
  return acc ^ v;
}

static uint32_t run(void) {
  uint32_t acc = 0;
  acc = fold(acc, read32(b0)); // straddles $C1 -> $C2
  acc = fold(acc, read32(b1)); // straddles $C2 -> $C3
  return acc;                  // host oracle is the source of truth
}

#ifdef HOST
#include <stdio.h>
int main(void) {
  printf("0x%08lX\n", (unsigned long)run());
  return 0;
}
#else
// target: write the checksum to WRAM and spin while the emulator settles.
volatile uint32_t corpus_result;
int main(void) {
  corpus_result = run();
  for (;;) __asm__ volatile("wai");
}
#endif

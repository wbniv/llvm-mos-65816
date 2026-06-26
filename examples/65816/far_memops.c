// #320/#321 — far (addrspace 2) memset/memcpy must land in the RIGHT BANK.
//
// THE BUG this gates: a far memop that the backend can't inline-expand (variable
// size, or constant size over MOSLegalizerInfo's SizeLimit) used to fall through
// `legalizeMemOp` into the generic `createMemLibcall`, which calls the NEAR
// runtime (__memset / memcpy, 16-bit char*) while handing it the 32-bit far
// pointer — the bank byte was silently dropped, so the bytes landed in bank $00
// (PPU/IO/low-WRAM) instead of the intended high-WRAM bank $7E. No crash, no
// diagnostic: a silent wrong-bank store. The fix routes far memops to a far-aware
// runtime (__memset_far / __memcpy_far) so the full 24-bit address survives.
//
// This test exercises BOTH independent producers of a far mem-intrinsic — the
// ones a "block the loop-idiom recognizer" fix would only half-cover:
//   (1) a strided far-store LOOP with a runtime length  -> loop-idiom forms
//       llvm.memset.p2 with a VARIABLE size (never inlines -> always libcalls).
//   (2) a far STRUCT/aggregate copy from a near ROM constant -> clang's
//       EmitAggregateCopy forms llvm.memcpy.p2.p0 (constant 64 B, over the
//       inline SizeLimit -> libcalls). The near source also proves the fix's
//       near->far (bank $00) pointer widening reads ROM correctly.
//
// Both regions live in HIGH WRAM ($7E2000), reachable only by 24-bit far
// addressing, then are read back via far LOADS (the well-gated `lda [dp]` path)
// and SUMMED — a value-sensitive fold, so a wrong-bank write (which reads back as
// uninitialized, not 0x5A / the ROM bytes) changes corpus_result. Needs +mos-a16
// (a runtime far pointer is a 32-bit value; see far_indir.c / far_store.c).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os far_memops.c
// Built + booted in MAME and bsnes-jg by dev/far_memops.sh (host: dev/run.sh far_memops).
// See docs/plans/2026-06-26-fix-the-far-addrspace-2-memset-memcpy-memmove-sile.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// High WRAM (bank $7E) — only 24-bit far addressing can reach it.
static FAR uint8_t *const hi = (FAR uint8_t *)0x7E2000u;

// A near ROM constant, the source of the far aggregate copy (b[i] == i).
struct Blk { uint8_t b[64]; };
static const struct Blk rom_blk = { .b = {
   0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,
  16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,
  32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,
  48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63 } };

// Launder the memset length to a RUNTIME value so it can never inline-expand
// (forces the createMemLibcall fallthrough — exactly where the bug lived).
volatile uint16_t n;

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

int main(void) {
  n = 50;
  uint16_t cnt = n;  // one volatile read -> loop-invariant runtime trip count

  // (1) variable-size far memset via a strided store loop -> llvm.memset.p2.
  for (uint16_t i = 0; i < cnt; i++)
    hi[i] = 0x5A;

  // (2) large constant far memcpy via an aggregate copy (near ROM -> far WRAM).
  *(FAR struct Blk *)(hi + 0x100) = rom_blk;

  // Read both regions back via far LOADS and SUM them (value-sensitive: a
  // wrong-bank write reads back as not-0x5A / not-the-ROM-bytes, so the sum
  // changes). Expected sum = 50*0x5A + sum(0..63) = 4500 + 2016 = 6516 -> 0x74.
  uint8_t acc = 0;
  for (uint16_t i = 0; i < cnt; i++)
    acc += hi[i];
  for (uint16_t i = 0; i < 64; i++)
    acc += hi[0x100 + i];

  corpus_result = acc;  // == 0x74 iff both memops landed in bank $7E
  for (;;) {            // stay alive while MAME settles
  }
}

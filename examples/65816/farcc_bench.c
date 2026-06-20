// #320 Inc 4 Phase 2 (M) — far-pointer CC CYCLE benchmark (variant-agnostic).
//
// Throughput proxy for the bytes+cycles measurement (dev/measure-far-cc.sh). The
// same make_far_ptr()/deref_far() round-trip as the gate source farcc_imag32.c, but
// run in an INFINITE loop that increments a volatile counter `iters` each time a far
// pointer crosses both calls. The probe (dev/probe-cycles.lua) runs a FIXED number of
// frames, then reads `iters`: more round-trips completed in the same wall of emulated
// time == cheaper per-call passing for that variant. MAME 0.285's Lua exposes no
// total_cycles(), so this frame-deterministic iteration count is the cycle metric
// (the parent plan's documented fallback, and the robust one here).
//
// Variant = build flag (+mos-farcc-imag32 | -split | -axy | -stack), exactly like the
// gates. corpus_result == 0xF3 each iteration doubles as the correctness sentinel, so a
// fast-but-wrong variant can't score. Needs +mos-a16 (32-bit far value legalization).
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 +mos-farcc-XXX -Os
// See docs/plans/2026-06-21-320-far-cc-M-measure-D-land-winner.md (M).

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

__attribute__((section(".far_rodata"))) const uint8_t bank1_sentinel = 0xA9;

volatile uint8_t corpus_result;  // == 0xF3 once the loop runs (correctness sentinel)
volatile uint32_t iters;         // round-trips completed; sampled by the probe at a fixed frame
volatile uint32_t opaque_addr;   // launders the address so the calls can't fold away

__attribute__((noinline)) static FAR const uint8_t *make_far_ptr(uint32_t a) {
  return (FAR const uint8_t *)a; // inttoptr: runtime 32-bit far pointer (RETURN CC)
}
__attribute__((noinline)) static uint8_t deref_far(FAR const uint8_t *p) {
  return *p; // lda [dp] (ARGUMENT CC)
}

int main(void) {
  opaque_addr = ((uint32_t)1 << 16) | (uint16_t)(uintptr_t)&bank1_sentinel;
  iters = 0;
  for (;;) {
    FAR const uint8_t *fp = make_far_ptr(opaque_addr); // far ptr returned across a call
    corpus_result = deref_far(fp) ^ 0x5A;              // far ptr passed across a call; 0xA9^0x5A=0xF3
    iters = iters + 1;                                 // volatile RMW: forces the round-trip + counts it
  }
}

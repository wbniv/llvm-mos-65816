// #320/#321 — far (addrspace 2) memset/memcpy/memmove with lengths above 65535.
//
// THE BUG this gates (docs/defects/mos-far-memop-length-truncation.json): the
// backend lowered every far memop it could not inline to __memset_far /
// __memcpy_far / __memmove_far, whose length is a 16-bit size_t, and truncated a
// wider length to 16 bits without a range check. A 70000-byte fill became 4464
// bytes, and 65536 became 0. No crash, no diagnostic. The fix keeps the 16-bit
// entries only for provably 16-bit lengths and otherwise calls the uint32_t
// __memset_far32 / __memcpy_far32 / __memmove_far32 (platforms/snes/mem-far.c).
//
// All three producers here are loop idioms over far pointers, as in real code:
//   (1) a constant 70000-iteration store loop   -> llvm.memset.p2 (70000);
//   (2) a runtime-length (uint32_t) store loop  -> llvm.memset.p2 (runtime);
//   (3) a runtime-length copy loop              -> llvm.memcpy.p2.p2 (runtime);
//   (4) a runtime-length overlapping shift loop -> llvm.memmove.p2.p2 (runtime).
// Every region lives in WRAM above $7E:2000 and crosses into bank $7F, so a
// truncated length leaves bytes past the 64 KiB boundary untouched. Each check
// sets one bit of corpus_result; all 16 pass iff corpus_result == 0xFFFF.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 +mos-a16 -O2 far_memops32.c
// Built + booted in MAME and bsnes-jg by dev/far_memops32.sh
// (host: dev/run.sh far_memops32).
// See docs/plans/2026-09-30-far-prerequisite-defects.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// $7E:2000..$7F:FFFF: the WRAM above the bank-$00 low-RAM mirror.
static FAR uint8_t *const p = (FAR uint8_t *)0x7E2000ul;
// Copy destination: $7F:8000..$7F:FFFF, disjoint from p[0 .. 70000] and from
// the copy source $7E:F000..$7F:6FFF.
static FAR uint8_t *const q = (FAR uint8_t *)0x7F8000ul;

#define BIG 70000ul // 0x11170: above 0xFFFF, low half 0x1170

// Runtime lengths, laundered so no bound is provable.
volatile uint32_t n_fill, n_copy, n_move;
// Runtime copies of p and q. With constant pointers the optimizer folds the
// copy and move loops' addresses to constants, and the loop idiom then keeps
// them as byte loops instead of forming llvm.memcpy / llvm.memmove.
FAR uint8_t *volatile p_rt = (FAR uint8_t *)0x7E2000ul;
FAR uint8_t *volatile q_rt = (FAR uint8_t *)0x7F8000ul;

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint16_t corpus_result;

__attribute__((noinline)) static void fill_const(uint8_t v) {
  for (uint32_t i = 0; i < BIG; i++) // (1) memset, constant 70000
    p[i] = v;
}

__attribute__((noinline)) static void fill_var(uint8_t v, uint32_t n) {
  for (uint32_t i = 0; i < n; i++) // (2) memset, runtime length
    p[i] = v;
}

__attribute__((noinline)) static void copy_var(FAR uint8_t *__restrict__ d,
                                               const FAR uint8_t *__restrict__ s,
                                               uint32_t n) {
  for (uint32_t i = 0; i < n; i++) // (3) memcpy, runtime length
    d[i] = s[i];
}

__attribute__((noinline)) static void shift_down(FAR uint8_t *d, uint32_t n) {
  const FAR uint8_t *s = d + 16;
  for (uint32_t i = 0; i < n; i++) // (4) memmove, runtime length
    d[i] = s[i];
}

int main(void) {
  uint16_t ok = 0;
  n_fill = BIG;
  n_copy = 0x8000;         // 32 KiB, from $7E:F000 across into bank $7F
  n_move = BIG - 16;

  p[BIG] = 0x11; // sentinel just past every fill
  fill_const(0xA5);
  if (p[0] == 0xA5) ok |= 1u << 0;
  if (p[0xDFFF] == 0xA5) ok |= 1u << 1;          // $7E:FFFF
  if (p[0xE000] == 0xA5) ok |= 1u << 2;          // $7F:0000
  if (p[BIG - 1] == 0xA5) ok |= 1u << 3;         // last byte, $7F:316F
  if (p[BIG] == 0x11) ok |= 1u << 4;             // sentinel untouched

  fill_var(0x5A, n_fill);
  if (p[0x1170] == 0x5A) ok |= 1u << 5;          // the truncated length
  if (p[0x10000] == 0x5A) ok |= 1u << 6;         // 64 KiB in
  if (p[BIG - 1] == 0x5A && p[BIG] == 0x11) ok |= 1u << 7;

  // Mark bytes, then shift the whole 70000-byte window down by 16.
  p[16] = 0x01;
  p[0x10010] = 0x02;
  p[BIG - 1] = 0x03;
  shift_down(p_rt, n_move);
  if (p[0] == 0x01) ok |= 1u << 8;
  if (p[0x10000] == 0x02) ok |= 1u << 9;         // moved across 64 KiB
  if (p[BIG - 17] == 0x03) ok |= 1u << 10;       // last moved byte
  if (p[BIG - 16] == 0x5A && p[BIG] == 0x11) ok |= 1u << 11;

  // Copy 32 KiB that starts in bank $7E and ends in bank $7F.
  p[0xD000] = 0x21;                              // $7E:F000, first source byte
  p[0xDFFF] = 0x22;                              // $7E:FFFF
  p[0xE000] = 0x23;                              // $7F:0000
  p[0x14FFFul] = 0x24;                           // $7F:6FFF = 0xD000 + 0x7FFF, last source byte
  copy_var(q_rt, p_rt + 0xD000, n_copy);               // dst $7F:8000..$7F:FFFF
  if (q[0] == 0x21) ok |= 1u << 12;
  if (q[0x0FFF] == 0x22 && q[0x1000] == 0x23) ok |= 1u << 13;
  if (q[0x7FFF] == 0x24) ok |= 1u << 14;
  if (q[0x2000] == 0x5A) ok |= 1u << 15;         // from $7F:1000 (p[0xF000])

  corpus_result = ok; // == 0xFFFF iff every length was honoured
  for (;;) __asm__ volatile("wai");
}

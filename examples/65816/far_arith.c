// #320 Increment 3 (3c) — far-pointer arithmetic (G_PTR_ADD on AS2).
//
// 3a proved a runtime far dereference (lda [dp]) and 3b a near->far cast. This
// program proves the third runtime piece: ARITHMETIC on a far pointer. A runtime
// far pointer to arr[0] is incremented (`fp++`) and the result dereferenced. The
// increment is a G_PTR_ADD {PF,S32} — a full 32-bit add (the bank byte carries
// across a 64 KB boundary, the correct flat-address behavior), NOT a 16-bit
// near-pointer bump. The address is laundered through a volatile so nothing folds
// to a constant; the deref of the incremented pointer is indirect-long `lda [dp]`.
//
// Needs +mos-a16: a runtime far pointer is a 32-bit VALUE, and `fp++` lowers (via
// ptrtoint/add/inttoptr) to a 32-bit add whose ±1 byte path splits the s32 into
// bytes — the s32->4x s8 G_UNMERGE_VALUES that this gate was the first to exercise
// (mirror of the existing 4x s8->s32 merge; both 32-bit value legalization, a16-
// gated). The default 8-bit build legitimately can't compile a runtime far value,
// so the gate is host-expected == +mos-a16 on both emulators, not a 4-way diff.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os far_arith.c
// Built + booted in MAME and bsnes-jg by dev/far_arith.sh
// (host: dev/run.sh far_arith). See docs/plans/2026-06-20-320-far-pointer-runtime.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Three bytes in bank $00 (ordinary near rodata). arr[1] is the sentinel the
// post-increment read must land on: 0xA9 ^ 0x5A = 0xF3 (the canonical pass byte).
static const uint8_t arr[3] = { 0x11, 0xA9, 0x33 };

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Launders the near address to a runtime value so the cast+arith+deref can't fold.
volatile uint16_t opaque_near;

int main(void) {
  opaque_near = (uint16_t)(uintptr_t)&arr[0];
  // Runtime far pointer to arr[0] (bank $00 : near low-16, zero-extended to 32-bit).
  FAR const uint8_t *fp = (FAR const uint8_t *)(uintptr_t)(uint32_t)opaque_near;
  fp++;                                 // G_PTR_ADD {PF,S32}: &arr[0] -> &arr[1]
  corpus_result = *fp ^ 0x5A;           // lda [dp] of arr[1]=0xA9; 0xA9 ^ 0x5A = 0xF3
  for (;;) {                            // stay alive while MAME settles
  }
}

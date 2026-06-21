// #320 (a) far pointers — sizeof(far*) == 4 gate (Layer F: getPointerWidthV(AS2)
// -> 32). Proves clang's C-level far-pointer size now matches the p2:32:8 IR
// width, and that a far pointer STORED in an aggregate lays out correctly.
//
// Before the change getPointerWidthV(AS2) was 16, so sizeof(FAR*) == 2 while the
// IR pointer is 4 bytes — a latent mismatch. A far pointer stored as a struct
// field then reserves only 2 bytes at the C level, but the IR 4-byte store
// overruns it and clobbers the next field. With sizeof == 4 the layout is
// consistent: `p` occupies bytes 0..3 and `tag` lives at offset 4, untouched.
//
// The runtime gate dereferences the STORED far pointer (proving it survived as a
// full 4-byte value) and XORs in the adjacent `tag` (proving the 4-byte store
// did NOT clobber it). corpus_result == 0x12 ^ 0xC3 == 0xD1 only if BOTH hold.
//
// Needs +mos-a16: a far pointer is a 32-bit value; storing/loading a p2 VALUE is
// a16-gated (Gap B), as in far_indir/far_store. Gate is host-expected ==
// +mos-a16 on both emulators; no default leg.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os far_sizeof.c
// Built + booted in MAME and bsnes-jg by dev/far_sizeof.sh (host: dev/run.sh far_sizeof).
// See docs/plans/2026-06-21-320-far-pointer-sizeof.md.

#include <stdint.h>
#define FAR __attribute__((address_space(2)))
typedef uint8_t (*far_fn_t)(uint8_t) __attribute__((far));

// Compile-time gate: far pointers are now 4 bytes (were 2).
_Static_assert(sizeof(FAR const void *) == 4, "far data pointer must be 4 bytes");
_Static_assert(sizeof(far_fn_t) == 4, "far function pointer must be 4 bytes");

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// Near data (bank $00). A far pointer to it is bank-0, zero-extended to 32 bits.
static const uint8_t arr[] = {0x12, 0x34};

// A far pointer stored as a struct field, with an adjacent byte that a 2-byte
// (mis-sized) far pointer store would clobber.
struct holder {
  FAR const uint8_t *p; // 4 bytes (offset 0..3)
  uint8_t tag;          // offset 4 — only safe if `p` is sized 4, not 2
};

// volatile + global so the struct is materialized in memory (no SROA into
// registers), exercising the real field layout.
volatile struct holder h;

int main(void) {
  h.tag = 0xC3;
  h.p = (FAR const uint8_t *)&arr[0]; // near->far cast, stored as a 4-byte far ptr
  uint8_t v = h.p[0];                 // deref the STORED far pointer -> 0x12
  corpus_result = (uint8_t)(v ^ h.tag); // 0x12 ^ 0xC3 = 0xD1 (tag not clobbered)
  for (;;) { // stay alive while MAME settles
  }
}

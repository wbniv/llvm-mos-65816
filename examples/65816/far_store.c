// #320 Increment 3 follow-up — runtime far-pointer STORE via 65816 indirect-long.
//
// Inc 3's gates (far_indir/far_cast/far_arith) all exercised the far LOAD
// (`lda [dp]`, A7). The store path (`sta [dp]`, opcode 87 = G_STORE_FAR_INDIR ->
// STIndirLong) was implemented symmetrically with the load but never gated. This
// closes that: a runtime far pointer (laundered through a volatile so it can't
// fold to absolute-long) WRITES a byte via `sta [dp]`, then the byte is read back
// near to prove the store hit the right 24-bit address.
//
// The far pointer targets a bank-$00 RAM byte (`target`), so the 24-bit store
// address is $0000xxxx — the same physical WRAM the harness samples. Needs
// +mos-a16 (a runtime far pointer is a 32-bit value; see far_indir.c).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os far_store.c
// Built + booted in MAME and bsnes-jg by dev/far_store.sh (host: dev/run.sh far_store).
// See docs/plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md (Phase 0).

#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Sampled by the harness from the $7E WRAM mirror (bank $00 low RAM).
volatile uint8_t corpus_result;

// The far store's destination: a near (bank $00) RAM byte.
volatile uint8_t target;

// Launders the far address to a runtime value so the store can't fold to
// absolute-long (it must stay an indirect-long [dp] store).
volatile uint32_t opaque_addr;

int main(void) {
  // 24-bit far address of `target`: bank $00 (high byte 0), near low-16 address.
  opaque_addr = (uint32_t)(uint16_t)(uintptr_t)&target;
  uint32_t a = opaque_addr;                       // opaque -> no fold
  FAR volatile uint8_t *fp = (FAR volatile uint8_t *)a; // runtime far ptr to target
  *fp = 0xF3;                                     // sta [dp]  (the thing under test)
  corpus_result = target;                         // read back near; == 0xF3 iff store landed
  for (;;) {                                      // stay alive while MAME settles
  }
}

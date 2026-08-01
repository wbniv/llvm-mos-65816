// #320 far-pointer DEFECT repro — a far (address_space(2)) constant-fill is miscompiled to the
// NEAR __memset libcall, which drops the 24-bit bank byte and writes the wrong bank.
//
// `grid[i] = 0x42` over a far pointer should emit indirect-long stores (`sta [dp]`, opcode $87) to
// $7E2000+. Instead, at -Os the loop-idiom recognizer coalesces it into `jsr __memset` with the
// 24-bit destination in the imaginary registers — but libc __memset is a near (16-bit, DBR-relative)
// routine, so it writes $00:2000.. (MMIO / open-bus on the SNES) and $7E2000 is never touched. The
// store→load round-trip a CRC gate uses can't catch it: a wrong-but-consistent address still round-
// trips (this is why examples/snes/mandel-mode7.c's far-buffer CRC passed despite the same class of
// risk). It surfaces only when an INDEPENDENT reader checks the physical far address.
// Full diagnosis + fix direction: docs/320-far-memset-miscompile.md.
//
// Build (default-8bit CANNOT compile a runtime far pointer; this is +mos-a16-only):
//   mos-clang --config mos-snes.cfg -mcpu=mosw65816 +mos-a16 -Os far_memset.c -o far_memset.sfc
// Symptom: disasm shows `jsr __memset`; on a real run $7E2000 stays at its (random) power-on value.
// Workaround: a VOLATILE far store is never coalesced — see HOP_DEFINE_CLEAR in hopalong.h.
//
// Gate: dev/run.sh far_memset asserts the bytes actually land at $7E2000 (an independent far read).
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 4 KiB far buffer in high WRAM
volatile uint16_t corpus_result;

int main(void) {
  uint16_t i = 0;
  do { grid[i] = 0x42; } while (++i != 4096);   // BUG: coalesced to near __memset -> wrong bank
  // Independent proof: read back via an explicit per-element far load (NOT memset/memcpy-shaped, so
  // it is not coalesced) and fold. If the fill landed at $7E2000, every byte is 0x42 and the xor-
  // fold of (0x42 ^ position-independent) is deterministic; if __memset wrote bank $00, these far
  // loads read the untouched (random on bsnes) $7E2000 and the fold mismatches the host reference.
  uint16_t acc = 0;
  i = 0;
  do { acc = (uint16_t)(acc + grid[i]); } while (++i != 4096);
  corpus_result = acc;                 // == 0x42 * 4096 mod 2^16 = 0x2000 iff the fill is correct
  for (;;) __asm__ volatile("wai");
}

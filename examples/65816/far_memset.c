// A nonvolatile constant fill forms llvm.memset.p2.i32 at -Os. Its destination
// is high WRAM, so the runtime's pointer parameter must retain the bank byte.
// The target checksum consumes the filled bytes; the emulator also reads all
// 4096 physical bytes independently to detect an incorrect shared address path.
// Gate: python3 dev/check-far-memset.py --output /tmp/far-memset-check
// Evidence and ABI contract: docs/320-far-memset-miscompile.md.
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

static FAR uint8_t *const grid = (FAR uint8_t *)0x7E2000u;   // 4 KiB far buffer in high WRAM
volatile uint16_t corpus_result;

int main(void) {
  uint16_t i = 0;
  do { grid[i] = 0x42; } while (++i != 4096);
  // Consume every byte through far loads. The sum is a completion check;
  // checking each physical byte in the harness also detects sum collisions.
  uint16_t acc = 0;
  i = 0;
  do { acc = (uint16_t)(acc + grid[i]); } while (++i != 4096);
  corpus_result = acc;                 // 0x42 * 4096 mod 2^16 = 0x2000
  for (;;) __asm__ volatile("wai");
}

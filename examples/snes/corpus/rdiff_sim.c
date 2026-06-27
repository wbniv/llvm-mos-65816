#include <stdint.h>
volatile uint16_t corpus_result;
#include "../../65816/rdiff.h"
/* .noinit: rdiff_gate_crc() explicitly initialises gstate; skip BSS zeroing.
 * Without this, BSS = 258 bytes (256 gstate + 2 corpus_result). The LTO-
 * compiled __memset is buggy for count ≥ 256 on 8-bit 65816 (small-program
 * context): Y used as sole counter, dp[4] never decremented → infinite loop. */
static rdiff_gate_state gstate __attribute__((section(".noinit..rdiff")));
int main(void) { corpus_result = rdiff_gate_crc(&gstate); return 0; }

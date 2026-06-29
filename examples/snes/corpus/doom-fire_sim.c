#include <stdint.h>
volatile uint16_t corpus_result;
#include "../../65816/doom-fire.h"
/* .noinit: doomfire_gate_crc() explicitly initialises the whole gate grid (all cells to 0,
 * then the source row), so BSS zeroing is unnecessary. Without this, BSS = 258 bytes
 * (256 gate grid + 2 corpus_result), and the LTO-compiled __memset is buggy for count ≥ 256
 * on the 8-bit 65816 small-program path (Y used as sole counter → never terminates). Same
 * workaround as rdiff_sim.c. */
static doomfire_gate_state gstate __attribute__((section(".noinit..doomfire")));
int main(void) { corpus_result = doomfire_gate_crc(&gstate); return 0; }

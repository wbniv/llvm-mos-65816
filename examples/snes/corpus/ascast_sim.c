// Build contract for dev/build.sh's example battery (grammar: dev/build.sh).
// mos-a16-only: the near-to-far address-space cast needs +mos-a16 (G_MERGE_VALUES legalization); see docs/defects/mos-default-mode-far-cast-legalization.json.
/* Dedicated +mos-a16 slice for the runtime near-to-far cast ladder. */
#include "../../65816/ascast.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = ascast_gate_crc(); for (;;) __asm__ volatile("wai"); }

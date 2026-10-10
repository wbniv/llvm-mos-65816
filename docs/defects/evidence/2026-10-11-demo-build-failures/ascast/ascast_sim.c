/* Dedicated +mos-a16 slice for the runtime near-to-far cast ladder. */
#include "../../65816/ascast.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = ascast_gate_crc(); for (;;) __asm__ volatile("wai"); }

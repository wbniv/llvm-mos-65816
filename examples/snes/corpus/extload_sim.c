/* Differential slice for signed and unsigned extending loads across width pairs. */
#include "../../65816/extload.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = extload_gate_crc(); for (;;) __asm__ volatile("wai"); }

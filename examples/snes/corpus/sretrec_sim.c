/* Differential slice for recursive calls returning an aggregate through sret. */
#include "../../65816/sretrec.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = sretrec_gate_crc(); for (;;) __asm__ volatile("wai"); }

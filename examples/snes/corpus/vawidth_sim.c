/* Differential slice for the promoted, native, wide and pointer variadic arguments. */
#include "../../65816/vawidth.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = vawidth_gate_crc(); for (;;) __asm__ volatile("wai"); }

/* Differential slice for indirect calls whose signatures have different arities. */
#include "../../65816/arityfan.h"
volatile uint16_t corpus_result;
int main(void) { corpus_result = arityfan_gate_crc(); for (;;) __asm__ volatile("wai"); }

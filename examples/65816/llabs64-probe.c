#include "llabs64.h"
volatile uint16_t llabs64_probe_result;
void llabs64_probe(void) { llabs64_probe_result = llabs64_step(UINT16_C(0x1210), 14u); }

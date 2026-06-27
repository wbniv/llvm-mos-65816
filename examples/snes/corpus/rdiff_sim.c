#include <stdint.h>
volatile uint16_t corpus_result;
#include "../../65816/rdiff.h"
static rdiff_gate_state gstate;
int main(void) { corpus_result = rdiff_gate_crc(&gstate); return 0; }

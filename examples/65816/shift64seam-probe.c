#include "shift64seam.h"
volatile uint16_t shift64seam_probe_result;
void shift64seam_probe(void) { shift64seam_probe_result=shift64seam_step(0x1388u,9u); }

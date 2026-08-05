// IR-only gate: keep the per-function feature attributes visible before LTO.
#include "mixedwidth.h"

uint16_t mixedwidth_probe(void) { return mixedwidth_model(); }

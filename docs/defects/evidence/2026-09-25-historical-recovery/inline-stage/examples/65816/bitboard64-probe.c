#include "bitboard64.h"

volatile uint16_t bitboard64_probe_result;

void bitboard64_probe(void) {
    bitboard64_reset();
    bitboard64_probe_result = bitboard64_step(0x120Bu, 23u);
}

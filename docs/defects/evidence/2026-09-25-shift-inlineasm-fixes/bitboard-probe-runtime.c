#include <stdint.h>
extern void bitboard64_probe(void);
extern volatile uint16_t bitboard64_probe_result;
#ifdef HOST_MAIN
#include <stdio.h>
#else
volatile uint16_t corpus_result;
#endif
int main(void) {
    bitboard64_probe();
#ifdef HOST_MAIN
    printf("0x%04X\n", (unsigned)bitboard64_probe_result);
    return 0;
#else
    corpus_result = bitboard64_probe_result;
    for (;;) {}
#endif
}

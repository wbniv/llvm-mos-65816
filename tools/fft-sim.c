/* Host oracle for the FFT differential gate.
 * Build: cc -O2 -I examples/65816 tools/fft-sim.c -o build/fft-sim
 */
#include <stdio.h>
#include "fft.h"

int main(void) {
    uint16_t h = fft_gate_crc();
    printf("fft gate  N=%u  LOG2_N=%u  hash=0x%04X\n",
           (unsigned)FFT_N, (unsigned)FFT_LOG2_N, (unsigned)h);
    return 0;
}

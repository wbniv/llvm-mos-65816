// Bare-metal 65CE02 entry: run the shared kernel, publish the checksum at $0400.
#include "asrkernel.h"
#define RESULT (*(volatile uint16_t *)0x0400)
#define FLAG   (*(volatile uint8_t  *)0x0402)
__attribute__((noinline)) void run(void) {
    RESULT = asr_kernel();
    FLAG = 0x5Au;                       // "kernel finished" sentinel
}
int main(void) { run(); for (;;) {} }

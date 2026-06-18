// KNOWN +mos-a16 CRASH (tracked) — deterministic register-allocation failure.
//
// Under `-mcpu=mosw65816` `+mos-a16` at -O1/-Os the register allocator aborts:
// "ran out of registers during register allocation in function 'main'".
// DEFAULT 8-bit -Os and +mos-a16 -O0 both compile cleanly, so this is an
// OPTIMIZED-+mos-a16 register-pressure failure, not a value/codegen bug.
//
// Reduced (delta-debugged) from examples/snes/corpus/globals.c — a corpus program
// built DEFAULT 8-bit, so this path was never exercised under +mos-a16, and the
// differential fuzzer never generated this shape, so it went undiscovered.
// Minimal trigger: a u16 accumulator (`r`) held live across a SECOND accumulation
// loop, together with two u16*u8 multiplies (`*one`). Two live 16-bit accumulators
// + the multiplies exhaust the scarce hard registers (A/Ac16, X/Y) + scavenger;
// shrinking the arrays to [2] removes the crash (lower loop/index pressure).
//
// Expected to FAIL to compile under +mos-a16 -O1/-Os until fixed. The fix is in the
// F3 / soft-stack spill-coverage family (allocator / spill path). When fixed, convert
// this into a positive differential gate (host == default == +mos-a16, both emulators).
// Tracked: TODO.md (#321 globals.c +mos-a16 -Os RA failure) + the fuzzer KNOWN_ISSUES
// entry "regalloc-out-of-registers". Do NOT wire a green dev/ test while it crashes.
#include <stdint.h>

uint16_t A[4] = { 1, 2, 3, 4 };
uint8_t  ab   = 0xAB;
uint16_t B[8];
uint8_t  bb;
volatile uint8_t  one = 1;
volatile uint16_t out;

int main(void) {
    uint16_t r = 0;
    uint8_t i;
    for (i = 0; i < 4; i++) r += (uint16_t)(A[i] * one);  // u16 accumulator + u16*u8 mul
    r += (uint16_t)(ab * one);                            // second multiply, r stays live
    uint16_t s = 0;
    for (i = 0; i < 8; i++) s += B[i];                    // r live across this whole loop
    s += bb;
    out = r + s;
    for (;;) {}
}

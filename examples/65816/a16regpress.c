// a16regpress.c — POSITIVE differential gate for the (now FIXED) +mos-a16 register-
// allocation deadlock that used to abort: "ran out of registers during register
// allocation in function 'main'" (KNOWN_ISSUES signature "regalloc-out-of-registers").
//
// Reduced (delta-debugged) from examples/snes/corpus/globals.c. Trigger: a u16
// accumulator (`r`) held live across a SECOND accumulation loop alongside u16*u8
// multiplies, iterating u16 arrays so the strength-reduced byte index advances `i += 2`.
// ROOT CAUSE (pinpointed on an asserts build, -debug-only=regalloc, 2026-06-24): the i8
// byte index, stepped `i += 2`, selected to ADCImm and so was pinned to register class
// Ac={A} (adc is hardware-A-only). Held live across the 16-bit indexed-load transit
// (Ac16 = A:B), it collided on A — greedy could not recolor the counter off the singleton
// {A}, and the single-instruction INF Ac16 transit could not spill -> deadlock. DEFAULT
// 8-bit and +mos-a16 -O0 always compiled clean.
//
// FIX (fork patch 0009-321-a16-pressure-incdec): under +mos-a16, selectAddSub lowers a
// small-constant i8 add/sub (|Amt| <= 2) to a relocatable G_INC/G_DEC chain (Anyi8 =
// A/X/Y/zp) instead of the A-pinned ADCImm, so the byte index coalesces into the X array
// index (`inx; inx; cpx`) and frees A16. Gated on hasAccum16() -> default 8-bit codegen is
// byte-identical. Now a green gate: dev/run.sh a16regpress asserts corpus_result is
// identical host == default == +mos-a16 on MAME + bsnes-jg, plus a disasm gate (the byte
// index increments via inx, not a clc/adc on A). The fuzzer
// KNOWN_ISSUES["regalloc-out-of-registers"] entry + this file's KNOWN_ISSUE_REPROS row
// were removed, so a recurrence hard-FAILS again (regression guard).
#include <stdint.h>

uint16_t A[4] = { 1, 2, 3, 4 };
uint8_t  ab   = 0xAB;
uint16_t B[8] = { 7, 11, 13, 17, 19, 23, 29, 31 };
uint8_t  bb   = 0x5C;
volatile uint8_t  one = 1;
volatile uint16_t out;
volatile unsigned short corpus_result;

int main(void) {
    uint16_t r = 0;
    uint8_t i;
    for (i = 0; i < 4; i++) r += (uint16_t)(A[i] * one);  // u16 accumulator + u16*u8 mul
    r += (uint16_t)(ab * one);                            // second multiply, r stays live
    uint16_t s = 0;
    for (i = 0; i < 8; i++) s += B[i];                    // r live across this whole loop
    s += bb;
    out = r + s;
    corpus_result = out;                                  // expose the result for the gate
    for (;;) __asm__ volatile("wai");
}

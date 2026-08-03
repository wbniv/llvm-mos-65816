/* a16isr.c — MINIMAL repro for the 65816 interrupt-prologue width defect found by demo #123
 * (`nmitally`). Four lines of C; the whole finding is in the emitted prologue.
 *
 * Build:  mos-clang --target=mos -mcpu=mosw65816 \
 *           -Xclang -target-feature -Xclang +mos-a16 -Os -S a16isr.c
 *
 * Emitted today (llvm-mos fork @ patch 0002):
 *
 *     nmi:
 *       cld
 *       pha                 <-- (1) sized assuming M=1, which the 65816 does NOT establish on
 *       clc                     interrupt entry; (2) an 8-bit save of a possibly-16-bit A
 *       lda __rc0
 *       adc #254            <-- 1-byte immediate, also sized assuming M=1
 *       ...
 *       rep #32             <-- the handler goes 16-bit here, destroying A's high byte (B)
 *       lda tally
 *       ...
 *       sep #32
 *       ...
 *       pla                 <-- 8-bit restore: B is gone
 *       rti
 *
 * Required on a 65816:  cld; rep #$30; pha; phx; phy; sep #$30; <body>; rep #$30; ply; plx; pla; rti
 * (P itself is pushed by hardware and popped by RTI, so only the register widths need handling.)
 *
 * Consequences on real silicon (measured on bsnes-jg via examples/snes/nmitally.c):
 *   default 8-bit build .... CRC == host oracle (no rep/sep anywhere, so nothing to inherit)
 *   +mos-a16 build ......... black screen, corpus_result stays 0x0000, reproducible 3/3
 *   +mos-xy16 build ........ same
 *
 * See docs/plans/2026-08-03-123-snes-nmitally.md ("Compiler defect"). */
#include <stdint.h>

volatile uint16_t tally;

__attribute__((interrupt)) void nmi(void) { tally += 3u; }

int main(void) { for (;;) { } }

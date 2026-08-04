// IRQ Gate (#139) — shared deterministic model for the first non-NMI hardware vector to run C.
//
// Two hardware interrupts are live at once:
//   * NMI  — v-blank, scanline 225, already exercised by #123/#124.
//   * IRQ  — the PPU V-count timer, programmed to scanline IRQGATE_VTIME (224). The first time
//            this platform's `irq` vector has ever reached a C handler instead of crt0's weak
//            `rti` stub.
//
// The two fire one scanline apart, and the IRQ handler's body is deliberately long enough to span
// that gap, so the v-blank NMI lands INSIDE the IRQ handler's own envelope — nesting a 65816
// interrupt envelope for the first time in this project.
//
// Determinism: both interrupts are asynchronous to the main loop, so each carries the #123
// armed/done handshake with its OWN exact stop count. Each tally is folded INDEPENDENTLY and the
// folds are then combined, so the gate hash cannot depend on which handler ran first or how the
// two interleaved.
#ifndef IRQGATE_H
#define IRQGATE_H

#include <stdint.h>

// Distinct stop counts: a handler wired to the wrong vector, or one vector servicing both, cannot
// land on the same pair of tallies.
#define IRQGATE_NMI_STOP 120u
#define IRQGATE_IRQ_STOP 96u

// V-count IRQ position. NMI fires at the start of v-blank (scanline 225); the IRQ is programmed
// well before it so the handler is already running when v-blank arrives. 200 rather than 224
// because a C interrupt handler's *prologue* is not free: `irq` saves 26 imaginary registers, and
// the measured entry latency from V-count trigger to the first line of the C body is ~5 scanlines.
// At VTIME=224 the handler did not begin until scanline 229 — after the NMI it was supposed to
// catch. See the plan's "Where the first design was wrong" section.
#define IRQGATE_VTIME 200u

// Envelope reentrancy, asserted rather than hoped for. Timing alone cannot guarantee the overlap
// (handler duration varies with width mode, and the ISR prologue cost is large), so the IRQ
// handler RENDEZVOUS with the NMI instead: having done its work it spins until the NMI tally it
// observed at entry changes. The NMI is non-maskable and arrives every frame, so the meeting is
// structural, not probabilistic — every one of the IRQGATE_IRQ_STOP armed IRQs is preempted by
// exactly one NMI inside its own envelope, in every width mode.
#define IRQGATE_NEST_EXPECT IRQGATE_IRQ_STOP

// Safety net on that spin: bounded so a mis-timed run yields a wrong CRC instead of a hung ROM.
#define IRQGATE_SPIN_LIMIT 20000u

#define IRQGATE_NMI_SEED 0x13579BDFu
#define IRQGATE_IRQ_SEED 0x2468ACE0u
#define IRQGATE_H_SEED 0x5C1Du

// Short v-blank body, as in #123.
static inline uint32_t irqgate_nmi_step(uint32_t v, uint16_t n) {
    return (uint32_t)(v + (uint32_t)0x00010001u + (uint32_t)n);
}

// LONG raster body. The iteration count is load-bearing: it is what guarantees the handler is
// still executing when the v-blank NMI arrives one scanline later. Twelve rounds of 32-bit
// rotate/xor/add cost several hundred cycles even under +mos-a16, and considerably more in the
// 8-bit default build — the margin only widens in the slower modes.
#define IRQGATE_IRQ_ROUNDS 12u
static inline uint32_t irqgate_irq_step(uint32_t v, uint16_t n) {
    for (uint8_t i = 0u; i < (uint8_t)IRQGATE_IRQ_ROUNDS; i++) {
        v = (uint32_t)(((v << 7) | (v >> 25)) ^ ((uint32_t)n + (uint32_t)i * (uint32_t)0x01010101u));
    }
    return v;
}

static inline uint16_t irqgate_fold(uint16_t h, uint8_t v) {
    return (uint16_t)((uint16_t)((h << 5) | (h >> 11)) ^ (uint16_t)v);
}

static inline uint16_t irqgate_fold32(uint16_t h, uint32_t v) {
    h = irqgate_fold(h, (uint8_t)v);
    h = irqgate_fold(h, (uint8_t)(v >> 8));
    h = irqgate_fold(h, (uint8_t)(v >> 16));
    h = irqgate_fold(h, (uint8_t)(v >> 24));
    return h;
}

static inline uint16_t irqgate_fold16(uint16_t h, uint16_t v) {
    h = irqgate_fold(h, (uint8_t)v);
    h = irqgate_fold(h, (uint8_t)(v >> 8));
    return h;
}

// Each vector's snapshot is folded on its own, then the two folds are combined. Interleaving is
// therefore invisible to the hash by construction.
static inline uint16_t irqgate_hash(uint16_t nmi_tally, uint32_t nmi_mix, uint16_t irq_tally,
                                    uint32_t irq_mix, uint16_t nest) {
    uint16_t hn = (uint16_t)IRQGATE_H_SEED;
    hn = irqgate_fold16(hn, nmi_tally);
    hn = irqgate_fold32(hn, nmi_mix);

    uint16_t hi = (uint16_t)IRQGATE_H_SEED;
    hi = irqgate_fold16(hi, irq_tally);
    hi = irqgate_fold32(hi, irq_mix);

    uint16_t h = (uint16_t)((uint16_t)((hn << 3) | (hn >> 13)) ^ hi);
    return irqgate_fold16(h, nest);
}

static uint16_t irqgate_model(uint16_t *nmi_out, uint16_t *irq_out, uint32_t *nmi_mix_out,
                              uint32_t *irq_mix_out) {
    uint32_t nmi_mix = (uint32_t)IRQGATE_NMI_SEED;
    for (uint16_t n = 1u; n <= (uint16_t)IRQGATE_NMI_STOP; n++)
        nmi_mix = irqgate_nmi_step(nmi_mix, n);

    uint32_t irq_mix = (uint32_t)IRQGATE_IRQ_SEED;
    for (uint16_t n = 1u; n <= (uint16_t)IRQGATE_IRQ_STOP; n++)
        irq_mix = irqgate_irq_step(irq_mix, n);

    if (nmi_out) *nmi_out = (uint16_t)IRQGATE_NMI_STOP;
    if (irq_out) *irq_out = (uint16_t)IRQGATE_IRQ_STOP;
    if (nmi_mix_out) *nmi_mix_out = nmi_mix;
    if (irq_mix_out) *irq_mix_out = irq_mix;
    return irqgate_hash((uint16_t)IRQGATE_NMI_STOP, nmi_mix, (uint16_t)IRQGATE_IRQ_STOP, irq_mix,
                        (uint16_t)IRQGATE_NEST_EXPECT);
}

#endif

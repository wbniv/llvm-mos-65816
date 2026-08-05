// Bank/Direct-Page Windows (#141) — shared deterministic model.
//
// The D/DBR half of the interrupt-entry contract. Mainline opens inline-asm windows with the
// direct page moved onto a sentinel decoy buffer (D window) and with the data bank moved to the
// far WRAM bank $7F (B window), while the v-blank NMI runs a D- and DBR-hungry C handler. Each
// window RENDEZVOUS with the handler (#139 discipline): it spins inside the asm until the
// handler's tally echo changes, so every window provably contains at least one NMI entry, in
// every width mode.
//
// The CRC folds, per run: the tally at its exact stop count, the 32-bit mix over every handler
// entry (including the ones that landed inside windows), the per-window-kind hit counts (each
// exactly DPBANK_WINDOW_ITERS), and the decoy checksum (sentinels untouched). Any handler entry
// that runs on a moved D or DBR without re-establishing the C ABI state corrupts at least one of
// those — that is the loud gate this demo exists to be.
#ifndef DPBANK_H
#define DPBANK_H

#include <stdint.h>

#define DPBANK_NMI_STOP 120u

// Windows per kind. Each waits for its own NMI, so 2*20 windows consume >= 40 of the 120 armed
// frames; the guard threshold keeps a late window from stranding a spin after disarm.
#define DPBANK_WINDOW_ITERS 20u
#define DPBANK_GUARD_MAX 110u

#define DPBANK_DECOY_SIZE 64u
#define DPBANK_MIX_SEED 0x0DB0DB01u
#define DPBANK_H_SEED 0xD9B1u

static inline uint8_t dpbank_decoy_byte(uint8_t i) {
    return (uint8_t)(0xC3u ^ (uint8_t)(i * 7u));
}

// __rc-heavy handler body: ten rounds of 32-bit rotate/xor/add force a wide live set of
// imaginary registers plus a soft-stack frame — every one of those accesses is D-relative.
#define DPBANK_ROUNDS 10u
static inline uint32_t dpbank_step(uint32_t v, uint16_t n) {
    for (uint8_t i = 0u; i < (uint8_t)DPBANK_ROUNDS; i++) {
        v = (uint32_t)(((v << 9) | (v >> 23)) + ((uint32_t)n ^ ((uint32_t)i * 0x00F100F1u)));
    }
    return v;
}

static inline uint16_t dpbank_fold(uint16_t h, uint8_t v) {
    return (uint16_t)((uint16_t)((h << 5) | (h >> 11)) ^ (uint16_t)v);
}

static inline uint16_t dpbank_fold16(uint16_t h, uint16_t v) {
    h = dpbank_fold(h, (uint8_t)v);
    return dpbank_fold(h, (uint8_t)(v >> 8));
}

static inline uint16_t dpbank_fold32(uint16_t h, uint32_t v) {
    h = dpbank_fold16(h, (uint16_t)v);
    return dpbank_fold16(h, (uint16_t)(v >> 16));
}

static inline uint16_t dpbank_hash(uint16_t tally, uint32_t mix, uint16_t hits_d,
                                   uint16_t hits_b, uint16_t decoy_sum) {
    uint16_t h = (uint16_t)DPBANK_H_SEED;
    h = dpbank_fold16(h, tally);
    h = dpbank_fold32(h, mix);
    h = dpbank_fold16(h, hits_d);
    h = dpbank_fold16(h, hits_b);
    h = dpbank_fold16(h, decoy_sum);
    return h;
}

static inline uint16_t dpbank_decoy_sum_expect(void) {
    uint16_t s = 0u;
    for (uint8_t i = 0u; i < (uint8_t)DPBANK_DECOY_SIZE; i++)
        s = (uint16_t)(s + (uint16_t)dpbank_decoy_byte(i));
    return s;
}

static uint16_t dpbank_model(uint32_t *mix_out, uint16_t *decoy_out) {
    uint32_t mix = (uint32_t)DPBANK_MIX_SEED;
    for (uint16_t n = 1u; n <= (uint16_t)DPBANK_NMI_STOP; n++) {
        mix = dpbank_step(mix, n);
        mix ^= (uint32_t)(uint8_t)(n ^ 0x5Au);   // the handler's frame-resident volatile local
    }
    uint16_t decoy = dpbank_decoy_sum_expect();
    if (mix_out) *mix_out = mix;
    if (decoy_out) *decoy_out = decoy;
    return dpbank_hash((uint16_t)DPBANK_NMI_STOP, mix, (uint16_t)DPBANK_WINDOW_ITERS,
                       (uint16_t)DPBANK_WINDOW_ITERS, decoy);
}

#endif

// Tiny Encryption Algorithm (TEA) — portable cipher for SNES demo #30.
//
// The hot loop is pure 32-bit add/XOR/shift — no multiply, no divide:
//   v0 += ((v1<<4) + k[0]) ^ (v1+sum) ^ ((v1>>5) + k[1])
//   v1 += ((v0<<4) + k[2]) ^ (v0+sum) ^ ((v0>>5) + k[3])
//
// Under +mos-a16, <<4 and >>5 on uint32_t are either:
//   - inlined as 4×ASL+ROL/LSR chains, OR
//   - delegated to __ashlsi3/__lshrsi3 at -Os for code size.
// Either path is a codegen corner no other battery demo exercises.
// The +/^ on uint32_t exercise rep/sep bracketed 16-bit arithmetic.
//
// NO bare int — all widths are explicit (uint8_t / uint32_t). See CLAUDE.md §width rules.
#ifndef TEA_H
#define TEA_H

#include <stdint.h>

#define TEA_ROUNDS  32u
#define TEA_DELTA   0x9E3779B9u   /* Fibonacci / golden-ratio constant */
#define TEA_GATE_N   8u

/* Fixed test key for the differential gate. */
static const uint32_t TEA_KEY[4] = {
    0x01234567u, 0x89ABCDEFu, 0xFEDCBA98u, 0x76543210u,
};

/* Standard TEA encipher: 32 rounds, 128-bit key in k[0..3].
   v[0]/v[1] are the 64-bit plaintext/ciphertext in-place. */
static inline void tea_encipher(uint32_t v[2], const uint32_t k[4]) {
    uint32_t v0 = v[0], v1 = v[1], sum = 0;
    for (uint8_t i = 0; i < (uint8_t)TEA_ROUNDS; i++) {
        sum += TEA_DELTA;
        v0 += ((v1 << 4) + k[0]) ^ (v1 + sum) ^ ((v1 >> 5) + k[1]);
        v1 += ((v0 << 4) + k[2]) ^ (v0 + sum) ^ ((v0 >> 5) + k[3]);
    }
    v[0] = v0; v[1] = v1;
}

/* Gate CRC: encrypt TEA_GATE_N fixed plaintexts with TEA_KEY,
   fold v[0]^v[1] into a rotate-XOR hash. */
static inline uint16_t tea_gate_crc(void) {
    uint16_t h = 0;
    for (uint16_t i = 0; i < (uint16_t)TEA_GATE_N; i++) {
        uint32_t v[2] = { (uint32_t)i, (uint32_t)(i + TEA_GATE_N) };
        tea_encipher(v, TEA_KEY);
        h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)(v[0] ^ v[1]);
    }
    return h;
}

#endif /* TEA_H */

#ifndef SRETREC_H
#define SRETREC_H

#include <stdint.h>

typedef struct { uint16_t a, b, c, d; } SrState;

__attribute__((noinline)) static SrState sr_recur(uint8_t depth, uint16_t seed) {
    SrState out;
    if (depth == 0u) {
        out.a = seed; out.b = (uint16_t)(seed ^ 0xA55Au);
        out.c = (uint16_t)(seed + 0x137u); out.d = (uint16_t)(seed - 0x29u);
        return out;
    }
    SrState child = sr_recur((uint8_t)(depth - 1u), (uint16_t)(seed + depth * 17u));
    out.a = (uint16_t)(child.a + depth);
    out.b = (uint16_t)(child.b ^ (uint16_t)(depth * 0x101u));
    out.c = (uint16_t)(child.c - (uint16_t)(depth * 3u));
    out.d = (uint16_t)(child.d + child.a + depth);
    return out;
}

static uint16_t sretrec_gate_crc(void) {
    uint16_t h = 0x6C31u;
    for (uint8_t d = 1u; d <= 12u; d++) {
        SrState s = sr_recur(d, (uint16_t)(0x1021u + d * 29u));
        h = (uint16_t)((h << 1) | (h >> 15)) ^ s.a ^ (uint16_t)(s.b * 3u)
          ^ (uint16_t)(s.c * 7u) ^ (uint16_t)(s.d * 11u);
    }
    return h;
}

#endif

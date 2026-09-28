#ifndef VAWIDTH_H
#define VAWIDTH_H

#include <stdarg.h>
#include <stdint.h>

static uint16_t vw_fold(uint16_t h, uint64_t v) {
    for (uint8_t i = 0; i < 8u; i++)
        h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)(v >> (i * 8u));
    return h;
}

__attribute__((noinline)) static uint16_t vw_read(uint16_t tag, ...) {
    va_list ap;
    va_start(ap, tag);
    uint16_t h = tag;
    h = vw_fold(h, (uint8_t)va_arg(ap, int));
    h = vw_fold(h, (uint16_t)va_arg(ap, unsigned int));
    h = vw_fold(h, (uint32_t)va_arg(ap, uint32_t));
    h = vw_fold(h, (uint64_t)va_arg(ap, uint64_t));
    const uint8_t *p = va_arg(ap, const uint8_t *);
    h = vw_fold(h, *p);
    va_end(ap);
    return h;
}

static uint16_t vawidth_gate_crc(void) {
    static const uint8_t pointed = 0xA7u;
    uint16_t h = vw_read(0x1357u, (int)0xE3, (unsigned int)0x91B2u,
                         (uint32_t)0x6D3A21C5u, (uint64_t)0xC17E5A903B24D68FULL,
                         &pointed);
    return h;
}

#endif

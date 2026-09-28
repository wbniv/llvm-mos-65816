#ifndef ARITYFAN_H
#define ARITYFAN_H

#include <stdint.h>

typedef uint16_t (*Af1)(uint16_t);
typedef uint16_t (*Af2)(uint16_t, uint16_t);
typedef uint16_t (*Af3)(uint16_t, uint16_t, uint16_t);
typedef uint16_t (*Af4)(uint16_t, uint16_t, uint16_t, uint16_t);
typedef union { Af1 f1; Af2 f2; Af3 f3; Af4 f4; } AfSlot;

__attribute__((noinline)) static uint16_t af_one(uint16_t a) { return (uint16_t)(a ^ 0x1357u); }
__attribute__((noinline)) static uint16_t af_two(uint16_t a, uint16_t b) { return (uint16_t)(a + b * 3u); }
__attribute__((noinline)) static uint16_t af_three(uint16_t a, uint16_t b, uint16_t c) { return (uint16_t)(a ^ (b << 1) ^ (c << 2)); }
__attribute__((noinline)) static uint16_t af_four(uint16_t a, uint16_t b, uint16_t c, uint16_t d) { return (uint16_t)(a + b * 3u + c * 5u + d * 7u); }

__attribute__((noinline)) static uint16_t af_call(uint8_t id, AfSlot *slots, uint16_t x) {
    switch (id & 3u) {
    case 0: return slots[0].f1(x);
    case 1: return slots[1].f2(x, (uint16_t)(x + 7u));
    case 2: return slots[2].f3(x, (uint16_t)(x + 7u), (uint16_t)(x ^ 0x55AAu));
    default: return slots[3].f4(x, (uint16_t)(x + 7u), (uint16_t)(x ^ 0x55AAu), (uint16_t)(x >> 1));
    }
}

static uint16_t arityfan_gate_crc(void) {
    AfSlot slots[4];
    slots[0].f1 = af_one; slots[1].f2 = af_two;
    slots[2].f3 = af_three; slots[3].f4 = af_four;
    uint16_t h = 0x42C7u;
    for (uint8_t i = 0; i < 64u; i++)
        h = (uint16_t)((h << 1) | (h >> 15)) ^ af_call(i, slots, (uint16_t)(i * 127u + 19u));
    return h;
}

#endif

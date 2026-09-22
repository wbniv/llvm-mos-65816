#include <stdint.h>

extern uint16_t ext(uint16_t, uint16_t);

__attribute__((noinline))
void stage(uint16_t *p, uint16_t k) {
    uint16_t a = (uint16_t)(p[0] + k);
    uint16_t b = (uint16_t)(p[1] ^ a);
    uint8_t c = (uint8_t)(((uint8_t *)p)[4] + (uint8_t)b);
    p[0] = (uint16_t)(ext(a, 13849u) + b);
    p[1] = (uint16_t)(b - (uint16_t)c);
    ((uint8_t *)p)[4] = (uint8_t)((a >> 8) ^ c);
}

#ifndef EXTLOAD_H
#define EXTLOAD_H

#include <stdint.h>

#define EL_FN(name, type, result) \
    __attribute__((noinline)) static result name(const volatile type *p) { return (result)*p; }

EL_FN(el_s8_s16, int8_t, int16_t)
EL_FN(el_s8_s32, int8_t, int32_t)
EL_FN(el_s8_s64, int8_t, int64_t)
EL_FN(el_u8_u16, uint8_t, uint16_t)
EL_FN(el_u8_u32, uint8_t, uint32_t)
EL_FN(el_u8_u64, uint8_t, uint64_t)
EL_FN(el_s16_s32, int16_t, int32_t)
EL_FN(el_s16_s64, int16_t, int64_t)
EL_FN(el_u16_u32, uint16_t, uint32_t)
EL_FN(el_u16_u64, uint16_t, uint64_t)
EL_FN(el_s32_s64, int32_t, int64_t)
EL_FN(el_u32_u64, uint32_t, uint64_t)

#undef EL_FN

static uint16_t extload_gate_crc(void) {
    static const volatile int8_t s8 = -117;
    static const volatile uint8_t u8 = 0xD3u;
    static const volatile int16_t s16 = -23451;
    static const volatile uint16_t u16 = 0xA17Bu;
    static const volatile int32_t s32 = (int32_t)0x87654321u;
    static const volatile uint32_t u32 = 0xFEDCBA98u;
    uint64_t values[12];
    values[0] = (uint16_t)el_s8_s16(&s8); values[1] = (uint32_t)el_s8_s32(&s8);
    values[2] = (uint64_t)el_s8_s64(&s8); values[3] = el_u8_u16(&u8);
    values[4] = el_u8_u32(&u8); values[5] = el_u8_u64(&u8);
    values[6] = (uint32_t)el_s16_s32(&s16); values[7] = (uint64_t)el_s16_s64(&s16);
    values[8] = el_u16_u32(&u16); values[9] = el_u16_u64(&u16);
    values[10] = (uint64_t)el_s32_s64(&s32); values[11] = el_u32_u64(&u32);
    uint16_t h = 0x73A9u;
    for (uint8_t i = 0; i < 12u; i++)
        h = (uint16_t)((h << 1) | (h >> 15)) ^ (uint16_t)values[i] ^ (uint16_t)(values[i] >> 32);
    return h;
}

#endif

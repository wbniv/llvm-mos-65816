# 1 "examples/snes/corpus/ascast_sim.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 370 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "examples/snes/corpus/ascast_sim.c" 2

# 1 "examples/snes/corpus/../../65816/ascast.h" 1



# 1 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 1 3
# 100 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef int16_t int_least16_t;
typedef uint16_t uint_least16_t;
typedef int16_t int_fast16_t;
typedef uint16_t uint_fast16_t;





typedef signed char int8_t;

typedef unsigned char uint8_t;







typedef int8_t int_least8_t;
typedef uint8_t uint_least8_t;
typedef int8_t int_fast8_t;
typedef uint8_t uint_fast8_t;
# 295 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/24/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 5 "examples/snes/corpus/../../65816/ascast.h" 2







static const uint8_t ac_data[16] = {
    0x13u, 0x27u, 0x3Bu, 0x4Fu, 0x52u, 0x66u, 0x7Au, 0x8Eu,
    0x91u, 0xA5u, 0xB9u, 0xCDu, 0xD0u, 0xE4u, 0xF8u, 0x0Cu
};
static volatile uintptr_t ac_opaque;

__attribute__((noinline)) static __attribute__((address_space(2))) const uint8_t *ac_to_far(const uint8_t *p) {
    return (__attribute__((address_space(2))) const uint8_t *)p;
}

__attribute__((noinline)) static const uint8_t *ac_to_near(__attribute__((address_space(2))) const uint8_t *p) {
    return (const uint8_t *)p;
}

__attribute__((noinline)) static uint8_t ac_read(uintptr_t address) {
    const uint8_t *near_p = (const uint8_t *)address;
    __attribute__((address_space(2))) const uint8_t *far_p = ac_to_far(near_p);
    const uint8_t *near_again = ac_to_near(far_p);
    __attribute__((address_space(2))) const uint8_t *far_again = ac_to_far(near_again);
    return *far_again;
}

static uint16_t ascast_gate_crc(void) {
    ac_opaque = (uintptr_t)&ac_data[0];
    uint16_t h = 0x2D61u;
    for (uint8_t i = 0; i < 16u; i++) {
        uintptr_t address = ac_opaque + i;
        h = (uint16_t)((h << 1) | (h >> 15)) ^ ac_read(address);
    }
    return h;
}
# 3 "examples/snes/corpus/ascast_sim.c" 2
volatile uint16_t corpus_result;
int main(void) { corpus_result = ascast_gate_crc(); for (;;) __asm__ volatile("wai"); }

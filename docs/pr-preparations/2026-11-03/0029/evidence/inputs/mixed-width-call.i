# 1 "/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c" 2
# 1 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 1 3
# 100 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
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
# 295 "/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/lib/clang/24/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 2 "/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c" 2

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

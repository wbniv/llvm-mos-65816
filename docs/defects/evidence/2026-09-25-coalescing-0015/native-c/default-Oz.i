# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c" 2
# 20 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c"
# 1 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 1 3
# 100 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
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
# 295 "/home/will/llvm-mos-65816/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 21 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c" 2

__attribute__((noinline)) void newton_step(int16_t *zr, int16_t *zi) {
    int16_t r = *zr, i = *zi;

    int16_t z2r = (int16_t)(((int32_t)r * (int32_t)r - (int32_t)i * (int32_t)i) >> 8);
    int16_t z2i = (int16_t)(((int32_t)r * (int32_t)i) >> 7);

    int16_t z3r = (int16_t)(((int32_t)z2r * (int32_t)r - (int32_t)z2i * (int32_t)i) >> 8);
    int16_t z3i = (int16_t)(((int32_t)z2r * (int32_t)i + (int32_t)z2i * (int32_t)r) >> 8);
    int16_t nr = (int16_t)(z3r - 256);
    int16_t ni = z3i;
    int16_t dr = (int16_t)(3 * (int32_t)z2r);
    int16_t di = (int16_t)(3 * (int32_t)z2i);
    int32_t snr = (int32_t)nr >> 1, sni = (int32_t)ni >> 1;
    int32_t sdr = (int32_t)dr >> 1, sdi = (int32_t)di >> 1;
    int32_t den = sdr * sdr + sdi * sdi;
    if (den == 0) return;
    int32_t qr = ((snr * sdr + sni * sdi) << 8) / den;
    int32_t qi = ((sni * sdr - snr * sdi) << 8) / den;
    if (qr > 512) qr = 512;
    if (qr < -512) qr = -512;
    if (qi > 512) qi = 512;
    if (qi < -512) qi = -512;
    *zr = (int16_t)(r - (int16_t)qr);
    *zi = (int16_t)(i - (int16_t)qi);
}

# 1 "/work/build/near-y-fix/near-wrap.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/work/build/near-y-fix/near-wrap.c" 2
# 1 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 1 3
# 100 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
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
# 295 "/work/build/near-y-fix/candidate/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 2 "/work/build/near-y-fix/near-wrap.c" 2

volatile uint16_t corpus_result;
__attribute__((noinline,used))
uint8_t near_wrap(const uint8_t *p, int16_t offset) {
  return p[offset];
}
asm(".text\n.global wrap_bank7e\nwrap_bank7e:\n"
    "php\n.byte $8b\n.byte $f4,$7e,$7e\n.byte $ab,$ab\n"
    "jsr near_wrap\n.byte $ab\nplp\nrts\n");
uint8_t wrap_bank7e(const uint8_t *p, int16_t offset);
int main(void) {
  *(volatile __attribute__((address_space(2))) uint8_t *)0x7ea802 = 0x5a;
  *(volatile __attribute__((address_space(2))) uint8_t *)0x7fa802 = 0xc3;
  uint8_t value = wrap_bank7e((const uint8_t *)0xa806, -4);
  corpus_result = value == 0x5a ? 0x5cf0 : (uint16_t)(0xa500 | value);
  for (;;) __asm__ volatile("wai");
}

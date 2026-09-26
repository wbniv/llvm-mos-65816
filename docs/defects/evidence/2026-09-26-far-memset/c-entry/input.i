# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-26-far-memset/original.c.txt"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-26-far-memset/original.c.txt" 2
# 19 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-26-far-memset/original.c.txt"
# 1 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 1 3
# 100 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
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
# 295 "/home/will/llvm-mos-65816/build/defect-baselines/2026-09-26-far-memset/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 20 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-26-far-memset/original.c.txt" 2


static __attribute__((address_space(2))) uint8_t *const grid = (__attribute__((address_space(2))) uint8_t *)0x7E2000u;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t i = 0;
  do { grid[i] = 0x42; } while (++i != 4096);




  uint16_t acc = 0;
  i = 0;
  do { acc = (uint16_t)(acc + grid[i]); } while (++i != 4096);
  corpus_result = acc;
  for (;;) __asm__ volatile("wai");
}

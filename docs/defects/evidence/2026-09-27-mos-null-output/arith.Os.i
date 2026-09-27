# 1 ".scratch/carry-pr/inputs/arith.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 363 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 ".scratch/carry-pr/inputs/arith.c" 2








# 1 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 1 3
# 100 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
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
# 295 "/work/.scratch/carry-scheduling/build/llvm-mos-install/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 10 ".scratch/carry-pr/inputs/arith.c" 2

volatile uint8_t a8 = 0xF0, b8 = 0x0F;
volatile uint16_t a16 = 1000, b16 = 7;
volatile uint32_t a32 = 100000, b32 = 3;
volatile uint16_t corpus_result;

int main(void) {
  uint16_t r = 0;
  r += (uint16_t)(a8 + b8);
  r += (uint16_t)(a8 & b8);
  r += (uint16_t)(a8 | b8);
  r += (uint16_t)(a8 ^ b8);
  r += (uint16_t)(a16 * b16);
  r += a16 / b16;
  r += a16 % b16;
  r += (uint16_t)(a32 / b32);
  r += (uint16_t)(a32 % b32);
  r += (uint16_t)(a16 << 1);
  r += (uint16_t)(a16 >> 2);
  corpus_result = r;
  for (;;) __asm__ volatile("");
}

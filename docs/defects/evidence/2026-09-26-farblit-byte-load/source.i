# 1 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c" 2
# 39 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c"
# 1 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 1 3
# 100 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
typedef long long int int64_t;

typedef long long unsigned int uint64_t;
# 122 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
typedef int64_t int_least64_t;
typedef uint64_t uint_least64_t;
typedef int64_t int_fast64_t;
typedef uint64_t uint_fast64_t;
# 197 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
typedef long int int32_t;




typedef long unsigned int uint32_t;
# 220 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
typedef int32_t int_least32_t;
typedef uint32_t uint_least32_t;
typedef int32_t int_fast32_t;
typedef uint32_t uint_fast32_t;
# 245 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
typedef int int16_t;

typedef unsigned int uint16_t;
# 259 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
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
# 295 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/build/carry-baseline-install/lib/clang/23/include/stdint.h" 3
typedef int intptr_t;






typedef unsigned int uintptr_t;





typedef long long int intmax_t;
typedef long long unsigned int uintmax_t;
# 40 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c" 2




volatile uint32_t rbase8 = 0xFFE0u;
volatile uint32_t rbase16 = 0x8000u;
volatile uint32_t rbasew = 0x7FE0u;
volatile uint32_t wbase8 = 0x7EFFE0u;
volatile uint32_t wbase16 = 0x7E4000u;
volatile uint32_t wbasec = 0x7F7FF0u;
volatile uint32_t rbasew16 = 0x10000u;
volatile uint16_t obase = 0xFFF0u;
volatile uint8_t k8 = 0xF0u;



static const uint16_t offs16[8] = {0x0000u, 0x00FFu, 0x0100u, 0x1234u,
                                   0x7FFFu, 0x8000u, 0xC001u, 0xFFFFu};

static inline uint32_t fold(uint32_t acc, uint32_t v) {
  acc = (acc << 1) | (acc >> 31);
  return acc ^ v;
}


extern const __attribute__((address_space(2))) uint16_t tbl[];



static uint32_t rd8(void) {
  const __attribute__((address_space(2))) uint8_t *src = ((const __attribute__((address_space(2))) uint8_t *)tbl) + rbase8;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, src[j]);
  return acc;
}
static uint32_t rdg(void) {
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, ((const __attribute__((address_space(2))) uint8_t *)tbl)[j]);
  return acc;
}
static uint32_t rd16(void) {
  const __attribute__((address_space(2))) uint8_t *src = ((const __attribute__((address_space(2))) uint8_t *)tbl) + rbase16;
  uint32_t acc = 0;
  for (uint8_t n = 0; n < 8; n++)
    acc = fold(acc, src[offs16[n]]);
  return acc;
}
static uint32_t rdw(void) {
  const __attribute__((address_space(2))) uint16_t *src = tbl + rbasew;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, src[j]);
  return acc;
}
static uint32_t rdw16(void) {
  const __attribute__((address_space(2))) uint8_t *src = ((const __attribute__((address_space(2))) uint8_t *)tbl) + rbasew16;
  uint16_t o = obase;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, src[o + j]);
  return acc;
}
static uint32_t rdw16g(void) {
  uint16_t o = obase;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, ((const __attribute__((address_space(2))) uint8_t *)tbl)[o + j]);
  return acc;
}
static uint32_t rdw8(void) {
  const __attribute__((address_space(2))) uint8_t *src = ((const __attribute__((address_space(2))) uint8_t *)tbl) + rbase8;
  uint8_t k = k8;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, src[(uint8_t)(j + k)]);
  return acc;
}
static void wr8(void) {
  __attribute__((address_space(2))) uint8_t *w = (__attribute__((address_space(2))) uint8_t *)wbase8;
  for (uint8_t j = 0; j < 64; j++)
    w[j] = (uint8_t)(j * 37u + 11u);
}
static void cp8(void) {
  __attribute__((address_space(2))) uint8_t *d = (__attribute__((address_space(2))) uint8_t *)wbasec;
  const __attribute__((address_space(2))) uint8_t *src = ((const __attribute__((address_space(2))) uint8_t *)tbl) + rbase8 + 8;
  for (uint8_t j = 0; j < 48; j++)
    d[j] = src[j];
}
static void wr16(void) {
  __attribute__((address_space(2))) uint8_t *w = (__attribute__((address_space(2))) uint8_t *)wbase16;
  for (uint8_t n = 0; n < 8; n++)
    w[offs16[n]] = (uint8_t)(0xA5u ^ (n * 29u));
}
# 205 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c"
static uint32_t run(void) {
  uint32_t acc = 0;
  acc = fold(acc, rd8());
  acc = fold(acc, rdg());
  acc = fold(acc, rd16());
  acc = fold(acc, rdw());
  acc = fold(acc, rdw16());
  acc = fold(acc, rdw16g());
  acc = fold(acc, rdw8());
  wr8();
  wr16();
  cp8();


  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7EFFE0u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7EFFFFu)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F0000u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F001Fu)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7E4000u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7E40FFu)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7E4100u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7E5234u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7EBFFFu)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7EC000u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F0001u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F3FFFu)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F7FF0u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F8007u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F8008u)));
  acc = fold(acc, (*(volatile __attribute__((address_space(2))) uint8_t *)(uint32_t)(0x7F801Fu)));
  return acc;
}
# 245 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/examples/65816/farblit.c"
volatile uint32_t corpus_result;
int main(void) {
  corpus_result = run();
  for (;;) __asm__ volatile("wai");
}

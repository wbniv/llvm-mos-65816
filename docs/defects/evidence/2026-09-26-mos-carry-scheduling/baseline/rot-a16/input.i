# 1 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/docs/defects/evidence/2026-09-26-mos-carry-scheduling/p_rot.c.txt"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 366 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/docs/defects/evidence/2026-09-26-mos-carry-scheduling/p_rot.c.txt" 2
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
# 2 "/home/will/llvm-mos-65816/.scratch/carry-scheduling/docs/defects/evidence/2026-09-26-mos-carry-scheduling/p_rot.c.txt" 2

extern const __attribute__((address_space(2))) uint16_t tbl[];
volatile int32_t i0=100,i1=50000,i2=90000;
volatile uint32_t out;
static inline uint32_t fold(uint32_t a,uint16_t v){a=(a<<1)|(a>>31);return a^(uint32_t)v;}
void f(void){uint32_t a=0;a=fold(a,tbl[i0]);a=fold(a,tbl[i1]);a=fold(a,tbl[i2]);out=a;}

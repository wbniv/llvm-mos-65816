# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/zp-index.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 362 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/zp-index.c" 2
typedef unsigned char __attribute__((address_space(1))) zp_byte;

unsigned char load_zp(unsigned char index) {
  return ((zp_byte *)17)[index];
}

void store_zp(unsigned char index, unsigned char value) {
  ((zp_byte *)17)[index] = value;
}

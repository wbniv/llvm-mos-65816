// Farblit checks native-width far accesses and range-proven runtime indexing.
// dev/farblit.sh checks each marked access in optimized assembly with line tables.
//
// rd8 / rdw8: byte [dp],Y with an 8-bit index, including a wrapped byte sum.
// rd16 / rdw16: byte [dp],Y with Y16 under +mos-xy16; A16 computes the pointer.
// rdw: one native 16-bit [dp] load with the scaled pointer computed explicitly.
// rdg: global long,X with X8. rdw16g uses X16 under +mos-xy16 and a computed
// pointer under A16. The wrapped 16-bit sum must stay within the source bank.
// wr8: byte [dp],Y with Y8. wr16 uses Y16 under +mos-xy16 and a computed
// pointer under A16. At -Os, cp8 loads and stores with Y8: its bounded loop
// proves j is 0..47, so the source displacement j+8 fits an 8-bit index.
//
// Runtime bases are volatile, and accesses cross bank boundaries. The host oracle
// models wrapping at MOS integer widths. Stores are read back through constant
// absolute-long addresses so a matching load-address error cannot hide a bad store.
// tbl[i] = (i + (i >> 16)) & 0xFFFF, little-endian, at $C10000 across three banks.
// High WRAM $7E2000-$7FFFFF is unused by the snes-hirom link script.
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// VOLATILE so every base is a runtime value (-> Imag32 quad + `[dp],y`), never an absolute-long
// constant.
volatile uint32_t rbase8 = 0xFFE0u;   // byte offset into tbl: $C1FFE0
volatile uint32_t rbase16 = 0x8000u;  // byte offset into tbl: $C18000
volatile uint32_t rbasew = 0x7FE0u;   // uint16_t ELEMENT offset: byte $C1FFC0
volatile uint32_t wbase8 = 0x7EFFE0u; // WRAM
volatile uint32_t wbase16 = 0x7E4000u; // WRAM
volatile uint32_t wbasec = 0x7F7FF0u; // WRAM
volatile uint32_t rbasew16 = 0x10000u; // byte offset into tbl: $C20000
volatile uint16_t obase = 0xFFF0u;     // 16-bit offset that wraps inside the loop
volatile uint8_t k8 = 0xF0u;           // 8-bit offset that wraps inside the loop

// 16-bit offsets: < $100, straddling $100, and >= $8000 (crossing into the next bank off
// $C18000 / $7E4000 is at +$8000 / +$C000).
static const uint16_t offs16[8] = {0x0000u, 0x00FFu, 0x0100u, 0x1234u,
                                   0x7FFFu, 0x8000u, 0xC001u, 0xFFFFu};

static inline uint32_t fold(uint32_t acc, uint32_t v) {
  acc = (acc << 1) | (acc >> 31); // rotate-left-1
  return acc ^ v;
}

#ifndef HOST
extern const FAR uint16_t tbl[];
#define TBLB ((const FAR uint8_t *)tbl)
#define RDA(a) (*(volatile FAR uint8_t *)(uint32_t)(a))

static uint32_t rd8(void) {
  const FAR uint8_t *src = TBLB + rbase8;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, src[j]); // FARBLIT-PROBE: rd8
  return acc;
}
static uint32_t rdg(void) {
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, TBLB[j]); // FARBLIT-PROBE: rdg
  return acc;
}
static uint32_t rd16(void) {
  const FAR uint8_t *src = TBLB + rbase16;
  uint32_t acc = 0;
  for (uint8_t n = 0; n < 8; n++)
    acc = fold(acc, src[offs16[n]]); // FARBLIT-PROBE: rd16
  return acc;
}
static uint32_t rdw(void) {
  const FAR uint16_t *src = tbl + rbasew;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, src[j]); // FARBLIT-PROBE: rdw
  return acc;
}
static uint32_t rdw16(void) {
  const FAR uint8_t *src = TBLB + rbasew16;
  uint16_t o = obase;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, src[o + j]); // FARBLIT-PROBE: rdw16
  return acc;
}
static uint32_t rdw16g(void) {
  uint16_t o = obase;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, TBLB[o + j]); // FARBLIT-PROBE: rdw16g
  return acc;
}
static uint32_t rdw8(void) {
  const FAR uint8_t *src = TBLB + rbase8;
  uint8_t k = k8;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, src[(uint8_t)(j + k)]); // FARBLIT-PROBE: rdw8
  return acc;
}
static void wr8(void) {
  FAR uint8_t *w = (FAR uint8_t *)wbase8;
  for (uint8_t j = 0; j < 64; j++)
    w[j] = (uint8_t)(j * 37u + 11u); // FARBLIT-PROBE: wr8
}
static void cp8(void) {
  FAR uint8_t *d = (FAR uint8_t *)wbasec;
  const FAR uint8_t *src = TBLB + rbase8 + 8;
  for (uint8_t j = 0; j < 48; j++)
    d[j] = src[j]; // FARBLIT-PROBE: cp8
}
static void wr16(void) {
  FAR uint8_t *w = (FAR uint8_t *)wbase16;
  for (uint8_t n = 0; n < 8; n++)
    w[offs16[n]] = (uint8_t)(0xA5u ^ (n * 29u)); // FARBLIT-PROBE: wr16
}
#else
// Host has no addrspace 2: reproduce the table's closed form byte-wise and model high WRAM
// $7E0000-$7FFFFF as an array.
static uint16_t tblv(uint32_t i) { return (uint16_t)((i + (i >> 16)) & 0xFFFFu); }
static uint8_t byteat(uint32_t b) {
  uint16_t v = tblv(b >> 1);
  return (b & 1u) ? (uint8_t)(v >> 8) : (uint8_t)v;
}
static uint8_t wram[0x20000];
#define RDA(a) (wram[(uint32_t)(a) - 0x7E0000u])

static uint32_t rd8(void) {
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, byteat(rbase8 + j));
  return acc;
}
static uint32_t rdg(void) {
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, byteat(j));
  return acc;
}
static uint32_t rd16(void) {
  uint32_t acc = 0;
  for (uint8_t n = 0; n < 8; n++)
    acc = fold(acc, byteat(rbase16 + offs16[n]));
  return acc;
}
static uint32_t rdw(void) {
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, tblv(rbasew + j));
  return acc;
}
static uint32_t rdw16(void) {
  uint16_t o = obase;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, byteat(rbasew16 + (uint16_t)(o + j)));
  return acc;
}
static uint32_t rdw16g(void) {
  uint16_t o = obase;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, byteat((uint16_t)(o + j)));
  return acc;
}
static uint32_t rdw8(void) {
  uint8_t k = k8;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, byteat(rbase8 + (uint8_t)(j + k)));
  return acc;
}
static void wr8(void) {
  for (uint8_t j = 0; j < 64; j++)
    wram[wbase8 - 0x7E0000u + j] = (uint8_t)(j * 37u + 11u);
}
static void cp8(void) {
  for (uint8_t j = 0; j < 48; j++)
    wram[wbasec - 0x7E0000u + j] = byteat(rbase8 + 8u + j);
}
static void wr16(void) {
  for (uint8_t n = 0; n < 8; n++)
    wram[wbase16 - 0x7E0000u + offs16[n]] = (uint8_t)(0xA5u ^ (n * 29u));
}
#endif

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
  // Read the stores back through CONSTANT absolute-long addresses — both sides of each
  // bank boundary, plus the extremes of each run.
  acc = fold(acc, RDA(0x7EFFE0u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7EFFFFu)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F0000u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F001Fu)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7E4000u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7E40FFu)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7E4100u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7E5234u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7EBFFFu)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7EC000u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F0001u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F3FFFu)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F7FF0u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F8007u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F8008u)); // FARBLIT-PROBE: readback
  acc = fold(acc, RDA(0x7F801Fu)); // FARBLIT-PROBE: readback
  return acc; // host oracle is the source of truth
}

#ifdef HOST
#include <stdio.h>
int main(void) {
  printf("0x%08lX\n", (unsigned long)run());
  return 0;
}
#else
volatile uint32_t corpus_result;
int main(void) {
  corpus_result = run();
  for (;;) __asm__ volatile("wai");
}
#endif

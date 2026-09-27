// #321 Phase 2 inc 2 GATE — `lda [dp],y` (b7) / `sta [dp],y` (97) with a RUNTIME index.
//
// Increment 2 (docs/plans/2026-09-25-dpy-indexed-phase2-increment2.md) folds a runtime byte offset
// into Y when known-bits prove it fits: 0..255 for an 8-bit Y, 0..65535 for a 16-bit Y (+mos-xy16
// only). The fold replaces a 32-bit pointer add, so it is only correct because `[dp],Y` adds Y to
// the FULL 24-bit pointer with carry into the bank byte — for an 8-bit AND a 16-bit Y, for loads
// AND stores. Every probe below crosses a bank boundary through Y, so a Y that wrapped inside the
// bank would read/write the wrong byte:
//
//   rd8   runtime far ptr $C1FFE0 + j (u8, 0..63)       8-bit Y, crosses $C1 -> $C2 at j = 32
//   rdg   GLOBAL base tbl ($C10000) + j (u8, 0..63)     NOT folded: an absolute base is declined
//                                                       (gate (d)); a correctness probe only
//   rd16  runtime far ptr $C18000 + offs16[n] (u16)     16-bit Y under xy16, crosses at >= $8000
//   rdw   far uint16_t ptr at byte $C1FFC0, [j] (u8)    scaled 2j+{0,1}: known-bits bound 511 > 255,
//                                                       so 16-bit Y under xy16; crosses at j = 32
//   wr8   runtime far ptr $7EFFE0 + j (u8, 0..63)       8-bit Y STORE, crosses WRAM $7E -> $7F
//   wr16  runtime far ptr $7E4000 + offs16[n] (u16)     16-bit Y STORE under xy16, reaches $7F3FFF
//   rdw16 runtime far ptr $C20000 + (o + j), o = 0xFFF0: the offset is the 16-bit `o + j` that
//         WRAPS at j = 16 (MOS int is 16 bits, no nuw) — C reads $C2FFF0..$C2FFFF then
//         $C20000..$C2000F. Folds only under xy16, with Y = the WRAPPED sum; a fold that
//         re-associated it into (ptr + o) + j would read $C30000.. instead.
//   rdw16g GLOBAL tbl[o + j] — dev/dpy-shapes/loop.c's exact shape. Not folded (absolute base);
//         kept as the wrap probe for whichever mode takes that shape next (`lda long,X`).
//   rdw8  runtime far ptr + (uint8_t)(j + k8), k8 = 0xF0: the same trap at 8 bits (wraps at j = 16).
//   cp8   far -> far copy loop, ONE Y for both `lda [src],y` and `sta [dst],y`; src $C1FFE8 crosses
//         $C1 -> $C2 at j = 0x18.
//
// Stores are read back through CONSTANT absolute-long addresses (`lda long`, $af), which never
// use Y, so a store that landed on the wrong byte cannot be masked by a load that mis-addresses
// the same way. (A bank-wrapped 8-bit-Y store would land in $7E0000-$7E001F, the direct page.)
//
// Under +mos-a16 alone rd16/rdw/wr16 are NOT foldable (offset > 255) and take the unchanged
// pointer-add path; under +mos-xy16 they fold with a 16-bit Y. Both builds must agree with the
// host oracle — the differential is host == +mos-a16 == +mos-a16 +mos-xy16 on MAME + bsnes-jg.
//
// Reuses farindex's generated table (tools/gen-farindex-lut-asm.py, HiROM banks $C1-$C3) and its
// VALUE CONTRACT: tbl[i] = (i + (i >> 16)) & 0xFFFF, little-endian, based at $C10000. High WRAM
// $7E2000-$7FFFFF is unused by the snes-hirom link script.
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
    acc = fold(acc, src[j]);
  return acc;
}
static uint32_t rdg(void) {
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, TBLB[j]);
  return acc;
}
static uint32_t rd16(void) {
  const FAR uint8_t *src = TBLB + rbase16;
  uint32_t acc = 0;
  for (uint8_t n = 0; n < 8; n++)
    acc = fold(acc, src[offs16[n]]);
  return acc;
}
static uint32_t rdw(void) {
  const FAR uint16_t *src = tbl + rbasew;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 64; j++)
    acc = fold(acc, src[j]);
  return acc;
}
static uint32_t rdw16(void) {
  const FAR uint8_t *src = TBLB + rbasew16;
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
    acc = fold(acc, TBLB[o + j]);
  return acc;
}
static uint32_t rdw8(void) {
  const FAR uint8_t *src = TBLB + rbase8;
  uint8_t k = k8;
  uint32_t acc = 0;
  for (uint8_t j = 0; j < 32; j++)
    acc = fold(acc, src[(uint8_t)(j + k)]);
  return acc;
}
static void wr8(void) {
  FAR uint8_t *w = (FAR uint8_t *)wbase8;
  for (uint8_t j = 0; j < 64; j++)
    w[j] = (uint8_t)(j * 37u + 11u);
}
static void cp8(void) {
  FAR uint8_t *d = (FAR uint8_t *)wbasec;
  const FAR uint8_t *src = TBLB + rbase8 + 8;
  for (uint8_t j = 0; j < 48; j++)
    d[j] = src[j];
}
static void wr16(void) {
  FAR uint8_t *w = (FAR uint8_t *)wbase16;
  for (uint8_t n = 0; n < 8; n++)
    w[offs16[n]] = (uint8_t)(0xA5u ^ (n * 29u));
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
  acc = fold(acc, RDA(0x7EFFE0u));
  acc = fold(acc, RDA(0x7EFFFFu));
  acc = fold(acc, RDA(0x7F0000u));
  acc = fold(acc, RDA(0x7F001Fu));
  acc = fold(acc, RDA(0x7E4000u));
  acc = fold(acc, RDA(0x7E40FFu));
  acc = fold(acc, RDA(0x7E4100u));
  acc = fold(acc, RDA(0x7E5234u));
  acc = fold(acc, RDA(0x7EBFFFu));
  acc = fold(acc, RDA(0x7EC000u));
  acc = fold(acc, RDA(0x7F0001u));
  acc = fold(acc, RDA(0x7F3FFFu));
  acc = fold(acc, RDA(0x7F7FF0u));
  acc = fold(acc, RDA(0x7F8007u));
  acc = fold(acc, RDA(0x7F8008u));
  acc = fold(acc, RDA(0x7F801Fu));
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

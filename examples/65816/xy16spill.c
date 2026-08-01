// #321 xy16 COMPILE-TIME GATE — static-stack spill with +mos-xy16 (implies +mos-a16).
//
// The xy16 Layer 4 changes (MOSInstrInfo::loadStoreRegStackSlot) add Xc16/Yc16 cases
// to the static-stack spill router — they must not disturb the existing Ac16 case. This
// test is the compile-time guard for that invariant: an Ac16 value is spilled across a
// call under +mos-xy16, so both the Ac16 spill path AND the new Xc16/Yc16 code path
// (inert at this source level since the legalizer doesn't yet assign to Xc16/Yc16)
// must compile clean under -verify-machineinstrs.
//
// Parallel to examples/65816/a16spill.c (which guards the same Ac16 spill under
// +mos-a16 alone). Driven by dev/run.sh xy16spill.
//
//   mos-clang --target=mos -mcpu=mosw65816 \
//     -Xclang -target-feature -Xclang +mos-xy16 \
//     -Os -mllvm -verify-machineinstrs -c xy16spill.c
volatile unsigned short in_u2 = 0x8298;
volatile unsigned short in_s0_u = 0x3C5F;
volatile unsigned short in_idx = 0xE623;
volatile unsigned short gs0 = 0x6B7F;
volatile unsigned char gb0 = 0x30;
volatile unsigned short corpus_result;
unsigned short arr[8] = {0xE409, 0x885C, 0x7520, 0x3457, 0xA286, 0x0FA9, 0x0B6D, 0x0D07};

__attribute__((noinline)) static unsigned short f0(unsigned short p0, unsigned short p1) {
  return (unsigned short)((unsigned short)((short)((unsigned short)0xE032u) >> 8) -
                          (unsigned short)((unsigned)in_u2 - (unsigned short)0xD515u));
}

int main(void) {
  unsigned short lu2 = 0xC795;
  short ls0 = 0xDD93;
  unsigned short *p = &arr[(unsigned)in_idx & 7];
  if (((unsigned short)0xA98Au) <=
      ((unsigned short)((unsigned)gs0 -
                        (unsigned)f0((unsigned short)((unsigned)lu2),
                                     (unsigned short)((unsigned)ls0))))) {
    *p = (unsigned short)0x6627u;
    gb0 = (unsigned char)((unsigned)arr[(unsigned)gb0 & 7]);
  } else {
    (void)((unsigned short)((unsigned)f0((unsigned short)((unsigned)gs0),
                                         (unsigned short)0x1CBCu) >
                             (unsigned short)((unsigned)gs0 ^ (unsigned)(*p))));
  }
  for (;;) __asm__ volatile("wai");
}

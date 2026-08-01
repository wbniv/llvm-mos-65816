// #321 xy16 SOFT-STACK SPILL GATE — +mos-xy16 with a recursive function.
//
// The xy16 Layer 4 changes (MOSRegisterInfo::expandLDSTStk) add Xc16/Yc16 cases
// to the soft-stack spill router — they must not disturb the existing Ac16 path.
// This is the compile+value guard for that invariant: a recursive function spills
// an Ac16 value to the SOFT STACK under +mos-xy16, so the new IsXc16/IsYc16 booleans
// (inert at this source level — the legalizer doesn't yet assign to Xc16/Yc16) and
// the extended pointer-forming guard must not break the Ac16 path.
//
// Parallel to examples/65816/a16spillr.c (+mos-a16 alone). Driven by dev/run.sh xy16spillr.
// Expected corpus_result: 0x3457 (host == default == +mos-xy16 on both emulators).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 \
//     -Xclang -target-feature -Xclang +mos-xy16 -Os xy16spillr.c
volatile unsigned short in_idx = 0xE623;
volatile unsigned short gs0 = 0x6B7F;
volatile unsigned char gb0 = 0x30;
volatile unsigned short corpus_result;
unsigned short arr[8] = {0xE409, 0x885C, 0x7520, 0x3457, 0xA286, 0x0FA9, 0x0B6D, 0x0D07};

__attribute__((noinline)) static unsigned short work(unsigned short n) {
  if (n == 0)
    return (unsigned short)((unsigned)gs0);
  unsigned short *p = &arr[(unsigned)in_idx & 7];
  unsigned short t;
  if ((unsigned short)0xA98Au <=
      (unsigned short)((unsigned)gs0 - (unsigned)work((unsigned short)((unsigned)n - 1u)))) {
    *p = (unsigned short)0x6627u;
    t = (unsigned short)((unsigned)arr[(unsigned)gb0 & 7]);
  } else {
    t = (unsigned short)((unsigned)work((unsigned short)((unsigned)n - 1u)) >
                         (unsigned short)((unsigned)gs0 ^ (unsigned)(*p)));
  }
  return (unsigned short)((unsigned)(*p) + (unsigned)t);
}

int main(void) {
  corpus_result = work(3);
  for (;;) __asm__ volatile("wai");
}

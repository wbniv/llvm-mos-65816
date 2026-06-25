// #321 / trig-accurate-LUT FINDING repro — far (addrspace 2) array indexed loads drop the
// high bits of the index offset, so a read whose `index*elemsize` crosses a 64 KiB bank
// boundary mis-addresses. Far indexed loads only work WITHIN one 64 KiB bank.
//
// Built on platforms/snes-hirom (HiROM, contiguous banks $C1+) where a >64 KiB array can live.
// The far table `tbl` is supplied by assembly (the mos frontend rejects a >64 KiB C array:
// 16-bit size_t); see tools/gen-sin-lut-asm.py / docs/plans/2026-06-25-trig-accurate-sin-lut-hirom.md.
// Here we instead use a small generated stub so the repro is self-contained — but the libfixmath
// LUT (102688 x uint16) shows the same failure.
//
// Observed on bsnes-jg (snes-hirom, +mos-a16), table based at $C10000:
//   tbl[100]    off 0x000C8 -> $C100C8 (bank $C1)  read OK   (no carry into the bank byte)
//   tbl[50000]  off 0x186A0 -> $C286A0 (bank $C2)  read WRONG (got 0x0000, want the C1+1 entry)
//   tbl[90000]  off 0x2BF20 -> $C3BF20 (bank $C3)  read WRONG (~ the offset truncated to 16 bits)
//
// The disasm is structurally correct (R_MOS_ADDR24_SEGMENT_LO/HI/BANK + `lda [dp]`); the defect is
// the runtime 24-bit pointer arithmetic for index offsets >= 64 KiB. Fix = backend codegen
// (far-pointer `G_PTR_ADD {PF,S32}` index must carry into the bank byte) — a compiler change.
//
// NOTE: this is a DOCUMENTED-OPEN repro, not yet a passing gate. The data array is provided by a
// generated .s at build time (the kernel just declares it extern far).
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

// Provided by a generated .far_rodata asm: tbl[i] = i (so a correct read of tbl[i] returns i).
extern const FAR uint16_t tbl[];

volatile int32_t i0 = 100, i1 = 50000, i2 = 90000;
volatile uint16_t r0, r1, r2;   // expect 100, 50000&0xFFFF, 90000&0xFFFF if reads were correct

int main(void) {
  r0 = tbl[i0];
  r1 = tbl[i1];
  r2 = tbl[i2];
  for (;;) { }
}

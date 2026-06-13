// #320 Increment 1 — far-pointer codegen disassembly test.
//
// A "far" (addrspace 2) byte access on the WDC 65816 lowers to absolute-long
// addressing — LDA/STA $xxxxxx (opcodes AF/8F, 4 bytes, 24-bit address incl. the
// bank byte) — while an ordinary near (addrspace 0) access stays 16-bit absolute
// — LDA/STA $xxxx (opcodes AD/8D/8E, 3 bytes). This is ROADMAP step 4,
// "addrspace -> addressing mode", verified at the disassembly level.
//
//   mos-clang --target=mos -mcpu=mosw65816 -Os -c far-deref.c -o far-deref.o
//   llvm-objdump -dr --mcpu=mosw65816 far-deref.o
//
// See docs/plans/2026-06-14-320-far-pointer-codegen.md. Driven by dev/run.sh far.

// A far pointer/global lives in address space 2.
#define FAR __attribute__((address_space(2)))

// (1) Constant addresses — deterministic encoding. Near 0x1234 stays 16-bit
// absolute; far 0x7E1234 becomes absolute-long, and the disassembly shows the
// full 24-bit address (note the bank byte 7e) only in the far case.
unsigned char load_near(void) { return *(volatile unsigned char *)0x1234; }
void store_near(void) { *(volatile unsigned char *)0x1234 = 0x42; }
unsigned char load_far(void) { return *(volatile unsigned char FAR *)0x7E1234; }
void store_far(void) { *(volatile unsigned char FAR *)0x7E1234 = 0x42; }

// (2) A far global — the realistic case. Its address is a symbol, so the far
// store must emit a 24-bit (R_MOS_ADDR24) relocation, not a 16-bit one.
extern volatile unsigned char FAR farbyte;
unsigned char load_far_global(void) { return farbyte; }
void store_far_global(void) { farbyte = 0x42; }

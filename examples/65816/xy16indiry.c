// #321 xy16 (zp),Y16 16-BIT-INDEX indirect-indexed GATE — B2 legalizer: G_LOAD_INDIR_IDX16.
//
// The sibling abs,X16 B2 path (G_LOAD_ABS_IDX16) is gated by xy16ops.c; the (zp),Y16
// path was wired (MOSLegalizerInfo tryIndirectIndexedAddressing -> G_LOAD_INDIR_IDX16;
// MOSInstructionSelector selectXY16 -> LDYImag16 + LDIndirYIdx16) but UNEXERCISED.
//
// Trigger: a RUNTIME pointer (volatile-pointer-to-volatile -> the base is loaded into an
// Imag16 ZP pair, i.e. the indirect (zp) form, NOT a compile-time-constant abs base) plus
// an unmasked `volatile unsigned short` byte offset (KnownBits cannot prove <=255, and it
// is not a G_ZEXT from <=8 bits) -> under +mos-xy16 the B2 gate emits G_LOAD_INDIR_IDX16,
// selecting LDYImag16 (idx -> Y16) + LDIndirYIdx16 (rep #$30; lda (dp),Y in 16-bit M/X).
//
// The offset is 0x102 (> 255) ON PURPOSE: a wrongly-8-bit Y would address byte 0x02 and
// read the WRONG value, so the host == default == +mos-a16 == +mos-xy16 differential
// catches a Y-truncation miscompile, not just a coincidental byte match.
//
//   g_buf[0x102] = 0x5A (low), g_buf[0x103] = 0x7E (high)  ->  LE u16 = 0x7E5A.
//   Expected corpus_result == 0x7E5A (host == default == +mos-a16 == +mos-xy16, both emulators).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 \
//     -Xclang -target-feature -Xclang +mos-xy16 -Os xy16indiry.c
unsigned char g_buf[0x140] = { [0x102] = 0x5A, [0x103] = 0x7E };
volatile unsigned char *volatile g_ptr = g_buf;   // runtime pointer -> Imag16 (zp) base
volatile unsigned short g_off = 0x102;            // unmasked u16 -> 16-bit Y (B2 gate fires)
volatile unsigned short corpus_result;

int main(void) {
    corpus_result = *(volatile unsigned short *)(g_ptr + g_off);  // (zp),Y16; expect 0x7E5A
    for (;;) __asm__ volatile("wai");
}

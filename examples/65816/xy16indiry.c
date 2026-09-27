// A volatile pointer and unmasked 16-bit byte offset require near (zp),Y16.
// The fused index load/access keeps Y=0x102 intact through allocation and
// width insertion. The word at that offset is 0x7E5A in every width mode.
unsigned char g_buf[0x140] = { [0x102] = 0x5A, [0x103] = 0x7E };
volatile unsigned char *volatile g_ptr = g_buf;   // runtime pointer -> Imag16 (zp) base
volatile unsigned short g_off = 0x102;            // unmasked u16 -> 16-bit Y (B2 gate fires)
volatile unsigned short corpus_result;

int main(void) {
    corpus_result = *(volatile unsigned short *)(g_ptr + g_off);  // (zp),Y16; expect 0x7E5A
    for (;;) __asm__ volatile("wai");
}

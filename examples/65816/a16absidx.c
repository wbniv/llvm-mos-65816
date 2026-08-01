// Native 16-bit abs,x load and store.
// `g_bytes` is a byte buffer; reading/writing 2 bytes at a time as unsigned short.
// `g_off` is a volatile global unsigned char so the compiler loads it at runtime
// (can't constant-fold the pointer arithmetic -> the LLVM IR sees
//  G_PTR_ADD(G_GLOBAL_VALUE(g_bytes), G_ZEXT(off)) -> tryIndexedAddressing16
//  emits G_LOAD16_ABS_IDX -> lda abs,x in M=0).
volatile unsigned char g_bytes[8] = {
  0x34, 0x12,   /* LE short 0x1234 at offset 0 */
  0x78, 0x56,   /* LE short 0x5678 at offset 2 */
  0xBC, 0x9A,   /* LE short 0x9ABC at offset 4 */
  0xF0, 0xDE,   /* LE short 0xDEF0 at offset 6 */
};
volatile unsigned char g_off = 4;
volatile unsigned short corpus_result;

int main(void) {
  unsigned char off = g_off;   /* runtime load; off has 8-bit type -> ZEXT to 16-bit */
  /* Read 16-bit value at byte offset 4 -> 0x9ABC */
  unsigned short val = *(volatile unsigned short *)(g_bytes + off);
  corpus_result = val;   /* expect 0x9ABC */
  for (;;) __asm__ volatile("wai");
}

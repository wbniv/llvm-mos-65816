// Native 16-bit (zp),y load via a runtime pointer + 8-bit Y offset.
// A volatile pointer-to-volatile forces the pointer to be loaded from memory
// each time (ZP Imag16 pair at runtime). `g_y_off` is volatile so the compiler
// can't constant-fold the address -> G_PTR_ADD(g_pptr_reg, G_ZEXT(y_off))
// -> tryIndexedAddressing16 emits G_LOAD16_INDIR_IDX -> lda (zp),y in M=0.
typedef struct { unsigned short a; unsigned short b; } Pair;
volatile Pair g_pair = {0x1234, 0x5678};
volatile Pair *volatile g_pptr = &g_pair;
volatile unsigned char g_y_off = 2;   /* byte offset to member .b */
volatile unsigned short corpus_result;

int main(void) {
  unsigned char y_off = g_y_off;   /* runtime load; 8-bit type -> ZEXT */
  /* g_pptr is a runtime 16-bit pointer (in Imag16).
     g_pptr->b is at g_pptr+2.  Because y_off is unsigned char,
     the offset is G_ZEXT(y_off) -> tryIndexedAddressing16 emits G_LOAD16_INDIR_IDX. */
  corpus_result = *(volatile unsigned short *)
                    ((volatile unsigned char *)g_pptr + y_off);  /* expect 0x5678 */
  for (;;) __asm__ volatile("wai");
}

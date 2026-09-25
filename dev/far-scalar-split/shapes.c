/* dev/far-scalar-split/shapes.c -- far 16-bit scalar access shapes, 16-bit ambient (+mos-a16).
 * Each function is compiled as-is ("current") and hand-edited to a single M=0 access ("m0",
 * dev/far-scalar-split/m0/<fn>.s) with nothing else changed. */
#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint16_t fg;     /* far ROM scalar                              */
extern FAR uint16_t       fc;     /* far WRAM scalar ($7E/$7F), read-modify-write */
extern volatile FAR uint16_t fv;  /* far WRAM scalar shared with an ISR: re-read  */
uint16_t srcw[32], dstw[32];
volatile uint16_t out;

/* (1) the §5 one-liner: leaf, A:X argument, A:X return */
uint16_t xe(uint16_t x) { return x ^ fg; }
/* (2) far WRAM counter RMW: two far loads + one far store, no A:X boundary on the value */
void tick(void) { fc = fc + fg; }
/* (3) loop, far volatile scalar re-read every iteration and consumed by a 16-bit op */
void mixv(void) { for (uint8_t j = 0; j < 32; j++) dstw[j] = srcw[j] ^ fv; }
/* (4) loop, non-volatile far scalar: loaded once (hoisted), used many times */
void mixh(void) { uint16_t k = fg; for (uint8_t j = 0; j < 32; j++) dstw[j] = (srcw[j] + k) ^ (k >> 1); }
/* (5) runtime far pointer walk (the census-dominant shape: lzss-gallery / farindex) */
uint16_t sump(const FAR uint16_t *p, uint8_t n) { uint16_t s = 0; while (n--) s += *p++; return s; }
/* (6) runtime far pointer store walk */
void fillp(FAR uint16_t *p, uint8_t n) { uint16_t v = out; while (n--) *p++ = v; }
/* (7) register-resident consumer: the value leaves in A:X (every use is a G_UNMERGE). Lesson 2:
 * a native M=0 load does not win here; today's legalizeLoadStore16 AllUsesUnmerge gate keeps the
 * NEAR analog byte-split, so a Phase 2 routed through it keeps this one byte-split too. */
uint16_t ldr(void) { return fg; }
/* (8) the corpus winner idiom (dblbridge _title_reserve, lzss-gallery main / vram_words_far):
 * far-source VRAM word upload through $2118/$2119 (uint8_t count: one back-edge for cycles.py) */
#define VMDATA (*(volatile uint16_t *)0x2118)
void vramup(const FAR uint16_t *p, uint8_t n) { while (n--) VMDATA = *p++; }
/* (9) store of a register-resident (A:X argument) value -- the store-side loss vector */
extern FAR uint16_t fs;
void str(uint16_t v) { fs = v; }

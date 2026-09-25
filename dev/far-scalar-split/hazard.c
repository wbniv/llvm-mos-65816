/* dev/far-scalar-split/hazard.c -- near-global s16 shapes the native path may select with a
 * 16-bit (DBR-relative, R_MOS_ADDR16) operand. Compiled with FAR empty, this shows which native s16
 * forms a Phase 2 must NOT hand a far symbol (it would drop the bank byte). Compiled with FAR as
 * address_space(2), it shows today's (byte-split) far output for the same shapes. */
#include <stdint.h>
#ifndef FAR
#define FAR __attribute__((address_space(2)))
#endif
extern FAR uint16_t hc;
extern FAR uint16_t hn;
volatile uint16_t o;
void h_inc(void) { hc++; }                             /* inc abs?                 */
void h_dec(void) { hc--; }                             /* dec abs?                 */
void h_or(void) { hc |= 0x0404; }                      /* tsb abs?                 */
void h_andn(void) { hc &= ~0x0404; }                   /* trb abs?                 */
void h_shl(void) { hc <<= 1; }                         /* asl abs?                 */
void h_zero(void) { hc = 0; }                          /* stz abs?                 */
void h_cmp(uint16_t x) { if (x == hc) o = 1; }         /* cmp fold                 */
void h_cmpimm(void) { if (hc == 0x1234) o = 1; }       /* CmpBrAbsImm16            */
void h_cmpaa(void) { if (hc == hn) o = 1; }            /* CmpBrAbsAbs16            */
void h_cnt(void) { for (uint16_t i = hn; i != 0; i--) o = i; }  /* xy16 B1: ldx abs16 */
void h_cpy(void) { hc = hn; }                          /* load->store copy         */

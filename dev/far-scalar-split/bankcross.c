// bankcross.c -- does a single M=0 16-bit far access at $xxFFFF carry into the NEXT bank
// (like today's byte-split `af fg` / `af fg+1`, whose second address the linker computes as a
// full 24-bit sum), or wrap within the bank?
//
// Uses the WRAM bank seam $7EFFFF|$7F0000. Seeds: $7EFFFE=$EE, $7EFFFF=$A5, $7F0000=$5A,
// $7E0000=$C3. A carry into the next bank reads hi=$5A; a within-bank wrap reads hi=$C3.
// $7E0000 is bank-0 $0000, i.e. the compiler's DP imaginary registers, so the probe sets D=$1F00
// for its own [dp] pointer, saves/restores $7E0000 around the test, and never touches DP $00.
//
//   R1 = M=0 `lda $7EFFFF`        (af, absolute long)          carry -> $5AA5, wrap -> $C3A5
//   R3 = M=0 `lda [dp]`  ptr $7EFFFF (a7, indirect long)       carry -> $5AA5, wrap -> $C3A5
//   R4 = M=0 `lda [dp],y` ptr $7EFFFE, Y=1 (b7)                carry -> $5AA5, wrap -> $C3A5
//   R5 = after M=0 `sta $7EFFFF` of $1234: ($7F0000) | ($7E0000)<<8   carry -> $C312, wrap -> $125A
//   R7 = after M=0 `sta [dp],y` (ptr $7EFFFE,Y=1) of $6789: same      carry -> $C367, wrap -> $675A
//   R2 = byte-split reference exactly as the compiler emits it today (M=1 `af $7EFFFF` + `af $7F0000`)
//
// Results: res_a = R1 | R3<<16, res_b = R4 | R5<<16, res_c = R7 | R2<<16.
// Expected if carry-into-next-bank (the byte-split semantics): res_a=0x5AA55AA5 res_b=0xC3125AA5
// res_c=0x5AA5C367.
#include <stdint.h>
#define FAR __attribute__((address_space(2)))

volatile uint32_t res_a, res_b, res_c;

static uint16_t rd16(uint32_t a) {
  const volatile FAR uint8_t *p = (const volatile FAR uint8_t *)a;
  return (uint16_t)(p[0] | (p[1] << 8));
}

int main(void) {
  __asm__ volatile(
      "sei\n"
      "php\n"
      "phd\n"
      "rep #$20\n"
      "lda #$1f00\n"
      "tcd\n"                 // D = $1F00: our [dp] pointer lives at $1F00..$1F02
      "sep #$20\n"
      "lda $7e0000\n"
      "pha\n"                 // save bank-0 $0000 (compiler DP)
      "lda #$ee\n  sta $7efffe\n"
      "lda #$a5\n  sta $7effff\n"
      "lda #$5a\n  sta $7f0000\n"
      "lda #$c3\n  sta $7e0000\n"
      // R2: today's byte-split shape (M=1, second address = first + 1 as a 24-bit sum)
      "lda $7effff\n  sta $7f0020\n"
      "lda $7f0000\n  sta $7f0021\n"
      // R1: M=0 absolute long
      "rep #$20\n"
      "lda $7effff\n  sta $7f0010\n"
      // R3: M=0 [dp], ptr $7EFFFF
      "lda #$ffff\n  sta $00\n"
      "sep #$20\n  lda #$7e\n  sta $02\n  rep #$20\n"
      "lda [$00]\n  sta $7f0012\n"
      // R4: M=0 [dp],y, ptr $7EFFFE, Y=1
      "lda #$fffe\n  sta $00\n"
      "ldy #$1\n"
      "lda [$00],y\n  sta $7f0014\n"
      // R5: M=0 absolute-long store $1234 -> $7EFFFF
      "lda #$1234\n  sta $7effff\n"
      "sep #$20\n"
      "lda $7f0000\n  sta $7f0016\n"
      "lda $7e0000\n  sta $7f0017\n"
      // reseed the seam bytes, then R7: M=0 [dp],y store $6789 (ptr $7EFFFE, Y=1)
      "lda #$5a\n  sta $7f0000\n"
      "lda #$c3\n  sta $7e0000\n"
      "rep #$20\n"
      "lda #$6789\n  sta [$00],y\n"
      "sep #$20\n"
      "lda $7f0000\n  sta $7f0018\n"
      "lda $7e0000\n  sta $7f0019\n"
      "pla\n"
      "sta $7e0000\n"         // restore compiler DP byte
      "pld\n"
      "plp\n"
      "cli\n"
      :
      :
      : "a", "x", "y", "memory");
  res_a = rd16(0x7f0010) | ((uint32_t)rd16(0x7f0012) << 16);
  res_b = rd16(0x7f0014) | ((uint32_t)rd16(0x7f0016) << 16);
  res_c = rd16(0x7f0018) | ((uint32_t)rd16(0x7f0020) << 16);
  for (;;) __asm__ volatile("wai");
}

/* frameabi_a0.c — #321 frame-ABI study, Phase A0 (the make-or-break gate).
 *
 * Proves at runtime that a TCD direct-page-window frame can coexist with
 * llvm-mos's linker-fixed __rc* imaginary registers (SNES link.ld pins
 * __rc0..__rc31 at ZP $00-$1F). On the 65816, zero-page (direct-page)
 * addressing is D-relative — operand N decodes as D+N — so the moment a
 * DP-window sets D != 0, `lda __rcN` (a DP form) would silently retarget to a
 * frame byte. The DP-window is only viable if __rc can still be reached, which
 * requires ABSOLUTE addressing (DBR:addr, ignores D). This test demonstrates
 * the split is real AND avoidable.
 *
 * The hand-encoded (.byte) sequence — entered native/M=1/X=1/DBR=0/D=0 from crt0:
 *
 *   phd                 ; 0B        save caller D (=0) on the hardware stack
 *   sep #$20            ; E2 20     M=1 (8-bit A)
 *   lda #$AA            ; A9 AA
 *   sta  $0010   (abs)  ; 8D 10 00  the "__rc16" cell  <- $AA   (D=0 here)
 *   stz  $1010   (abs)  ; 9C 10 10  the frame cell     <- $00
 *   rep #$20            ; C2 20     M=0 (16-bit A) to set D
 *   lda #$1000          ; A9 00 10
 *   tcd                 ; 5B        D := $1000   (enter DP-window)
 *   sep #$20            ; E2 20     M=1
 *   lda #$BB            ; A9 BB
 *   sta  $10     (DP)   ; 85 10     DP write -> D+$10 = $1010 <- $BB
 *   lda  $10     (DP)   ; A5 10     DP read  -> $1010 -> $BB   (proves DP=D+off)
 *   xba                 ; EB        B := $BB  (stash high byte)
 *   lda  $0010   (abs)  ; AD 10 00  abs read -> $0010 -> $AA  *** WHILE D=$1000 ***
 *   rep #$20            ; C2 20     M=0, C = B:A = $BBAA
 *   sta  $1F00   (abs)  ; 8D 00 1F  result scratch <- $BBAA
 *   sep #$20            ; E2 20     M=1 (codegen default)
 *   pld                 ; 2B        restore D (=0) without touching A/C
 *
 * Expected corpus_result == 0xBBAA. If the DP write to "$10" had (wrongly) hit
 * the __rc at $0010, the abs read would return $BB -> 0xBBBB; if abs wrongly
 * added D, the read would miss -> a different value. Only a correct DP/abs split
 * yields 0xBBAA.
 *
 * Addresses: $0010 = __rc16 (an imaginary-register slot, not the $00/$01
 * soft-SP); $1000/$1010 = a scratch DP-window frame in mid low-WRAM; $1F00 =
 * a result scratch below the soft stack ($2000). All free in this leaf ROM.
 *
 * Built DEFAULT (8-bit) — the DP-vs-abs mechanism is M-width-independent; this
 * is a hardware/ABI feasibility proof, not a codegen differential.
 */

volatile unsigned short corpus_result;

int main(void) {
  asm volatile(
    ".byte 0x0B\n"            /* phd            */
    ".byte 0xE2,0x20\n"       /* sep #$20       */
    ".byte 0xA9,0xAA\n"       /* lda #$AA       */
    ".byte 0x8D,0x10,0x00\n"  /* sta  $0010 abs */
    ".byte 0x9C,0x10,0x10\n"  /* stz  $1010 abs */
    ".byte 0xC2,0x20\n"       /* rep #$20       */
    ".byte 0xA9,0x00,0x10\n"  /* lda #$1000     */
    ".byte 0x5B\n"            /* tcd            */
    ".byte 0xE2,0x20\n"       /* sep #$20       */
    ".byte 0xA9,0xBB\n"       /* lda #$BB       */
    ".byte 0x85,0x10\n"       /* sta  $10 DP    */
    ".byte 0xA5,0x10\n"       /* lda  $10 DP    */
    ".byte 0xEB\n"            /* xba            */
    ".byte 0xAD,0x10,0x00\n"  /* lda  $0010 abs */
    ".byte 0xC2,0x20\n"       /* rep #$20       */
    ".byte 0x8D,0x00,0x1F\n"  /* sta  $1F00 abs */
    ".byte 0xE2,0x20\n"       /* sep #$20       */
    ".byte 0x2B\n"            /* pld            */
    ::: "a", "memory");

  corpus_result = *(volatile unsigned short *)0x1F00;
  for (;;) {
  }
}

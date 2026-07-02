.include "imag.inc"

; ---------------------------------------------------------------------------
; SNES (65816 native-mode) setjmp / longjmp.
;
; The common mos-platform/common/c/setjmp.S is a 6502 implementation: it reads
; the return address from a hardcoded page-$0100 address (tsx; lda $101,x /
; $102,x) and restores the hard stack pointer with `tax; txs`. On the 65816 in
; native mode -- which the SNES crt0 enters via XCE -- the stack pointer S is a
; 16-bit register and TXS transfers all 16 bits of X. With the codegen-default
; 8-bit index width, the `tax` loads a 16-bit X whose high byte is 0, so `txs`
; drops S into page 0; the subsequent `rts` then reads the return address from
; the wrong page and jumps to garbage -- longjmp never returns.
;
; This SNES override is byte-layout-compatible with the common jmp_buf (see
; <setjmp.h>: ret_addr[2], s[1], sp[2], csrs[14] = 19 bytes) -- it saves only
; the low byte of S, as the 6502 version does. That is correct here because the
; SNES hardware stack is confined to page 1 by the platform contract: crt0 sets
; S = $01FF and the 256-byte page-1 stack never leaves page 1. longjmp restores
; S by reconstructing the full 16-bit value $01xx (ora #$0100) instead of the
; broken $00xx, and reads/writes the return address stack-relative (1,s / 2,s)
; rather than at a hardcoded $0101/$0102.
;
; The ambient register widths are the codegen default M=1 (8-bit A), X=1 (8-bit
; index). The one 16-bit region (reconstructing and loading S) is bracketed by
; rep/sep #$20, toggling only the accumulator; the index width -- and therefore
; the 8-bit jmp_buf offset held in Y -- is left untouched.
;
; Built with -mcpu=mosw65816 and added to snes-c ahead of the common-c merge, so
; this object shadows common's 6502 setjmp.S.obj in libc.a (see CMakeLists.txt).
; ---------------------------------------------------------------------------

.section .text.setjmp
.global setjmp
setjmp:
  ; Save return address (stack-relative -- page-agnostic)
  ldy #0
  lda 1,s
  sta (__rc2),y
  iny
  lda 2,s
  sta (__rc2),y
  iny

  ; Save hard stack pointer (low byte; the page-1 high byte $01 is invariant and
  ; is reconstructed in longjmp)
  tsx
  txa
  sta (__rc2),y
  iny

  ; Save soft stack pointer
  lda __rc0
  sta (__rc2),y
  iny
  lda __rc1
  sta (__rc2),y
  iny

  ; Save CSRs
  lda __rc18
  sta (__rc2),y
  iny
  lda __rc19
  sta (__rc2),y
  iny
  lda __rc20
  sta (__rc2),y
  iny
  lda __rc21
  sta (__rc2),y
  iny
  lda __rc22
  sta (__rc2),y
  iny
  lda __rc23
  sta (__rc2),y
  iny
  lda __rc24
  sta (__rc2),y
  iny
  lda __rc25
  sta (__rc2),y
  iny
  lda __rc26
  sta (__rc2),y
  iny
  lda __rc27
  sta (__rc2),y
  iny
  lda __rc28
  sta (__rc2),y
  iny
  lda __rc29
  sta (__rc2),y
  iny
  lda __rc30
  sta (__rc2),y
  iny
  lda __rc31
  sta (__rc2),y

  ; Return zero
  lda #0
  ldx #0
  rts

.section .text.longjmp
.global longjmp
longjmp:
  ; Save return value
  sta __rc16
  stx __rc17

  ; Restore CSRs (offsets 5..18 -> __rc18..__rc31)
  ldy #5
  lda (__rc2),y
  sta __rc18
  iny
  lda (__rc2),y
  sta __rc19
  iny
  lda (__rc2),y
  sta __rc20
  iny
  lda (__rc2),y
  sta __rc21
  iny
  lda (__rc2),y
  sta __rc22
  iny
  lda (__rc2),y
  sta __rc23
  iny
  lda (__rc2),y
  sta __rc24
  iny
  lda (__rc2),y
  sta __rc25
  iny
  lda (__rc2),y
  sta __rc26
  iny
  lda (__rc2),y
  sta __rc27
  iny
  lda (__rc2),y
  sta __rc28
  iny
  lda (__rc2),y
  sta __rc29
  iny
  lda (__rc2),y
  sta __rc30
  iny
  lda (__rc2),y
  sta __rc31

  ; Restore soft stack pointer (offsets 3,4)
  ldy #3
  lda (__rc2),y
  sta __rc0
  iny
  lda (__rc2),y
  sta __rc1

  ; Restore hard stack pointer (offset 2): reconstruct the page-1 16-bit S = $01xx
  ldy #2
  lda (__rc2),y
  rep #$20
  and #$00ff
  ora #$0100
  tcs
  sep #$20

  ; Restore return address onto the restored stack (stack-relative)
  ldy #0
  lda (__rc2),y
  sta 1,s
  iny
  lda (__rc2),y
  sta 2,s

  ; Restore return value
  lda __rc16
  ldx __rc17

  rts

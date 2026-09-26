; RUN: llvm-mc -triple mos -mcpu=mosw65816 -show-encoding < %s | FileCheck %s

; 65816 counterpart of modifier-width.s: with absolute long available there are
; three operand widths to confuse, not two, so a 24-bit modifier on a small
; constant must reach absolute long and a 16-bit one must stop at absolute.

; mos24() selects absolute long whatever the value.

    lda mos24(1193046)          ; CHECK: encoding: [0xaf,0x56,0x34,0x12]
    lda mos24(1193046),x        ; CHECK: encoding: [0xbf,0x56,0x34,0x12]
    lda mos24(240)              ; CHECK: encoding: [0xaf,0xf0,0x00,0x00]
    lda mos24(240),x            ; CHECK: encoding: [0xbf,0xf0,0x00,0x00]
    sta mos24(1193046),x        ; CHECK: encoding: [0x9f,0x56,0x34,0x12]
    jmp mos24(1193046)          ; CHECK: encoding: [0x5c,0x56,0x34,0x12]

; mos16() stops at absolute, and does not widen to long either.

    lda mos16(240),x            ; CHECK: encoding: [0xbd,0xf0,0x00]
    lda mos16(4660),x           ; CHECK: encoding: [0xbd,0x34,0x12]
    jmp mos16(240)              ; CHECK: encoding: [0x4c,0xf0,0x00]
    lda mos24segment(1193046)   ; CHECK: encoding: [0xad,0x56,0x34]

; mos13() is 13 bits wide, so it is too wide for direct page and lands on
; absolute -- the same rule, at the SPC700 modifier's width.

    lda mos13(16)               ; CHECK: encoding: [0xad,0x10,0x00]

; mos8() still reaches the direct page forms, including the long indirect ones
; whose base operand is direct page only.

    lda mos8(16)                ; CHECK: encoding: [0xa5,0x10]
    lda [mos8(16)],y            ; CHECK: encoding: [0xb7,0x10]
    lda (mos8(16),x)            ; CHECK: encoding: [0xa1,0x10]

; An unmodified constant still picks its width from its value.

    lda 16                      ; CHECK: encoding: [0xa5,0x10]
    lda 4660                    ; CHECK: encoding: [0xad,0x34,0x12]
    lda 1193046                 ; CHECK: encoding: [0xaf,0x56,0x34,0x12]
    lda 1193046,x               ; CHECK: encoding: [0xbf,0x56,0x34,0x12]

; RUN: llvm-mc -triple mos -mcpu=mos6502 -show-encoding < %s | FileCheck %s

; An explicit width modifier states the operand width the programmer asked for,
; so it must never be narrowed to a smaller addressing mode -- not even when the
; value would fit in one. zero page,X computes (base + X) & 0xFF and wraps
; inside page zero; absolute,X carries into the high byte, so the two are not
; interchangeable. MOSMCInstLower::wrapAbsoluteIdxBase emits exactly the
; mos16(<small constant>) form below to force the absolute encoding, which only
; works if the assembler honours the modifier's width.

; A 16-bit modifier on a constant selects absolute, never zero page.

    lda mos16(240)              ; CHECK: encoding: [0xad,0xf0,0x00]
    lda mos16(240),x            ; CHECK: encoding: [0xbd,0xf0,0x00]
    lda mos16(0),x              ; CHECK: encoding: [0xbd,0x00,0x00]
    lda mos16(4660),x           ; CHECK: encoding: [0xbd,0x34,0x12]
    lda mos16(65535),x          ; CHECK: encoding: [0xbd,0xff,0xff]
    lda mos16(-1),x             ; CHECK: encoding: [0xbd,0xff,0xff]
    sta mos16(16),x             ; CHECK: encoding: [0x9d,0x10,0x00]
    sta mos16(16),y             ; CHECK: encoding: [0x99,0x10,0x00]
    ldx mos16(16),y             ; CHECK: encoding: [0xbe,0x10,0x00]
    cmp mos16(16)               ; CHECK: encoding: [0xcd,0x10,0x00]

; A symbol assigned an absolute value is a constant too, and takes the same
; path.

val = 240
    lda mos16(val),x            ; CHECK: encoding: [0xbd,0xf0,0x00]

; mos24segment() is also 16 bits wide, so it behaves like mos16(). The same
; holds for a symbolic operand: see modifiers.s, lda mos24segment(addr8) -> ad.

    lda mos24segment(1193046)   ; CHECK: encoding: [0xad,0x56,0x34]
    lda mos24segment(1193046),x ; CHECK: encoding: [0xbd,0x56,0x34]

; The narrowing is width-driven, not value-driven: an 8-bit modifier still
; picks zero page, whatever the value it masks.

    lda mos8(240)               ; CHECK: encoding: [0xa5,0xf0]
    lda mos8(240),x             ; CHECK: encoding: [0xb5,0xf0]
    lda mos8(4660)              ; CHECK: encoding: [0xa5,0x34]
    lda (mos8(240)),y           ; CHECK: encoding: [0xb1,0xf0]
    lda (mos8(240),x)           ; CHECK: encoding: [0xa1,0xf0]
    lda #mos8(4660)             ; CHECK: encoding: [0xa9,0x34]
    lda mos16lo(4660)           ; CHECK: encoding: [0xa5,0x34]
    lda mos16hi(4660)           ; CHECK: encoding: [0xa5,0x12]
    lda mos24bank(1193046)      ; CHECK: encoding: [0xa5,0x12]

; An unmodified constant is unaffected: it still picks the narrowest mode that
; holds its value.

    lda 240                     ; CHECK: encoding: [0xa5,0xf0]
    lda 240,x                   ; CHECK: encoding: [0xb5,0xf0]
    lda 4660,x                  ; CHECK: encoding: [0xbd,0x34,0x12]

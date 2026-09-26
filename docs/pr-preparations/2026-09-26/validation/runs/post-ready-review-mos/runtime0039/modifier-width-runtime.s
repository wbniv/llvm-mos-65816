; The indexed absolute address $00F0 + X=$10 is $0100, not zero-page $00.
; Distinct bytes at those addresses make the addressing-mode choice observable.
; mos-sim prints a byte written to $FFF9 and exits with the byte sent to $FFF8.
.text
.globl _start
_start:
    lda #87
    sta 0
    lda #80
    sta 256
    ldx #16
    lda mos16(240),x
    sta 65529
    eor #80
    sta 65528

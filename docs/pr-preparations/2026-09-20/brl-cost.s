; Split with split-file; assemble each part for mosw65816 and inspect .text.
; The 128-byte gap forces BRA outside its signed 8-bit displacement range.
;--- bra.s
bra target
.space 128
target:
rts
;--- jmp.s
jmp target
.space 128
target:
rts

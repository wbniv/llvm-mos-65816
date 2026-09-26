; RUN: llvm-mc -triple mos -filetype=obj %s -o %t.direct.o
; RUN: llvm-mc -triple mos -show-encoding %s -o %t.s
; RUN: llvm-mc -triple mos -filetype=obj %t.s -o %t.roundtrip.o
; RUN: cmp %t.direct.o %t.roundtrip.o
; RUN: llvm-readelf -x .resolved %t.direct.o | FileCheck %s

; Text output must retain the decimal directive's character count for every
; supported width. Reassembly must preserve both bytes and relocations.
.section .unresolved,"a",@progbits
  .mos_addr_asciz external+1, 1
  .mos_addr_asciz external+2, 2
  .mos_addr_asciz external+3, 3
  .mos_addr_asciz external+4, 4
  .mos_addr_asciz external+5, 5
  .mos_addr_asciz external+6, 6
  .mos_addr_asciz external+7, 7
  .mos_addr_asciz external+8, 8

; Computed and forward-defined constants use the same decimal representation.
.section .resolved,"a",@progbits
  .mos_addr_asciz 5+3, 2
  .mos_addr_asciz later, 2
  .mos_addr_asciz end-begin, 2
later = 42
.section .distance,"a",@progbits
begin:
  .space 7
end:

; CHECK: 0x00000000 38000034 32003700 00

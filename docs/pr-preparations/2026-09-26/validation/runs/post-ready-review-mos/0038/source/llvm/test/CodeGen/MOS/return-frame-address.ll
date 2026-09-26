; RUN: llc -mtriple=mos -mcpu=mos6502 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,M6502
; RUN: llc -mtriple=mos -mcpu=mos6502 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,M6502
; RUN: llc -mtriple=mos -mcpu=mosw65816 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,W65816

; __builtin_return_address(0) is the word JSR pushed on the hard stack (the
; address of its own last byte) plus one. __builtin_frame_address(0) is the
; incoming soft stack pointer. Neither stack has a frame chain, so any other
; level is zero. (SPC700: return-address-spc700.ll.)

declare void @sink(ptr)
declare void @keep(i8)

; The word sits just above the stack pointer at entry: S+1 and S+2.
define ptr @return_address() {
; CHECK-LABEL: return_address:
; M6502:       tsx
; M6502-NEXT:  lda 257,x
; M6502:       lda 258,x
; W65816:      lda 1,s
; W65816:      lda 2,s
; CHECK:       inc __rc2
; CHECK:       inc __rc3
; CHECK:       rts
  %r = call ptr @llvm.returnaddress(i32 0)
  ret ptr %r
}

; A value live across a call is kept in a callee-saved register, which the
; prologue pushes on the hard stack; the read is displaced by that push.
define ptr @return_address_after_push(i8 %v) {
; CHECK-LABEL: return_address_after_push:
; CHECK:       {{ph[axy]}}
; M6502:       tsx
; M6502-NEXT:  lda 258,x
; M6502:       lda 259,x
; W65816:      lda 2,s
; W65816:      lda 3,s
; CHECK:       {{pl[axy]}}
  call void @sink(ptr null)
  call void @keep(i8 %v)
  %r = call ptr @llvm.returnaddress(i32 0)
  ret ptr %r
}

define ptr @return_address_level_1() {
; CHECK-LABEL: return_address_level_1:
; CHECK-NOT:   tsx
; CHECK-NOT:   ,s
; CHECK:       #0
; CHECK:       rts
  %r = call ptr @llvm.returnaddress(i32 1)
  ret ptr %r
}

; An interrupt handler has no C return address.
@slot = global ptr null

define void @isr() "interrupt" {
; CHECK-LABEL: isr:
; CHECK-NOT:   tsx
; CHECK-NOT:   ,s
; CHECK:       rti
  %r = call ptr @llvm.returnaddress(i32 0)
  store ptr %r, ptr @slot
  ret void
}

; No frame: the frame address is the stack pointer itself.
define ptr @frame_address() {
; CHECK-LABEL: frame_address:
; CHECK:       {{ld[ax]}} __rc0
; CHECK-NEXT:  {{st[ax]}} __rc2
; CHECK-NEXT:  {{ld[ax]}} __rc1
; CHECK-NEXT:  {{st[ax]}} __rc3
; CHECK:       rts
  %f = call ptr @llvm.frameaddress(i32 0)
  ret ptr %f
}

; With a 16-byte frame the frame address is the stack pointer plus 16, the
; value it had on entry.
define ptr @frame_address_with_frame() {
; CHECK-LABEL: frame_address_with_frame:
; CHECK:       lda __rc0
; CHECK:       adc #16
; CHECK:       rts
  %a = alloca [16 x i8]
  call void @sink(ptr %a)
  %f = call ptr @llvm.frameaddress(i32 0)
  ret ptr %f
}

define ptr @frame_address_level_1() {
; CHECK-LABEL: frame_address_level_1:
; CHECK-NOT:   __rc0
; CHECK:       #0
; CHECK:       rts
  %f = call ptr @llvm.frameaddress(i32 1)
  ret ptr %f
}

declare ptr @llvm.returnaddress(i32 immarg)
declare ptr @llvm.frameaddress(i32 immarg)

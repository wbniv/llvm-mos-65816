; RUN: llc -mtriple=mos -mcpu=mosspc700 -O2 -verify-machineinstrs < %s | FileCheck %s

; SPC700 CALL pushes the return address itself, so the word read from the hard
; stack is used as it is; the stack pointer transfer and the indexed load are the
; SPC700 forms of tsx and lda abs,x. (Kept apart from return-frame-address.ll so
; the SPC700 spellings are checked on their own.)

declare void @keep(i8)

define ptr @return_address() {
; CHECK-LABEL: return_address:
; CHECK:       mov x,s
; CHECK-NEXT:  mov a,257+x
; CHECK:       mov a,258+x
; CHECK-NOT:   inc
; CHECK-NOT:   adc
; CHECK:       ret
  %r = call ptr @llvm.returnaddress(i32 0)
  ret ptr %r
}

; A value live across a call is kept in a callee-saved register, which the
; prologue pushes on the hard stack; the read is displaced by that push.
define ptr @return_address_after_push(i8 %v) {
; CHECK-LABEL: return_address_after_push:
; CHECK:       push x
; CHECK:       mov x,s
; CHECK-NEXT:  mov a,258+x
; CHECK:       mov a,259+x
; CHECK:       pop x
  call void @keep(i8 %v)
  call void @keep(i8 %v)
  %r = call ptr @llvm.returnaddress(i32 0)
  ret ptr %r
}

declare ptr @llvm.returnaddress(i32 immarg)

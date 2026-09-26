; RUN: llc -mtriple=mos -mcpu=mos6502 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s

; Zero-page pointer arithmetic has an eight-bit offset. The byte index must
; remain eight bits when selecting indexed loads and stores.
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"

define i8 @load_zp(i8 %index) {
; CHECK-LABEL: load_zp:
; CHECK: lda {{.*}}17,{{[xy]}}
  %p = getelementptr i8, ptr addrspace(1) inttoptr (i8 17 to ptr addrspace(1)), i8 %index
  %v = load i8, ptr addrspace(1) %p, align 1
  ret i8 %v
}

define void @store_zp(i8 %index, i8 %value) {
; CHECK-LABEL: store_zp:
; CHECK: sta {{.*}}17,{{[xy]}}
  %p = getelementptr i8, ptr addrspace(1) inttoptr (i8 17 to ptr addrspace(1)), i8 %index
  store i8 %value, ptr addrspace(1) %p, align 1
  ret void
}

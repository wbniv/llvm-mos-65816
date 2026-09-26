; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s

; A far fill exceeding the inline limit requires a runtime whose destination
; parameter retains the bank byte. The i32 length is the loop-idiom form for
; a 4096-byte fill at $7E2000. A near fill uses the near runtime ABI.
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"

define void @far_constant_fill() {
; CHECK-LABEL: far_constant_fill:
; CHECK: {{jsr|jmp}} __memset_far{{$}}
  call void @llvm.memset.p2.i32(ptr addrspace(2) inttoptr (i32 8265728 to ptr addrspace(2)), i8 66, i32 4096, i1 false)
  ret void
}

define void @far_variable_fill(ptr addrspace(2) %dst, i8 %value, i16 %size) {
; CHECK-LABEL: far_variable_fill:
; CHECK: {{jsr|jmp}} __memset_far{{$}}
  call void @llvm.memset.p2.i16(ptr addrspace(2) %dst, i8 %value, i16 %size, i1 false)
  ret void
}

define void @near_variable_fill(ptr %dst, i8 %value, i16 %size) {
; CHECK-LABEL: near_variable_fill:
; CHECK: {{jsr|jmp}} __memset{{$}}
  call void @llvm.memset.p0.i16(ptr %dst, i8 %value, i16 %size, i1 false)
  ret void
}

declare void @llvm.memset.p2.i32(ptr addrspace(2), i8, i32, i1 immarg)
declare void @llvm.memset.p2.i16(ptr addrspace(2), i8, i16, i1 immarg)
declare void @llvm.memset.p0.i16(ptr, i8, i16, i1 immarg)

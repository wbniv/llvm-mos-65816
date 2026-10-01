; RUN: llc -mtriple=mos -mcpu=moshuc6280 -O2 %s -o - | FileCheck %s
; A 32-byte constant copied into a local array lowers to two 16-byte TII block
; moves into the function's static stack. Each destination is the stack
; object's own address plus the piece's offset, not plus the block length.
; CHECK-LABEL: fill:
; CHECK: tii .L__const.fill.line,.Lfill_sstk,#16
; CHECK-NEXT: tii .L__const.fill.line+16,.Lfill_sstk+16,#16
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"
@__const.fill.line = private unnamed_addr constant [32 x i8] c"0123456789abcdefghijklmnopqrstuv", align 1
declare void @use(ptr)
define void @fill() norecurse {
  %line = alloca [32 x i8], align 1
  call void @llvm.memcpy.p0.p0.i16(ptr align 1 %line, ptr align 1 @__const.fill.line, i16 32, i1 false)
  call void @use(ptr %line)
  ret void
}
declare void @llvm.memcpy.p0.p0.i16(ptr noalias writeonly, ptr noalias readonly, i16, i1 immarg)

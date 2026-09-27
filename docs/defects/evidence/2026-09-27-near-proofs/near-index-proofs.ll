; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -mos-recover-near-nowrap=false -verify-machineinstrs < %s | FileCheck %s --check-prefix=DISABLED

; The inbounds byte loop has an unsigned no-wrap address recurrence. Its
; destination index must retain that proof across loop strength reduction.
; CHECK-LABEL: far_rt_blit:
; CHECK-NOT: adc
; CHECK: lda [__rc{{[0-9]+}}],y
; CHECK-NEXT: sta (__rc{{[0-9]+}}),y
; CHECK: rts
; DISABLED-LABEL: far_rt_blit:
; DISABLED: adc
; DISABLED: sta (__rc{{[0-9]+}})
; DISABLED: rts
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"

define void @far_rt_blit(i32 %a, ptr %dst) {
entry:
  %p = inttoptr i32 %a to ptr addrspace(2)
  br label %loop

loop:                                             ; preds = %loop, %entry
  %j = phi i8 [ 0, %entry ], [ %j1, %loop ]
  %x = zext i8 %j to i32
  %q = getelementptr inbounds i8, ptr addrspace(2) %p, i32 %x
  %v = load i8, ptr addrspace(2) %q, align 1
  %d = getelementptr inbounds i8, ptr %dst, i8 %j
  store i8 %v, ptr %d, align 1
  %j1 = add nuw nsw i8 %j, 1
  %c = icmp eq i8 %j1, 64
  br i1 %c, label %exit, label %loop

exit:                                             ; preds = %loop
  ret void
}

; An unflagged near GEP permits wrapping even with a nonnegative loop index.
; CHECK-LABEL: wrapping_blit:
; CHECK: adc
; CHECK: sta (__rc{{[0-9]+}}){{$}}
; CHECK: rts
define void @wrapping_blit(i32 %a, ptr %dst) {
entry:
  %p = inttoptr i32 %a to ptr addrspace(2)
  br label %loop

loop:                                             ; preds = %loop, %entry
  %j = phi i8 [ 0, %entry ], [ %j1, %loop ]
  %x = zext i8 %j to i32
  %q = getelementptr inbounds i8, ptr addrspace(2) %p, i32 %x
  %v = load i8, ptr addrspace(2) %q, align 1
  %d = getelementptr i8, ptr %dst, i8 %j
  store i8 %v, ptr %d, align 1
  %j1 = add nuw nsw i8 %j, 1
  %c = icmp eq i8 %j1, 64
  br i1 %c, label %exit, label %loop

exit:                                             ; preds = %loop
  ret void
}

; ModuleID = 'vendor/llvm-mos/llvm/test/CodeGen/MOS/far-indir-indexed.ll'
source_filename = "vendor/llvm-mos/llvm/test/CodeGen/MOS/far-indir-indexed.ll"
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

; ModuleID = '/work/build/near-y-fix/near-wrap.c'
source_filename = "/work/build/near-y-fix/near-wrap.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

module asm ".text"
module asm ".global wrap_bank7e"
module asm "wrap_bank7e:"
module asm "php"
module asm ".byte $8b"
module asm ".byte $f4,$7e,$7e"
module asm ".byte $ab,$ab"
module asm "jsr near_wrap"
module asm ".byte $ab"
module asm "plp"
module asm "rts"

@corpus_result = dso_local global i16 0, align 1
@llvm.compiler.used = appending global [1 x ptr] [ptr @near_wrap], section "llvm.metadata"

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(argmem: read)
define dso_local zeroext i8 @near_wrap(ptr noundef readonly captures(none) %0, i16 noundef %1) #0 {
  %3 = getelementptr inbounds i8, ptr %0, i16 %1
  %4 = load i8, ptr %3, align 1, !tbaa !6
  ret i8 %4
}

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #1 {
  store volatile i8 90, ptr addrspace(2) inttoptr (i32 8300546 to ptr addrspace(2)), align 2, !tbaa !6
  store volatile i8 -61, ptr addrspace(2) inttoptr (i32 8366082 to ptr addrspace(2)), align 2, !tbaa !6
  %1 = tail call zeroext i8 @wrap_bank7e(ptr noundef nonnull inttoptr (i16 -22522 to ptr), i16 noundef -4) #3
  %2 = icmp eq i8 %1, 90
  br i1 %2, label %6, label %3

3:                                                ; preds = %0
  %4 = zext i8 %1 to i16
  %5 = or disjoint i16 %4, -23296
  br label %6

6:                                                ; preds = %0, %3
  %7 = phi i16 [ %5, %3 ], [ 23792, %0 ]
  store volatile i16 %7, ptr @corpus_result, align 1, !tbaa !2
  br label %8

8:                                                ; preds = %8, %6
  tail call void asm sideeffect "wai", ""() #4, !srcloc !7
  br label %8
}

; Function Attrs: minsize optsize
declare dso_local zeroext i8 @wrap_bank7e(ptr noundef, i16 noundef) local_unnamed_addr #2

attributes #0 = { minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(argmem: read) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #1 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #2 = { minsize optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16,+mos-xy16" }
attributes #3 = { minsize nounwind optsize }
attributes #4 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!4, !4, i64 0}
!7 = !{i64 678}

; ModuleID = '/work/examples/snes/corpus/montorbit_sim.c'
source_filename = "/work/examples/snes/corpus/montorbit_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %6, %0
  %2 = phi i16 [ 0, %0 ], [ %13, %6 ]
  %3 = phi i16 [ 0, %0 ], [ %16, %6 ]
  %4 = phi i16 [ 24575, %0 ], [ %15, %6 ]
  %5 = icmp eq i16 %3, 64
  br i1 %5, label %17, label %6

6:                                                ; preds = %1
  %7 = zext i16 %4 to i32
  %8 = tail call fastcc i16 @mo_redc(i32 noundef %7) #3
  %9 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %10 = mul nsw i16 %8, 97
  %11 = mul nuw nsw i16 %3, 13
  %12 = xor i16 %11, %9
  %13 = xor i16 %12, %10
  %14 = mul nuw nsw i32 %7, 32764
  %15 = tail call fastcc range(i16 0, -24575) i16 @mo_redc(i32 noundef %14) #3
  %16 = add nuw nsw i16 %3, 1
  br label %1, !llvm.loop !6

17:                                               ; preds = %1
  store volatile i16 %2, ptr @corpus_result, align 1, !tbaa !2
  br label %18

18:                                               ; preds = %18, %17
  tail call void asm sideeffect "wai", ""() #4, !srcloc !8
  br label %18
}

; Function Attrs: inlinehint minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc range(i16 0, -24575) i16 @mo_redc(i32 noundef range(i32 0, 1677721601) %0) unnamed_addr #1 {
  %2 = trunc i32 %0 to i16
  %3 = mul i16 %2, -24577
  %4 = zext i16 %3 to i32
  %5 = mul nuw i32 %4, 40961
  %6 = add i32 %5, %0
  %7 = lshr i32 %6, 16
  %8 = trunc nuw i32 %7 to i16
  %9 = icmp ugt i16 %8, -24576
  br i1 %9, label %10, label %12

10:                                               ; preds = %1
  %11 = add nsw i16 %8, 24575
  br label %12

12:                                               ; preds = %10, %1
  %13 = phi i16 [ %11, %10 ], [ %8, %1 ]
  ret i16 %13
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { inlinehint minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { minsize optsize }
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
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = !{i64 560}

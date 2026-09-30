; ModuleID = '/work/examples/snes/corpus/montorbit_sim.c'
source_filename = "/work/examples/snes/corpus/montorbit_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %32, %0
  %2 = phi i16 [ 24575, %0 ], [ %33, %32 ]
  %3 = phi i16 [ 0, %0 ], [ %34, %32 ]
  %4 = phi i16 [ 0, %0 ], [ %20, %32 ]
  %5 = zext i16 %2 to i32
  %6 = mul i16 %2, -24577
  %7 = zext i16 %6 to i32
  %8 = mul nuw i32 %7, 40961
  %9 = add nuw i32 %8, %5
  %10 = lshr i32 %9, 16
  %11 = trunc nuw i32 %10 to i16
  %12 = icmp ugt i16 %11, -24576
  br i1 %12, label %13, label %14

13:                                               ; preds = %1
  br label %14

14:                                               ; preds = %13, %1
  %15 = phi i16 [ 0, %13 ], [ %11, %1 ]
  %16 = tail call i16 @llvm.fshl.i16(i16 %4, i16 %4, i16 1)
  %17 = mul nsw i16 %15, 97
  %18 = mul nuw nsw i16 %3, 13
  %19 = xor i16 %16, %18
  %20 = xor i16 %19, %17
  %21 = mul nuw nsw i32 %5, 32764
  %22 = trunc i32 %21 to i16
  %23 = mul i16 %22, -24577
  %24 = zext i16 %23 to i32
  %25 = mul nuw i32 %24, 40961
  %26 = add i32 %25, %21
  %27 = lshr i32 %26, 16
  %28 = trunc nuw i32 %27 to i16
  %29 = icmp ugt i16 %28, -24576
  br i1 %29, label %30, label %32

30:                                               ; preds = %14
  %31 = add nsw i16 %28, 24575
  br label %32

32:                                               ; preds = %30, %14
  %33 = phi i16 [ %31, %30 ], [ %28, %14 ]
  %34 = add nuw nsw i16 %3, 1
  %35 = icmp eq i16 %34, 64
  br i1 %35, label %36, label %1, !llvm.loop !6

36:                                               ; preds = %32
  store volatile i16 %20, ptr @corpus_result, align 1, !tbaa !2
  br label %37

37:                                               ; preds = %37, %36
  tail call void asm sideeffect "wai", ""() #2, !srcloc !8
  br label %37
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind }

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

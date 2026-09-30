; ModuleID = '/work/examples/snes/corpus/tea_sim.c'
source_filename = "/work/examples/snes/corpus/tea_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %34, %0
  %2 = phi i16 [ 0, %0 ], [ %38, %34 ]
  %3 = phi i16 [ 0, %0 ], [ %39, %34 ]
  %4 = icmp eq i16 %3, 8
  br i1 %4, label %40, label %5

5:                                                ; preds = %1
  %6 = zext nneg i16 %3 to i32
  %7 = or disjoint i16 %3, 8
  %8 = zext nneg i16 %7 to i32
  br label %9

9:                                                ; preds = %15, %5
  %10 = phi i32 [ %6, %5 ], [ %24, %15 ]
  %11 = phi i32 [ %8, %5 ], [ %32, %15 ]
  %12 = phi i32 [ 0, %5 ], [ %16, %15 ]
  %13 = phi i8 [ 0, %5 ], [ %33, %15 ]
  %14 = icmp eq i8 %13, 32
  br i1 %14, label %34, label %15

15:                                               ; preds = %9
  %16 = add i32 %12, -1640531527
  %17 = shl i32 %11, 4
  %18 = add i32 %17, 19088743
  %19 = add i32 %16, %11
  %20 = lshr i32 %11, 5
  %21 = add nuw nsw i32 %20, -1985229329
  %22 = xor i32 %21, %18
  %23 = xor i32 %22, %19
  %24 = add i32 %23, %10
  %25 = shl i32 %24, 4
  %26 = add i32 %25, -19088744
  %27 = add i32 %24, %16
  %28 = xor i32 %26, %27
  %29 = lshr i32 %24, 5
  %30 = add nuw nsw i32 %29, 1985229328
  %31 = xor i32 %28, %30
  %32 = add i32 %31, %11
  %33 = add nuw nsw i8 %13, 1
  br label %9, !llvm.loop !6

34:                                               ; preds = %9
  %35 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %36 = xor i32 %11, %10
  %37 = trunc i32 %36 to i16
  %38 = xor i16 %35, %37
  %39 = add nuw nsw i16 %3, 1
  br label %1, !llvm.loop !8

40:                                               ; preds = %1
  store volatile i16 %2, ptr @corpus_result, align 1, !tbaa !2
  br label %41

41:                                               ; preds = %41, %40
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %41
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!8 = distinct !{!8, !7}
!9 = !{i64 383}

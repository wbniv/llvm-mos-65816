; ModuleID = '/work/examples/snes/corpus/tea_sim.c'
source_filename = "/work/examples/snes/corpus/tea_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %31, %0
  %2 = phi i16 [ 0, %0 ], [ %36, %31 ]
  %3 = phi i16 [ 0, %0 ], [ %35, %31 ]
  %4 = zext nneg i16 %2 to i32
  %5 = or disjoint i16 %2, 8
  %6 = zext nneg i16 %5 to i32
  br label %7

7:                                                ; preds = %7, %1
  %8 = phi i8 [ 0, %1 ], [ %29, %7 ]
  %9 = phi i32 [ 0, %1 ], [ %12, %7 ]
  %10 = phi i32 [ %6, %1 ], [ %28, %7 ]
  %11 = phi i32 [ %4, %1 ], [ %20, %7 ]
  %12 = add i32 %9, -1640531527
  %13 = shl i32 %10, 4
  %14 = add i32 %13, 19088743
  %15 = add i32 %12, %10
  %16 = lshr i32 %10, 5
  %17 = add nuw nsw i32 %16, -1985229329
  %18 = xor i32 %14, %15
  %19 = xor i32 %18, %17
  %20 = add i32 %19, %11
  %21 = shl i32 %20, 4
  %22 = add i32 %21, -19088744
  %23 = add i32 %20, %12
  %24 = xor i32 %22, %23
  %25 = lshr i32 %20, 5
  %26 = add nuw nsw i32 %25, 1985229328
  %27 = xor i32 %24, %26
  %28 = add i32 %27, %10
  %29 = add nuw nsw i8 %8, 1
  %30 = icmp eq i8 %29, 32
  br i1 %30, label %31, label %7, !llvm.loop !6

31:                                               ; preds = %7
  %32 = tail call i16 @llvm.fshl.i16(i16 %3, i16 %3, i16 1)
  %33 = xor i32 %28, %20
  %34 = trunc i32 %33 to i16
  %35 = xor i16 %32, %34
  %36 = add nuw nsw i16 %2, 1
  %37 = icmp eq i16 %36, 8
  br i1 %37, label %38, label %1, !llvm.loop !8

38:                                               ; preds = %31
  store volatile i16 %35, ptr @corpus_result, align 1, !tbaa !2
  br label %39

39:                                               ; preds = %39, %38
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %39
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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

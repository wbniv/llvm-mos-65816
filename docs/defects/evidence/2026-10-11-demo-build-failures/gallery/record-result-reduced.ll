; ModuleID = 'rr7.c'
source_filename = "rr7.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@g_failed = dso_local local_unnamed_addr global [62 x i8] zeroinitializer, align 1
@g_done = dso_local local_unnamed_addr global [62 x i8] zeroinitializer, align 1
@g_count = dso_local local_unnamed_addr global i8 0, align 1
@corpus_result = dso_local global i16 0, align 1

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define dso_local i16 @record_result(i8 noundef zeroext %0, i16 noundef %1, i8 noundef zeroext %2) local_unnamed_addr #0 {
  %4 = zext i8 %0 to i16
  %5 = getelementptr inbounds nuw i8, ptr @g_failed, i16 %4
  store i8 %2, ptr %5, align 1, !tbaa !7
  %6 = getelementptr inbounds nuw i8, ptr @g_done, i16 %4
  %7 = load i8, ptr %6, align 1, !tbaa !7
  %8 = icmp eq i8 %7, 0
  br i1 %8, label %9, label %12

9:                                                ; preds = %3
  store i8 1, ptr %6, align 1, !tbaa !7
  %10 = load i8, ptr @g_count, align 1, !tbaa !7
  %11 = add i8 %10, 1
  store i8 %11, ptr @g_count, align 1, !tbaa !7
  br label %14

12:                                               ; preds = %3
  %13 = load i8, ptr @g_count, align 1, !tbaa !7
  br label %14

14:                                               ; preds = %12, %9
  %15 = phi i8 [ %13, %12 ], [ %11, %9 ]
  %16 = icmp eq i8 %15, 62
  br i1 %16, label %20, label %29

17:                                               ; preds = %20
  %18 = icmp eq i8 %26, 0
  %19 = select i1 %18, i16 5394, i16 -27374
  store volatile i16 %19, ptr @corpus_result, align 1, !tbaa !8
  br label %29

20:                                               ; preds = %14, %20
  %21 = phi i8 [ %27, %20 ], [ 0, %14 ]
  %22 = phi i8 [ %26, %20 ], [ 0, %14 ]
  %23 = zext nneg i8 %21 to i16
  %24 = getelementptr i8, ptr @g_failed, i16 %23
  %25 = load i8, ptr %24, align 1, !tbaa !7
  %26 = or i8 %25, %22
  %27 = add nuw nsw i8 %21, 1
  %28 = icmp eq i8 %27, 62
  br i1 %28, label %17, label %20, !llvm.loop !9

29:                                               ; preds = %17, %14
  %30 = phi i16 [ %19, %17 ], [ %1, %14 ]
  ret i16 %30
}

attributes #0 = { nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos.git 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63)"}
!2 = !{!3, !4, i64 0}
!3 = !{!"__libc_errno", !4, i64 0}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!5, !5, i64 0}
!8 = !{!4, !4, i64 0}
!9 = distinct !{!9, !10}
!10 = !{!"llvm.loop.mustprogress"}

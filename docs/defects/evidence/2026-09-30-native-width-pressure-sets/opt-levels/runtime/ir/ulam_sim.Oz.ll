; ModuleID = '/work/examples/snes/corpus/ulam_sim.c'
source_filename = "/work/examples/snes/corpus/ulam_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@ul_comp = internal unnamed_addr global [128 x i8] zeroinitializer, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %4, %0
  %2 = phi i8 [ %7, %4 ], [ 0, %0 ]
  %3 = icmp eq i8 %2, -128
  br i1 %3, label %8, label %4

4:                                                ; preds = %1
  %5 = zext i8 %2 to i16
  %6 = getelementptr i8, ptr @ul_comp, i16 %5
  store i8 0, ptr %6, align 1, !tbaa !6
  %7 = add nuw i8 %2, 1
  br label %1, !llvm.loop !7

8:                                                ; preds = %1
  %9 = load i8, ptr @ul_comp, align 1, !tbaa !6
  %10 = or i8 %9, 3
  store i8 %10, ptr @ul_comp, align 1, !tbaa !6
  br label %11

11:                                               ; preds = %37, %8
  %12 = phi i16 [ 2, %8 ], [ %38, %37 ]
  %13 = icmp eq i16 %12, 32
  br i1 %13, label %39, label %14

14:                                               ; preds = %11
  %15 = lshr i16 %12, 3
  %16 = getelementptr inbounds nuw i8, ptr @ul_comp, i16 %15
  %17 = load i8, ptr %16, align 1, !tbaa !6
  %18 = zext i8 %17 to i16
  %19 = and i16 %12, 7
  %20 = shl nuw nsw i16 1, %19
  %21 = and i16 %20, %18
  %22 = icmp eq i16 %21, 0
  br i1 %22, label %23, label %37

23:                                               ; preds = %14
  %24 = mul i16 %12, %12
  br label %25

25:                                               ; preds = %28, %23
  %26 = phi i16 [ %24, %23 ], [ %36, %28 ]
  %27 = icmp ult i16 %26, 1024
  br i1 %27, label %28, label %37

28:                                               ; preds = %25
  %29 = lshr i16 %26, 3
  %30 = getelementptr inbounds nuw i8, ptr @ul_comp, i16 %29
  %31 = load i8, ptr %30, align 1, !tbaa !6
  %32 = and i16 %26, 7
  %33 = shl nuw nsw i16 1, %32
  %34 = trunc nuw i16 %33 to i8
  %35 = or i8 %31, %34
  store i8 %35, ptr %30, align 1, !tbaa !6
  %36 = add nuw i16 %26, %12
  br label %25, !llvm.loop !9

37:                                               ; preds = %25, %14
  %38 = add nuw nsw i16 %12, 1
  br label %11, !llvm.loop !10

39:                                               ; preds = %11, %43
  %40 = phi i16 [ %56, %43 ], [ 0, %11 ]
  %41 = phi i16 [ %55, %43 ], [ 0, %11 ]
  %42 = icmp eq i16 %40, 1024
  br i1 %42, label %57, label %43

43:                                               ; preds = %39
  %44 = lshr i16 %40, 3
  %45 = getelementptr inbounds nuw i8, ptr @ul_comp, i16 %44
  %46 = load i8, ptr %45, align 1, !tbaa !6
  %47 = zext i8 %46 to i16
  %48 = and i16 %40, 7
  %49 = tail call i16 @llvm.fshl.i16(i16 %41, i16 %41, i16 1)
  %50 = shl nuw nsw i16 1, %48
  %51 = and i16 %50, %47
  %52 = icmp eq i16 %51, 0
  %53 = select i1 %52, i16 97, i16 13
  %54 = mul i16 %53, %40
  %55 = xor i16 %54, %49
  %56 = add nuw nsw i16 %40, 1
  br label %39, !llvm.loop !11

57:                                               ; preds = %39
  store volatile i16 %41, ptr @corpus_result, align 1, !tbaa !2
  br label %58

58:                                               ; preds = %58, %57
  tail call void asm sideeffect "wai", ""() #2, !srcloc !12
  br label %58
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
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = distinct !{!9, !8}
!10 = distinct !{!10, !8}
!11 = distinct !{!11, !8}
!12 = !{i64 465}

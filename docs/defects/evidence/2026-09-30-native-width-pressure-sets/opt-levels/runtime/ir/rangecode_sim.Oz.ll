; ModuleID = '/work/examples/snes/corpus/rangecode_sim.c'
source_filename = "/work/examples/snes/corpus/rangecode_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %53, %0
  %2 = phi i16 [ 0, %0 ], [ %28, %53 ]
  %3 = phi i32 [ -1, %0 ], [ %30, %53 ]
  %4 = phi i32 [ 0, %0 ], [ %29, %53 ]
  %5 = phi i16 [ 0, %0 ], [ %55, %53 ]
  %6 = phi i16 [ 2048, %0 ], [ %54, %53 ]
  %7 = phi i16 [ -21279, %0 ], [ %15, %53 ]
  %8 = icmp eq i16 %5, 200
  br i1 %8, label %56, label %9

9:                                                ; preds = %1
  %10 = shl i16 %7, 7
  %11 = xor i16 %10, %7
  %12 = lshr i16 %11, 9
  %13 = xor i16 %12, %11
  %14 = shl i16 %13, 8
  %15 = xor i16 %14, %13
  %16 = lshr i32 %3, 12
  %17 = zext nneg i16 %6 to i32
  %18 = mul nuw i32 %16, %17
  %19 = and i16 %13, 1
  %20 = icmp eq i16 %19, 0
  br i1 %20, label %24, label %21

21:                                               ; preds = %9
  %22 = add i32 %18, %4
  %23 = sub i32 %3, %18
  br label %24

24:                                               ; preds = %21, %9
  %25 = phi i32 [ %4, %9 ], [ %22, %21 ]
  %26 = phi i32 [ %18, %9 ], [ %23, %21 ]
  br label %27

27:                                               ; preds = %24, %32
  %28 = phi i16 [ %36, %32 ], [ %2, %24 ]
  %29 = phi i32 [ %37, %32 ], [ %25, %24 ]
  %30 = phi i32 [ %38, %32 ], [ %26, %24 ]
  %31 = icmp ult i32 %30, 16777216
  br i1 %31, label %32, label %39

32:                                               ; preds = %27
  %33 = lshr i32 %29, 24
  %34 = tail call i16 @llvm.fshl.i16(i16 %28, i16 %28, i16 3)
  %35 = trunc nuw nsw i32 %33 to i16
  %36 = xor i16 %34, %35
  %37 = shl i32 %29, 8
  %38 = shl nuw i32 %30, 8
  br label %27, !llvm.loop !6

39:                                               ; preds = %27
  br i1 %20, label %40, label %44

40:                                               ; preds = %39
  %41 = sub i16 4096, %6
  %42 = lshr i16 %41, 5
  %43 = add i16 %42, %6
  br label %47

44:                                               ; preds = %39
  %45 = lshr i16 %6, 5
  %46 = sub i16 %6, %45
  br label %47

47:                                               ; preds = %44, %40
  %48 = phi i16 [ %43, %40 ], [ %46, %44 ]
  %49 = icmp ult i16 %48, 32
  br i1 %49, label %53, label %50

50:                                               ; preds = %47
  %51 = icmp ugt i16 %48, 4064
  br i1 %51, label %52, label %53

52:                                               ; preds = %50
  br label %53

53:                                               ; preds = %52, %50, %47
  %54 = phi i16 [ 4064, %52 ], [ %48, %50 ], [ 32, %47 ]
  %55 = add nuw nsw i16 %5, 1
  br label %1, !llvm.loop !8

56:                                               ; preds = %1, %61
  %57 = phi i16 [ %65, %61 ], [ %2, %1 ]
  %58 = phi i32 [ %66, %61 ], [ %4, %1 ]
  %59 = phi i8 [ %67, %61 ], [ 0, %1 ]
  %60 = icmp eq i8 %59, 4
  br i1 %60, label %68, label %61

61:                                               ; preds = %56
  %62 = lshr i32 %58, 24
  %63 = tail call i16 @llvm.fshl.i16(i16 %57, i16 %57, i16 3)
  %64 = trunc nuw nsw i32 %62 to i16
  %65 = xor i16 %63, %64
  %66 = shl i32 %58, 8
  %67 = add nuw nsw i8 %59, 1
  br label %56, !llvm.loop !9

68:                                               ; preds = %56
  %69 = lshr i32 %3, 16
  %70 = xor i32 %69, %3
  %71 = trunc i32 %70 to i16
  %72 = xor i16 %6, %71
  %73 = xor i16 %72, %57
  store volatile i16 %73, ptr @corpus_result, align 1, !tbaa !2
  br label %74

74:                                               ; preds = %74, %68
  tail call void asm sideeffect "wai", ""() #2, !srcloc !10
  br label %74
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
!9 = distinct !{!9, !7}
!10 = !{i64 435}

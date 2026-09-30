; ModuleID = '/work/examples/snes/corpus/rangecode_sim.c'
source_filename = "/work/examples/snes/corpus/rangecode_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %54, %0
  %2 = phi i16 [ -21279, %0 ], [ %13, %54 ]
  %3 = phi i16 [ 2048, %0 ], [ %55, %54 ]
  %4 = phi i16 [ 0, %0 ], [ %56, %54 ]
  %5 = phi i32 [ 0, %0 ], [ %39, %54 ]
  %6 = phi i32 [ -1, %0 ], [ %40, %54 ]
  %7 = phi i16 [ 0, %0 ], [ %38, %54 ]
  %8 = shl i16 %2, 7
  %9 = xor i16 %8, %2
  %10 = lshr i16 %9, 9
  %11 = xor i16 %10, %9
  %12 = shl i16 %11, 8
  %13 = xor i16 %12, %11
  %14 = lshr i32 %6, 12
  %15 = zext nneg i16 %3 to i32
  %16 = mul nuw i32 %14, %15
  %17 = and i16 %11, 1
  %18 = icmp eq i16 %17, 0
  br i1 %18, label %22, label %19

19:                                               ; preds = %1
  %20 = add i32 %16, %5
  %21 = sub i32 %6, %16
  br label %22

22:                                               ; preds = %19, %1
  %23 = phi i32 [ %5, %1 ], [ %20, %19 ]
  %24 = phi i32 [ %16, %1 ], [ %21, %19 ]
  %25 = icmp ult i32 %24, 16777216
  br i1 %25, label %26, label %37

26:                                               ; preds = %22, %26
  %27 = phi i16 [ %33, %26 ], [ %7, %22 ]
  %28 = phi i32 [ %34, %26 ], [ %23, %22 ]
  %29 = phi i32 [ %35, %26 ], [ %24, %22 ]
  %30 = lshr i32 %28, 24
  %31 = tail call i16 @llvm.fshl.i16(i16 %27, i16 %27, i16 3)
  %32 = trunc nuw nsw i32 %30 to i16
  %33 = xor i16 %31, %32
  %34 = shl i32 %28, 8
  %35 = shl nuw i32 %29, 8
  %36 = icmp ult i32 %29, 65536
  br i1 %36, label %26, label %37, !llvm.loop !6

37:                                               ; preds = %26, %22
  %38 = phi i16 [ %7, %22 ], [ %33, %26 ]
  %39 = phi i32 [ %23, %22 ], [ %34, %26 ]
  %40 = phi i32 [ %24, %22 ], [ %35, %26 ]
  br i1 %18, label %41, label %45

41:                                               ; preds = %37
  %42 = sub i16 4096, %3
  %43 = lshr i16 %42, 5
  %44 = add i16 %43, %3
  br label %48

45:                                               ; preds = %37
  %46 = lshr i16 %3, 5
  %47 = sub i16 %3, %46
  br label %48

48:                                               ; preds = %45, %41
  %49 = phi i16 [ %44, %41 ], [ %47, %45 ]
  %50 = icmp ult i16 %49, 32
  br i1 %50, label %54, label %51

51:                                               ; preds = %48
  %52 = icmp ugt i16 %49, 4064
  br i1 %52, label %53, label %54

53:                                               ; preds = %51
  br label %54

54:                                               ; preds = %53, %51, %48
  %55 = phi i16 [ 4064, %53 ], [ %49, %51 ], [ 32, %48 ]
  %56 = add nuw nsw i16 %4, 1
  %57 = icmp eq i16 %56, 200
  br i1 %57, label %58, label %1, !llvm.loop !8

58:                                               ; preds = %54, %58
  %59 = phi i8 [ %67, %58 ], [ 0, %54 ]
  %60 = phi i32 [ %66, %58 ], [ %39, %54 ]
  %61 = phi i16 [ %65, %58 ], [ %38, %54 ]
  %62 = lshr i32 %60, 24
  %63 = tail call i16 @llvm.fshl.i16(i16 %61, i16 %61, i16 3)
  %64 = trunc nuw nsw i32 %62 to i16
  %65 = xor i16 %63, %64
  %66 = shl i32 %60, 8
  %67 = add nuw nsw i8 %59, 1
  %68 = icmp eq i8 %67, 4
  br i1 %68, label %69, label %58, !llvm.loop !9

69:                                               ; preds = %58
  %70 = lshr i32 %40, 16
  %71 = xor i32 %70, %40
  %72 = trunc i32 %71 to i16
  %73 = xor i16 %55, %72
  %74 = xor i16 %73, %65
  store volatile i16 %74, ptr @corpus_result, align 1, !tbaa !2
  br label %75

75:                                               ; preds = %75, %69
  tail call void asm sideeffect "wai", ""() #2, !srcloc !10
  br label %75
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
!8 = distinct !{!8, !7}
!9 = distinct !{!9, !7}
!10 = !{i64 435}

; ModuleID = '/work/examples/snes/corpus/satcast_sim.c'
source_filename = "/work/examples/snes/corpus/satcast_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@_SC_TX = internal unnamed_addr constant [8 x i8] c"\01\03\06\08\09\0B\0E\02", align 1
@_SC_TY = internal unnamed_addr constant [8 x i8] c"\01\05\07\08\0A\0C\0F\0D", align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %72, %0
  %2 = phi i16 [ 0, %0 ], [ %69, %72 ]
  %3 = phi i16 [ 0, %0 ], [ %73, %72 ]
  %4 = shl nuw i16 %3, 12
  %5 = sitofp i16 %4 to float
  br label %6

6:                                                ; preds = %65, %1
  %7 = phi i8 [ 0, %1 ], [ %70, %65 ]
  %8 = phi i16 [ %2, %1 ], [ %69, %65 ]
  %9 = zext nneg i8 %7 to i16
  %10 = getelementptr i8, ptr @_SC_TX, i16 %9
  %11 = load i8, ptr %10, align 1, !tbaa !6
  %12 = zext i8 %11 to i16
  %13 = getelementptr i8, ptr @_SC_TY, i16 %9
  %14 = load i8, ptr %13, align 1, !tbaa !6
  %15 = zext i8 %14 to i16
  %16 = add nsw i16 %15, -8
  %17 = sub nsw i16 8, %12
  %18 = sub nsw i16 %17, %16
  %19 = add nsw i8 %7, -7
  %20 = icmp ult i8 %19, -4
  br i1 %20, label %23, label %21

21:                                               ; preds = %6
  %22 = add nsw i16 %12, -8
  br label %27

23:                                               ; preds = %6
  %24 = icmp samesign ult i8 %7, 3
  br i1 %24, label %25, label %27

25:                                               ; preds = %23
  %26 = sub nuw nsw i16 8, %15
  br label %27

27:                                               ; preds = %25, %23, %21
  %28 = phi i16 [ %17, %25 ], [ %17, %23 ], [ %22, %21 ]
  %29 = phi i16 [ %26, %25 ], [ %16, %23 ], [ %16, %21 ]
  %30 = icmp slt i16 %18, 0
  br i1 %30, label %31, label %33

31:                                               ; preds = %27
  %32 = sub nsw i16 0, %18
  br label %33

33:                                               ; preds = %31, %27
  %34 = phi i16 [ %32, %31 ], [ %18, %27 ]
  %35 = icmp ult i16 %28, %29
  br i1 %35, label %36, label %37

36:                                               ; preds = %33
  br label %37

37:                                               ; preds = %36, %33
  %38 = phi i16 [ %28, %36 ], [ %29, %33 ]
  %39 = phi i16 [ %29, %36 ], [ %28, %33 ]
  %40 = icmp samesign ult i16 %38, %34
  br i1 %40, label %41, label %42

41:                                               ; preds = %37
  br label %42

42:                                               ; preds = %41, %37
  %43 = phi i16 [ %34, %41 ], [ %38, %37 ]
  %44 = icmp ult i16 %39, %43
  br i1 %44, label %45, label %46

45:                                               ; preds = %42
  br label %46

46:                                               ; preds = %45, %42
  %47 = phi i16 [ %39, %45 ], [ %43, %42 ]
  %48 = phi i16 [ %43, %45 ], [ %39, %42 ]
  %49 = sitofp i16 %48 to float
  %50 = uitofp nneg i16 %47 to float
  %51 = fmul nnan float %49, %49
  %52 = fmul nnan float %50, %50
  %53 = fmul nnan float %51, 2.000000e+02
  %54 = fmul nnan float %52, 5.000000e+01
  %55 = fsub float %53, %54
  %56 = fadd float %55, %5
  %57 = fcmp uno float %56, 0.000000e+00
  br i1 %57, label %65, label %58

58:                                               ; preds = %46
  %59 = tail call nsz float @llvm.minnum.f32(float %56, float 3.276700e+04)
  %60 = tail call nsz float @llvm.maxnum.f32(float %59, float -3.276800e+04)
  %61 = fptosi float %60 to i16
  %62 = lshr i16 %61, 14
  %63 = trunc nuw nsw i16 %62 to i8
  %64 = xor i8 %63, 2
  br label %65

65:                                               ; preds = %58, %46
  %66 = phi i8 [ %64, %58 ], [ 0, %46 ]
  %67 = zext nneg i8 %66 to i16
  %68 = tail call i16 @llvm.fshl.i16(i16 %8, i16 %8, i16 1)
  %69 = xor i16 %68, %67
  %70 = add nuw nsw i8 %7, 1
  %71 = icmp eq i8 %70, 8
  br i1 %71, label %72, label %6, !llvm.loop !7

72:                                               ; preds = %65
  %73 = add nuw nsw i16 %3, 1
  %74 = icmp eq i16 %73, 16
  br i1 %74, label %75, label %1, !llvm.loop !9

75:                                               ; preds = %72
  store volatile i16 %69, ptr @corpus_result, align 1, !tbaa !2
  br label %76

76:                                               ; preds = %76, %75
  tail call void asm sideeffect "wai", ""() #3, !srcloc !10
  br label %76
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.minnum.f32(float, float) #1

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nounwind }

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
!10 = !{i64 512}

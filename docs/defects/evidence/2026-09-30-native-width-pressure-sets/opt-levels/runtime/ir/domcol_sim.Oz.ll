; ModuleID = '/work/examples/snes/corpus/domcol_sim.c'
source_filename = "/work/examples/snes/corpus/domcol_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %17, %0
  %2 = phi i16 [ 0, %0 ], [ %20, %17 ]
  %3 = phi i16 [ 0, %0 ], [ %19, %17 ]
  %4 = icmp eq i16 %2, 4
  br i1 %4, label %75, label %5

5:                                                ; preds = %1
  %6 = add nsw i16 %2, -2
  %7 = sitofp i16 %6 to float
  %8 = fmul nnan float %7, 2.500000e-01
  %9 = lshr i16 %2, 1
  %10 = add nsw i16 %9, -1
  %11 = sitofp i16 %10 to float
  %12 = fmul nnan float %11, 2.500000e-01
  br label %13

13:                                               ; preds = %69, %5
  %14 = phi i8 [ 0, %5 ], [ %74, %69 ]
  %15 = phi i16 [ %3, %5 ], [ %73, %69 ]
  %16 = icmp eq i8 %14, 9
  br i1 %16, label %17, label %21

17:                                               ; preds = %13
  %18 = tail call i16 @llvm.fshl.i16(i16 %15, i16 %15, i16 1)
  %19 = xor i16 %18, 3
  %20 = add nuw nsw i16 %2, 1
  br label %1, !llvm.loop !6

21:                                               ; preds = %13
  %22 = zext nneg i8 %14 to i16
  %23 = add nsw i16 %22, -4
  %24 = sitofp i16 %23 to float
  %25 = fmul nnan float %24, 2.500000e-01
  %26 = fmul nnan float %25, %25
  %27 = tail call float @llvm.copysign.f32(float 0.000000e+00, float %25)
  %28 = fadd float %27, %27
  %29 = fadd float %26, -1.000000e+00
  %30 = fadd float %8, %26
  %31 = fadd float %12, %28
  %32 = fmul float %30, %30
  %33 = fmul float %31, %31
  %34 = fadd float %32, %33
  %35 = fmul float %29, %30
  %36 = fmul float %28, %31
  %37 = fadd float %35, %36
  %38 = fmul float %28, %30
  %39 = fmul float %29, %31
  %40 = fsub float %38, %39
  %41 = fdiv float 1.000000e+00, %34
  %42 = fmul float %37, %41
  %43 = fmul float %40, %41
  %44 = fcmp ord float %42, 0.000000e+00
  br i1 %44, label %45, label %69

45:                                               ; preds = %21
  %46 = fcmp ord float %43, 0.000000e+00
  br i1 %46, label %47, label %69

47:                                               ; preds = %45
  %48 = tail call float @llvm.fabs.f32(float %42)
  %49 = fcmp ogt float %48, 0x43ABC16D60000000
  br i1 %49, label %69, label %50

50:                                               ; preds = %47
  %51 = tail call float @llvm.fabs.f32(float %43)
  %52 = fcmp ogt float %51, 0x43ABC16D60000000
  br i1 %52, label %69, label %53

53:                                               ; preds = %50
  %54 = fcmp olt float %42, 0.000000e+00
  br i1 %54, label %55, label %57

55:                                               ; preds = %53
  %56 = fneg float %42
  br label %57

57:                                               ; preds = %55, %53
  %58 = phi float [ %56, %55 ], [ %42, %53 ]
  %59 = fcmp olt float %43, 0.000000e+00
  br i1 %59, label %60, label %62

60:                                               ; preds = %57
  %61 = fneg float %43
  br label %62

62:                                               ; preds = %60, %57
  %63 = phi float [ %61, %60 ], [ %43, %57 ]
  %64 = fadd float %58, %63
  %65 = fcmp ogt float %64, 8.000000e+00
  br i1 %65, label %69, label %66

66:                                               ; preds = %62
  %67 = fcmp ogt float %64, 1.500000e+00
  %68 = zext i1 %67 to i8
  br label %69

69:                                               ; preds = %66, %62, %50, %47, %45, %21
  %70 = phi i8 [ 3, %50 ], [ 3, %21 ], [ 3, %45 ], [ 3, %47 ], [ 2, %62 ], [ %68, %66 ]
  %71 = zext nneg i8 %70 to i16
  %72 = tail call i16 @llvm.fshl.i16(i16 %15, i16 %15, i16 1)
  %73 = xor i16 %72, %71
  %74 = add nuw nsw i8 %14, 1
  br label %13, !llvm.loop !8

75:                                               ; preds = %1
  store volatile i16 %3, ptr @corpus_result, align 1, !tbaa !2
  br label %76

76:                                               ; preds = %76, %75
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %76
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.copysign.f32(float, float) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.fabs.f32(float) #1

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
!9 = !{i64 397}

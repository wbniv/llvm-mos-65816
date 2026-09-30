; ModuleID = '/work/examples/snes/corpus/domcol_sim.c'
source_filename = "/work/examples/snes/corpus/domcol_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %11, %0
  %2 = phi i16 [ 0, %0 ], [ %13, %11 ]
  %3 = phi i16 [ 0, %0 ], [ %14, %11 ]
  %4 = add nsw i16 %3, -2
  %5 = sitofp i16 %4 to float
  %6 = fmul nnan float %5, 2.500000e-01
  %7 = lshr i16 %3, 1
  %8 = add nsw i16 %7, -1
  %9 = sitofp i16 %8 to float
  %10 = fmul nnan float %9, 2.500000e-01
  br label %16

11:                                               ; preds = %66
  %12 = tail call i16 @llvm.fshl.i16(i16 %70, i16 %70, i16 1)
  %13 = xor i16 %12, 3
  %14 = add nuw nsw i16 %3, 1
  %15 = icmp eq i16 %14, 4
  br i1 %15, label %73, label %1, !llvm.loop !6

16:                                               ; preds = %66, %1
  %17 = phi i16 [ %2, %1 ], [ %70, %66 ]
  %18 = phi i8 [ 0, %1 ], [ %71, %66 ]
  %19 = zext nneg i8 %18 to i16
  %20 = add nsw i16 %19, -4
  %21 = sitofp i16 %20 to float
  %22 = fmul nnan float %21, 2.500000e-01
  %23 = fmul nnan float %22, %22
  %24 = tail call float @llvm.copysign.f32(float 0.000000e+00, float %22)
  %25 = fadd float %24, %24
  %26 = fadd float %23, -1.000000e+00
  %27 = fadd float %6, %23
  %28 = fadd float %10, %25
  %29 = fmul float %27, %27
  %30 = fmul float %28, %28
  %31 = fadd float %29, %30
  %32 = fmul float %26, %27
  %33 = fmul float %25, %28
  %34 = fadd float %32, %33
  %35 = fmul float %25, %27
  %36 = fmul float %26, %28
  %37 = fsub float %35, %36
  %38 = fdiv float 1.000000e+00, %31
  %39 = fmul float %34, %38
  %40 = fmul float %37, %38
  %41 = fcmp ord float %39, 0.000000e+00
  br i1 %41, label %42, label %66

42:                                               ; preds = %16
  %43 = fcmp ord float %40, 0.000000e+00
  br i1 %43, label %44, label %66

44:                                               ; preds = %42
  %45 = tail call float @llvm.fabs.f32(float %39)
  %46 = fcmp ogt float %45, 0x43ABC16D60000000
  br i1 %46, label %66, label %47

47:                                               ; preds = %44
  %48 = tail call float @llvm.fabs.f32(float %40)
  %49 = fcmp ogt float %48, 0x43ABC16D60000000
  br i1 %49, label %66, label %50

50:                                               ; preds = %47
  %51 = fcmp olt float %39, 0.000000e+00
  br i1 %51, label %52, label %54

52:                                               ; preds = %50
  %53 = fneg float %39
  br label %54

54:                                               ; preds = %52, %50
  %55 = phi float [ %53, %52 ], [ %39, %50 ]
  %56 = fcmp olt float %40, 0.000000e+00
  br i1 %56, label %57, label %59

57:                                               ; preds = %54
  %58 = fneg float %40
  br label %59

59:                                               ; preds = %57, %54
  %60 = phi float [ %58, %57 ], [ %40, %54 ]
  %61 = fadd float %55, %60
  %62 = fcmp ogt float %61, 8.000000e+00
  br i1 %62, label %66, label %63

63:                                               ; preds = %59
  %64 = fcmp ogt float %61, 1.500000e+00
  %65 = zext i1 %64 to i8
  br label %66

66:                                               ; preds = %63, %59, %47, %44, %42, %16
  %67 = phi i8 [ 3, %47 ], [ 3, %16 ], [ 3, %42 ], [ 3, %44 ], [ 2, %59 ], [ %65, %63 ]
  %68 = zext nneg i8 %67 to i16
  %69 = tail call i16 @llvm.fshl.i16(i16 %17, i16 %17, i16 1)
  %70 = xor i16 %69, %68
  %71 = add nuw nsw i8 %18, 1
  %72 = icmp eq i8 %71, 9
  br i1 %72, label %11, label %16, !llvm.loop !8

73:                                               ; preds = %11
  store volatile i16 %13, ptr @corpus_result, align 1, !tbaa !2
  br label %74

74:                                               ; preds = %74, %73
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %74
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.copysign.f32(float, float) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.fabs.f32(float) #1

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
!9 = !{i64 397}

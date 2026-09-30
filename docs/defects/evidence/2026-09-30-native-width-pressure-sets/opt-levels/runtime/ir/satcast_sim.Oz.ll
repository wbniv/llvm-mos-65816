; ModuleID = '/work/examples/snes/corpus/satcast_sim.c'
source_filename = "/work/examples/snes/corpus/satcast_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@_SC_TX = internal unnamed_addr constant [8 x i8] c"\01\03\06\08\09\0B\0E\02", align 1
@_SC_TY = internal unnamed_addr constant [8 x i8] c"\01\05\07\08\0A\0C\0F\0D", align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %75, %0
  %2 = phi i16 [ 0, %0 ], [ %76, %75 ]
  %3 = phi i16 [ 0, %0 ], [ %10, %75 ]
  %4 = icmp eq i16 %2, 16
  br i1 %4, label %77, label %5

5:                                                ; preds = %1
  %6 = shl nuw i16 %2, 12
  %7 = sitofp i16 %6 to float
  br label %8

8:                                                ; preds = %69, %5
  %9 = phi i8 [ %74, %69 ], [ 0, %5 ]
  %10 = phi i16 [ %73, %69 ], [ %3, %5 ]
  %11 = icmp eq i8 %9, 8
  br i1 %11, label %75, label %12

12:                                               ; preds = %8
  %13 = zext nneg i8 %9 to i16
  %14 = getelementptr i8, ptr @_SC_TX, i16 %13
  %15 = load i8, ptr %14, align 1, !tbaa !6
  %16 = zext i8 %15 to i16
  %17 = getelementptr i8, ptr @_SC_TY, i16 %13
  %18 = load i8, ptr %17, align 1, !tbaa !6
  %19 = zext i8 %18 to i16
  %20 = add nsw i16 %19, -8
  %21 = sub nsw i16 8, %16
  %22 = sub nsw i16 %21, %20
  %23 = add nsw i8 %9, -7
  %24 = icmp ult i8 %23, -4
  br i1 %24, label %27, label %25

25:                                               ; preds = %12
  %26 = add nsw i16 %16, -8
  br label %31

27:                                               ; preds = %12
  %28 = icmp samesign ult i8 %9, 3
  br i1 %28, label %29, label %31

29:                                               ; preds = %27
  %30 = sub nuw nsw i16 8, %19
  br label %31

31:                                               ; preds = %29, %27, %25
  %32 = phi i16 [ %21, %29 ], [ %21, %27 ], [ %26, %25 ]
  %33 = phi i16 [ %30, %29 ], [ %20, %27 ], [ %20, %25 ]
  %34 = icmp slt i16 %22, 0
  br i1 %34, label %35, label %37

35:                                               ; preds = %31
  %36 = sub nsw i16 0, %22
  br label %37

37:                                               ; preds = %35, %31
  %38 = phi i16 [ %36, %35 ], [ %22, %31 ]
  %39 = icmp ult i16 %32, %33
  br i1 %39, label %40, label %41

40:                                               ; preds = %37
  br label %41

41:                                               ; preds = %40, %37
  %42 = phi i16 [ %32, %40 ], [ %33, %37 ]
  %43 = phi i16 [ %33, %40 ], [ %32, %37 ]
  %44 = icmp samesign ult i16 %42, %38
  br i1 %44, label %45, label %46

45:                                               ; preds = %41
  br label %46

46:                                               ; preds = %45, %41
  %47 = phi i16 [ %38, %45 ], [ %42, %41 ]
  %48 = icmp ult i16 %43, %47
  br i1 %48, label %49, label %50

49:                                               ; preds = %46
  br label %50

50:                                               ; preds = %49, %46
  %51 = phi i16 [ %43, %49 ], [ %47, %46 ]
  %52 = phi i16 [ %47, %49 ], [ %43, %46 ]
  %53 = sitofp i16 %52 to float
  %54 = uitofp nneg i16 %51 to float
  %55 = fmul nnan float %53, %53
  %56 = fmul nnan float %54, %54
  %57 = fmul nnan float %55, 2.000000e+02
  %58 = fmul nnan float %56, 5.000000e+01
  %59 = fsub float %57, %58
  %60 = fadd float %59, %7
  %61 = fcmp uno float %60, 0.000000e+00
  br i1 %61, label %69, label %62

62:                                               ; preds = %50
  %63 = tail call nsz float @llvm.minnum.f32(float %60, float 3.276700e+04)
  %64 = tail call nsz float @llvm.maxnum.f32(float %63, float -3.276800e+04)
  %65 = fptosi float %64 to i16
  %66 = lshr i16 %65, 14
  %67 = trunc nuw nsw i16 %66 to i8
  %68 = xor i8 %67, 2
  br label %69

69:                                               ; preds = %62, %50
  %70 = phi i8 [ %68, %62 ], [ 0, %50 ]
  %71 = zext nneg i8 %70 to i16
  %72 = tail call i16 @llvm.fshl.i16(i16 %10, i16 %10, i16 1)
  %73 = xor i16 %72, %71
  %74 = add nuw nsw i8 %9, 1
  br label %8, !llvm.loop !7

75:                                               ; preds = %8
  %76 = add nuw nsw i16 %2, 1
  br label %1, !llvm.loop !9

77:                                               ; preds = %1
  store volatile i16 %3, ptr @corpus_result, align 1, !tbaa !2
  br label %78

78:                                               ; preds = %78, %77
  tail call void asm sideeffect "wai", ""() #3, !srcloc !10
  br label %78
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.minnum.f32(float, float) #1

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.maxnum.f32(float, float) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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

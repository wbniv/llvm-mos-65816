; ModuleID = '/work/examples/snes/corpus/satcast_sim.c'
source_filename = "/work/examples/snes/corpus/satcast_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i16 [ 0, %0 ], [ %77, %1 ]
  %3 = phi i16 [ 0, %0 ], [ %78, %1 ]
  %4 = shl nuw i16 %3, 12
  %5 = sitofp i16 %4 to float
  %6 = fadd float %5, 3.675000e+04
  %7 = tail call nsz float @llvm.minnum.f32(float %6, float 3.276700e+04)
  %8 = tail call nsz float @llvm.maxnum.f32(float %7, float -3.276800e+04)
  %9 = fptosi float %8 to i16
  %10 = lshr i16 %9, 14
  %11 = trunc nuw nsw i16 %10 to i8
  %12 = xor i8 %11, 2
  %13 = zext nneg i8 %12 to i16
  %14 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %15 = xor i16 %14, %13
  %16 = fadd float %5, 1.155000e+04
  %17 = tail call nsz float @llvm.minnum.f32(float %16, float 3.276700e+04)
  %18 = tail call nsz float @llvm.maxnum.f32(float %17, float -3.276800e+04)
  %19 = fptosi float %18 to i16
  %20 = lshr i16 %19, 14
  %21 = trunc nuw nsw i16 %20 to i8
  %22 = xor i8 %21, 2
  %23 = zext nneg i8 %22 to i16
  %24 = tail call i16 @llvm.fshl.i16(i16 %15, i16 %15, i16 1)
  %25 = xor i16 %24, %23
  %26 = or disjoint i16 %4, 1600
  %27 = sitofp i16 %26 to float
  %28 = tail call nsz float @llvm.minnum.f32(float %27, float 3.276700e+04)
  %29 = tail call nsz float @llvm.maxnum.f32(float %28, float -3.276800e+04)
  %30 = fptosi float %29 to i16
  %31 = lshr i16 %30, 14
  %32 = trunc nuw nsw i16 %31 to i8
  %33 = xor i8 %32, 2
  %34 = zext nneg i8 %33 to i16
  %35 = tail call i16 @llvm.fshl.i16(i16 %25, i16 %25, i16 1)
  %36 = xor i16 %35, %34
  %37 = tail call nsz float @llvm.minnum.f32(float %5, float 3.276700e+04)
  %38 = tail call nsz float @llvm.maxnum.f32(float %37, float -3.276800e+04)
  %39 = fptosi float %38 to i16
  %40 = lshr i16 %39, 14
  %41 = trunc nuw nsw i16 %40 to i8
  %42 = xor i8 %41, 2
  %43 = zext nneg i8 %42 to i16
  %44 = tail call i16 @llvm.fshl.i16(i16 %36, i16 %36, i16 1)
  %45 = xor i16 %44, %43
  %46 = tail call i16 @llvm.fshl.i16(i16 %45, i16 %45, i16 1)
  %47 = xor i16 %46, %34
  %48 = fadd float %5, 9.000000e+03
  %49 = tail call nsz float @llvm.minnum.f32(float %48, float 3.276700e+04)
  %50 = tail call nsz float @llvm.maxnum.f32(float %49, float -3.276800e+04)
  %51 = fptosi float %50 to i16
  %52 = lshr i16 %51, 14
  %53 = trunc nuw nsw i16 %52 to i8
  %54 = xor i8 %53, 2
  %55 = zext nneg i8 %54 to i16
  %56 = tail call i16 @llvm.fshl.i16(i16 %47, i16 %47, i16 1)
  %57 = xor i16 %56, %55
  %58 = fadd float %5, 3.135000e+04
  %59 = tail call nsz float @llvm.minnum.f32(float %58, float 3.276700e+04)
  %60 = tail call nsz float @llvm.maxnum.f32(float %59, float -3.276800e+04)
  %61 = fptosi float %60 to i16
  %62 = lshr i16 %61, 14
  %63 = trunc nuw nsw i16 %62 to i8
  %64 = xor i8 %63, 2
  %65 = zext nneg i8 %64 to i16
  %66 = tail call i16 @llvm.fshl.i16(i16 %57, i16 %57, i16 1)
  %67 = xor i16 %66, %65
  %68 = fadd float %5, 5.950000e+03
  %69 = tail call nsz float @llvm.minnum.f32(float %68, float 3.276700e+04)
  %70 = tail call nsz float @llvm.maxnum.f32(float %69, float -3.276800e+04)
  %71 = fptosi float %70 to i16
  %72 = lshr i16 %71, 14
  %73 = trunc nuw nsw i16 %72 to i8
  %74 = xor i8 %73, 2
  %75 = zext nneg i8 %74 to i16
  %76 = tail call i16 @llvm.fshl.i16(i16 %67, i16 %67, i16 1)
  %77 = xor i16 %76, %75
  %78 = add nuw nsw i16 %3, 1
  %79 = icmp eq i16 %78, 16
  br i1 %79, label %80, label %1, !llvm.loop !6

80:                                               ; preds = %1
  store volatile i16 %77, ptr @corpus_result, align 1, !tbaa !2
  br label %81

81:                                               ; preds = %81, %80
  tail call void asm sideeffect "wai", ""() #3, !srcloc !8
  br label %81
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
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = !{i64 512}

; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20060420-1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20060420-1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@buffer = dso_local global [64 x float] zeroinitializer, align 1

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(read, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define dso_local void @foo(ptr noundef %0, ptr noundef readonly captures(none) %1, i16 noundef %2, i16 noundef %3) local_unnamed_addr #0 {
  %5 = icmp sgt i16 %3, 0
  br i1 %5, label %6, label %37

6:                                                ; preds = %4
  %7 = ptrtoint ptr %0 to i16
  %8 = icmp sgt i16 %2, 1
  %9 = trunc i16 %7 to i4
  %10 = sub i4 0, %9
  %11 = zext i4 %10 to i16
  br label %12

12:                                               ; preds = %6, %30
  %13 = phi i8 [ 0, %6 ], [ %36, %30 ]
  %14 = phi i16 [ 0, %6 ], [ %34, %30 ]
  %15 = icmp eq i16 %14, %11
  br i1 %15, label %37, label %16

16:                                               ; preds = %12
  %17 = load ptr, ptr %1, align 1, !tbaa !6
  %18 = getelementptr inbounds nuw [4 x i8], ptr %17, i16 %14
  %19 = load float, ptr %18, align 1, !tbaa !9
  br i1 %8, label %20, label %30

20:                                               ; preds = %16, %20
  %21 = phi float [ %27, %20 ], [ %19, %16 ]
  %22 = phi i16 [ %28, %20 ], [ 1, %16 ]
  %23 = getelementptr inbounds nuw [2 x i8], ptr %1, i16 %22
  %24 = load ptr, ptr %23, align 1, !tbaa !6
  %25 = getelementptr inbounds nuw [4 x i8], ptr %24, i16 %14
  %26 = load float, ptr %25, align 1, !tbaa !9
  %27 = fadd float %21, %26
  %28 = add nuw nsw i16 %22, 1
  %29 = icmp eq i16 %28, %2
  br i1 %29, label %30, label %20, !llvm.loop !11

30:                                               ; preds = %20, %16
  %31 = phi float [ %19, %16 ], [ %27, %20 ]
  %32 = zext nneg i8 %13 to i16
  %33 = getelementptr i8, ptr %0, i16 %32
  store float %31, ptr %33, align 1, !tbaa !9
  %34 = add nuw nsw i16 %14, 1
  %35 = icmp eq i16 %34, %3
  %36 = add nuw nsw i8 %13, 4
  br i1 %35, label %112, label %12, !llvm.loop !13

37:                                               ; preds = %12, %4
  %38 = phi i16 [ 0, %4 ], [ %11, %12 ]
  %39 = add nsw i16 %3, -15
  %40 = icmp slt i16 %38, %39
  br i1 %40, label %41, label %43

41:                                               ; preds = %37
  %42 = icmp sgt i16 %2, 1
  br label %49

43:                                               ; preds = %82, %37
  %44 = phi i16 [ %38, %37 ], [ %91, %82 ]
  %45 = icmp slt i16 %44, %3
  br i1 %45, label %46, label %112

46:                                               ; preds = %43
  %47 = load ptr, ptr %1, align 1, !tbaa !6
  %48 = icmp sgt i16 %2, 1
  br label %93

49:                                               ; preds = %41, %82
  %50 = phi i16 [ %38, %41 ], [ %91, %82 ]
  %51 = load ptr, ptr %1, align 1, !tbaa !6
  %52 = getelementptr inbounds nuw [4 x i8], ptr %51, i16 %50
  %53 = load <4 x float>, ptr %52, align 16, !tbaa !14
  %54 = getelementptr inbounds nuw i8, ptr %52, i16 16
  %55 = load <4 x float>, ptr %54, align 16, !tbaa !14
  %56 = getelementptr inbounds nuw i8, ptr %52, i16 32
  %57 = load <4 x float>, ptr %56, align 16, !tbaa !14
  %58 = getelementptr inbounds nuw i8, ptr %52, i16 48
  %59 = load <4 x float>, ptr %58, align 16, !tbaa !14
  br i1 %42, label %60, label %82

60:                                               ; preds = %49, %60
  %61 = phi <4 x float> [ %79, %60 ], [ %59, %49 ]
  %62 = phi <4 x float> [ %76, %60 ], [ %57, %49 ]
  %63 = phi <4 x float> [ %73, %60 ], [ %55, %49 ]
  %64 = phi <4 x float> [ %70, %60 ], [ %53, %49 ]
  %65 = phi i16 [ %80, %60 ], [ 1, %49 ]
  %66 = getelementptr inbounds nuw [2 x i8], ptr %1, i16 %65
  %67 = load ptr, ptr %66, align 1, !tbaa !6
  %68 = getelementptr inbounds nuw [4 x i8], ptr %67, i16 %50
  %69 = load <4 x float>, ptr %68, align 16, !tbaa !14
  %70 = fadd <4 x float> %64, %69
  %71 = getelementptr inbounds nuw i8, ptr %68, i16 16
  %72 = load <4 x float>, ptr %71, align 16, !tbaa !14
  %73 = fadd <4 x float> %63, %72
  %74 = getelementptr inbounds nuw i8, ptr %68, i16 32
  %75 = load <4 x float>, ptr %74, align 16, !tbaa !14
  %76 = fadd <4 x float> %62, %75
  %77 = getelementptr inbounds nuw i8, ptr %68, i16 48
  %78 = load <4 x float>, ptr %77, align 16, !tbaa !14
  %79 = fadd <4 x float> %61, %78
  %80 = add nuw nsw i16 %65, 1
  %81 = icmp eq i16 %80, %2
  br i1 %81, label %82, label %60, !llvm.loop !15

82:                                               ; preds = %60, %49
  %83 = phi <4 x float> [ %53, %49 ], [ %70, %60 ]
  %84 = phi <4 x float> [ %55, %49 ], [ %73, %60 ]
  %85 = phi <4 x float> [ %57, %49 ], [ %76, %60 ]
  %86 = phi <4 x float> [ %59, %49 ], [ %79, %60 ]
  %87 = getelementptr inbounds nuw [4 x i8], ptr %0, i16 %50
  store <4 x float> %83, ptr %87, align 16, !tbaa !14
  %88 = getelementptr inbounds nuw i8, ptr %87, i16 16
  store <4 x float> %84, ptr %88, align 16, !tbaa !14
  %89 = getelementptr inbounds nuw i8, ptr %87, i16 32
  store <4 x float> %85, ptr %89, align 16, !tbaa !14
  %90 = getelementptr inbounds nuw i8, ptr %87, i16 48
  store <4 x float> %86, ptr %90, align 16, !tbaa !14
  %91 = add nuw nsw i16 %50, 16
  %92 = icmp slt i16 %91, %39
  br i1 %92, label %49, label %43, !llvm.loop !16

93:                                               ; preds = %46, %107
  %94 = phi i16 [ %44, %46 ], [ %110, %107 ]
  %95 = getelementptr inbounds nuw [4 x i8], ptr %47, i16 %94
  %96 = load float, ptr %95, align 1, !tbaa !9
  br i1 %48, label %97, label %107

97:                                               ; preds = %93, %97
  %98 = phi float [ %104, %97 ], [ %96, %93 ]
  %99 = phi i16 [ %105, %97 ], [ 1, %93 ]
  %100 = getelementptr inbounds nuw [2 x i8], ptr %1, i16 %99
  %101 = load ptr, ptr %100, align 1, !tbaa !6
  %102 = getelementptr inbounds nuw [4 x i8], ptr %101, i16 %94
  %103 = load float, ptr %102, align 1, !tbaa !9
  %104 = fadd float %98, %103
  %105 = add nuw nsw i16 %99, 1
  %106 = icmp eq i16 %105, %2
  br i1 %106, label %107, label %97, !llvm.loop !17

107:                                              ; preds = %97, %93
  %108 = phi float [ %96, %93 ], [ %104, %97 ]
  %109 = getelementptr inbounds nuw [4 x i8], ptr %0, i16 %94
  store float %108, ptr %109, align 1, !tbaa !9
  %110 = add nuw nsw i16 %94, 1
  %111 = icmp eq i16 %110, %3
  br i1 %111, label %112, label %93, !llvm.loop !18

112:                                              ; preds = %30, %107, %43
  ret void
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #2 {
  %1 = alloca [2 x ptr], align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #5
  %2 = and i16 trunc (i32 sub (i32 0, i32 ptrtoint (ptr @buffer to i32)) to i16), 63
  %3 = getelementptr inbounds nuw i8, ptr @buffer, i16 %2
  %4 = getelementptr inbounds nuw i8, ptr %3, i16 64
  store ptr %4, ptr %1, align 1, !tbaa !6
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 128
  %6 = getelementptr inbounds nuw i8, ptr %1, i16 2
  store ptr %5, ptr %6, align 1, !tbaa !6
  br label %7

7:                                                ; preds = %0, %7
  %8 = phi i8 [ 0, %0 ], [ %18, %7 ]
  %9 = phi i16 [ 0, %0 ], [ %16, %7 ]
  %10 = uitofp nneg i16 %9 to float
  %11 = tail call float @llvm.fmuladd.f32(float %10, float 1.100000e+01, float %10)
  %12 = zext nneg i8 %8 to i16
  %13 = getelementptr i8, ptr %4, i16 %12
  store float %11, ptr %13, align 1, !tbaa !9
  %14 = tail call float @llvm.fmuladd.f32(float %10, float 1.200000e+01, float %10)
  %15 = getelementptr i8, ptr %5, i16 %12
  store float %14, ptr %15, align 1, !tbaa !9
  %16 = add nuw nsw i16 %9, 1
  %17 = icmp eq i16 %16, 16
  %18 = add nuw nsw i8 %8, 4
  br i1 %17, label %19, label %7, !llvm.loop !19

19:                                               ; preds = %7
  call void @foo(ptr noundef nonnull %3, ptr noundef nonnull %1, i16 noundef 2, i16 noundef 16) #6
  br label %24

20:                                               ; preds = %24
  %21 = add nuw nsw i16 %26, 1
  %22 = icmp eq i16 %21, 16
  %23 = add nuw nsw i8 %25, 4
  br i1 %22, label %36, label %24, !llvm.loop !20

24:                                               ; preds = %19, %20
  %25 = phi i8 [ 0, %19 ], [ %23, %20 ]
  %26 = phi i16 [ 0, %19 ], [ %21, %20 ]
  %27 = uitofp nneg i16 %26 to float
  %28 = tail call float @llvm.fmuladd.f32(float %27, float 1.100000e+01, float %27)
  %29 = fadd float %28, %27
  %30 = tail call float @llvm.fmuladd.f32(float %27, float 1.200000e+01, float %29)
  %31 = zext nneg i8 %25 to i16
  %32 = getelementptr i8, ptr %3, i16 %31
  %33 = load float, ptr %32, align 1, !tbaa !9
  %34 = fcmp une float %33, %30
  br i1 %34, label %35, label %20

35:                                               ; preds = %24
  tail call void @abort() #7
  unreachable

36:                                               ; preds = %20
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #5
  ret i16 0
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.fmuladd.f32(float, float, float) #3

; Function Attrs: noreturn nounwind optsize
declare dso_local void @abort() local_unnamed_addr #4

attributes #0 = { nofree noinline norecurse nosync nounwind optsize memory(read, argmem: readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #3 = { mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #5 = { nounwind }
attributes #6 = { optsize }
attributes #7 = { noreturn nounwind optsize }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"p1 float", !8, i64 0}
!8 = !{!"any pointer", !4, i64 0}
!9 = !{!10, !10, i64 0}
!10 = !{!"float", !4, i64 0}
!11 = distinct !{!11, !12}
!12 = !{!"llvm.loop.mustprogress"}
!13 = distinct !{!13, !12}
!14 = !{!4, !4, i64 0}
!15 = distinct !{!15, !12}
!16 = distinct !{!16, !12}
!17 = distinct !{!17, !12}
!18 = distinct !{!18, !12}
!19 = distinct !{!19, !12}
!20 = distinct !{!20, !12}

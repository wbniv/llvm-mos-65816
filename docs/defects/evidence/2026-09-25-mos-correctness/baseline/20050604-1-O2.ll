; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20050604-1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20050604-1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%union.anon = type { <4 x i16> }
%union.anon.0 = type { <4 x float> }

@u = dso_local local_unnamed_addr global %union.anon zeroinitializer, align 8
@v = dso_local local_unnamed_addr global %union.anon.0 zeroinitializer, align 16

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define dso_local void @foo() local_unnamed_addr #0 {
  %1 = load <4 x i16>, ptr @u, align 8, !tbaa !6
  %2 = add <4 x i16> %1, <i16 24, i16 0, i16 0, i16 0>
  store <4 x i16> %2, ptr @u, align 8, !tbaa !6
  %3 = load <4 x float>, ptr @v, align 16, !tbaa !6
  %4 = fadd <4 x float> %3, <float 1.800000e+01, float 2.000000e+01, float 2.200000e+01, float 0.000000e+00>
  %5 = fadd <4 x float> %4, <float 1.800000e+01, float 2.000000e+01, float 2.200000e+01, float 0.000000e+00>
  store <4 x float> %5, ptr @v, align 16, !tbaa !6
  ret void
}

; Function Attrs: nounwind
define dso_local noundef i16 @main() local_unnamed_addr #1 {
  %1 = load <4 x i16>, ptr @u, align 8, !tbaa !6
  %2 = add <4 x i16> %1, <i16 24, i16 0, i16 0, i16 0>
  store <4 x i16> %2, ptr @u, align 8, !tbaa !6
  %3 = load <4 x float>, ptr @v, align 16, !tbaa !6
  %4 = fadd <4 x float> %3, <float 1.800000e+01, float 2.000000e+01, float 2.200000e+01, float 0.000000e+00>
  %5 = fadd <4 x float> %4, <float 1.800000e+01, float 2.000000e+01, float 2.200000e+01, float 0.000000e+00>
  store <4 x float> %5, ptr @v, align 16, !tbaa !6
  %6 = extractelement <4 x i16> %2, i64 0
  %7 = icmp eq i16 %6, 24
  %8 = extractelement <4 x i16> %2, i64 2
  %9 = extractelement <4 x i16> %2, i64 3
  %10 = extractelement <4 x float> %5, i64 0
  %11 = extractelement <4 x float> %5, i64 1
  %12 = extractelement <4 x float> %5, i64 2
  %13 = extractelement <4 x float> %5, i64 3
  br i1 %7, label %14, label %21

14:                                               ; preds = %0
  %15 = extractelement <4 x i16> %2, i64 1
  %16 = icmp eq i16 %15, 0
  br i1 %16, label %17, label %21

17:                                               ; preds = %14
  %18 = icmp eq i16 %8, 0
  br i1 %18, label %19, label %21

19:                                               ; preds = %17
  %20 = icmp eq i16 %9, 0
  br i1 %20, label %22, label %21

21:                                               ; preds = %19, %17, %14, %0
  tail call void @abort() #3
  unreachable

22:                                               ; preds = %19
  %23 = fcmp une float %10, 3.600000e+01
  br i1 %23, label %30, label %24

24:                                               ; preds = %22
  %25 = fcmp une float %11, 4.000000e+01
  br i1 %25, label %30, label %26

26:                                               ; preds = %24
  %27 = fcmp une float %12, 4.400000e+01
  br i1 %27, label %30, label %28

28:                                               ; preds = %26
  %29 = fcmp une float %13, 0.000000e+00
  br i1 %29, label %30, label %31

30:                                               ; preds = %28, %26, %24, %22
  tail call void @abort() #3
  unreachable

31:                                               ; preds = %28
  ret i16 0
}

; Function Attrs: noreturn nounwind
declare dso_local void @abort() local_unnamed_addr #2

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #2 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #3 = { noreturn nounwind }

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

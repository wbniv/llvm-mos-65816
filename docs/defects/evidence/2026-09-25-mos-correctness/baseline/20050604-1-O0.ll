; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20050604-1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20050604-1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%union.anon = type { <4 x i16> }
%union.anon.0 = type { <4 x float> }

@u = dso_local global %union.anon zeroinitializer, align 8
@v = dso_local global %union.anon.0 zeroinitializer, align 16

; Function Attrs: noinline nounwind optnone
define dso_local void @foo() #0 {
  %1 = alloca i16, align 1
  %2 = alloca <4 x i16>, align 8
  %3 = alloca <4 x float>, align 16
  store i16 0, ptr %1, align 1
  br label %4

4:                                                ; preds = %11, %0
  %5 = load i16, ptr %1, align 1
  %6 = icmp ult i16 %5, 2
  br i1 %6, label %7, label %14

7:                                                ; preds = %4
  store <4 x i16> <i16 12, i16 -32768, i16 0, i16 0>, ptr %2, align 8
  %8 = load <4 x i16>, ptr %2, align 8
  %9 = load <4 x i16>, ptr @u, align 8
  %10 = add <4 x i16> %9, %8
  store <4 x i16> %10, ptr @u, align 8
  br label %11

11:                                               ; preds = %7
  %12 = load i16, ptr %1, align 1
  %13 = add i16 %12, 1
  store i16 %13, ptr %1, align 1
  br label %4, !llvm.loop !2

14:                                               ; preds = %4
  store i16 0, ptr %1, align 1
  br label %15

15:                                               ; preds = %22, %14
  %16 = load i16, ptr %1, align 1
  %17 = icmp ult i16 %16, 2
  br i1 %17, label %18, label %25

18:                                               ; preds = %15
  store <4 x float> <float 1.800000e+01, float 2.000000e+01, float 2.200000e+01, float 0.000000e+00>, ptr %3, align 16
  %19 = load <4 x float>, ptr %3, align 16
  %20 = load <4 x float>, ptr @v, align 16
  %21 = fadd <4 x float> %20, %19
  store <4 x float> %21, ptr @v, align 16
  br label %22

22:                                               ; preds = %18
  %23 = load i16, ptr %1, align 1
  %24 = add i16 %23, 1
  store i16 %24, ptr %1, align 1
  br label %15, !llvm.loop !4

25:                                               ; preds = %15
  ret void
}

; Function Attrs: noinline nounwind optnone
define dso_local i16 @main() #0 {
  %1 = alloca i16, align 1
  store i16 0, ptr %1, align 1
  call void @foo()
  %2 = load i16, ptr @u, align 8
  %3 = icmp ne i16 %2, 24
  br i1 %3, label %13, label %4

4:                                                ; preds = %0
  %5 = load i16, ptr getelementptr inbounds nuw (i8, ptr @u, i16 2), align 2
  %6 = icmp ne i16 %5, 0
  br i1 %6, label %13, label %7

7:                                                ; preds = %4
  %8 = load i16, ptr getelementptr inbounds nuw (i8, ptr @u, i16 4), align 4
  %9 = icmp ne i16 %8, 0
  br i1 %9, label %13, label %10

10:                                               ; preds = %7
  %11 = load i16, ptr getelementptr inbounds nuw (i8, ptr @u, i16 6), align 2
  %12 = icmp ne i16 %11, 0
  br i1 %12, label %13, label %14

13:                                               ; preds = %10, %7, %4, %0
  call void @abort() #2
  unreachable

14:                                               ; preds = %10
  %15 = load float, ptr @v, align 16
  %16 = fpext float %15 to double
  %17 = fcmp une double %16, 3.600000e+01
  br i1 %17, label %30, label %18

18:                                               ; preds = %14
  %19 = load float, ptr getelementptr inbounds nuw (i8, ptr @v, i16 4), align 4
  %20 = fpext float %19 to double
  %21 = fcmp une double %20, 4.000000e+01
  br i1 %21, label %30, label %22

22:                                               ; preds = %18
  %23 = load float, ptr getelementptr inbounds nuw (i8, ptr @v, i16 8), align 8
  %24 = fpext float %23 to double
  %25 = fcmp une double %24, 4.400000e+01
  br i1 %25, label %30, label %26

26:                                               ; preds = %22
  %27 = load float, ptr getelementptr inbounds nuw (i8, ptr @v, i16 12), align 4
  %28 = fpext float %27 to double
  %29 = fcmp une double %28, 0.000000e+00
  br i1 %29, label %30, label %31

30:                                               ; preds = %26, %22, %18, %14
  call void @abort() #2
  unreachable

31:                                               ; preds = %26
  ret i16 0
}

; Function Attrs: noreturn nounwind
declare dso_local void @abort() #1

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #2 = { noreturn nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = distinct !{!2, !3}
!3 = !{!"llvm.loop.mustprogress"}
!4 = distinct !{!4, !3}

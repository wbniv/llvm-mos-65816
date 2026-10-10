; ModuleID = '/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c'
source_filename = "/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: noinline nounwind optnone
define dso_local void @stage(ptr noundef %0, i16 noundef %1) #0 {
  %3 = alloca ptr, align 1
  %4 = alloca i16, align 1
  %5 = alloca i16, align 1
  %6 = alloca i16, align 1
  %7 = alloca i8, align 1
  store ptr %0, ptr %3, align 1
  store i16 %1, ptr %4, align 1
  %8 = load ptr, ptr %3, align 1
  %9 = getelementptr inbounds i16, ptr %8, i16 0
  %10 = load i16, ptr %9, align 1
  %11 = load i16, ptr %4, align 1
  %12 = add i16 %10, %11
  store i16 %12, ptr %5, align 1
  %13 = load ptr, ptr %3, align 1
  %14 = getelementptr inbounds i16, ptr %13, i16 1
  %15 = load i16, ptr %14, align 1
  %16 = load i16, ptr %5, align 1
  %17 = xor i16 %15, %16
  store i16 %17, ptr %6, align 1
  %18 = load ptr, ptr %3, align 1
  %19 = getelementptr inbounds i8, ptr %18, i16 4
  %20 = load i8, ptr %19, align 1
  %21 = zext i8 %20 to i16
  %22 = load i16, ptr %6, align 1
  %23 = trunc i16 %22 to i8
  %24 = zext i8 %23 to i16
  %25 = add nsw i16 %21, %24
  %26 = trunc i16 %25 to i8
  store i8 %26, ptr %7, align 1
  %27 = load i16, ptr %5, align 1
  %28 = call i16 @ext(i16 noundef %27, i16 noundef 13849)
  %29 = load i16, ptr %6, align 1
  %30 = add i16 %28, %29
  %31 = load ptr, ptr %3, align 1
  %32 = getelementptr inbounds i16, ptr %31, i16 0
  store i16 %30, ptr %32, align 1
  %33 = load i16, ptr %6, align 1
  %34 = load i8, ptr %7, align 1
  %35 = zext i8 %34 to i16
  %36 = sub i16 %33, %35
  %37 = load ptr, ptr %3, align 1
  %38 = getelementptr inbounds i16, ptr %37, i16 1
  store i16 %36, ptr %38, align 1
  %39 = load i16, ptr %5, align 1
  %40 = lshr i16 %39, 8
  %41 = load i8, ptr %7, align 1
  %42 = zext i8 %41 to i16
  %43 = xor i16 %40, %42
  %44 = trunc i16 %43 to i8
  %45 = load ptr, ptr %3, align 1
  %46 = getelementptr inbounds i8, ptr %45, i16 4
  store i8 %44, ptr %46, align 1
  ret void
}

declare dso_local i16 @ext(i16 noundef, i16 noundef) #1

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos.git 367513ea6a79a4a0e0f23894a43710c45f33135f)"}

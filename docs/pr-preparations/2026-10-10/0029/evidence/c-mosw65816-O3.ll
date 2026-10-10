; ModuleID = '/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c'
source_filename = "/work/docs/pr-preparations/2026-10-10/0029/evidence/mixed-width-call.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: noinline nounwind
define dso_local void @stage(ptr nofree noundef captures(none) %0, i16 noundef %1) local_unnamed_addr #0 {
  %3 = load i16, ptr %0, align 1, !tbaa !7
  %4 = add i16 %3, %1
  %5 = getelementptr inbounds nuw i8, ptr %0, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !7
  %7 = xor i16 %6, %4
  %8 = getelementptr inbounds nuw i8, ptr %0, i16 4
  %9 = load i8, ptr %8, align 1, !tbaa !8
  %10 = trunc i16 %7 to i8
  %11 = add i8 %9, %10
  %12 = tail call i16 @ext(i16 noundef %4, i16 noundef 13849) #2
  %13 = add i16 %12, %7
  store i16 %13, ptr %0, align 1, !tbaa !7
  %14 = zext i8 %11 to i16
  %15 = sub i16 %7, %14
  store i16 %15, ptr %5, align 1, !tbaa !7
  %16 = lshr i16 %4, 8
  %17 = trunc nuw i16 %16 to i8
  %18 = xor i8 %11, %17
  store i8 %18, ptr %8, align 1, !tbaa !8
  ret void
}

declare dso_local i16 @ext(i16 noundef, i16 noundef) local_unnamed_addr #1

attributes #0 = { noinline nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }
attributes #1 = { "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos.git 367513ea6a79a4a0e0f23894a43710c45f33135f)"}
!2 = !{!3, !4, i64 0}
!3 = !{!"__libc_errno", !4, i64 0}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!4, !4, i64 0}
!8 = !{!5, !5, i64 0}

; ModuleID = 'docs/defects/evidence/2026-09-25-trunc-imag8-i1/source.c'
source_filename = "docs/defects/evidence/2026-09-25-trunc-imag8-i1/source.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define dso_local noundef zeroext i8 @trunc_imag8_i1(i8 noundef zeroext %0, i8 noundef zeroext %1) local_unnamed_addr #0 {
  %3 = trunc i8 %1 to i1
  br i1 %3, label %4, label %6

4:                                                ; preds = %2
  %5 = sub i8 %0, %1
  br label %6

6:                                                ; preds = %2, %4
  %7 = phi i8 [ %5, %4 ], [ %0, %2 ]
  ret i8 %7
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}

; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@one = dso_local global i16 1, align 1

; Function Attrs: mustprogress nofree norecurse nounwind willreturn memory(readwrite, argmem: none, target_mem: none)
define dso_local noundef i16 @main(i16 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #0 {
  %3 = load volatile i16, ptr @one, align 1, !tbaa !2
  ret i16 0
}

attributes #0 = { mustprogress nofree norecurse nounwind willreturn memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}

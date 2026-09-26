; ModuleID = '/home/will/llvm-mos-65816/.scratch/carry-scheduling/docs/defects/evidence/2026-09-26-mos-carry-scheduling/p_rot.c.txt'
source_filename = "/home/will/llvm-mos-65816/.scratch/carry-scheduling/docs/defects/evidence/2026-09-26-mos-carry-scheduling/p_rot.c.txt"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@i0 = dso_local global i32 100, align 1
@i1 = dso_local global i32 50000, align 1
@i2 = dso_local global i32 90000, align 1
@tbl = external dso_local local_unnamed_addr addrspace(2) constant [0 x i16], align 1
@out = dso_local global i32 0, align 1

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define dso_local void @f() local_unnamed_addr #0 {
  %1 = load volatile i32, ptr @i0, align 1, !tbaa !6
  %2 = getelementptr inbounds [2 x i8], ptr addrspace(2) @tbl, i32 %1
  %3 = load i16, ptr addrspace(2) %2, align 1, !tbaa !2
  %4 = zext i16 %3 to i32
  %5 = load volatile i32, ptr @i1, align 1, !tbaa !6
  %6 = getelementptr inbounds [2 x i8], ptr addrspace(2) @tbl, i32 %5
  %7 = load i16, ptr addrspace(2) %6, align 1, !tbaa !2
  %8 = zext i16 %7 to i32
  %9 = load volatile i32, ptr @i2, align 1, !tbaa !6
  %10 = getelementptr inbounds [2 x i8], ptr addrspace(2) @tbl, i32 %9
  %11 = load i16, ptr addrspace(2) %10, align 1, !tbaa !2
  %12 = shl nuw nsw i32 %4, 2
  %13 = shl nuw nsw i32 %8, 1
  %14 = xor i32 %13, %12
  %15 = zext i16 %11 to i32
  %16 = xor i32 %14, %15
  store volatile i32 %16, ptr @out, align 1, !tbaa !6
  ret void
}

attributes #0 = { nofree norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (/upstream 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"long", !4, i64 0}

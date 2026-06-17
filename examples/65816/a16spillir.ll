; a16spillir.ll — hermetic LLVM-IR crash-regression for the SOFT-STACK Ac16 spill (#321 / F3).
;
; Frozen IR of examples/65816/a16spillr.c. The runtime test (dev/a16spillr.sh) guards the same bug
; end-to-end but depends on the C front end + optimizer continuing to keep (a) the recursion (-> the
; soft/reentrant stack) and (b) a 16-bit value resident in Ac16 across the recursive call. This fixture
; PINS that IR so the regression survives front-end/optimizer drift: only the BACKEND codegen path under
; test can change it.
;
; The bug (fixed): a reentrant function holding Ac16 across a call fell through
; MOSRegisterInfo::expandLDSTStk to a byte path that COPYed A16 through an 8-bit GPR -> invalid MIR
; ("Scavenger spill ... not implemented" / "SelectImm $a16"). The fix spills Ac16 with a 16-bit indirect
; STAIndir16/LDAIndir16. (+mos-a16 is pinned in the function attributes below; the driver also passes
; -mattr=+mos-a16.)
;
; Driven by dev/a16spillir.sh (dev/run.sh a16spillir): llc must (1) compile clean under
; -verify-machineinstrs, and (2) emit a soft-stack Ac16 spill (STStk/LDStk $a16) so the path is exercised.
; Regenerate (if a16spillr.c changes) by re-emitting and re-prepending this header:
;   mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
;     -S -emit-llvm examples/65816/a16spillr.c -o examples/65816/a16spillir.ll
; Plan: docs/plans/2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md
;
; ModuleID = 'examples/65816/a16spillr.c'
source_filename = "examples/65816/a16spillr.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@in_idx = dso_local global i16 -6621, align 1
@gs0 = dso_local global i16 27519, align 1
@gb0 = dso_local global i8 48, align 1
@arr = dso_local local_unnamed_addr global [8 x i16] [i16 -7159, i16 -30628, i16 29984, i16 13399, i16 -23930, i16 4009, i16 2925, i16 3335], align 1
@corpus_result = dso_local global i16 0, align 1

; Function Attrs: nofree noreturn nounwind optsize memory(readwrite, target_mem: none)
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = tail call fastcc zeroext i16 @work(i16 noundef zeroext 3) #2
  store volatile i16 %1, ptr @corpus_result, align 1, !tbaa !6
  br label %2

2:                                                ; preds = %2, %0
  br label %2
}

; Function Attrs: nofree noinline nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define internal fastcc zeroext i16 @work(i16 noundef zeroext range(i16 0, 4) %0) unnamed_addr #1 {
  %2 = icmp eq i16 %0, 0
  br i1 %2, label %3, label %5

3:                                                ; preds = %1
  %4 = load volatile i16, ptr @gs0, align 1, !tbaa !6
  br label %31

5:                                                ; preds = %1
  %6 = load volatile i16, ptr @in_idx, align 1, !tbaa !6
  %7 = and i16 %6, 7
  %8 = getelementptr inbounds nuw [2 x i8], ptr @arr, i16 %7
  %9 = load volatile i16, ptr @gs0, align 1, !tbaa !6
  %10 = add nsw i16 %0, -1
  %11 = tail call fastcc zeroext i16 @work(i16 noundef zeroext %10) #2
  %12 = sub i16 %9, %11
  %13 = icmp ugt i16 %12, -22135
  br i1 %13, label %14, label %20

14:                                               ; preds = %5
  store i16 26151, ptr %8, align 1, !tbaa !6
  %15 = load volatile i8, ptr @gb0, align 1, !tbaa !8
  %16 = and i8 %15, 7
  %17 = zext nneg i8 %16 to i16
  %18 = getelementptr inbounds nuw [2 x i8], ptr @arr, i16 %17
  %19 = load i16, ptr %18, align 1, !tbaa !6
  br label %27

20:                                               ; preds = %5
  %21 = tail call fastcc zeroext i16 @work(i16 noundef zeroext %10) #2
  %22 = load volatile i16, ptr @gs0, align 1, !tbaa !6
  %23 = load i16, ptr %8, align 1, !tbaa !6
  %24 = xor i16 %23, %22
  %25 = icmp ugt i16 %21, %24
  %26 = zext i1 %25 to i16
  br label %27

27:                                               ; preds = %20, %14
  %28 = phi i16 [ 26151, %14 ], [ %23, %20 ]
  %29 = phi i16 [ %19, %14 ], [ %26, %20 ]
  %30 = add i16 %28, %29
  br label %31

31:                                               ; preds = %27, %3
  %32 = phi i16 [ %4, %3 ], [ %30, %27 ]
  ret i16 %32
}

attributes #0 = { nofree noreturn nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { nofree noinline nounwind optsize memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #2 = { optsize }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git c798c31416f72b395c658b5502d281a162387ab1)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"short", !4, i64 0}
!8 = !{!4, !4, i64 0}

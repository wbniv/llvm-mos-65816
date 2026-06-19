; a16unmerge.ll — hermetic crash-regression for the #321 +mos-a16 s32 legalizer gap.
;
; Frozen -Os IR of the Csmith fuzzer's seed 11 (wt/321-csmith) — the exact program that
; surfaced the bug. Under +mos-a16 main's CRC fold (low16(crc) ^ high16(crc) of a
; MATERIALIZED i32) makes the legalizer split an s32 into two s16 halves —
; "G_UNMERGE_VALUES %_(s32) -> 2x s16" — plus the trunc/ext/merge that follow. Before the
; fix those s32<->s16 artifacts were .unsupported(), so the backend aborted ("unable to
; legalize instruction: ... = G_UNMERGE_VALUES %_(s32)"). The DEFAULT 8-bit build narrows
; the same i32 through s8 bytes and never hits it.
;
; This is the ACTUAL failing IR (every hand-minimized one-liner folds to byte ops and stops
; triggering — the bug needs seed 11's i32 register pressure), frozen so the guard survives
; front-end/optimizer drift: only the backend codegen path under test can change it. Pure
; compile-time gate, no emulator; runtime correctness is covered by the Csmith differential
; sweep. Validated red-green: fails on baseline llc, clean with the fix.
; Drive: dev/run.sh a16unmerge. Plan: docs/plans/2026-06-19-321-a16-unmerge-s32-legalizer.md
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@g_16 = internal global [1 x i32] [i32 3], align 1
@g_24 = internal global i32 548736875, align 1
@g_81 = internal global [4 x i32] zeroinitializer, align 1
@g_94 = internal global i8 -5, align 1
@g_102 = internal global [3 x i8] c"\A5\A5\A5", align 1
@crc32_context = internal unnamed_addr global i32 -1, align 1
@corpus_result = dso_local global i16 0, align 1
@crc32_tab = internal unnamed_addr global [256 x i32] zeroinitializer, align 1
@g_37 = internal global ptr @g_24, align 1
@g_143 = internal global ptr @g_144, align 1
@g_144 = internal global ptr @g_94, align 1

; Function Attrs: nofree norecurse noreturn nounwind optsize memory(readwrite, target_mem: none)
define dso_local noundef i16 @main(i16 noundef %0, ptr noundef readonly captures(none) %1) local_unnamed_addr #0 {
  br label %3

3:                                                ; preds = %2, %18
  %4 = phi i16 [ %20, %18 ], [ 0, %2 ]
  %5 = zext nneg i16 %4 to i32
  br label %6

6:                                                ; preds = %14, %3
  %7 = phi i16 [ 8, %3 ], [ %16, %14 ]
  %8 = phi i32 [ %5, %3 ], [ %15, %14 ]
  %9 = and i32 %8, 1
  %10 = icmp eq i32 %9, 0
  %11 = lshr i32 %8, 1
  br i1 %10, label %14, label %12

12:                                               ; preds = %6
  %13 = xor i32 %11, -306674912
  br label %14

14:                                               ; preds = %12, %6
  %15 = phi i32 [ %13, %12 ], [ %11, %6 ]
  %16 = add nsw i16 %7, -1
  %17 = icmp samesign ugt i16 %7, 1
  br i1 %17, label %6, label %18, !llvm.loop !8

18:                                               ; preds = %14
  %19 = getelementptr inbounds nuw [4 x i8], ptr @crc32_tab, i16 %4
  store i32 %15, ptr %19, align 1, !tbaa !10
  %20 = add nuw nsw i16 %4, 1
  %21 = icmp eq i16 %20, 256
  br i1 %21, label %22, label %3, !llvm.loop !12

22:                                               ; preds = %18
  %23 = load i32, ptr @g_16, align 1, !tbaa !10
  %24 = icmp ne i32 %23, 117
  %25 = zext i1 %24 to i32
  %26 = icmp sge i32 %23, %25
  %27 = zext i1 %26 to i32
  %28 = load i32, ptr @g_24, align 1, !tbaa !10
  %29 = xor i32 %28, %27
  store i32 %29, ptr @g_24, align 1, !tbaa !10
  %30 = load volatile ptr, ptr @g_37, align 1, !tbaa !13
  %31 = load i32, ptr %30, align 1, !tbaa !10
  %32 = or i32 %31, 1
  store i32 %32, ptr %30, align 1, !tbaa !10
  store i32 1, ptr @g_16, align 1, !tbaa !10
  %33 = load volatile ptr, ptr @g_37, align 1, !tbaa !13
  %34 = load volatile ptr, ptr @g_37, align 1, !tbaa !13
  %35 = load i32, ptr %34, align 1, !tbaa !10
  store i32 %35, ptr @g_16, align 1, !tbaa !10
  %36 = load volatile ptr, ptr @g_37, align 1, !tbaa !13
  %37 = load i32, ptr %36, align 1, !tbaa !10
  %38 = icmp eq i32 %37, 0
  br i1 %38, label %39, label %43

39:                                               ; preds = %22
  %40 = load volatile ptr, ptr @g_143, align 1, !tbaa !16
  %41 = load volatile ptr, ptr @g_37, align 1, !tbaa !13
  store i32 8, ptr %41, align 1, !tbaa !10
  %42 = load i32, ptr @g_16, align 1, !tbaa !10
  br label %43

43:                                               ; preds = %39, %22
  %44 = phi i32 [ %42, %39 ], [ %35, %22 ]
  tail call fastcc void @transparent_crc(i32 noundef %44) #2
  %45 = load i32, ptr @g_24, align 1, !tbaa !10
  tail call fastcc void @transparent_crc(i32 noundef %45) #2
  br label %46

46:                                               ; preds = %43, %46
  %47 = phi i8 [ 0, %43 ], [ %54, %46 ]
  %48 = phi i16 [ 0, %43 ], [ %52, %46 ]
  %49 = zext nneg i8 %47 to i16
  %50 = getelementptr i8, ptr @g_81, i16 %49
  %51 = load volatile i32, ptr %50, align 1, !tbaa !10
  tail call fastcc void @transparent_crc(i32 noundef %51) #2
  %52 = add nuw nsw i16 %48, 1
  %53 = icmp eq i16 %52, 4
  %54 = add nuw nsw i8 %47, 4
  br i1 %53, label %55, label %46, !llvm.loop !19

55:                                               ; preds = %46
  %56 = load i8, ptr @g_94, align 1, !tbaa !20
  %57 = zext i8 %56 to i32
  tail call fastcc void @transparent_crc(i32 noundef %57) #2
  br label %58

58:                                               ; preds = %55, %58
  %59 = phi i8 [ 0, %55 ], [ %64, %58 ]
  %60 = zext nneg i8 %59 to i16
  %61 = getelementptr i8, ptr @g_102, i16 %60
  %62 = load volatile i8, ptr %61, align 1, !tbaa !20
  %63 = zext i8 %62 to i32
  tail call fastcc void @transparent_crc(i32 noundef %63) #2
  %64 = add nuw nsw i8 %59, 1
  %65 = icmp eq i8 %64, 3
  br i1 %65, label %66, label %58, !llvm.loop !21

66:                                               ; preds = %58
  tail call fastcc void @transparent_crc(i32 noundef -255869901) #2
  tail call fastcc void @transparent_crc(i32 noundef -10530) #2
  %67 = load i32, ptr @crc32_context, align 1, !tbaa !10
  %68 = xor i32 %67, -1
  %69 = lshr i32 %68, 16
  %70 = xor i32 %69, %68
  %71 = trunc i32 %70 to i16
  store volatile i16 %71, ptr @corpus_result, align 1, !tbaa !22
  br label %72

72:                                               ; preds = %72, %66
  br label %72
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @transparent_crc(i32 noundef %0) unnamed_addr #1 {
  %2 = load i32, ptr @crc32_context, align 1, !tbaa !10
  %3 = xor i32 %2, %0
  %4 = trunc i32 %3 to i16
  %5 = and i16 %4, 255
  %6 = getelementptr inbounds nuw [4 x i8], ptr @crc32_tab, i16 %5
  %7 = load i32, ptr %6, align 1, !tbaa !10
  %8 = lshr i32 %2, 16
  %9 = lshr i32 %7, 8
  %10 = xor i32 %9, %8
  %11 = lshr i32 %3, 8
  %12 = xor i32 %11, %7
  %13 = trunc i32 %12 to i16
  %14 = and i16 %13, 255
  %15 = getelementptr inbounds nuw [4 x i8], ptr @crc32_tab, i16 %14
  %16 = load i32, ptr %15, align 1, !tbaa !10
  %17 = xor i32 %10, %16
  %18 = lshr i32 %0, 16
  %19 = lshr i32 %17, 8
  %20 = xor i32 %17, %18
  %21 = trunc i32 %20 to i16
  %22 = and i16 %21, 255
  %23 = getelementptr inbounds nuw [4 x i8], ptr @crc32_tab, i16 %22
  %24 = load i32, ptr %23, align 1, !tbaa !10
  %25 = xor i32 %19, %24
  %26 = lshr i32 %0, 24
  %27 = lshr i32 %25, 8
  %28 = xor i32 %25, %26
  %29 = trunc i32 %28 to i16
  %30 = and i16 %29, 255
  %31 = getelementptr inbounds nuw [4 x i8], ptr @crc32_tab, i16 %30
  %32 = load i32, ptr %31, align 1, !tbaa !10
  %33 = xor i32 %27, %32
  store i32 %33, ptr @crc32_context, align 1, !tbaa !10
  ret void
}

attributes #0 = { nofree norecurse noreturn nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(readwrite, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #2 = { optsize }

!llvm.module.flags = !{!0, !1, !2}
!llvm.ident = !{!3}
!llvm.errno.tbaa = !{!4}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{i32 1, !"ThinLTO", i32 0}
!2 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!3 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git c798c31416f72b395c658b5502d281a162387ab1)"}
!4 = !{!5, !5, i64 0}
!5 = !{!"int", !6, i64 0}
!6 = !{!"omnipotent char", !7, i64 0}
!7 = !{!"Simple C/C++ TBAA"}
!8 = distinct !{!8, !9}
!9 = !{!"llvm.loop.mustprogress"}
!10 = !{!11, !11, i64 0}
!11 = !{!"long", !6, i64 0}
!12 = distinct !{!12, !9}
!13 = !{!14, !14, i64 0}
!14 = !{!"p1 long", !15, i64 0}
!15 = !{!"any pointer", !6, i64 0}
!16 = !{!17, !17, i64 0}
!17 = !{!"p2 omnipotent char", !18, i64 0}
!18 = !{!"any p2 pointer", !15, i64 0}
!19 = distinct !{!19, !9}
!20 = !{!6, !6, i64 0}
!21 = distinct !{!21, !9}
!22 = !{!23, !23, i64 0}
!23 = !{!"short", !6, i64 0}

^0 = module: (path: "[Regular LTO]", hash: (0, 0, 0, 0, 0))
^1 = gv: (name: "transparent_crc", summaries: (function: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), insts: 34, funcFlags: (readNone: 0, readOnly: 0, noRecurse: 1, returnDoesNotAlias: 0, noInline: 0, alwaysInline: 0, noUnwind: 1, mayThrow: 0, hasUnknownCall: 0, mustBeUnreachable: 0), refs: (^13, ^3)))) ; guid = 254283591527318490
^2 = gv: (name: "g_81", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 575327982858051706
^3 = gv: (name: "crc32_tab", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 873264002823908301
^4 = gv: (name: "g_37", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0), refs: (^9)))) ; guid = 2310042444486339581
^5 = gv: (name: "g_102", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 2970641636187360914
^6 = gv: (name: "g_144", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0), refs: (^7)))) ; guid = 5081188952063429189
^7 = gv: (name: "g_94", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 5564688034006996340
^8 = gv: (name: "g_143", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0), refs: (^6)))) ; guid = 9388096820682065746
^9 = gv: (name: "g_24", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 10644172363365225949
^10 = gv: (name: "g_16", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 12397857957709454543
^11 = gv: (name: "corpus_result", summaries: (variable: (module: ^0, flags: (linkage: external, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 15048766475834254559
^12 = gv: (name: "main", summaries: (function: (module: ^0, flags: (linkage: external, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), insts: 85, funcFlags: (readNone: 0, readOnly: 0, noRecurse: 1, returnDoesNotAlias: 0, noInline: 0, alwaysInline: 0, noUnwind: 1, mayThrow: 0, hasUnknownCall: 0, mustBeUnreachable: 0), calls: ((callee: ^1, tail: 1)), refs: (^3, ^10, ^9, ^4, ^8, ^2, ^7, ^5, ^13, ^11)))) ; guid = 15822663052811949562
^13 = gv: (name: "crc32_context", summaries: (variable: (module: ^0, flags: (linkage: internal, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 1, constant: 0)))) ; guid = 16894353333308976424
^14 = flags: 8
^15 = blockcount: 0

; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64-probe.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/inline-stage/examples/65816/bitboard64-probe.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@bitboard64_probe_result = dso_local global i16 0, align 1
@bitboard64_state.0 = internal unnamed_addr global i64 0, align 1
@bitboard64_state.1 = internal unnamed_addr global i64 0, align 1
@bitboard64_opaque = internal global i64 0, align 8

; Function Attrs: nofree norecurse nosync nounwind optsize memory(readwrite, target_mem: none)
define dso_local void @bitboard64_probe() local_unnamed_addr #0 {
  store i64 1, ptr @bitboard64_state.0, align 1, !tbaa !7
  store i64 1, ptr @bitboard64_state.1, align 1, !tbaa !10
  %1 = tail call fastcc i16 @bitboard64_step() #4
  store volatile i16 %1, ptr @bitboard64_probe_result, align 1, !tbaa !11
  ret void
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define internal fastcc i16 @bitboard64_step() unnamed_addr #1 {
  %1 = load i64, ptr @bitboard64_state.0, align 1, !tbaa !7
  %2 = lshr i64 %1, 1
  %3 = and i64 %2, 9187201950435737471
  %4 = lshr i64 %1, 2
  %5 = and i64 %4, 4557430888798830399
  %6 = shl i64 %1, 1
  %7 = and i64 %6, -72340172838076674
  %8 = shl i64 %1, 2
  %9 = and i64 %8, -217020518514230020
  %10 = or i64 %3, %7
  %11 = or i64 %5, %9
  %12 = shl i64 %10, 16
  %13 = lshr i64 %10, 16
  %14 = or i64 %12, %13
  %15 = shl i64 %11, 8
  %16 = or i64 %14, %15
  %17 = lshr i64 %11, 8
  %18 = or i64 %16, %17
  %19 = load i64, ptr @bitboard64_state.1, align 1, !tbaa !10
  %20 = xor i64 %19, -1
  %21 = and i64 %18, %20
  store volatile i64 %18, ptr @bitboard64_opaque, align 8, !tbaa !12
  %22 = load volatile i64, ptr @bitboard64_opaque, align 8, !tbaa !12
  %23 = tail call range(i64 0, 65) i64 @llvm.ctpop.i64(i64 %22)
  %24 = icmp eq i64 %21, 0
  br i1 %24, label %25, label %37

25:                                               ; preds = %0
  %26 = trunc nuw nsw i64 %23 to i8
  %27 = mul i8 %26, 7
  %28 = add i8 %27, 43
  %29 = and i8 %28, 63
  %30 = icmp eq i8 %29, 0
  br i1 %30, label %37, label %31

31:                                               ; preds = %25, %31
  %32 = phi i64 [ %35, %31 ], [ 1, %25 ]
  %33 = phi i8 [ %34, %31 ], [ %29, %25 ]
  %34 = add nsw i8 %33, -1
  %35 = shl nuw i64 %32, 1
  %36 = icmp eq i8 %34, 0
  br i1 %36, label %37, label %31, !llvm.loop !13

37:                                               ; preds = %31, %25, %0
  %38 = phi i64 [ %21, %0 ], [ 1, %25 ], [ %35, %31 ]
  %39 = phi i64 [ %19, %0 ], [ 0, %25 ], [ 0, %31 ]
  store volatile i64 %38, ptr @bitboard64_opaque, align 8, !tbaa !12
  %40 = load volatile i64, ptr @bitboard64_opaque, align 8, !tbaa !12
  %41 = tail call range(i64 0, 65) i64 @llvm.cttz.i64(i64 %40, i1 true)
  %42 = icmp eq i64 %41, 0
  br i1 %42, label %51, label %43

43:                                               ; preds = %37
  %44 = trunc nuw nsw i64 %41 to i8
  br label %45

45:                                               ; preds = %43, %45
  %46 = phi i64 [ %49, %45 ], [ 1, %43 ]
  %47 = phi i8 [ %48, %45 ], [ %44, %43 ]
  %48 = add nsw i8 %47, -1
  %49 = shl nuw i64 %46, 1
  %50 = icmp eq i8 %48, 0
  br i1 %50, label %51, label %45, !llvm.loop !13

51:                                               ; preds = %45, %37
  %52 = phi i64 [ 1, %37 ], [ %49, %45 ]
  store volatile i64 %52, ptr @bitboard64_opaque, align 8, !tbaa !12
  %53 = load volatile i64, ptr @bitboard64_opaque, align 8, !tbaa !12
  %54 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %53, i1 true)
  store i64 %52, ptr @bitboard64_state.0, align 1, !tbaa !7
  %55 = or i64 %39, %52
  store i64 %55, ptr @bitboard64_state.1, align 1, !tbaa !10
  %56 = trunc nuw nsw i64 %41 to i16
  %57 = trunc nuw nsw i64 %23 to i16
  %58 = shl nuw nsw i16 %57, 8
  %59 = or disjoint i16 %58, %56
  %60 = xor i16 %59, 16738
  %61 = trunc nuw nsw i64 %54 to i16
  %62 = add nuw nsw i16 %60, %61
  %63 = trunc i64 %55 to i16
  %64 = add i16 %62, %63
  %65 = lshr i64 %55, 32
  %66 = trunc i64 %65 to i16
  %67 = add i16 %64, %66
  ret i16 %67
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctpop.i64(i64) #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.cttz.i64(i64, i1 immarg) #3

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctlz.i64(i64, i1 immarg) #3

attributes #0 = { nofree norecurse nosync nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { nofree noinline norecurse nosync nounwind optsize memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #2 = { mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { optsize }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (/home/will/llvm-mos 742d554bf08042b8df93d791c335260fadd16643)"}
!2 = !{!3, !4, i64 0}
!3 = !{!"__libc_errno", !4, i64 0}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!8, !9, i64 0}
!8 = !{!"", !9, i64 0, !9, i64 8, !9, i64 16, !5, i64 24, !5, i64 25, !5, i64 26}
!9 = !{!"long long", !5, i64 0}
!10 = !{!8, !9, i64 8}
!11 = !{!4, !4, i64 0}
!12 = !{!9, !9, i64 0}
!13 = distinct !{!13, !14}
!14 = !{!"llvm.loop.mustprogress"}

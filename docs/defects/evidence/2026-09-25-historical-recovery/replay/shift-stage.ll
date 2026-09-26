; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/shift-stage/examples/65816/bitboard64-probe.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-historical-recovery/shift-stage/examples/65816/bitboard64-probe.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@bitboard64_probe_result = dso_local global i16 0, align 1
@bitboard64_state.0 = internal unnamed_addr global i64 0, align 1
@bitboard64_state.1 = internal unnamed_addr global i64 0, align 1
@bitboard64_opaque = internal global i64 0, align 8

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define dso_local void @bitboard64_probe() local_unnamed_addr #0 {
  store i64 1, ptr @bitboard64_state.0, align 1, !tbaa !6
  store i64 1, ptr @bitboard64_state.1, align 1, !tbaa !9
  %1 = tail call fastcc i16 @bitboard64_step() #4
  store volatile i16 %1, ptr @bitboard64_probe_result, align 1, !tbaa !2
  ret void
}

; Function Attrs: nofree noinline norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define internal fastcc i16 @bitboard64_step() unnamed_addr #1 {
  %1 = load i64, ptr @bitboard64_state.0, align 1, !tbaa !6
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
  %19 = load i64, ptr @bitboard64_state.1, align 1, !tbaa !9
  %20 = xor i64 %19, -1
  %21 = and i64 %18, %20
  store volatile i64 %18, ptr @bitboard64_opaque, align 8, !tbaa !10
  %22 = load volatile i64, ptr @bitboard64_opaque, align 8, !tbaa !10
  %23 = tail call range(i64 0, 65) i64 @llvm.ctpop.i64(i64 %22)
  %24 = icmp eq i64 %21, 0
  br i1 %24, label %25, label %32

25:                                               ; preds = %0
  %26 = trunc nuw nsw i64 %23 to i8
  %27 = mul i8 %26, 7
  %28 = add i8 %27, 43
  %29 = and i8 %28, 63
  %30 = zext nneg i8 %29 to i64
  %31 = shl nuw i64 1, %30
  br label %32

32:                                               ; preds = %0, %25
  %33 = phi i64 [ %31, %25 ], [ %21, %0 ]
  %34 = phi i64 [ 0, %25 ], [ %19, %0 ]
  store volatile i64 %33, ptr @bitboard64_opaque, align 8, !tbaa !10
  %35 = load volatile i64, ptr @bitboard64_opaque, align 8, !tbaa !10
  %36 = tail call range(i64 0, 65) i64 @llvm.cttz.i64(i64 %35, i1 true)
  %37 = trunc nuw nsw i64 %36 to i16
  %38 = shl nuw i64 1, %36
  store volatile i64 %38, ptr @bitboard64_opaque, align 8, !tbaa !10
  %39 = load volatile i64, ptr @bitboard64_opaque, align 8, !tbaa !10
  %40 = tail call range(i64 0, 65) i64 @llvm.ctlz.i64(i64 %39, i1 true)
  store i64 %38, ptr @bitboard64_state.0, align 1, !tbaa !6
  %41 = or i64 %34, %38
  store i64 %41, ptr @bitboard64_state.1, align 1, !tbaa !9
  %42 = trunc nuw nsw i64 %23 to i16
  %43 = shl nuw nsw i16 %42, 8
  %44 = or disjoint i16 %43, %37
  %45 = xor i16 %44, 16738
  %46 = trunc nuw nsw i64 %40 to i16
  %47 = add nuw nsw i16 %45, %46
  %48 = trunc i64 %41 to i16
  %49 = add i16 %47, %48
  %50 = lshr i64 %41, 32
  %51 = trunc i64 %50 to i16
  %52 = add i16 %49, %51
  ret i16 %52
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctpop.i64(i64) #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.cttz.i64(i64, i1 immarg) #3

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctlz.i64(i64, i1 immarg) #3

attributes #0 = { nofree norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { nofree noinline norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #2 = { mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { optsize }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !8, i64 0}
!7 = !{!"", !8, i64 0, !8, i64 8, !8, i64 16, !4, i64 24, !4, i64 25, !4, i64 26}
!8 = !{!"long long", !4, i64 0}
!9 = !{!7, !8, i64 8}
!10 = !{!8, !8, i64 0}

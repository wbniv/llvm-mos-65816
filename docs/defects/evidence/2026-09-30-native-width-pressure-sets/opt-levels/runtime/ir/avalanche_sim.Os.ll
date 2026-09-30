; ModuleID = '/work/examples/snes/corpus/avalanche_sim.c'
source_filename = "/work/examples/snes/corpus/avalanche_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i64 [ 81985529216486895, %0 ], [ %15, %1 ]
  %3 = phi i64 [ -1, %0 ], [ %21, %1 ]
  %4 = phi i16 [ 0, %0 ], [ %22, %1 ]
  %5 = add i64 %2, -7046029254386353131
  %6 = lshr i64 %5, 30
  %7 = xor i64 %6, %5
  %8 = mul i64 %7, -4658895280553007687
  %9 = lshr i64 %8, 27
  %10 = xor i64 %9, %8
  %11 = mul i64 %10, -7723592293110705685
  %12 = lshr i64 %11, 31
  %13 = xor i64 %12, %11
  %14 = lshr i64 %13, 32
  %15 = xor i64 %14, %13
  %16 = xor i64 %15, %3
  %17 = lshr i64 %15, 17
  %18 = add i64 %16, %17
  %19 = or i64 %15, 1
  %20 = udiv i64 %18, %19
  %21 = xor i64 %18, %20
  %22 = add nuw nsw i16 %4, 1
  %23 = icmp eq i16 %22, 256
  br i1 %23, label %24, label %1, !llvm.loop !6

24:                                               ; preds = %1, %24
  %25 = phi i8 [ %33, %24 ], [ 0, %1 ]
  %26 = phi i16 [ %32, %24 ], [ 0, %1 ]
  %27 = shl nuw nsw i8 %25, 4
  %28 = zext nneg i8 %27 to i64
  %29 = lshr i64 %21, %28
  %30 = trunc i64 %29 to i16
  %31 = tail call i16 @llvm.fshl.i16(i16 %26, i16 %26, i16 1)
  %32 = xor i16 %31, %30
  %33 = add nuw nsw i8 %25, 1
  %34 = icmp eq i8 %33, 4
  br i1 %34, label %35, label %24, !llvm.loop !8

35:                                               ; preds = %24
  store volatile i16 %32, ptr @corpus_result, align 1, !tbaa !2
  br label %36

36:                                               ; preds = %36, %35
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %36
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = distinct !{!8, !7}
!9 = !{i64 874}

; ModuleID = '/work/examples/snes/corpus/avalanche_sim.c'
source_filename = "/work/examples/snes/corpus/avalanche_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %6, %0
  %2 = phi i16 [ 0, %0 ], [ %24, %6 ]
  %3 = phi i64 [ -1, %0 ], [ %23, %6 ]
  %4 = phi i64 [ 81985529216486895, %0 ], [ %17, %6 ]
  %5 = icmp eq i16 %2, 256
  br i1 %5, label %25, label %6

6:                                                ; preds = %1
  %7 = add i64 %4, -7046029254386353131
  %8 = lshr i64 %7, 30
  %9 = xor i64 %8, %7
  %10 = mul i64 %9, -4658895280553007687
  %11 = lshr i64 %10, 27
  %12 = xor i64 %11, %10
  %13 = mul i64 %12, -7723592293110705685
  %14 = lshr i64 %13, 31
  %15 = xor i64 %14, %13
  %16 = lshr i64 %15, 32
  %17 = xor i64 %16, %15
  %18 = xor i64 %17, %3
  %19 = lshr i64 %17, 17
  %20 = add i64 %18, %19
  %21 = or i64 %17, 1
  %22 = udiv i64 %20, %21
  %23 = xor i64 %22, %20
  %24 = add nuw nsw i16 %2, 1
  br label %1, !llvm.loop !6

25:                                               ; preds = %1, %29
  %26 = phi i16 [ %35, %29 ], [ 0, %1 ]
  %27 = phi i8 [ %36, %29 ], [ 0, %1 ]
  %28 = icmp eq i8 %27, 4
  br i1 %28, label %37, label %29

29:                                               ; preds = %25
  %30 = shl nuw nsw i8 %27, 4
  %31 = zext nneg i8 %30 to i64
  %32 = lshr i64 %3, %31
  %33 = trunc i64 %32 to i16
  %34 = tail call i16 @llvm.fshl.i16(i16 %26, i16 %26, i16 1)
  %35 = xor i16 %34, %33
  %36 = add nuw nsw i8 %27, 1
  br label %25, !llvm.loop !8

37:                                               ; preds = %25
  store volatile i16 %26, ptr @corpus_result, align 1, !tbaa !2
  br label %38

38:                                               ; preds = %38, %37
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %38
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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

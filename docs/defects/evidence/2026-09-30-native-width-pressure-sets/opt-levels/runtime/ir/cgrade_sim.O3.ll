; ModuleID = '/work/examples/snes/corpus/cgrade_sim.c'
source_filename = "/work/examples/snes/corpus/cgrade_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i16 [ 0, %0 ], [ %25, %1 ]
  %3 = phi i16 [ 0, %0 ], [ %26, %1 ]
  %4 = mul nuw nsw i16 %3, 3
  %5 = add nuw nsw i16 %4, 7
  %6 = add nsw i16 %3, -40
  %7 = shl nuw nsw i16 %3, 1
  %8 = add nsw i16 %7, -30
  %9 = sub nsw i16 50, %3
  %10 = and i16 %3, 15
  %11 = lshr i16 %3, 1
  %12 = and i16 %11, 31
  %13 = trunc nuw i16 %3 to i8
  %14 = urem i8 %13, 7
  %15 = zext nneg i8 %14 to i16
  %16 = and i16 %3, 3
  %17 = add nuw nsw i16 %16, 2
  %18 = and i16 %3, 7
  %19 = add nsw i16 %18, -3
  %20 = urem i8 %13, 5
  %21 = add nuw nsw i8 %20, 1
  %22 = zext nneg i8 %21 to i16
  %23 = tail call fastcc i16 @color_grade(i16 noundef %5, i16 noundef %6, i16 noundef %8, i16 noundef %9, i16 noundef %10, i16 noundef %12, i16 noundef %15, i16 noundef %17, i16 noundef %19, i16 noundef %22)
  %24 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %25 = xor i16 %23, %24
  %26 = add nuw nsw i16 %3, 1
  %27 = icmp eq i16 %26, 100
  br i1 %27, label %28, label %1, !llvm.loop !6

28:                                               ; preds = %1
  store volatile i16 %25, ptr @corpus_result, align 1, !tbaa !2
  br label %29

29:                                               ; preds = %29, %28
  tail call void asm sideeffect "wai", ""() #3, !srcloc !8
  br label %29
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define internal fastcc range(i16 -19, 230) i16 @color_grade(i16 noundef range(i16 7, 305) %0, i16 noundef range(i16 -40, 60) %1, i16 noundef range(i16 -30, 169) %2, i16 noundef range(i16 -49, 51) %3, i16 noundef range(i16 0, 16) %4, i16 noundef range(i16 0, 32) %5, i16 noundef range(i16 0, 7) %6, i16 noundef range(i16 2, 6) %7, i16 noundef range(i16 -3, 5) %8, i16 noundef range(i16 1, 6) %9) unnamed_addr #1 {
  %11 = mul nuw nsw i16 %7, %0
  %12 = zext nneg i16 %11 to i32
  %13 = sext i16 %3 to i32
  %14 = zext nneg i16 %4 to i32
  %15 = zext nneg i16 %5 to i32
  %16 = zext nneg i16 %6 to i32
  %17 = sext i16 %8 to i32
  %18 = zext nneg i16 %9 to i32
  %19 = mul nsw i32 %18, %17
  %20 = add nsw i16 %2, %1
  %21 = sext i16 %20 to i32
  %22 = add nsw i32 %21, %13
  %23 = add nsw i32 %22, %14
  %24 = sub nsw i32 %23, %15
  %25 = add nsw i32 %24, %16
  %26 = add nsw i32 %25, %12
  %27 = add nsw i32 %26, %19
  %28 = lshr i32 %27, 3
  %29 = trunc i32 %28 to i16
  ret i16 %29
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nounwind }

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
!8 = !{i64 413}

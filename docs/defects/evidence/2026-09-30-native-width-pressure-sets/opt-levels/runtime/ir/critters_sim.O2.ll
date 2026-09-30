; ModuleID = '/work/examples/snes/corpus/critters_sim.c'
source_filename = "/work/examples/snes/corpus/critters_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Critter = type { i8, i16, i16, i16, i16, i8, i8 }

@corpus_result = dso_local global i16 0, align 1
@critters_gate_crc.cr = internal global [24 x %struct.Critter] zeroinitializer, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i8 [ 0, %0 ], [ %30, %1 ]
  %3 = phi i8 [ 0, %0 ], [ %28, %1 ]
  %4 = zext nneg i8 %3 to i16
  %5 = zext i8 %2 to i16
  %6 = getelementptr i8, ptr @critters_gate_crc.cr, i16 %5
  store i8 0, ptr %6, align 1, !tbaa !6
  %7 = urem i8 %3, 6
  %8 = mul nuw nsw i8 %7, 18
  %9 = add nuw nsw i8 %8, 8
  %10 = zext nneg i8 %9 to i16
  %11 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 1), i16 %5
  store i16 %10, ptr %11, align 1, !tbaa !8
  %12 = udiv i8 %3, 6
  %13 = mul nuw i8 %12, 26
  %14 = zext i8 %13 to i16
  %15 = add nuw nsw i16 %14, 8
  %16 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 3), i16 %5
  store i16 %15, ptr %16, align 1, !tbaa !9
  %17 = and i16 %4, 1
  %18 = add nuw nsw i16 %17, 1
  %19 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 5), i16 %5
  store i16 %18, ptr %19, align 1, !tbaa !10
  %20 = lshr i16 %4, 1
  %21 = and i16 %20, 1
  %22 = add nuw nsw i16 %21, 1
  %23 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 7), i16 %5
  store i16 %22, ptr %23, align 1, !tbaa !11
  %24 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 9), i16 %5
  store i8 0, ptr %24, align 1, !tbaa !12
  %25 = urem i8 %3, 3
  %26 = add nuw nsw i8 %25, 1
  %27 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 10), i16 %5
  store i8 %26, ptr %27, align 1, !tbaa !13
  %28 = add nuw nsw i8 %3, 1
  %29 = icmp eq i8 %28, 24
  %30 = add i8 %2, 11
  br i1 %29, label %31, label %1, !llvm.loop !14

31:                                               ; preds = %1, %34
  %32 = phi i16 [ %35, %34 ], [ 0, %1 ]
  %33 = phi i16 [ %53, %34 ], [ 0, %1 ]
  br label %37

34:                                               ; preds = %37
  %35 = add nuw nsw i16 %32, 1
  %36 = icmp eq i16 %35, 120
  br i1 %36, label %57, label %31, !llvm.loop !16

37:                                               ; preds = %37, %31
  %38 = phi i8 [ 0, %31 ], [ %56, %37 ]
  %39 = phi i8 [ 0, %31 ], [ %54, %37 ]
  %40 = phi i16 [ %33, %31 ], [ %53, %37 ]
  %41 = zext i8 %38 to i16
  %42 = getelementptr i8, ptr @critters_gate_crc.cr, i16 %41
  tail call fastcc void @critter_step(ptr noundef nonnull %42)
  %43 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 1), i16 %41
  %44 = load i16, ptr %43, align 1, !tbaa !8
  %45 = mul i16 %44, 3
  %46 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @critters_gate_crc.cr, i16 3), i16 %41
  %47 = load i16, ptr %46, align 1, !tbaa !9
  %48 = add i16 %45, %47
  %49 = load i8, ptr %42, align 1, !tbaa !6
  %50 = zext i8 %49 to i16
  %51 = add i16 %48, %50
  %52 = tail call i16 @llvm.fshl.i16(i16 %40, i16 %40, i16 1)
  %53 = xor i16 %51, %52
  %54 = add nuw nsw i8 %39, 1
  %55 = icmp eq i8 %54, 24
  %56 = add i8 %38, 11
  br i1 %55, label %34, label %37, !llvm.loop !17

57:                                               ; preds = %34
  store volatile i16 %53, ptr @corpus_result, align 1, !tbaa !2
  br label %58

58:                                               ; preds = %58, %57
  tail call void asm sideeffect "wai", ""() #3, !srcloc !18
  br label %58
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(argmem: readwrite)
define internal fastcc void @critter_step(ptr noundef captures(none) %0) unnamed_addr #1 {
  %2 = load i8, ptr %0, align 1, !tbaa !6
  switch i8 %2, label %34 [
    i8 0, label %20
    i8 1, label %3
    i8 2, label %8
  ]

3:                                                ; preds = %1
  %4 = getelementptr inbounds nuw i8, ptr %0, i16 9
  %5 = load i8, ptr %4, align 1, !tbaa !12
  %6 = add i8 %5, 1
  store i8 %6, ptr %4, align 1, !tbaa !12
  %7 = icmp ult i8 %6, 12
  br i1 %7, label %25, label %20

8:                                                ; preds = %1
  %9 = getelementptr inbounds nuw i8, ptr %0, i16 9
  %10 = load i8, ptr %9, align 1, !tbaa !12
  %11 = add i8 %10, 1
  store i8 %11, ptr %9, align 1, !tbaa !12
  %12 = icmp ult i8 %11, 12
  br i1 %12, label %25, label %13

13:                                               ; preds = %8
  %14 = getelementptr inbounds nuw i8, ptr %0, i16 5
  %15 = load i16, ptr %14, align 1, !tbaa !10
  %16 = sub nsw i16 0, %15
  store i16 %16, ptr %14, align 1, !tbaa !10
  %17 = getelementptr inbounds nuw i8, ptr %0, i16 7
  %18 = load i16, ptr %17, align 1, !tbaa !11
  %19 = sub nsw i16 0, %18
  store i16 %19, ptr %17, align 1, !tbaa !11
  br label %20

20:                                               ; preds = %3, %1, %13
  %21 = phi i16 [ 1, %1 ], [ 1, %13 ], [ 3, %3 ]
  %22 = phi i16 [ 5, %1 ], [ 5, %13 ], [ 7, %3 ]
  %23 = phi i8 [ 1, %1 ], [ 1, %13 ], [ 2, %3 ]
  %24 = getelementptr inbounds nuw i8, ptr %0, i16 9
  store i8 0, ptr %24, align 1, !tbaa !12
  br label %25

25:                                               ; preds = %20, %8, %3
  %26 = phi i16 [ 1, %3 ], [ 3, %8 ], [ %21, %20 ]
  %27 = phi i16 [ 5, %3 ], [ 7, %8 ], [ %22, %20 ]
  %28 = phi i8 [ 1, %3 ], [ 2, %8 ], [ %23, %20 ]
  %29 = getelementptr inbounds nuw i8, ptr %0, i16 %26
  %30 = load i16, ptr %29, align 1, !tbaa !2
  %31 = getelementptr inbounds nuw i8, ptr %0, i16 %27
  %32 = load i16, ptr %31, align 1, !tbaa !2
  %33 = add nsw i16 %32, %30
  store i16 %33, ptr %29, align 1, !tbaa !2
  store i8 %28, ptr %0, align 1, !tbaa !6
  br label %34

34:                                               ; preds = %25, %1
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!6 = !{!7, !4, i64 0}
!7 = !{!"", !4, i64 0, !3, i64 1, !3, i64 3, !3, i64 5, !3, i64 7, !4, i64 9, !4, i64 10}
!8 = !{!7, !3, i64 1}
!9 = !{!7, !3, i64 3}
!10 = !{!7, !3, i64 5}
!11 = !{!7, !3, i64 7}
!12 = !{!7, !4, i64 9}
!13 = !{!7, !4, i64 10}
!14 = distinct !{!14, !15}
!15 = !{!"llvm.loop.mustprogress"}
!16 = distinct !{!16, !15}
!17 = distinct !{!17, !15}
!18 = !{i64 411}

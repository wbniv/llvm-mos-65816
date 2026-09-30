; ModuleID = '/work/examples/snes/corpus/critters_sim.c'
source_filename = "/work/examples/snes/corpus/critters_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Critter = type { i8, i16, i16, i16, i16, i8, i8 }

@corpus_result = dso_local global i16 0, align 1
@critters_gate_crc.cr = internal global [24 x %struct.Critter] zeroinitializer, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %4, %0
  %2 = phi i8 [ 0, %0 ], [ %28, %4 ]
  %3 = icmp eq i8 %2, 24
  br i1 %3, label %29, label %4

4:                                                ; preds = %1
  %5 = zext nneg i8 %2 to i16
  %6 = getelementptr inbounds nuw [11 x i8], ptr @critters_gate_crc.cr, i16 %5
  store i8 0, ptr %6, align 1, !tbaa !6
  %7 = urem i8 %2, 6
  %8 = mul nuw nsw i8 %7, 18
  %9 = add nuw nsw i8 %8, 8
  %10 = zext nneg i8 %9 to i16
  %11 = getelementptr inbounds nuw i8, ptr %6, i16 1
  store i16 %10, ptr %11, align 1, !tbaa !8
  %12 = udiv i8 %2, 6
  %13 = mul nuw i8 %12, 26
  %14 = zext i8 %13 to i16
  %15 = add nuw nsw i16 %14, 8
  %16 = getelementptr inbounds nuw i8, ptr %6, i16 3
  store i16 %15, ptr %16, align 1, !tbaa !9
  %17 = and i16 %5, 1
  %18 = add nuw nsw i16 %17, 1
  %19 = getelementptr inbounds nuw i8, ptr %6, i16 5
  store i16 %18, ptr %19, align 1, !tbaa !10
  %20 = lshr i16 %5, 1
  %21 = and i16 %20, 1
  %22 = add nuw nsw i16 %21, 1
  %23 = getelementptr inbounds nuw i8, ptr %6, i16 7
  store i16 %22, ptr %23, align 1, !tbaa !11
  %24 = getelementptr inbounds nuw i8, ptr %6, i16 9
  store i8 0, ptr %24, align 1, !tbaa !12
  %25 = urem i8 %2, 3
  %26 = add nuw nsw i8 %25, 1
  %27 = getelementptr inbounds nuw i8, ptr %6, i16 10
  store i8 %26, ptr %27, align 1, !tbaa !13
  %28 = add nuw nsw i8 %2, 1
  br label %1, !llvm.loop !14

29:                                               ; preds = %1, %37
  %30 = phi i16 [ %34, %37 ], [ 0, %1 ]
  %31 = phi i16 [ %38, %37 ], [ 0, %1 ]
  %32 = icmp eq i16 %31, 120
  br i1 %32, label %54, label %33

33:                                               ; preds = %29, %39
  %34 = phi i16 [ %52, %39 ], [ %30, %29 ]
  %35 = phi i8 [ %53, %39 ], [ 0, %29 ]
  %36 = icmp eq i8 %35, 24
  br i1 %36, label %37, label %39

37:                                               ; preds = %33
  %38 = add nuw nsw i16 %31, 1
  br label %29, !llvm.loop !16

39:                                               ; preds = %33
  %40 = zext nneg i8 %35 to i16
  %41 = getelementptr inbounds nuw [11 x i8], ptr @critters_gate_crc.cr, i16 %40
  tail call fastcc void @critter_step(ptr noundef nonnull %41) #3
  %42 = getelementptr inbounds nuw i8, ptr %41, i16 1
  %43 = load i16, ptr %42, align 1, !tbaa !8
  %44 = mul i16 %43, 3
  %45 = getelementptr inbounds nuw i8, ptr %41, i16 3
  %46 = load i16, ptr %45, align 1, !tbaa !9
  %47 = add i16 %44, %46
  %48 = load i8, ptr %41, align 1, !tbaa !6
  %49 = zext i8 %48 to i16
  %50 = add i16 %47, %49
  %51 = tail call i16 @llvm.fshl.i16(i16 %34, i16 %34, i16 1)
  %52 = xor i16 %50, %51
  %53 = add nuw nsw i8 %35, 1
  br label %33, !llvm.loop !17

54:                                               ; preds = %29
  store volatile i16 %30, ptr @corpus_result, align 1, !tbaa !2
  br label %55

55:                                               ; preds = %55, %54
  tail call void asm sideeffect "wai", ""() #4, !srcloc !18
  br label %55
}

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(argmem: readwrite)
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

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { minsize optsize }
attributes #4 = { nounwind }

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

; ModuleID = 'docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c'
source_filename = "docs/defects/evidence/2026-09-28-vlastack-xy16-stale-reload/input/examples/snes/corpus/vlastack_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@vs_totalruns = internal unnamed_addr global i16 0, align 1
@vs_nruns = internal unnamed_addr global [24 x i8] zeroinitializer, align 1
@vs_pfxsum = internal unnamed_addr global [24 x i16] zeroinitializer, align 1
@vs_img = internal unnamed_addr global [24 x [64 x i8]] zeroinitializer, align 1
@vs_rowoff = internal unnamed_addr global [24 x i16] zeroinitializer, align 1
@vs_rle = internal unnamed_addr global [792 x i8] zeroinitializer, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  tail call fastcc void @vs_build() #6
  tail call fastcc void @vs_decode() #6
  %1 = load i16, ptr @vs_totalruns, align 1, !tbaa !2
  %2 = xor i16 %1, 19755
  %3 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %4 = mul i16 %3, 25173
  %5 = add i16 %4, 13849
  br label %6

6:                                                ; preds = %26, %0
  %7 = phi i8 [ 0, %0 ], [ %30, %26 ]
  %8 = phi ptr [ @vs_img, %0 ], [ %28, %26 ]
  %9 = phi i8 [ 0, %0 ], [ %27, %26 ]
  %10 = phi i16 [ %5, %0 ], [ %42, %26 ]
  %11 = zext nneg i8 %9 to i16
  %12 = getelementptr i8, ptr @vs_nruns, i16 %11
  %13 = load i8, ptr %12, align 1, !tbaa !6
  %14 = zext i8 %13 to i16
  %15 = xor i16 %10, %14
  %16 = tail call i16 @llvm.fshl.i16(i16 %15, i16 %15, i16 1)
  %17 = mul i16 %16, 25173
  %18 = add i16 %17, 13849
  %19 = zext nneg i8 %7 to i16
  %20 = getelementptr i8, ptr @vs_pfxsum, i16 %19
  %21 = load i16, ptr %20, align 1, !tbaa !2
  %22 = xor i16 %18, %21
  %23 = tail call i16 @llvm.fshl.i16(i16 %22, i16 %22, i16 1)
  %24 = mul i16 %23, 25173
  %25 = add i16 %24, 13849
  br label %31

26:                                               ; preds = %31
  %27 = add nuw nsw i8 %9, 1
  %28 = getelementptr i8, ptr %8, i16 64
  %29 = icmp eq i8 %27, 24
  %30 = add nuw nsw i8 %7, 2
  br i1 %29, label %44, label %6, !llvm.loop !7

31:                                               ; preds = %31, %6
  %32 = phi i16 [ %25, %6 ], [ %42, %31 ]
  %33 = phi i8 [ 0, %6 ], [ %40, %31 ]
  %34 = zext nneg i8 %33 to i16
  %35 = getelementptr i8, ptr %8, i16 %34
  %36 = load i8, ptr %35, align 1, !tbaa !6
  %37 = zext i8 %36 to i16
  %38 = xor i16 %32, %37
  %39 = tail call i16 @llvm.fshl.i16(i16 %38, i16 %38, i16 1)
  %40 = add nuw nsw i8 %33, 1
  %41 = mul i16 %39, 25173
  %42 = add i16 %41, 13849
  %43 = icmp eq i8 %40, 64
  br i1 %43, label %26, label %31, !llvm.loop !9

44:                                               ; preds = %26
  store volatile i16 %42, ptr @corpus_result, align 1, !tbaa !2
  br label %45

45:                                               ; preds = %45, %44
  tail call void asm sideeffect "wai", ""() #7, !srcloc !10
  br label %45
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(write, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc void @vs_build() unnamed_addr #1 {
  br label %2

1:                                                ; preds = %50
  store i16 %54, ptr @vs_totalruns, align 1, !tbaa !2
  ret void

2:                                                ; preds = %0, %50
  %3 = phi i8 [ 0, %0 ], [ %57, %50 ]
  %4 = phi i16 [ 12059, %0 ], [ %19, %50 ]
  %5 = phi i16 [ 0, %0 ], [ %51, %50 ]
  %6 = phi i8 [ 0, %0 ], [ %55, %50 ]
  %7 = phi i16 [ 0, %0 ], [ %54, %50 ]
  %8 = zext nneg i8 %3 to i16
  %9 = getelementptr i8, ptr @vs_rowoff, i16 %8
  store i16 %5, ptr %9, align 1, !tbaa !2
  %10 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @vs_rle, i16 1), i16 %5
  %11 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @vs_rle, i16 2), i16 %5
  br label %12

12:                                               ; preds = %2, %31
  %13 = phi i8 [ 0, %2 ], [ %49, %31 ]
  %14 = phi i16 [ %4, %2 ], [ %19, %31 ]
  %15 = phi i16 [ 0, %2 ], [ %32, %31 ]
  %16 = phi i8 [ 0, %2 ], [ %45, %31 ]
  %17 = phi i16 [ %5, %2 ], [ %41, %31 ]
  %18 = mul i16 %14, 25173
  %19 = add i16 %18, 13849
  %20 = icmp eq i8 %16, 15
  br i1 %20, label %28, label %21

21:                                               ; preds = %12
  %22 = lshr i16 %19, 9
  %23 = and i16 %22, 7
  %24 = add nuw nsw i16 %23, 2
  %25 = add nuw nsw i16 %24, %15
  %26 = icmp samesign ugt i16 %25, 64
  %27 = trunc nuw nsw i16 %24 to i8
  br i1 %26, label %28, label %31

28:                                               ; preds = %21, %12
  %29 = trunc nuw nsw i16 %15 to i8
  %30 = sub nuw nsw i8 64, %29
  br label %31

31:                                               ; preds = %28, %21
  %32 = phi i16 [ 64, %28 ], [ %25, %21 ]
  %33 = phi i8 [ %30, %28 ], [ %27, %21 ]
  %34 = trunc i16 %19 to i8
  %35 = lshr i8 %34, 5
  %36 = and i8 %35, 3
  %37 = add nuw nsw i8 %16, %6
  %38 = shl nuw i8 %37, 2
  %39 = and i8 %38, 12
  %40 = or disjoint i8 %36, %39
  %41 = add i16 %17, 2
  %42 = zext nneg i8 %13 to i16
  %43 = getelementptr i8, ptr %10, i16 %42
  store i8 %33, ptr %43, align 1, !tbaa !6
  %44 = getelementptr i8, ptr %11, i16 %42
  store i8 %40, ptr %44, align 1, !tbaa !6
  %45 = add nuw nsw i8 %16, 1
  %46 = icmp samesign ult i16 %32, 64
  %47 = icmp samesign ult i8 %16, 15
  %48 = select i1 %46, i1 %47, i1 false
  %49 = add nuw nsw i8 %13, 2
  br i1 %48, label %12, label %50, !llvm.loop !11

50:                                               ; preds = %31
  %51 = add i16 %17, 3
  %52 = getelementptr inbounds nuw i8, ptr @vs_rle, i16 %5
  store i8 %45, ptr %52, align 1, !tbaa !6
  %53 = zext nneg i8 %45 to i16
  %54 = add i16 %7, %53
  %55 = add nuw nsw i8 %6, 1
  %56 = icmp eq i8 %55, 24
  %57 = add nuw nsw i8 %3, 2
  br i1 %56, label %1, label %2, !llvm.loop !12
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize
define internal fastcc void @vs_decode() unnamed_addr #2 {
  br label %2

1:                                                ; preds = %59
  ret void

2:                                                ; preds = %0, %59
  %3 = phi i8 [ 0, %0 ], [ %64, %59 ]
  %4 = phi i8 [ 0, %0 ], [ %62, %59 ]
  %5 = zext nneg i8 %4 to i16
  %6 = shl nuw nsw i16 %5, 6
  %7 = getelementptr i8, ptr @vs_img, i16 %6
  %8 = zext nneg i8 %3 to i16
  %9 = getelementptr i8, ptr @vs_rowoff, i16 %8
  %10 = load i16, ptr %9, align 1, !tbaa !2
  %11 = getelementptr inbounds nuw i8, ptr @vs_rle, i16 %10
  %12 = load i8, ptr %11, align 1, !tbaa !6
  %13 = getelementptr i8, ptr @vs_nruns, i16 %5
  store i8 %12, ptr %13, align 1, !tbaa !6
  %14 = zext i8 %12 to i16
  %15 = tail call ptr @llvm.stacksave.p0()
  %16 = alloca i16, i16 %14, align 1
  %17 = icmp eq i8 %12, 0
  br i1 %17, label %18, label %19

18:                                               ; preds = %2
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(64) %7, i8 0, i16 64, i1 false), !tbaa !6
  br label %59

19:                                               ; preds = %2
  %20 = getelementptr i8, ptr %11, i16 1
  br label %23

21:                                               ; preds = %23
  %22 = getelementptr i8, ptr %11, i16 2
  br label %37

23:                                               ; preds = %19, %23
  %24 = phi i8 [ 0, %19 ], [ %33, %23 ]
  %25 = phi i16 [ 0, %19 ], [ %31, %23 ]
  %26 = zext i8 %24 to i16
  %27 = shl nuw nsw i16 %26, 1
  %28 = getelementptr i8, ptr %20, i16 %27
  %29 = load i8, ptr %28, align 1, !tbaa !6
  %30 = zext i8 %29 to i16
  %31 = add i16 %25, %30
  %32 = getelementptr inbounds nuw [2 x i8], ptr %16, i16 %26
  store i16 %31, ptr %32, align 1, !tbaa !2
  %33 = add nuw i8 %24, 1
  %34 = icmp eq i8 %33, %12
  br i1 %34, label %21, label %23, !llvm.loop !13

35:                                               ; preds = %51
  %36 = icmp samesign ult i16 %52, 64
  br i1 %36, label %55, label %58

37:                                               ; preds = %21, %51
  %38 = phi i8 [ 0, %21 ], [ %53, %51 ]
  %39 = phi i16 [ 0, %21 ], [ %52, %51 ]
  %40 = zext i8 %38 to i16
  %41 = getelementptr inbounds nuw [2 x i8], ptr %16, i16 %40
  %42 = load i16, ptr %41, align 1, !tbaa !2
  %43 = tail call i16 @llvm.umin.i16(i16 %42, i16 64)
  %44 = icmp samesign ult i16 %39, %43
  br i1 %44, label %45, label %51

45:                                               ; preds = %37
  %46 = shl nuw nsw i16 %40, 1
  %47 = getelementptr i8, ptr %22, i16 %46
  %48 = load i8, ptr %47, align 1, !tbaa !6
  %49 = getelementptr i8, ptr %7, i16 %39
  %50 = sub nuw nsw i16 %43, %39
  tail call void @llvm.memset.p0.i16(ptr align 1 %49, i8 %48, i16 %50, i1 false), !tbaa !6
  br label %51

51:                                               ; preds = %45, %37
  %52 = phi i16 [ %39, %37 ], [ %43, %45 ]
  %53 = add nuw i8 %38, 1
  %54 = icmp eq i8 %53, %12
  br i1 %54, label %35, label %37, !llvm.loop !14

55:                                               ; preds = %35
  %56 = getelementptr i8, ptr %7, i16 %52
  %57 = sub nuw nsw i16 64, %52
  tail call void @llvm.memset.p0.i16(ptr align 1 %56, i8 0, i16 %57, i1 false), !tbaa !6
  br label %58

58:                                               ; preds = %35, %55
  br label %65

59:                                               ; preds = %65, %18
  %60 = phi i16 [ -25033, %18 ], [ %73, %65 ]
  %61 = getelementptr i8, ptr @vs_pfxsum, i16 %8
  store i16 %60, ptr %61, align 1, !tbaa !2
  call void @llvm.stackrestore.p0(ptr %15)
  %62 = add nuw nsw i8 %4, 1
  %63 = icmp eq i8 %62, 24
  %64 = add nuw nsw i8 %3, 2
  br i1 %63, label %1, label %2, !llvm.loop !15

65:                                               ; preds = %58, %65
  %66 = phi i8 [ %74, %65 ], [ 0, %58 ]
  %67 = phi i16 [ %73, %65 ], [ -25033, %58 ]
  %68 = zext i8 %66 to i16
  %69 = getelementptr inbounds nuw [2 x i8], ptr %16, i16 %68
  %70 = load i16, ptr %69, align 1, !tbaa !2
  %71 = xor i16 %70, %67
  %72 = mul i16 %71, 25173
  %73 = add i16 %72, 13849
  %74 = add nuw i8 %66, 1
  %75 = icmp eq i8 %74, %12
  br i1 %75, label %59, label %65, !llvm.loop !16
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare ptr @llvm.stacksave.p0() #3

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.stackrestore.p0(ptr) #3

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #4

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.umin.i16(i16, i16) #4

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #5

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-xy16" }
attributes #1 = { nofree noinline norecurse nosync nounwind optsize memory(write, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-xy16" }
attributes #2 = { nofree noinline norecurse nosync nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-xy16" }
attributes #3 = { mustprogress nocallback nofree nosync nounwind willreturn }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #6 = { optsize }
attributes #7 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = distinct !{!9, !8}
!10 = !{i64 871}
!11 = distinct !{!11, !8}
!12 = distinct !{!12, !8}
!13 = distinct !{!13, !8}
!14 = distinct !{!14, !8}
!15 = distinct !{!15, !8}
!16 = distinct !{!16, !8}

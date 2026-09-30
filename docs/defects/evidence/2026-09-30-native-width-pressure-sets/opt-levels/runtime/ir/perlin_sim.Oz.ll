; ModuleID = '/work/examples/snes/corpus/perlin_sim.c'
source_filename = "/work/examples/snes/corpus/perlin_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@pn_ready = internal unnamed_addr global i1 false, align 1
@PN_PERM = internal unnamed_addr global [512 x i8] zeroinitializer, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = load i1, ptr @pn_ready, align 1
  br i1 %1, label %36, label %2

2:                                                ; preds = %0, %5
  %3 = phi i16 [ %8, %5 ], [ 0, %0 ]
  %4 = icmp eq i16 %3, 256
  br i1 %4, label %9, label %5

5:                                                ; preds = %2
  %6 = trunc nuw i16 %3 to i8
  %7 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %3
  store i8 %6, ptr %7, align 1, !tbaa !6
  %8 = add nuw nsw i16 %3, 1
  br label %2, !llvm.loop !7

9:                                                ; preds = %2, %13
  %10 = phi i16 [ %26, %13 ], [ 255, %2 ]
  %11 = phi i16 [ %19, %13 ], [ 10861, %2 ]
  %12 = icmp eq i16 %10, 0
  br i1 %12, label %27, label %13

13:                                               ; preds = %9
  %14 = shl i16 %11, 7
  %15 = xor i16 %14, %11
  %16 = lshr i16 %15, 9
  %17 = xor i16 %16, %15
  %18 = shl i16 %17, 8
  %19 = xor i16 %18, %17
  %20 = add nuw nsw i16 %10, 1
  %21 = urem i16 %19, %20
  %22 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %10
  %23 = load i8, ptr %22, align 1, !tbaa !6
  %24 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %21
  %25 = load i8, ptr %24, align 1, !tbaa !6
  store i8 %25, ptr %22, align 1, !tbaa !6
  store i8 %23, ptr %24, align 1, !tbaa !6
  %26 = add nsw i16 %10, -1
  br label %9, !llvm.loop !9

27:                                               ; preds = %9, %30
  %28 = phi i16 [ %34, %30 ], [ 0, %9 ]
  %29 = icmp eq i16 %28, 256
  br i1 %29, label %35, label %30

30:                                               ; preds = %27
  %31 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %28
  %32 = load i8, ptr %31, align 1, !tbaa !6
  %33 = getelementptr inbounds nuw i8, ptr %31, i16 256
  store i8 %32, ptr %33, align 1, !tbaa !6
  %34 = add nuw nsw i16 %28, 1
  br label %27, !llvm.loop !10

35:                                               ; preds = %27
  store i1 true, ptr @pn_ready, align 1
  br label %36

36:                                               ; preds = %35, %0
  br label %37

37:                                               ; preds = %36, %41
  %38 = phi i16 [ %97, %41 ], [ 0, %36 ]
  %39 = phi i16 [ %96, %41 ], [ 0, %36 ]
  %40 = icmp eq i16 %38, 120
  br i1 %40, label %98, label %41

41:                                               ; preds = %37
  %42 = mul nuw nsw i16 %38, 96
  %43 = zext nneg i16 %42 to i32
  %44 = mul nuw nsw i16 %38, 53
  %45 = add nuw nsw i16 %44, 128
  %46 = zext nneg i16 %45 to i32
  %47 = lshr i16 %42, 8
  %48 = lshr i32 %46, 8
  %49 = and i32 %43, 224
  %50 = and i32 %46, 255
  %51 = tail call fastcc i32 @pn_fade(i32 noundef %49) #3
  %52 = tail call fastcc i32 @pn_fade(i32 noundef %50) #3
  %53 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %47
  %54 = load i8, ptr %53, align 1, !tbaa !6
  %55 = zext i8 %54 to i32
  %56 = add nuw nsw i32 %48, %55
  %57 = trunc nuw nsw i32 %56 to i16
  %58 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %57
  %59 = load i8, ptr %58, align 1, !tbaa !6
  %60 = getelementptr inbounds nuw i8, ptr %58, i16 1
  %61 = load i8, ptr %60, align 1, !tbaa !6
  %62 = getelementptr inbounds nuw i8, ptr %53, i16 1
  %63 = load i8, ptr %62, align 1, !tbaa !6
  %64 = zext i8 %63 to i32
  %65 = add nuw nsw i32 %48, %64
  %66 = trunc nuw nsw i32 %65 to i16
  %67 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %66
  %68 = load i8, ptr %67, align 1, !tbaa !6
  %69 = getelementptr inbounds nuw i8, ptr %67, i16 1
  %70 = load i8, ptr %69, align 1, !tbaa !6
  %71 = tail call fastcc i32 @pn_grad(i8 noundef zeroext %59, i32 noundef %49, i32 noundef %50) #3
  %72 = or i32 %43, -256
  %73 = tail call fastcc i32 @pn_grad(i8 noundef zeroext %68, i32 noundef %72, i32 noundef %50) #3
  %74 = sub nsw i32 %73, %71
  %75 = mul nsw i32 %74, %51
  %76 = ashr i32 %75, 8
  %77 = add nsw i32 %76, %71
  %78 = or i32 %46, -256
  %79 = tail call fastcc i32 @pn_grad(i8 noundef zeroext %61, i32 noundef %49, i32 noundef %78) #3
  %80 = tail call fastcc i32 @pn_grad(i8 noundef zeroext %70, i32 noundef %72, i32 noundef %78) #3
  %81 = sub nsw i32 %80, %79
  %82 = mul nsw i32 %81, %51
  %83 = lshr i32 %82, 8
  %84 = sub nsw i32 %79, %77
  %85 = add nsw i32 %84, %83
  %86 = mul i32 %85, %52
  %87 = lshr i32 %86, 8
  %88 = add nsw i32 %87, %77
  %89 = trunc i32 %88 to i16
  %90 = tail call i16 @llvm.fshl.i16(i16 %39, i16 %39, i16 1)
  %91 = xor i16 %90, %89
  %92 = zext nneg i16 %38 to i32
  %93 = tail call fastcc i32 @pn_fade(i32 noundef %92) #3
  %94 = trunc nsw i32 %93 to i16
  %95 = tail call i16 @llvm.fshl.i16(i16 %91, i16 %91, i16 1)
  %96 = xor i16 %95, %94
  %97 = add nuw nsw i16 %38, 1
  br label %37, !llvm.loop !11

98:                                               ; preds = %37
  store volatile i16 %39, ptr @corpus_result, align 1, !tbaa !2
  br label %99

99:                                               ; preds = %99, %98
  tail call void asm sideeffect "wai", ""() #4, !srcloc !12
  br label %99
}

; Function Attrs: minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc range(i32 -1251, 2531) i32 @pn_fade(i32 noundef range(i32 0, 256) %0) unnamed_addr #1 {
  %2 = mul nuw nsw i32 %0, %0
  %3 = lshr i32 %2, 8
  %4 = mul nuw nsw i32 %3, %0
  %5 = lshr i32 %4, 8
  %6 = mul nuw nsw i32 %0, 6
  %7 = add nuw nsw i32 %6, -3840
  %8 = mul nsw i32 %7, %0
  %9 = ashr i32 %8, 8
  %10 = add nsw i32 %9, 2560
  %11 = mul nsw i32 %10, %5
  %12 = ashr i32 %11, 8
  ret i32 %12
}

; Function Attrs: minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc range(i32 -512, 513) i32 @pn_grad(i8 noundef zeroext %0, i32 noundef range(i32 -256, 256) %1, i32 noundef range(i32 -256, 256) %2) unnamed_addr #1 {
  %4 = and i8 %0, 3
  switch i8 %4, label %11 [
    i8 0, label %5
    i8 1, label %7
    i8 2, label %9
    i8 3, label %12
  ]

5:                                                ; preds = %3
  %6 = add nsw i32 %2, %1
  br label %15

7:                                                ; preds = %3
  %8 = sub nsw i32 %2, %1
  br label %15

9:                                                ; preds = %3
  %10 = sub nsw i32 %1, %2
  br label %15

11:                                               ; preds = %3
  unreachable

12:                                               ; preds = %3
  %13 = add nsw i32 %1, %2
  %14 = sub nsw i32 0, %13
  br label %15

15:                                               ; preds = %12, %9, %7, %5
  %16 = phi i32 [ %14, %12 ], [ %6, %5 ], [ %8, %7 ], [ %10, %9 ]
  ret i32 %16
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { minsize mustprogress nofree norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = distinct !{!9, !8}
!10 = distinct !{!10, !8}
!11 = distinct !{!11, !8}
!12 = !{i64 344}

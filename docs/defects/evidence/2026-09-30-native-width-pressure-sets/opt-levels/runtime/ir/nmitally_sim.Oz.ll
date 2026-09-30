; ModuleID = '/work/examples/snes/corpus/nmitally_sim.c'
source_filename = "/work/examples/snes/corpus/nmitally_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca i16, align 1
  %2 = alloca i32, align 1
  %3 = alloca i16, align 1
  call void @llvm.lifetime.start.p0(ptr nonnull %1)
  call void @llvm.lifetime.start.p0(ptr nonnull %2)
  call void @llvm.lifetime.start.p0(ptr nonnull %3)
  store volatile i16 0, ptr %1, align 1, !tbaa !6
  store volatile i32 0, ptr %2, align 1, !tbaa !9
  store volatile i16 -21279, ptr %3, align 1, !tbaa !10
  br label %4

4:                                                ; preds = %11, %0
  %5 = phi i32 [ 0, %0 ], [ %19, %11 ]
  %6 = phi i16 [ -30293, %0 ], [ %15, %11 ]
  %7 = phi i16 [ 4660, %0 ], [ %13, %11 ]
  %8 = phi i16 [ 0, %0 ], [ %52, %11 ]
  %9 = phi i16 [ 0, %0 ], [ %53, %11 ]
  %10 = icmp eq i16 %9, 240
  br i1 %10, label %54, label %11

11:                                               ; preds = %4
  %12 = mul i16 %7, 25173
  %13 = add i16 %12, 13849
  %14 = lshr i16 %13, 3
  %15 = xor i16 %14, %6
  %16 = zext i16 %13 to i32
  %17 = zext i16 %15 to i32
  %18 = mul nuw i32 %17, %16
  %19 = add i32 %18, %5
  %20 = load volatile i16, ptr %3, align 1, !tbaa !10
  %21 = shl i16 %20, 7
  %22 = xor i16 %21, %20
  %23 = lshr i16 %22, 9
  %24 = xor i16 %23, %22
  %25 = shl i16 %24, 8
  %26 = xor i16 %25, %24
  store volatile i16 %26, ptr %3, align 1, !tbaa !10
  %27 = load volatile i16, ptr %1, align 1, !tbaa !6
  %28 = add i16 %27, 1
  store volatile i16 %28, ptr %1, align 1, !tbaa !6
  %29 = load volatile i32, ptr %2, align 1, !tbaa !9
  %30 = zext i16 %26 to i32
  %31 = zext i16 %28 to i32
  %32 = shl nuw nsw i32 %31, 3
  %33 = add i32 %32, %29
  %34 = add i32 %33, %30
  store volatile i32 %34, ptr %2, align 1, !tbaa !9
  %35 = load volatile i32, ptr %2, align 1, !tbaa !9
  %36 = tail call i16 @llvm.fshl.i16(i16 %8, i16 %8, i16 1)
  %37 = load volatile i16, ptr %1, align 1, !tbaa !6
  %38 = xor i16 %37, %36
  %39 = tail call i16 @llvm.fshl.i16(i16 %38, i16 %38, i16 1)
  %40 = trunc i32 %35 to i16
  %41 = xor i16 %39, %40
  %42 = tail call i16 @llvm.fshl.i16(i16 %41, i16 %41, i16 1)
  %43 = lshr i32 %35, 16
  %44 = trunc nuw i32 %43 to i16
  %45 = xor i16 %42, %44
  %46 = tail call i16 @llvm.fshl.i16(i16 %45, i16 %45, i16 1)
  %47 = lshr i32 %19, 16
  %48 = xor i32 %47, %19
  %49 = trunc i32 %48 to i16
  %50 = xor i16 %46, %49
  %51 = xor i16 %50, %13
  %52 = xor i16 %51, %15
  %53 = add nuw nsw i16 %9, 1
  br label %4, !llvm.loop !11

54:                                               ; preds = %4
  call void @llvm.lifetime.end.p0(ptr nonnull %1)
  call void @llvm.lifetime.end.p0(ptr nonnull %2)
  call void @llvm.lifetime.end.p0(ptr nonnull %3)
  store volatile i16 %8, ptr @corpus_result, align 1, !tbaa !2
  br label %55

55:                                               ; preds = %55, %54
  tail call void asm sideeffect "wai", ""() #3, !srcloc !13
  br label %55
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
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
!6 = !{!7, !3, i64 0}
!7 = !{!"", !3, i64 0, !8, i64 2, !3, i64 6}
!8 = !{!"long", !4, i64 0}
!9 = !{!7, !8, i64 2}
!10 = !{!7, !3, i64 6}
!11 = distinct !{!11, !12}
!12 = !{!"llvm.loop.mustprogress"}
!13 = !{i64 820}

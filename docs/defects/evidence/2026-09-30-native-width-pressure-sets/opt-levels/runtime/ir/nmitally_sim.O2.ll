; ModuleID = '/work/examples/snes/corpus/nmitally_sim.c'
source_filename = "/work/examples/snes/corpus/nmitally_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind
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

4:                                                ; preds = %4, %0
  %5 = phi i16 [ 0, %0 ], [ %51, %4 ]
  %6 = phi i16 [ 0, %0 ], [ %50, %4 ]
  %7 = phi i16 [ 4660, %0 ], [ %11, %4 ]
  %8 = phi i16 [ -30293, %0 ], [ %13, %4 ]
  %9 = phi i32 [ 0, %0 ], [ %17, %4 ]
  %10 = mul i16 %7, 25173
  %11 = add i16 %10, 13849
  %12 = lshr i16 %11, 3
  %13 = xor i16 %12, %8
  %14 = zext i16 %11 to i32
  %15 = zext i16 %13 to i32
  %16 = mul nuw i32 %15, %14
  %17 = add i32 %16, %9
  %18 = load volatile i16, ptr %3, align 1, !tbaa !10
  %19 = shl i16 %18, 7
  %20 = xor i16 %19, %18
  %21 = lshr i16 %20, 9
  %22 = xor i16 %21, %20
  %23 = shl i16 %22, 8
  %24 = xor i16 %23, %22
  store volatile i16 %24, ptr %3, align 1, !tbaa !10
  %25 = load volatile i16, ptr %1, align 1, !tbaa !6
  %26 = add i16 %25, 1
  store volatile i16 %26, ptr %1, align 1, !tbaa !6
  %27 = load volatile i32, ptr %2, align 1, !tbaa !9
  %28 = zext i16 %24 to i32
  %29 = zext i16 %26 to i32
  %30 = shl nuw nsw i32 %29, 3
  %31 = add i32 %30, %27
  %32 = add i32 %31, %28
  store volatile i32 %32, ptr %2, align 1, !tbaa !9
  %33 = load volatile i32, ptr %2, align 1, !tbaa !9
  %34 = tail call i16 @llvm.fshl.i16(i16 %6, i16 %6, i16 1)
  %35 = load volatile i16, ptr %1, align 1, !tbaa !6
  %36 = xor i16 %35, %34
  %37 = tail call i16 @llvm.fshl.i16(i16 %36, i16 %36, i16 1)
  %38 = trunc i32 %33 to i16
  %39 = xor i16 %37, %38
  %40 = tail call i16 @llvm.fshl.i16(i16 %39, i16 %39, i16 1)
  %41 = lshr i32 %33, 16
  %42 = trunc nuw i32 %41 to i16
  %43 = xor i16 %40, %42
  %44 = tail call i16 @llvm.fshl.i16(i16 %43, i16 %43, i16 1)
  %45 = lshr i32 %17, 16
  %46 = xor i32 %45, %17
  %47 = trunc i32 %46 to i16
  %48 = xor i16 %44, %47
  %49 = xor i16 %48, %11
  %50 = xor i16 %49, %13
  %51 = add nuw nsw i16 %5, 1
  %52 = icmp eq i16 %51, 240
  br i1 %52, label %53, label %4, !llvm.loop !11

53:                                               ; preds = %4
  call void @llvm.lifetime.end.p0(ptr nonnull %1)
  call void @llvm.lifetime.end.p0(ptr nonnull %2)
  call void @llvm.lifetime.end.p0(ptr nonnull %3)
  store volatile i16 %50, ptr @corpus_result, align 1, !tbaa !2
  br label %54

54:                                               ; preds = %54, %53
  tail call void asm sideeffect "wai", ""() #3, !srcloc !13
  br label %54
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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

; ModuleID = '/work/examples/snes/corpus/sodo_sim.c'
source_filename = "/work/examples/snes/corpus/sodo_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca [18 x i8], align 1
  br label %2

2:                                                ; preds = %29, %0
  %3 = phi i16 [ 0, %0 ], [ %31, %29 ]
  %4 = phi i16 [ 0, %0 ], [ %32, %29 ]
  %5 = zext nneg i16 %4 to i64
  %6 = mul nuw nsw i64 %5, 41000000000
  %7 = add nsw i64 %6, -620000000000
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #3
  %8 = icmp samesign ult i16 %4, 16
  br i1 %8, label %10, label %9

9:                                                ; preds = %2
  br label %10

10:                                               ; preds = %9, %2
  %11 = phi i8 [ 1, %9 ], [ -1, %2 ]
  br label %12

12:                                               ; preds = %21, %10
  %13 = phi i8 [ 0, %10 ], [ %25, %21 ]
  %14 = phi i64 [ %7, %10 ], [ %16, %21 ]
  %15 = srem i64 %14, 10
  %16 = sdiv i64 %14, 10
  %17 = icmp slt i64 %15, 0
  %18 = trunc nsw i64 %15 to i8
  br i1 %17, label %19, label %21

19:                                               ; preds = %12
  %20 = sub nsw i8 0, %18
  br label %21

21:                                               ; preds = %19, %12
  %22 = phi i8 [ %20, %19 ], [ %18, %12 ]
  %23 = zext nneg i8 %13 to i16
  %24 = getelementptr i8, ptr %1, i16 %23
  store i8 %22, ptr %24, align 1, !tbaa !6
  %25 = add nuw nsw i8 %13, 1
  %26 = icmp eq i8 %25, 18
  br i1 %26, label %27, label %12, !llvm.loop !7

27:                                               ; preds = %21
  %28 = zext i8 %11 to i16
  br label %34

29:                                               ; preds = %34
  %30 = tail call i16 @llvm.fshl.i16(i16 %3, i16 %3, i16 1)
  %31 = xor i16 %42, %30
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #3
  %32 = add nuw nsw i16 %4, 1
  %33 = icmp eq i16 %32, 60
  br i1 %33, label %45, label %2, !llvm.loop !9

34:                                               ; preds = %34, %27
  %35 = phi i8 [ 0, %27 ], [ %43, %34 ]
  %36 = phi i16 [ %28, %27 ], [ %42, %34 ]
  %37 = mul i16 %36, 10
  %38 = zext nneg i8 %35 to i16
  %39 = getelementptr i8, ptr %1, i16 %38
  %40 = load i8, ptr %39, align 1, !tbaa !6
  %41 = zext i8 %40 to i16
  %42 = add i16 %37, %41
  %43 = add nuw nsw i8 %35, 1
  %44 = icmp eq i8 %43, 18
  br i1 %44, label %29, label %34, !llvm.loop !10

45:                                               ; preds = %29
  store volatile i16 %31, ptr @corpus_result, align 1, !tbaa !2
  br label %46

46:                                               ; preds = %46, %45
  tail call void asm sideeffect "wai", ""() #3, !srcloc !11
  br label %46
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = distinct !{!9, !8}
!10 = distinct !{!10, !8}
!11 = !{i64 459}

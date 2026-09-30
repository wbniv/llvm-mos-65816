; ModuleID = '/work/examples/snes/corpus/sodo_sim.c'
source_filename = "/work/examples/snes/corpus/sodo_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca [18 x i8], align 1
  br label %2

2:                                                ; preds = %36, %0
  %3 = phi i16 [ 0, %0 ], [ %39, %36 ]
  %4 = phi i16 [ 0, %0 ], [ %38, %36 ]
  %5 = icmp eq i16 %3, 60
  br i1 %5, label %48, label %6

6:                                                ; preds = %2
  %7 = zext nneg i16 %3 to i64
  %8 = mul nuw nsw i64 %7, 41000000000
  %9 = add nsw i64 %8, -620000000000
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #3
  %10 = icmp samesign ult i16 %3, 16
  br i1 %10, label %12, label %11

11:                                               ; preds = %6
  br label %12

12:                                               ; preds = %11, %6
  %13 = phi i8 [ 1, %11 ], [ -1, %6 ]
  br label %14

14:                                               ; preds = %25, %12
  %15 = phi i64 [ %9, %12 ], [ %20, %25 ]
  %16 = phi i8 [ 0, %12 ], [ %29, %25 ]
  %17 = icmp eq i8 %16, 18
  br i1 %17, label %30, label %18

18:                                               ; preds = %14
  %19 = srem i64 %15, 10
  %20 = sdiv i64 %15, 10
  %21 = icmp slt i64 %19, 0
  %22 = trunc nsw i64 %19 to i8
  br i1 %21, label %23, label %25

23:                                               ; preds = %18
  %24 = sub nsw i8 0, %22
  br label %25

25:                                               ; preds = %23, %18
  %26 = phi i8 [ %24, %23 ], [ %22, %18 ]
  %27 = zext nneg i8 %16 to i16
  %28 = getelementptr i8, ptr %1, i16 %27
  store i8 %26, ptr %28, align 1, !tbaa !6
  %29 = add nuw nsw i8 %16, 1
  br label %14, !llvm.loop !7

30:                                               ; preds = %14
  %31 = zext i8 %13 to i16
  br label %32

32:                                               ; preds = %40, %30
  %33 = phi i16 [ %31, %30 ], [ %46, %40 ]
  %34 = phi i8 [ 0, %30 ], [ %47, %40 ]
  %35 = icmp eq i8 %34, 18
  br i1 %35, label %36, label %40

36:                                               ; preds = %32
  %37 = tail call i16 @llvm.fshl.i16(i16 %4, i16 %4, i16 1)
  %38 = xor i16 %33, %37
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #3
  %39 = add nuw nsw i16 %3, 1
  br label %2, !llvm.loop !9

40:                                               ; preds = %32
  %41 = mul i16 %33, 10
  %42 = zext nneg i8 %34 to i16
  %43 = getelementptr i8, ptr %1, i16 %42
  %44 = load i8, ptr %43, align 1, !tbaa !6
  %45 = zext i8 %44 to i16
  %46 = add i16 %41, %45
  %47 = add nuw nsw i8 %34, 1
  br label %32, !llvm.loop !10

48:                                               ; preds = %2
  store volatile i16 %4, ptr @corpus_result, align 1, !tbaa !2
  br label %49

49:                                               ; preds = %49, %48
  tail call void asm sideeffect "wai", ""() #3, !srcloc !11
  br label %49
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
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = distinct !{!9, !8}
!10 = distinct !{!10, !8}
!11 = !{i64 459}

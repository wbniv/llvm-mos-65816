; ModuleID = '/work/examples/snes/corpus/ulam_sim.c'
source_filename = "/work/examples/snes/corpus/ulam_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@ul_comp = internal unnamed_addr global [128 x i8] zeroinitializer, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(127) getelementptr inbounds nuw (i8, ptr @ul_comp, i16 1), i8 0, i16 127, i1 false), !tbaa !6
  store i8 3, ptr @ul_comp, align 1, !tbaa !6
  br label %1

1:                                                ; preds = %24, %0
  %2 = phi i16 [ 2, %0 ], [ %25, %24 ]
  %3 = lshr i16 %2, 3
  %4 = getelementptr inbounds nuw i8, ptr @ul_comp, i16 %3
  %5 = load i8, ptr %4, align 1, !tbaa !6
  %6 = zext i8 %5 to i16
  %7 = and i16 %2, 7
  %8 = shl nuw nsw i16 1, %7
  %9 = and i16 %8, %6
  %10 = icmp eq i16 %9, 0
  br i1 %10, label %11, label %24

11:                                               ; preds = %1
  %12 = mul i16 %2, %2
  br label %13

13:                                               ; preds = %13, %11
  %14 = phi i16 [ %22, %13 ], [ %12, %11 ]
  %15 = lshr i16 %14, 3
  %16 = getelementptr inbounds nuw i8, ptr @ul_comp, i16 %15
  %17 = load i8, ptr %16, align 1, !tbaa !6
  %18 = and i16 %14, 7
  %19 = shl nuw nsw i16 1, %18
  %20 = trunc nuw i16 %19 to i8
  %21 = or i8 %17, %20
  store i8 %21, ptr %16, align 1, !tbaa !6
  %22 = add i16 %14, %2
  %23 = icmp ult i16 %22, 1024
  br i1 %23, label %13, label %24, !llvm.loop !7

24:                                               ; preds = %13, %1
  %25 = add nuw nsw i16 %2, 1
  %26 = icmp eq i16 %25, 32
  br i1 %26, label %27, label %1, !llvm.loop !9

27:                                               ; preds = %24, %27
  %28 = phi i16 [ %41, %27 ], [ 0, %24 ]
  %29 = phi i16 [ %42, %27 ], [ 0, %24 ]
  %30 = lshr i16 %29, 3
  %31 = getelementptr inbounds nuw i8, ptr @ul_comp, i16 %30
  %32 = load i8, ptr %31, align 1, !tbaa !6
  %33 = zext i8 %32 to i16
  %34 = and i16 %29, 7
  %35 = tail call i16 @llvm.fshl.i16(i16 %28, i16 %28, i16 1)
  %36 = shl nuw nsw i16 1, %34
  %37 = and i16 %36, %33
  %38 = icmp eq i16 %37, 0
  %39 = select i1 %38, i16 97, i16 13
  %40 = mul i16 %39, %29
  %41 = xor i16 %40, %35
  %42 = add nuw nsw i16 %29, 1
  %43 = icmp eq i16 %42, 1024
  br i1 %43, label %44, label %27, !llvm.loop !10

44:                                               ; preds = %27
  store volatile i16 %41, ptr @corpus_result, align 1, !tbaa !2
  br label %45

45:                                               ; preds = %45, %44
  tail call void asm sideeffect "wai", ""() #3, !srcloc !11
  br label %45
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #2

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: write) }
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
!11 = !{i64 465}

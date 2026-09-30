; ModuleID = '/work/examples/snes/corpus/fenwick_sim.c'
source_filename = "/work/examples/snes/corpus/fenwick_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Fenwick = type { [17 x i16], [17 x i16] }

@corpus_result = dso_local global i16 0, align 1
@fenwick_gate_crc.f = internal unnamed_addr global %struct.Fenwick zeroinitializer, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(68) @fenwick_gate_crc.f, i8 0, i64 68, i1 false)
  br label %1

1:                                                ; preds = %43, %0
  %2 = phi i16 [ 0, %0 ], [ %48, %43 ]
  %3 = phi i16 [ 0, %0 ], [ %44, %43 ]
  %4 = and i16 %3, 15
  %5 = add nuw nsw i16 %4, 1
  br label %8

6:                                                ; preds = %36
  %7 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 32), align 1, !tbaa !2
  br label %40

8:                                                ; preds = %36, %1
  %9 = phi i8 [ 0, %1 ], [ %39, %36 ]
  %10 = phi i16 [ 1, %1 ], [ %37, %36 ]
  %11 = icmp samesign ugt i16 %10, %5
  br i1 %11, label %12, label %14

12:                                               ; preds = %8
  %13 = sub nsw i16 %5, %10
  br label %16

14:                                               ; preds = %8
  %15 = sub nsw i16 %10, %5
  br label %16

16:                                               ; preds = %14, %12
  %17 = phi i16 [ %13, %12 ], [ %15, %14 ]
  %18 = icmp sgt i16 %17, -8
  br i1 %18, label %19, label %21

19:                                               ; preds = %16
  %20 = add nsw i16 %17, 8
  br label %21

21:                                               ; preds = %19, %16
  %22 = phi i16 [ %20, %19 ], [ 0, %16 ]
  %23 = zext nneg i8 %9 to i16
  %24 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 36), i16 %23
  %25 = load i16, ptr %24, align 1, !tbaa !2
  %26 = sub i16 %22, %25
  store i16 %22, ptr %24, align 1, !tbaa !2
  br label %27

27:                                               ; preds = %27, %21
  %28 = phi i16 [ %10, %21 ], [ %34, %27 ]
  %29 = getelementptr inbounds nuw [2 x i8], ptr @fenwick_gate_crc.f, i16 %28
  %30 = load i16, ptr %29, align 1, !tbaa !2
  %31 = add nsw i16 %26, %30
  store i16 %31, ptr %29, align 1, !tbaa !2
  %32 = sub nsw i16 0, %28
  %33 = and i16 %28, %32
  %34 = add nuw nsw i16 %33, %28
  %35 = icmp samesign ult i16 %34, 17
  br i1 %35, label %27, label %36, !llvm.loop !6

36:                                               ; preds = %27
  %37 = add nuw nsw i16 %10, 1
  %38 = icmp eq i16 %37, 17
  %39 = add nuw nsw i8 %9, 2
  br i1 %38, label %6, label %8, !llvm.loop !8

40:                                               ; preds = %86, %6
  %41 = phi i16 [ %2, %6 ], [ %90, %86 ]
  %42 = phi i16 [ 1, %6 ], [ %91, %86 ]
  br label %50

43:                                               ; preds = %86
  %44 = add nuw nsw i16 %3, 1
  %45 = xor i16 %3, -1
  %46 = and i16 %44, %45
  %47 = tail call i16 @llvm.fshl.i16(i16 %90, i16 %90, i16 1)
  %48 = xor i16 %47, %46
  %49 = icmp eq i16 %44, 120
  br i1 %49, label %93, label %1, !llvm.loop !9

50:                                               ; preds = %50, %40
  %51 = phi i16 [ %55, %50 ], [ 0, %40 ]
  %52 = phi i16 [ %57, %50 ], [ %42, %40 ]
  %53 = getelementptr inbounds nuw [2 x i8], ptr @fenwick_gate_crc.f, i16 %52
  %54 = load i16, ptr %53, align 1, !tbaa !2
  %55 = add nsw i16 %54, %51
  %56 = add i16 %52, -1
  %57 = and i16 %56, %52
  %58 = icmp eq i16 %57, 0
  br i1 %58, label %59, label %50, !llvm.loop !10

59:                                               ; preds = %50, %59
  %60 = phi i8 [ %69, %59 ], [ 0, %50 ]
  %61 = phi i16 [ %67, %59 ], [ 1, %50 ]
  %62 = phi i16 [ %66, %59 ], [ 0, %50 ]
  %63 = zext nneg i8 %60 to i16
  %64 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 36), i16 %63
  %65 = load i16, ptr %64, align 1, !tbaa !2
  %66 = add nsw i16 %65, %62
  %67 = add nuw nsw i16 %61, 1
  %68 = icmp eq i16 %61, %42
  %69 = add nuw nsw i8 %60, 2
  br i1 %68, label %70, label %59, !llvm.loop !11

70:                                               ; preds = %59
  %71 = tail call i16 @llvm.fshl.i16(i16 %41, i16 %41, i16 1)
  %72 = xor i16 %55, %71
  %73 = tail call i16 @llvm.fshl.i16(i16 %72, i16 %72, i16 1)
  %74 = xor i16 %66, %73
  %75 = add nsw i16 %42, -1
  %76 = icmp eq i16 %75, 0
  br i1 %76, label %86, label %77

77:                                               ; preds = %70, %77
  %78 = phi i16 [ %82, %77 ], [ 0, %70 ]
  %79 = phi i16 [ %84, %77 ], [ %75, %70 ]
  %80 = getelementptr inbounds nuw [2 x i8], ptr @fenwick_gate_crc.f, i16 %79
  %81 = load i16, ptr %80, align 1, !tbaa !2
  %82 = add nsw i16 %81, %78
  %83 = add i16 %79, -1
  %84 = and i16 %83, %79
  %85 = icmp eq i16 %84, 0
  br i1 %85, label %86, label %77, !llvm.loop !10

86:                                               ; preds = %77, %70
  %87 = phi i16 [ 0, %70 ], [ %82, %77 ]
  %88 = sub nsw i16 %7, %87
  %89 = tail call i16 @llvm.fshl.i16(i16 %74, i16 %74, i16 1)
  %90 = xor i16 %88, %89
  %91 = add nuw nsw i16 %42, 5
  %92 = icmp samesign ult i16 %42, 12
  br i1 %92, label %40, label %43, !llvm.loop !12

93:                                               ; preds = %43
  store volatile i16 %48, ptr @corpus_result, align 1, !tbaa !2
  br label %94

94:                                               ; preds = %94, %93
  tail call void asm sideeffect "wai", ""() #3, !srcloc !13
  br label %94
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #2

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = distinct !{!8, !7}
!9 = distinct !{!9, !7}
!10 = distinct !{!10, !7}
!11 = distinct !{!11, !7}
!12 = distinct !{!12, !7}
!13 = !{i64 334}

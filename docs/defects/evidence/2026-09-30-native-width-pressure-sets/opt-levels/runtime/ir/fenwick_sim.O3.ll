; ModuleID = '/work/examples/snes/corpus/fenwick_sim.c'
source_filename = "/work/examples/snes/corpus/fenwick_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Fenwick = type { [17 x i16], [17 x i16] }

@corpus_result = dso_local global i16 0, align 1
@fenwick_gate_crc.f = internal unnamed_addr global %struct.Fenwick zeroinitializer, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 1 dereferenceable(68) @fenwick_gate_crc.f, i8 0, i64 68, i1 false)
  br label %1

1:                                                ; preds = %38, %0
  %2 = phi i16 [ 0, %0 ], [ %119, %38 ]
  %3 = phi i16 [ 0, %0 ], [ %115, %38 ]
  %4 = and i16 %3, 15
  %5 = add nuw nsw i16 %4, 1
  br label %6

6:                                                ; preds = %34, %1
  %7 = phi i8 [ 0, %1 ], [ %37, %34 ]
  %8 = phi i16 [ 1, %1 ], [ %35, %34 ]
  %9 = icmp samesign ugt i16 %8, %5
  br i1 %9, label %10, label %12

10:                                               ; preds = %6
  %11 = sub nsw i16 %5, %8
  br label %14

12:                                               ; preds = %6
  %13 = sub nsw i16 %8, %5
  br label %14

14:                                               ; preds = %12, %10
  %15 = phi i16 [ %11, %10 ], [ %13, %12 ]
  %16 = icmp sgt i16 %15, -8
  br i1 %16, label %17, label %19

17:                                               ; preds = %14
  %18 = add nsw i16 %15, 8
  br label %19

19:                                               ; preds = %17, %14
  %20 = phi i16 [ %18, %17 ], [ 0, %14 ]
  %21 = zext nneg i8 %7 to i16
  %22 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 36), i16 %21
  %23 = load i16, ptr %22, align 1, !tbaa !2
  %24 = sub i16 %20, %23
  store i16 %20, ptr %22, align 1, !tbaa !2
  br label %25

25:                                               ; preds = %25, %19
  %26 = phi i16 [ %8, %19 ], [ %32, %25 ]
  %27 = getelementptr inbounds nuw [2 x i8], ptr @fenwick_gate_crc.f, i16 %26
  %28 = load i16, ptr %27, align 1, !tbaa !2
  %29 = add nsw i16 %24, %28
  store i16 %29, ptr %27, align 1, !tbaa !2
  %30 = sub nsw i16 0, %26
  %31 = and i16 %26, %30
  %32 = add nuw nsw i16 %31, %26
  %33 = icmp samesign ult i16 %32, 17
  br i1 %33, label %25, label %34, !llvm.loop !6

34:                                               ; preds = %25
  %35 = add nuw nsw i16 %8, 1
  %36 = icmp eq i16 %35, 17
  %37 = add nuw nsw i8 %7, 2
  br i1 %36, label %38, label %6, !llvm.loop !8

38:                                               ; preds = %34
  %39 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 32), align 1, !tbaa !2
  %40 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 36), align 1, !tbaa !2
  %41 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 2), align 1, !tbaa !2
  %42 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %43 = xor i16 %41, %42
  %44 = tail call i16 @llvm.fshl.i16(i16 %43, i16 %43, i16 1)
  %45 = xor i16 %44, %40
  %46 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 12), align 1, !tbaa !2
  %47 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 8), align 1, !tbaa !2
  %48 = add nsw i16 %47, %46
  %49 = tail call i16 @llvm.fshl.i16(i16 %45, i16 %45, i16 1)
  %50 = xor i16 %49, %39
  %51 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 38), align 1, !tbaa !2
  %52 = add nsw i16 %51, %40
  %53 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 40), align 1, !tbaa !2
  %54 = add nsw i16 %52, %53
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 42), align 1, !tbaa !2
  %56 = add nsw i16 %54, %55
  %57 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 44), align 1, !tbaa !2
  %58 = add nsw i16 %56, %57
  %59 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 46), align 1, !tbaa !2
  %60 = add nsw i16 %58, %59
  %61 = tail call i16 @llvm.fshl.i16(i16 %50, i16 %50, i16 1)
  %62 = xor i16 %61, %48
  %63 = tail call i16 @llvm.fshl.i16(i16 %62, i16 %62, i16 1)
  %64 = xor i16 %60, %63
  %65 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 10), align 1, !tbaa !2
  %66 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 22), align 1, !tbaa !2
  %67 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 20), align 1, !tbaa !2
  %68 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 16), align 1, !tbaa !2
  %69 = add i16 %68, %67
  %70 = add i16 %69, %66
  %71 = add i16 %47, %65
  %72 = sub i16 %39, %71
  %73 = tail call i16 @llvm.fshl.i16(i16 %64, i16 %64, i16 1)
  %74 = xor i16 %73, %72
  %75 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 48), align 1, !tbaa !2
  %76 = add nsw i16 %75, %60
  %77 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 50), align 1, !tbaa !2
  %78 = add nsw i16 %76, %77
  %79 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 52), align 1, !tbaa !2
  %80 = add nsw i16 %78, %79
  %81 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 54), align 1, !tbaa !2
  %82 = add nsw i16 %80, %81
  %83 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 56), align 1, !tbaa !2
  %84 = add nsw i16 %82, %83
  %85 = tail call i16 @llvm.fshl.i16(i16 %74, i16 %74, i16 1)
  %86 = xor i16 %70, %85
  %87 = tail call i16 @llvm.fshl.i16(i16 %86, i16 %86, i16 1)
  %88 = xor i16 %84, %87
  %89 = sub i16 %39, %69
  %90 = tail call i16 @llvm.fshl.i16(i16 %88, i16 %88, i16 1)
  %91 = xor i16 %90, %89
  %92 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 58), align 1, !tbaa !2
  %93 = add nsw i16 %92, %84
  %94 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 60), align 1, !tbaa !2
  %95 = add nsw i16 %93, %94
  %96 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 62), align 1, !tbaa !2
  %97 = add nsw i16 %95, %96
  %98 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 64), align 1, !tbaa !2
  %99 = add nsw i16 %97, %98
  %100 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 66), align 1, !tbaa !2
  %101 = add nsw i16 %99, %100
  %102 = tail call i16 @llvm.fshl.i16(i16 %91, i16 %91, i16 1)
  %103 = xor i16 %102, %39
  %104 = tail call i16 @llvm.fshl.i16(i16 %103, i16 %103, i16 1)
  %105 = xor i16 %104, %101
  %106 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 24), align 1, !tbaa !2
  %107 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 28), align 1, !tbaa !2
  %108 = load i16, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 30), align 1, !tbaa !2
  %109 = add i16 %68, %106
  %110 = add i16 %109, %107
  %111 = add i16 %110, %108
  %112 = sub i16 %39, %111
  %113 = tail call i16 @llvm.fshl.i16(i16 %105, i16 %105, i16 1)
  %114 = xor i16 %112, %113
  %115 = add nuw nsw i16 %3, 1
  %116 = xor i16 %3, -1
  %117 = and i16 %115, %116
  %118 = tail call i16 @llvm.fshl.i16(i16 %114, i16 %114, i16 1)
  %119 = xor i16 %118, %117
  %120 = icmp eq i16 %115, 120
  br i1 %120, label %121, label %1, !llvm.loop !9

121:                                              ; preds = %38
  store volatile i16 %119, ptr @corpus_result, align 1, !tbaa !2
  br label %122

122:                                              ; preds = %122, %121
  tail call void asm sideeffect "wai", ""() #3, !srcloc !10
  br label %122
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #2

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
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = distinct !{!8, !7}
!9 = distinct !{!9, !7}
!10 = !{i64 334}

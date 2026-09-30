; ModuleID = '/work/examples/snes/corpus/boids_sim.c'
source_filename = "/work/examples/snes/corpus/boids_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Boid = type { %struct.vec2, %struct.vec2 }
%struct.vec2 = type { i16, i16 }

@corpus_result = dso_local global i16 0, align 1
@boids_gate_crc.gf = internal unnamed_addr global [8 x %struct.Boid] zeroinitializer, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  store i16 2096, ptr @boids_gate_crc.gf, align 1, !tbaa !6
  store i16 32, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), align 1, !tbaa !9
  store i16 8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), align 1, !tbaa !10
  store i16 30, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), align 1, !tbaa !11
  store i16 1336, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1, !tbaa !6
  store i16 364, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1, !tbaa !9
  store i16 -11, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 12), align 1, !tbaa !10
  store i16 -13, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 14), align 1, !tbaa !11
  store i16 3656, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 16), align 1, !tbaa !6
  store i16 1893, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 18), align 1, !tbaa !9
  store i16 3, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 20), align 1, !tbaa !10
  store i16 -4, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 22), align 1, !tbaa !11
  store i16 1898, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 24), align 1, !tbaa !6
  store i16 2419, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 26), align 1, !tbaa !9
  store i16 -17, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 28), align 1, !tbaa !10
  store i16 -9, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 30), align 1, !tbaa !11
  store i16 3569, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 32), align 1, !tbaa !6
  store i16 2131, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 34), align 1, !tbaa !9
  store i16 -20, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 36), align 1, !tbaa !10
  store i16 -26, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 38), align 1, !tbaa !11
  store i16 3806, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 40), align 1, !tbaa !6
  store i16 926, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 42), align 1, !tbaa !9
  store i16 22, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 44), align 1, !tbaa !10
  store i16 -8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 46), align 1, !tbaa !11
  store i16 1516, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 48), align 1, !tbaa !6
  store i16 3285, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 50), align 1, !tbaa !9
  store i16 19, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 52), align 1, !tbaa !10
  store i16 -32, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 54), align 1, !tbaa !11
  store i16 1491, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 56), align 1, !tbaa !6
  store i16 797, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 58), align 1, !tbaa !9
  store i16 -6, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 60), align 1, !tbaa !10
  store i16 22, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 62), align 1, !tbaa !11
  br label %1

1:                                                ; preds = %48, %0
  %2 = phi i8 [ 0, %0 ], [ %49, %48 ]
  br label %3

3:                                                ; preds = %43, %1
  %4 = phi i8 [ %47, %43 ], [ 0, %1 ]
  %5 = phi i8 [ %45, %43 ], [ 0, %1 ]
  %6 = tail call fastcc { i16, i16 } @boid_acc(i8 noundef zeroext %5)
  %7 = extractvalue { i16, i16 } %6, 0
  %8 = extractvalue { i16, i16 } %6, 1
  %9 = zext nneg i8 %4 to i16
  %10 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %9
  %11 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %9
  %12 = load i16, ptr %11, align 1
  %13 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %9
  %14 = load i16, ptr %13, align 1
  %15 = tail call fastcc { i16, i16 } @v2_add(i16 %12, i16 %14, i16 %7, i16 %8)
  %16 = extractvalue { i16, i16 } %15, 0
  %17 = extractvalue { i16, i16 } %15, 1
  %18 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %16, i16 %17, i16 noundef 40)
  %19 = extractvalue { i16, i16 } %18, 0
  %20 = extractvalue { i16, i16 } %18, 1
  store i16 %19, ptr %11, align 1, !tbaa !2
  store i16 %20, ptr %13, align 1, !tbaa !2
  %21 = load i16, ptr %10, align 1
  %22 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %9
  %23 = load i16, ptr %22, align 1
  %24 = tail call fastcc { i16, i16 } @v2_add(i16 %21, i16 %23, i16 %19, i16 %20)
  %25 = extractvalue { i16, i16 } %24, 0
  %26 = extractvalue { i16, i16 } %24, 1
  %27 = icmp slt i16 %25, 0
  br i1 %27, label %28, label %30

28:                                               ; preds = %3
  %29 = add nsw i16 %25, 4096
  br label %34

30:                                               ; preds = %3
  %31 = icmp samesign ult i16 %25, 4096
  br i1 %31, label %34, label %32

32:                                               ; preds = %30
  %33 = add nsw i16 %25, -4096
  br label %34

34:                                               ; preds = %32, %30, %28
  %35 = phi i16 [ %29, %28 ], [ %33, %32 ], [ %25, %30 ]
  %36 = icmp slt i16 %26, 0
  br i1 %36, label %37, label %39

37:                                               ; preds = %34
  %38 = add nsw i16 %26, 3584
  br label %43

39:                                               ; preds = %34
  %40 = icmp samesign ult i16 %26, 3584
  br i1 %40, label %43, label %41

41:                                               ; preds = %39
  %42 = add nsw i16 %26, -3584
  br label %43

43:                                               ; preds = %41, %39, %37
  %44 = phi i16 [ %38, %37 ], [ %42, %41 ], [ %26, %39 ]
  store i16 %35, ptr %10, align 1, !tbaa !2
  store i16 %44, ptr %22, align 1, !tbaa !2
  %45 = add nuw nsw i8 %5, 1
  %46 = icmp eq i8 %45, 8
  %47 = add nuw nsw i8 %4, 8
  br i1 %46, label %48, label %3, !llvm.loop !12

48:                                               ; preds = %43
  %49 = add nuw nsw i8 %2, 1
  %50 = icmp eq i8 %49, 12
  br i1 %50, label %51, label %1, !llvm.loop !14

51:                                               ; preds = %48
  %52 = load i16, ptr @boids_gate_crc.gf, align 1, !tbaa !6
  %53 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), align 1, !tbaa !9
  %54 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), align 1, !tbaa !10
  %55 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), align 1, !tbaa !11
  %56 = tail call i16 @llvm.fshl.i16(i16 %52, i16 %52, i16 1)
  %57 = xor i16 %56, %53
  %58 = tail call i16 @llvm.fshl.i16(i16 %57, i16 %57, i16 1)
  %59 = xor i16 %58, %54
  %60 = tail call i16 @llvm.fshl.i16(i16 %59, i16 %59, i16 1)
  %61 = xor i16 %60, %55
  %62 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1, !tbaa !6
  %63 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1, !tbaa !9
  %64 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 12), align 1, !tbaa !10
  %65 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 14), align 1, !tbaa !11
  %66 = tail call i16 @llvm.fshl.i16(i16 %61, i16 %61, i16 1)
  %67 = xor i16 %62, %66
  %68 = tail call i16 @llvm.fshl.i16(i16 %67, i16 %67, i16 1)
  %69 = xor i16 %68, %63
  %70 = tail call i16 @llvm.fshl.i16(i16 %69, i16 %69, i16 1)
  %71 = xor i16 %70, %64
  %72 = tail call i16 @llvm.fshl.i16(i16 %71, i16 %71, i16 1)
  %73 = xor i16 %72, %65
  %74 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 16), align 1, !tbaa !6
  %75 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 18), align 1, !tbaa !9
  %76 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 20), align 1, !tbaa !10
  %77 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 22), align 1, !tbaa !11
  %78 = tail call i16 @llvm.fshl.i16(i16 %73, i16 %73, i16 1)
  %79 = xor i16 %74, %78
  %80 = tail call i16 @llvm.fshl.i16(i16 %79, i16 %79, i16 1)
  %81 = xor i16 %80, %75
  %82 = tail call i16 @llvm.fshl.i16(i16 %81, i16 %81, i16 1)
  %83 = xor i16 %82, %76
  %84 = tail call i16 @llvm.fshl.i16(i16 %83, i16 %83, i16 1)
  %85 = xor i16 %84, %77
  %86 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 24), align 1, !tbaa !6
  %87 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 26), align 1, !tbaa !9
  %88 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 28), align 1, !tbaa !10
  %89 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 30), align 1, !tbaa !11
  %90 = tail call i16 @llvm.fshl.i16(i16 %85, i16 %85, i16 1)
  %91 = xor i16 %86, %90
  %92 = tail call i16 @llvm.fshl.i16(i16 %91, i16 %91, i16 1)
  %93 = xor i16 %92, %87
  %94 = tail call i16 @llvm.fshl.i16(i16 %93, i16 %93, i16 1)
  %95 = xor i16 %94, %88
  %96 = tail call i16 @llvm.fshl.i16(i16 %95, i16 %95, i16 1)
  %97 = xor i16 %96, %89
  %98 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 32), align 1, !tbaa !6
  %99 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 34), align 1, !tbaa !9
  %100 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 36), align 1, !tbaa !10
  %101 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 38), align 1, !tbaa !11
  %102 = tail call i16 @llvm.fshl.i16(i16 %97, i16 %97, i16 1)
  %103 = xor i16 %98, %102
  %104 = tail call i16 @llvm.fshl.i16(i16 %103, i16 %103, i16 1)
  %105 = xor i16 %104, %99
  %106 = tail call i16 @llvm.fshl.i16(i16 %105, i16 %105, i16 1)
  %107 = xor i16 %106, %100
  %108 = tail call i16 @llvm.fshl.i16(i16 %107, i16 %107, i16 1)
  %109 = xor i16 %108, %101
  %110 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 40), align 1, !tbaa !6
  %111 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 42), align 1, !tbaa !9
  %112 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 44), align 1, !tbaa !10
  %113 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 46), align 1, !tbaa !11
  %114 = tail call i16 @llvm.fshl.i16(i16 %109, i16 %109, i16 1)
  %115 = xor i16 %110, %114
  %116 = tail call i16 @llvm.fshl.i16(i16 %115, i16 %115, i16 1)
  %117 = xor i16 %116, %111
  %118 = tail call i16 @llvm.fshl.i16(i16 %117, i16 %117, i16 1)
  %119 = xor i16 %118, %112
  %120 = tail call i16 @llvm.fshl.i16(i16 %119, i16 %119, i16 1)
  %121 = xor i16 %120, %113
  %122 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 48), align 1, !tbaa !6
  %123 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 50), align 1, !tbaa !9
  %124 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 52), align 1, !tbaa !10
  %125 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 54), align 1, !tbaa !11
  %126 = tail call i16 @llvm.fshl.i16(i16 %121, i16 %121, i16 1)
  %127 = xor i16 %122, %126
  %128 = tail call i16 @llvm.fshl.i16(i16 %127, i16 %127, i16 1)
  %129 = xor i16 %128, %123
  %130 = tail call i16 @llvm.fshl.i16(i16 %129, i16 %129, i16 1)
  %131 = xor i16 %130, %124
  %132 = tail call i16 @llvm.fshl.i16(i16 %131, i16 %131, i16 1)
  %133 = xor i16 %132, %125
  %134 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 56), align 1, !tbaa !6
  %135 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 58), align 1, !tbaa !9
  %136 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 60), align 1, !tbaa !10
  %137 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 62), align 1, !tbaa !11
  %138 = tail call i16 @llvm.fshl.i16(i16 %133, i16 %133, i16 1)
  %139 = xor i16 %134, %138
  %140 = tail call i16 @llvm.fshl.i16(i16 %139, i16 %139, i16 1)
  %141 = xor i16 %140, %135
  %142 = tail call i16 @llvm.fshl.i16(i16 %141, i16 %141, i16 1)
  %143 = xor i16 %142, %136
  %144 = tail call i16 @llvm.fshl.i16(i16 %143, i16 %143, i16 1)
  %145 = xor i16 %144, %137
  store volatile i16 %145, ptr @corpus_result, align 1, !tbaa !2
  br label %146

146:                                              ; preds = %146, %51
  tail call void asm sideeffect "wai", ""() #5, !srcloc !15
  br label %146
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(read, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_acc(i8 noundef zeroext %0) unnamed_addr #1 {
  %2 = tail call fastcc { i16, i16 } @boid_separation(i8 noundef zeroext %0)
  %3 = extractvalue { i16, i16 } %2, 0
  %4 = extractvalue { i16, i16 } %2, 1
  %5 = tail call fastcc { i16, i16 } @boid_alignment(i8 noundef zeroext %0)
  %6 = extractvalue { i16, i16 } %5, 0
  %7 = extractvalue { i16, i16 } %5, 1
  %8 = tail call fastcc { i16, i16 } @boid_cohesion(i8 noundef zeroext %0)
  %9 = extractvalue { i16, i16 } %8, 0
  %10 = extractvalue { i16, i16 } %8, 1
  %11 = tail call fastcc { i16, i16 } @v2_add(i16 %3, i16 %4, i16 %6, i16 %7)
  %12 = extractvalue { i16, i16 } %11, 0
  %13 = extractvalue { i16, i16 } %11, 1
  %14 = tail call fastcc { i16, i16 } @v2_add(i16 %12, i16 %13, i16 %9, i16 %10)
  %15 = extractvalue { i16, i16 } %14, 0
  %16 = extractvalue { i16, i16 } %14, 1
  %17 = zext i8 %0 to i16
  %18 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %17
  %19 = load i16, ptr %18, align 1
  %20 = getelementptr inbounds nuw i8, ptr %18, i16 2
  %21 = load i16, ptr %20, align 1
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 2048, i16 1792, i16 %19, i16 %21)
  %23 = extractvalue { i16, i16 } %22, 0
  %24 = extractvalue { i16, i16 } %22, 1
  %25 = tail call fastcc { i16, i16 } @v2_scale(i16 %23, i16 %24, i16 noundef 256)
  %26 = extractvalue { i16, i16 } %25, 0
  %27 = extractvalue { i16, i16 } %25, 1
  %28 = tail call fastcc { i16, i16 } @v2_add(i16 %15, i16 %16, i16 %26, i16 %27)
  %29 = extractvalue { i16, i16 } %28, 0
  %30 = extractvalue { i16, i16 } %28, 1
  %31 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %29, i16 %30, i16 noundef 14)
  ret { i16, i16 } %31
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define internal fastcc { i16, i16 } @v2_clampbox(i16 %0, i16 %1, i16 noundef range(i16 14, 41) %2) unnamed_addr #2 {
  %4 = icmp sgt i16 %0, %2
  br i1 %4, label %9, label %5

5:                                                ; preds = %3
  %6 = sub nsw i16 0, %2
  %7 = icmp slt i16 %0, %6
  br i1 %7, label %8, label %9

8:                                                ; preds = %5
  br label %9

9:                                                ; preds = %3, %5, %8
  %10 = phi i16 [ %0, %5 ], [ %6, %8 ], [ %2, %3 ]
  %11 = icmp sgt i16 %1, %2
  br i1 %11, label %16, label %12

12:                                               ; preds = %9
  %13 = sub nsw i16 0, %2
  %14 = icmp slt i16 %1, %13
  br i1 %14, label %15, label %16

15:                                               ; preds = %12
  br label %16

16:                                               ; preds = %9, %12, %15
  %17 = phi i16 [ %1, %12 ], [ %13, %15 ], [ %2, %9 ]
  %18 = insertvalue { i16, i16 } poison, i16 %10, 0
  %19 = insertvalue { i16, i16 } %18, i16 %17, 1
  ret { i16, i16 } %19
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define internal fastcc { i16, i16 } @v2_add(i16 %0, i16 %1, i16 range(i16 -2048, 2048) %2, i16 range(i16 -2048, 2048) %3) unnamed_addr #2 {
  %5 = add i16 %2, %0
  %6 = add i16 %3, %1
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_separation(i8 noundef zeroext %0) unnamed_addr #3 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %9

7:                                                ; preds = %33
  %8 = tail call fastcc { i16, i16 } @v2_scale(i16 %35, i16 %34, i16 noundef 40)
  ret { i16, i16 } %8

9:                                                ; preds = %1, %33
  %10 = phi i8 [ 0, %1 ], [ %38, %33 ]
  %11 = phi i16 [ 0, %1 ], [ %35, %33 ]
  %12 = phi i16 [ 0, %1 ], [ %34, %33 ]
  %13 = phi i8 [ 0, %1 ], [ %36, %33 ]
  %14 = icmp eq i8 %13, %0
  br i1 %14, label %33, label %15

15:                                               ; preds = %9
  %16 = zext nneg i8 %10 to i16
  %17 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %16
  %18 = load i16, ptr %17, align 1
  %19 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %16
  %20 = load i16, ptr %19, align 1
  %21 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %18, i16 %20)
  %22 = extractvalue { i16, i16 } %21, 0
  %23 = extractvalue { i16, i16 } %21, 1
  %24 = sext i16 %22 to i32
  %25 = mul nsw i32 %24, %24
  %26 = sext i16 %23 to i32
  %27 = mul nsw i32 %26, %26
  %28 = add nuw nsw i32 %27, %25
  %29 = icmp samesign ult i32 %28, 65536
  br i1 %29, label %30, label %33

30:                                               ; preds = %15
  %31 = add i16 %22, %11
  %32 = add i16 %23, %12
  br label %33

33:                                               ; preds = %15, %30, %9
  %34 = phi i16 [ %12, %9 ], [ %32, %30 ], [ %12, %15 ]
  %35 = phi i16 [ %11, %9 ], [ %31, %30 ], [ %11, %15 ]
  %36 = add nuw nsw i8 %13, 1
  %37 = icmp eq i8 %36, 8
  %38 = add nuw nsw i8 %10, 8
  br i1 %37, label %7, label %9, !llvm.loop !16
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_alignment(i8 noundef zeroext %0) unnamed_addr #3 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %9

7:                                                ; preds = %41
  %8 = icmp eq i16 %42, 0
  br i1 %8, label %64, label %48

9:                                                ; preds = %1, %41
  %10 = phi i8 [ 0, %1 ], [ %47, %41 ]
  %11 = phi i32 [ 0, %1 ], [ %44, %41 ]
  %12 = phi i32 [ 0, %1 ], [ %43, %41 ]
  %13 = phi i16 [ 0, %1 ], [ %42, %41 ]
  %14 = phi i8 [ 0, %1 ], [ %45, %41 ]
  %15 = icmp eq i8 %14, %0
  br i1 %15, label %41, label %16

16:                                               ; preds = %9
  %17 = zext nneg i8 %10 to i16
  %18 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %17
  %19 = load i16, ptr %18, align 1
  %20 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %17
  %21 = load i16, ptr %20, align 1
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 %19, i16 %21, i16 %4, i16 %6)
  %23 = extractvalue { i16, i16 } %22, 0
  %24 = extractvalue { i16, i16 } %22, 1
  %25 = sext i16 %23 to i32
  %26 = mul nsw i32 %25, %25
  %27 = sext i16 %24 to i32
  %28 = mul nsw i32 %27, %27
  %29 = add nuw nsw i32 %28, %26
  %30 = icmp samesign ult i32 %29, 589824
  br i1 %30, label %31, label %41

31:                                               ; preds = %16
  %32 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %17
  %33 = load i16, ptr %32, align 1, !tbaa !10
  %34 = sext i16 %33 to i32
  %35 = add nsw i32 %11, %34
  %36 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %17
  %37 = load i16, ptr %36, align 1, !tbaa !11
  %38 = sext i16 %37 to i32
  %39 = add nsw i32 %12, %38
  %40 = add nsw i16 %13, 1
  br label %41

41:                                               ; preds = %16, %31, %9
  %42 = phi i16 [ %13, %9 ], [ %40, %31 ], [ %13, %16 ]
  %43 = phi i32 [ %12, %9 ], [ %39, %31 ], [ %12, %16 ]
  %44 = phi i32 [ %11, %9 ], [ %35, %31 ], [ %11, %16 ]
  %45 = add nuw nsw i8 %14, 1
  %46 = icmp eq i8 %45, 8
  %47 = add nuw nsw i8 %10, 8
  br i1 %46, label %7, label %9, !llvm.loop !17

48:                                               ; preds = %7
  %49 = sext i16 %42 to i32
  %50 = sdiv i32 %44, %49
  %51 = trunc i32 %50 to i16
  %52 = sdiv i32 %43, %49
  %53 = trunc i32 %52 to i16
  %54 = getelementptr inbounds nuw i8, ptr %3, i16 4
  %55 = load i16, ptr %54, align 1
  %56 = getelementptr inbounds nuw i8, ptr %3, i16 6
  %57 = load i16, ptr %56, align 1
  %58 = tail call fastcc { i16, i16 } @v2_sub(i16 %51, i16 %53, i16 %55, i16 %57)
  %59 = extractvalue { i16, i16 } %58, 0
  %60 = extractvalue { i16, i16 } %58, 1
  %61 = tail call fastcc { i16, i16 } @v2_scale(i16 %59, i16 %60, i16 noundef 16)
  %62 = extractvalue { i16, i16 } %61, 0
  %63 = extractvalue { i16, i16 } %61, 1
  br label %64

64:                                               ; preds = %7, %48
  %65 = phi i16 [ %63, %48 ], [ 0, %7 ]
  %66 = phi i16 [ %62, %48 ], [ 0, %7 ]
  %67 = insertvalue { i16, i16 } poison, i16 %66, 0
  %68 = insertvalue { i16, i16 } %67, i16 %65, 1
  ret { i16, i16 } %68
}

; Function Attrs: nofree noinline norecurse nosync nounwind memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_cohesion(i8 noundef zeroext %0) unnamed_addr #3 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %9

7:                                                ; preds = %37
  %8 = icmp eq i16 %38, 0
  br i1 %8, label %56, label %44

9:                                                ; preds = %1, %37
  %10 = phi i8 [ 0, %1 ], [ %43, %37 ]
  %11 = phi i32 [ 0, %1 ], [ %40, %37 ]
  %12 = phi i32 [ 0, %1 ], [ %39, %37 ]
  %13 = phi i16 [ 0, %1 ], [ %38, %37 ]
  %14 = phi i8 [ 0, %1 ], [ %41, %37 ]
  %15 = icmp eq i8 %14, %0
  br i1 %15, label %37, label %16

16:                                               ; preds = %9
  %17 = zext nneg i8 %10 to i16
  %18 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %17
  %19 = load i16, ptr %18, align 1
  %20 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %17
  %21 = load i16, ptr %20, align 1
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 %19, i16 %21, i16 %4, i16 %6)
  %23 = extractvalue { i16, i16 } %22, 0
  %24 = extractvalue { i16, i16 } %22, 1
  %25 = sext i16 %23 to i32
  %26 = mul nsw i32 %25, %25
  %27 = sext i16 %24 to i32
  %28 = mul nsw i32 %27, %27
  %29 = add nuw nsw i32 %28, %26
  %30 = icmp samesign ult i32 %29, 589824
  br i1 %30, label %31, label %37

31:                                               ; preds = %16
  %32 = sext i16 %19 to i32
  %33 = add nsw i32 %11, %32
  %34 = sext i16 %21 to i32
  %35 = add nsw i32 %12, %34
  %36 = add nsw i16 %13, 1
  br label %37

37:                                               ; preds = %16, %31, %9
  %38 = phi i16 [ %13, %9 ], [ %36, %31 ], [ %13, %16 ]
  %39 = phi i32 [ %12, %9 ], [ %35, %31 ], [ %12, %16 ]
  %40 = phi i32 [ %11, %9 ], [ %33, %31 ], [ %11, %16 ]
  %41 = add nuw nsw i8 %14, 1
  %42 = icmp eq i8 %41, 8
  %43 = add nuw nsw i8 %10, 8
  br i1 %42, label %7, label %9, !llvm.loop !18

44:                                               ; preds = %7
  %45 = sext i16 %38 to i32
  %46 = sdiv i32 %40, %45
  %47 = trunc i32 %46 to i16
  %48 = sdiv i32 %39, %45
  %49 = trunc i32 %48 to i16
  %50 = tail call fastcc { i16, i16 } @v2_sub(i16 %47, i16 %49, i16 %4, i16 %6)
  %51 = extractvalue { i16, i16 } %50, 0
  %52 = extractvalue { i16, i16 } %50, 1
  %53 = tail call fastcc { i16, i16 } @v2_scale(i16 %51, i16 %52, i16 noundef 40)
  %54 = extractvalue { i16, i16 } %53, 0
  %55 = extractvalue { i16, i16 } %53, 1
  br label %56

56:                                               ; preds = %7, %44
  %57 = phi i16 [ %55, %44 ], [ 0, %7 ]
  %58 = phi i16 [ %54, %44 ], [ 0, %7 ]
  %59 = insertvalue { i16, i16 } poison, i16 %58, 0
  %60 = insertvalue { i16, i16 } %59, i16 %57, 1
  ret { i16, i16 } %60
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define internal fastcc { i16, i16 } @v2_scale(i16 %0, i16 %1, i16 noundef range(i16 16, 257) %2) unnamed_addr #2 {
  %4 = sdiv i16 %0, %2
  %5 = sdiv i16 %1, %2
  %6 = insertvalue { i16, i16 } poison, i16 %4, 0
  %7 = insertvalue { i16, i16 } %6, i16 %5, 1
  ret { i16, i16 } %7
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define internal fastcc { i16, i16 } @v2_sub(i16 %0, i16 %1, i16 %2, i16 %3) unnamed_addr #2 {
  %5 = sub i16 %0, %2
  %6 = sub i16 %1, %3
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #4

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nofree noinline norecurse nosync nounwind memory(read, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nofree noinline norecurse nosync nounwind memory(read, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #4 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #5 = { nounwind }

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
!7 = !{!"", !8, i64 0, !8, i64 4}
!8 = !{!"", !3, i64 0, !3, i64 2}
!9 = !{!7, !3, i64 2}
!10 = !{!7, !3, i64 4}
!11 = !{!7, !3, i64 6}
!12 = distinct !{!12, !13}
!13 = !{!"llvm.loop.mustprogress"}
!14 = distinct !{!14, !13}
!15 = !{i64 957}
!16 = distinct !{!16, !13}
!17 = distinct !{!17, !13}
!18 = distinct !{!18, !13}

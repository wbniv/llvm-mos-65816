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
  %57 = xor i16 %53, %56
  %58 = tail call i16 @llvm.fshl.i16(i16 %57, i16 %57, i16 1)
  %59 = xor i16 %58, %54
  %60 = tail call i16 @llvm.fshl.i16(i16 %59, i16 %59, i16 1)
  %61 = xor i16 %60, %55
  %62 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1, !tbaa !6
  %63 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1, !tbaa !9
  %64 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 12), align 1, !tbaa !10
  %65 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 14), align 1, !tbaa !11
  %66 = tail call i16 @llvm.fshl.i16(i16 %61, i16 %61, i16 1)
  %67 = xor i16 %66, %62
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
  %79 = xor i16 %78, %74
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
  %91 = xor i16 %90, %86
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
  %103 = xor i16 %102, %98
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
  %115 = xor i16 %114, %110
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
  %127 = xor i16 %126, %122
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
  %139 = xor i16 %138, %134
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

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none, target_mem: none)
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

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_separation(i8 noundef zeroext %0) unnamed_addr #3 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = icmp eq i8 %0, 0
  br i1 %7, label %25, label %8

8:                                                ; preds = %1
  %9 = load i16, ptr @boids_gate_crc.gf, align 1
  %10 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), align 1
  %11 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %9, i16 %10)
  %12 = extractvalue { i16, i16 } %11, 0
  %13 = extractvalue { i16, i16 } %11, 1
  %14 = sext i16 %12 to i32
  %15 = mul nsw i32 %14, %14
  %16 = sext i16 %13 to i32
  %17 = mul nsw i32 %16, %16
  %18 = add nuw nsw i32 %17, %15
  %19 = icmp samesign ult i32 %18, 65536
  br i1 %19, label %20, label %21

20:                                               ; preds = %8
  br label %21

21:                                               ; preds = %8, %20
  %22 = phi i16 [ 0, %8 ], [ %13, %20 ]
  %23 = phi i16 [ 0, %8 ], [ %12, %20 ]
  %24 = icmp eq i8 %0, 1
  br i1 %24, label %46, label %25

25:                                               ; preds = %1, %21
  %26 = phi i16 [ %23, %21 ], [ 0, %1 ]
  %27 = phi i16 [ %22, %21 ], [ 0, %1 ]
  %28 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1
  %29 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1
  %30 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %28, i16 %29)
  %31 = extractvalue { i16, i16 } %30, 0
  %32 = extractvalue { i16, i16 } %30, 1
  %33 = sext i16 %31 to i32
  %34 = mul nsw i32 %33, %33
  %35 = sext i16 %32 to i32
  %36 = mul nsw i32 %35, %35
  %37 = add nuw nsw i32 %36, %34
  %38 = icmp samesign ult i32 %37, 65536
  br i1 %38, label %39, label %42

39:                                               ; preds = %25
  %40 = add i16 %31, %26
  %41 = add i16 %32, %27
  br label %42

42:                                               ; preds = %39, %25
  %43 = phi i16 [ %27, %25 ], [ %41, %39 ]
  %44 = phi i16 [ %26, %25 ], [ %40, %39 ]
  %45 = icmp eq i8 %0, 2
  br i1 %45, label %67, label %46

46:                                               ; preds = %21, %42
  %47 = phi i16 [ %44, %42 ], [ %23, %21 ]
  %48 = phi i16 [ %43, %42 ], [ %22, %21 ]
  %49 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 16), align 1
  %50 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 18), align 1
  %51 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %49, i16 %50)
  %52 = extractvalue { i16, i16 } %51, 0
  %53 = extractvalue { i16, i16 } %51, 1
  %54 = sext i16 %52 to i32
  %55 = mul nsw i32 %54, %54
  %56 = sext i16 %53 to i32
  %57 = mul nsw i32 %56, %56
  %58 = add nuw nsw i32 %57, %55
  %59 = icmp samesign ult i32 %58, 65536
  br i1 %59, label %60, label %63

60:                                               ; preds = %46
  %61 = add i16 %52, %47
  %62 = add i16 %53, %48
  br label %63

63:                                               ; preds = %60, %46
  %64 = phi i16 [ %48, %46 ], [ %62, %60 ]
  %65 = phi i16 [ %47, %46 ], [ %61, %60 ]
  %66 = icmp eq i8 %0, 3
  br i1 %66, label %88, label %67

67:                                               ; preds = %42, %63
  %68 = phi i16 [ %65, %63 ], [ %44, %42 ]
  %69 = phi i16 [ %64, %63 ], [ %43, %42 ]
  %70 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 24), align 1
  %71 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 26), align 1
  %72 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %70, i16 %71)
  %73 = extractvalue { i16, i16 } %72, 0
  %74 = extractvalue { i16, i16 } %72, 1
  %75 = sext i16 %73 to i32
  %76 = mul nsw i32 %75, %75
  %77 = sext i16 %74 to i32
  %78 = mul nsw i32 %77, %77
  %79 = add nuw nsw i32 %78, %76
  %80 = icmp samesign ult i32 %79, 65536
  br i1 %80, label %81, label %84

81:                                               ; preds = %67
  %82 = add i16 %73, %68
  %83 = add i16 %74, %69
  br label %84

84:                                               ; preds = %81, %67
  %85 = phi i16 [ %69, %67 ], [ %83, %81 ]
  %86 = phi i16 [ %68, %67 ], [ %82, %81 ]
  %87 = icmp eq i8 %0, 4
  br i1 %87, label %109, label %88

88:                                               ; preds = %63, %84
  %89 = phi i16 [ %86, %84 ], [ %65, %63 ]
  %90 = phi i16 [ %85, %84 ], [ %64, %63 ]
  %91 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 32), align 1
  %92 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 34), align 1
  %93 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %91, i16 %92)
  %94 = extractvalue { i16, i16 } %93, 0
  %95 = extractvalue { i16, i16 } %93, 1
  %96 = sext i16 %94 to i32
  %97 = mul nsw i32 %96, %96
  %98 = sext i16 %95 to i32
  %99 = mul nsw i32 %98, %98
  %100 = add nuw nsw i32 %99, %97
  %101 = icmp samesign ult i32 %100, 65536
  br i1 %101, label %102, label %105

102:                                              ; preds = %88
  %103 = add i16 %94, %89
  %104 = add i16 %95, %90
  br label %105

105:                                              ; preds = %102, %88
  %106 = phi i16 [ %90, %88 ], [ %104, %102 ]
  %107 = phi i16 [ %89, %88 ], [ %103, %102 ]
  %108 = icmp eq i8 %0, 5
  br i1 %108, label %130, label %109

109:                                              ; preds = %84, %105
  %110 = phi i16 [ %107, %105 ], [ %86, %84 ]
  %111 = phi i16 [ %106, %105 ], [ %85, %84 ]
  %112 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 40), align 1
  %113 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 42), align 1
  %114 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %112, i16 %113)
  %115 = extractvalue { i16, i16 } %114, 0
  %116 = extractvalue { i16, i16 } %114, 1
  %117 = sext i16 %115 to i32
  %118 = mul nsw i32 %117, %117
  %119 = sext i16 %116 to i32
  %120 = mul nsw i32 %119, %119
  %121 = add nuw nsw i32 %120, %118
  %122 = icmp samesign ult i32 %121, 65536
  br i1 %122, label %123, label %126

123:                                              ; preds = %109
  %124 = add i16 %115, %110
  %125 = add i16 %116, %111
  br label %126

126:                                              ; preds = %123, %109
  %127 = phi i16 [ %111, %109 ], [ %125, %123 ]
  %128 = phi i16 [ %110, %109 ], [ %124, %123 ]
  %129 = icmp eq i8 %0, 6
  br i1 %129, label %151, label %130

130:                                              ; preds = %105, %126
  %131 = phi i16 [ %128, %126 ], [ %107, %105 ]
  %132 = phi i16 [ %127, %126 ], [ %106, %105 ]
  %133 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 48), align 1
  %134 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 50), align 1
  %135 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %133, i16 %134)
  %136 = extractvalue { i16, i16 } %135, 0
  %137 = extractvalue { i16, i16 } %135, 1
  %138 = sext i16 %136 to i32
  %139 = mul nsw i32 %138, %138
  %140 = sext i16 %137 to i32
  %141 = mul nsw i32 %140, %140
  %142 = add nuw nsw i32 %141, %139
  %143 = icmp samesign ult i32 %142, 65536
  br i1 %143, label %144, label %147

144:                                              ; preds = %130
  %145 = add i16 %136, %131
  %146 = add i16 %137, %132
  br label %147

147:                                              ; preds = %144, %130
  %148 = phi i16 [ %132, %130 ], [ %146, %144 ]
  %149 = phi i16 [ %131, %130 ], [ %145, %144 ]
  %150 = icmp eq i8 %0, 7
  br i1 %150, label %168, label %151

151:                                              ; preds = %126, %147
  %152 = phi i16 [ %149, %147 ], [ %128, %126 ]
  %153 = phi i16 [ %148, %147 ], [ %127, %126 ]
  %154 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 56), align 1
  %155 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 58), align 1
  %156 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %154, i16 %155)
  %157 = extractvalue { i16, i16 } %156, 0
  %158 = extractvalue { i16, i16 } %156, 1
  %159 = sext i16 %157 to i32
  %160 = mul nsw i32 %159, %159
  %161 = sext i16 %158 to i32
  %162 = mul nsw i32 %161, %161
  %163 = add nuw nsw i32 %162, %160
  %164 = icmp samesign ult i32 %163, 65536
  br i1 %164, label %165, label %168

165:                                              ; preds = %151
  %166 = add i16 %157, %152
  %167 = add i16 %158, %153
  br label %168

168:                                              ; preds = %165, %151, %147
  %169 = phi i16 [ %148, %147 ], [ %167, %165 ], [ %153, %151 ]
  %170 = phi i16 [ %149, %147 ], [ %166, %165 ], [ %152, %151 ]
  %171 = tail call fastcc { i16, i16 } @v2_scale(i16 %170, i16 %169, i16 noundef 40)
  ret { i16, i16 } %171
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_alignment(i8 noundef zeroext %0) unnamed_addr #3 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = icmp eq i8 %0, 0
  br i1 %7, label %30, label %8

8:                                                ; preds = %1
  %9 = load i16, ptr @boids_gate_crc.gf, align 1
  %10 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), align 1
  %11 = tail call fastcc { i16, i16 } @v2_sub(i16 %9, i16 %10, i16 %4, i16 %6)
  %12 = extractvalue { i16, i16 } %11, 0
  %13 = extractvalue { i16, i16 } %11, 1
  %14 = sext i16 %12 to i32
  %15 = mul nsw i32 %14, %14
  %16 = sext i16 %13 to i32
  %17 = mul nsw i32 %16, %16
  %18 = add nuw nsw i32 %17, %15
  %19 = icmp samesign ult i32 %18, 589824
  br i1 %19, label %20, label %25

20:                                               ; preds = %8
  %21 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), align 1, !tbaa !10
  %22 = sext i16 %21 to i32
  %23 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), align 1, !tbaa !11
  %24 = sext i16 %23 to i32
  br label %25

25:                                               ; preds = %8, %20
  %26 = phi i16 [ 0, %8 ], [ 1, %20 ]
  %27 = phi i32 [ 0, %8 ], [ %24, %20 ]
  %28 = phi i32 [ 0, %8 ], [ %22, %20 ]
  %29 = icmp eq i8 %0, 1
  br i1 %29, label %58, label %30

30:                                               ; preds = %1, %25
  %31 = phi i32 [ %28, %25 ], [ 0, %1 ]
  %32 = phi i32 [ %27, %25 ], [ 0, %1 ]
  %33 = phi i16 [ %26, %25 ], [ 0, %1 ]
  %34 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1
  %35 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1
  %36 = tail call fastcc { i16, i16 } @v2_sub(i16 %34, i16 %35, i16 %4, i16 %6)
  %37 = extractvalue { i16, i16 } %36, 0
  %38 = extractvalue { i16, i16 } %36, 1
  %39 = sext i16 %37 to i32
  %40 = mul nsw i32 %39, %39
  %41 = sext i16 %38 to i32
  %42 = mul nsw i32 %41, %41
  %43 = add nuw nsw i32 %42, %40
  %44 = icmp samesign ult i32 %43, 589824
  br i1 %44, label %45, label %53

45:                                               ; preds = %30
  %46 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 12), align 1, !tbaa !10
  %47 = sext i16 %46 to i32
  %48 = add nsw i32 %31, %47
  %49 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 14), align 1, !tbaa !11
  %50 = sext i16 %49 to i32
  %51 = add nsw i32 %32, %50
  %52 = add nuw nsw i16 %33, 1
  br label %53

53:                                               ; preds = %45, %30
  %54 = phi i16 [ %33, %30 ], [ %52, %45 ]
  %55 = phi i32 [ %32, %30 ], [ %51, %45 ]
  %56 = phi i32 [ %31, %30 ], [ %48, %45 ]
  %57 = icmp eq i8 %0, 2
  br i1 %57, label %86, label %58

58:                                               ; preds = %25, %53
  %59 = phi i32 [ %56, %53 ], [ %28, %25 ]
  %60 = phi i32 [ %55, %53 ], [ %27, %25 ]
  %61 = phi i16 [ %54, %53 ], [ %26, %25 ]
  %62 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 16), align 1
  %63 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 18), align 1
  %64 = tail call fastcc { i16, i16 } @v2_sub(i16 %62, i16 %63, i16 %4, i16 %6)
  %65 = extractvalue { i16, i16 } %64, 0
  %66 = extractvalue { i16, i16 } %64, 1
  %67 = sext i16 %65 to i32
  %68 = mul nsw i32 %67, %67
  %69 = sext i16 %66 to i32
  %70 = mul nsw i32 %69, %69
  %71 = add nuw nsw i32 %70, %68
  %72 = icmp samesign ult i32 %71, 589824
  br i1 %72, label %73, label %81

73:                                               ; preds = %58
  %74 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 20), align 1, !tbaa !10
  %75 = sext i16 %74 to i32
  %76 = add nsw i32 %59, %75
  %77 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 22), align 1, !tbaa !11
  %78 = sext i16 %77 to i32
  %79 = add nsw i32 %60, %78
  %80 = add nuw nsw i16 %61, 1
  br label %81

81:                                               ; preds = %73, %58
  %82 = phi i16 [ %61, %58 ], [ %80, %73 ]
  %83 = phi i32 [ %60, %58 ], [ %79, %73 ]
  %84 = phi i32 [ %59, %58 ], [ %76, %73 ]
  %85 = icmp eq i8 %0, 3
  br i1 %85, label %114, label %86

86:                                               ; preds = %53, %81
  %87 = phi i32 [ %84, %81 ], [ %56, %53 ]
  %88 = phi i32 [ %83, %81 ], [ %55, %53 ]
  %89 = phi i16 [ %82, %81 ], [ %54, %53 ]
  %90 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 24), align 1
  %91 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 26), align 1
  %92 = tail call fastcc { i16, i16 } @v2_sub(i16 %90, i16 %91, i16 %4, i16 %6)
  %93 = extractvalue { i16, i16 } %92, 0
  %94 = extractvalue { i16, i16 } %92, 1
  %95 = sext i16 %93 to i32
  %96 = mul nsw i32 %95, %95
  %97 = sext i16 %94 to i32
  %98 = mul nsw i32 %97, %97
  %99 = add nuw nsw i32 %98, %96
  %100 = icmp samesign ult i32 %99, 589824
  br i1 %100, label %101, label %109

101:                                              ; preds = %86
  %102 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 28), align 1, !tbaa !10
  %103 = sext i16 %102 to i32
  %104 = add nsw i32 %87, %103
  %105 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 30), align 1, !tbaa !11
  %106 = sext i16 %105 to i32
  %107 = add nsw i32 %88, %106
  %108 = add nuw nsw i16 %89, 1
  br label %109

109:                                              ; preds = %101, %86
  %110 = phi i16 [ %89, %86 ], [ %108, %101 ]
  %111 = phi i32 [ %88, %86 ], [ %107, %101 ]
  %112 = phi i32 [ %87, %86 ], [ %104, %101 ]
  %113 = icmp eq i8 %0, 4
  br i1 %113, label %142, label %114

114:                                              ; preds = %81, %109
  %115 = phi i32 [ %112, %109 ], [ %84, %81 ]
  %116 = phi i32 [ %111, %109 ], [ %83, %81 ]
  %117 = phi i16 [ %110, %109 ], [ %82, %81 ]
  %118 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 32), align 1
  %119 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 34), align 1
  %120 = tail call fastcc { i16, i16 } @v2_sub(i16 %118, i16 %119, i16 %4, i16 %6)
  %121 = extractvalue { i16, i16 } %120, 0
  %122 = extractvalue { i16, i16 } %120, 1
  %123 = sext i16 %121 to i32
  %124 = mul nsw i32 %123, %123
  %125 = sext i16 %122 to i32
  %126 = mul nsw i32 %125, %125
  %127 = add nuw nsw i32 %126, %124
  %128 = icmp samesign ult i32 %127, 589824
  br i1 %128, label %129, label %137

129:                                              ; preds = %114
  %130 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 36), align 1, !tbaa !10
  %131 = sext i16 %130 to i32
  %132 = add nsw i32 %115, %131
  %133 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 38), align 1, !tbaa !11
  %134 = sext i16 %133 to i32
  %135 = add nsw i32 %116, %134
  %136 = add nuw nsw i16 %117, 1
  br label %137

137:                                              ; preds = %129, %114
  %138 = phi i16 [ %117, %114 ], [ %136, %129 ]
  %139 = phi i32 [ %116, %114 ], [ %135, %129 ]
  %140 = phi i32 [ %115, %114 ], [ %132, %129 ]
  %141 = icmp eq i8 %0, 5
  br i1 %141, label %170, label %142

142:                                              ; preds = %109, %137
  %143 = phi i32 [ %140, %137 ], [ %112, %109 ]
  %144 = phi i32 [ %139, %137 ], [ %111, %109 ]
  %145 = phi i16 [ %138, %137 ], [ %110, %109 ]
  %146 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 40), align 1
  %147 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 42), align 1
  %148 = tail call fastcc { i16, i16 } @v2_sub(i16 %146, i16 %147, i16 %4, i16 %6)
  %149 = extractvalue { i16, i16 } %148, 0
  %150 = extractvalue { i16, i16 } %148, 1
  %151 = sext i16 %149 to i32
  %152 = mul nsw i32 %151, %151
  %153 = sext i16 %150 to i32
  %154 = mul nsw i32 %153, %153
  %155 = add nuw nsw i32 %154, %152
  %156 = icmp samesign ult i32 %155, 589824
  br i1 %156, label %157, label %165

157:                                              ; preds = %142
  %158 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 44), align 1, !tbaa !10
  %159 = sext i16 %158 to i32
  %160 = add nsw i32 %143, %159
  %161 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 46), align 1, !tbaa !11
  %162 = sext i16 %161 to i32
  %163 = add nsw i32 %144, %162
  %164 = add nuw nsw i16 %145, 1
  br label %165

165:                                              ; preds = %157, %142
  %166 = phi i16 [ %145, %142 ], [ %164, %157 ]
  %167 = phi i32 [ %144, %142 ], [ %163, %157 ]
  %168 = phi i32 [ %143, %142 ], [ %160, %157 ]
  %169 = icmp eq i8 %0, 6
  br i1 %169, label %198, label %170

170:                                              ; preds = %137, %165
  %171 = phi i32 [ %168, %165 ], [ %140, %137 ]
  %172 = phi i32 [ %167, %165 ], [ %139, %137 ]
  %173 = phi i16 [ %166, %165 ], [ %138, %137 ]
  %174 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 48), align 1
  %175 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 50), align 1
  %176 = tail call fastcc { i16, i16 } @v2_sub(i16 %174, i16 %175, i16 %4, i16 %6)
  %177 = extractvalue { i16, i16 } %176, 0
  %178 = extractvalue { i16, i16 } %176, 1
  %179 = sext i16 %177 to i32
  %180 = mul nsw i32 %179, %179
  %181 = sext i16 %178 to i32
  %182 = mul nsw i32 %181, %181
  %183 = add nuw nsw i32 %182, %180
  %184 = icmp samesign ult i32 %183, 589824
  br i1 %184, label %185, label %193

185:                                              ; preds = %170
  %186 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 52), align 1, !tbaa !10
  %187 = sext i16 %186 to i32
  %188 = add nsw i32 %171, %187
  %189 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 54), align 1, !tbaa !11
  %190 = sext i16 %189 to i32
  %191 = add nsw i32 %172, %190
  %192 = add nuw nsw i16 %173, 1
  br label %193

193:                                              ; preds = %185, %170
  %194 = phi i16 [ %173, %170 ], [ %192, %185 ]
  %195 = phi i32 [ %172, %170 ], [ %191, %185 ]
  %196 = phi i32 [ %171, %170 ], [ %188, %185 ]
  %197 = icmp eq i8 %0, 7
  br i1 %197, label %221, label %198

198:                                              ; preds = %165, %193
  %199 = phi i32 [ %196, %193 ], [ %168, %165 ]
  %200 = phi i32 [ %195, %193 ], [ %167, %165 ]
  %201 = phi i16 [ %194, %193 ], [ %166, %165 ]
  %202 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 56), align 1
  %203 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 58), align 1
  %204 = tail call fastcc { i16, i16 } @v2_sub(i16 %202, i16 %203, i16 %4, i16 %6)
  %205 = extractvalue { i16, i16 } %204, 0
  %206 = extractvalue { i16, i16 } %204, 1
  %207 = sext i16 %205 to i32
  %208 = mul nsw i32 %207, %207
  %209 = sext i16 %206 to i32
  %210 = mul nsw i32 %209, %209
  %211 = add nuw nsw i32 %210, %208
  %212 = icmp samesign ult i32 %211, 589824
  br i1 %212, label %213, label %221

213:                                              ; preds = %198
  %214 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 60), align 1, !tbaa !10
  %215 = sext i16 %214 to i32
  %216 = add nsw i32 %199, %215
  %217 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 62), align 1, !tbaa !11
  %218 = sext i16 %217 to i32
  %219 = add nsw i32 %200, %218
  %220 = add nuw nsw i16 %201, 1
  br label %226

221:                                              ; preds = %198, %193
  %222 = phi i16 [ %194, %193 ], [ %201, %198 ]
  %223 = phi i32 [ %195, %193 ], [ %200, %198 ]
  %224 = phi i32 [ %196, %193 ], [ %199, %198 ]
  %225 = icmp eq i16 %222, 0
  br i1 %225, label %245, label %226

226:                                              ; preds = %213, %221
  %227 = phi i32 [ %216, %213 ], [ %224, %221 ]
  %228 = phi i32 [ %219, %213 ], [ %223, %221 ]
  %229 = phi i16 [ %220, %213 ], [ %222, %221 ]
  %230 = zext nneg i16 %229 to i32
  %231 = sdiv i32 %227, %230
  %232 = trunc i32 %231 to i16
  %233 = sdiv i32 %228, %230
  %234 = trunc i32 %233 to i16
  %235 = getelementptr inbounds nuw i8, ptr %3, i16 4
  %236 = load i16, ptr %235, align 1
  %237 = getelementptr inbounds nuw i8, ptr %3, i16 6
  %238 = load i16, ptr %237, align 1
  %239 = tail call fastcc { i16, i16 } @v2_sub(i16 %232, i16 %234, i16 %236, i16 %238)
  %240 = extractvalue { i16, i16 } %239, 0
  %241 = extractvalue { i16, i16 } %239, 1
  %242 = tail call fastcc { i16, i16 } @v2_scale(i16 %240, i16 %241, i16 noundef 16)
  %243 = extractvalue { i16, i16 } %242, 0
  %244 = extractvalue { i16, i16 } %242, 1
  br label %245

245:                                              ; preds = %221, %226
  %246 = phi i16 [ %244, %226 ], [ 0, %221 ]
  %247 = phi i16 [ %243, %226 ], [ 0, %221 ]
  %248 = insertvalue { i16, i16 } poison, i16 %247, 0
  %249 = insertvalue { i16, i16 } %248, i16 %246, 1
  ret { i16, i16 } %249
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_cohesion(i8 noundef zeroext %0) unnamed_addr #3 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  %7 = icmp eq i8 %0, 0
  br i1 %7, label %28, label %8

8:                                                ; preds = %1
  %9 = load i16, ptr @boids_gate_crc.gf, align 1
  %10 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), align 1
  %11 = tail call fastcc { i16, i16 } @v2_sub(i16 %9, i16 %10, i16 %4, i16 %6)
  %12 = extractvalue { i16, i16 } %11, 0
  %13 = extractvalue { i16, i16 } %11, 1
  %14 = sext i16 %12 to i32
  %15 = mul nsw i32 %14, %14
  %16 = sext i16 %13 to i32
  %17 = mul nsw i32 %16, %16
  %18 = add nuw nsw i32 %17, %15
  %19 = icmp samesign ult i32 %18, 589824
  br i1 %19, label %20, label %23

20:                                               ; preds = %8
  %21 = sext i16 %9 to i32
  %22 = sext i16 %10 to i32
  br label %23

23:                                               ; preds = %8, %20
  %24 = phi i16 [ 0, %8 ], [ 1, %20 ]
  %25 = phi i32 [ 0, %8 ], [ %22, %20 ]
  %26 = phi i32 [ 0, %8 ], [ %21, %20 ]
  %27 = icmp eq i8 %0, 1
  br i1 %27, label %54, label %28

28:                                               ; preds = %1, %23
  %29 = phi i32 [ %26, %23 ], [ 0, %1 ]
  %30 = phi i32 [ %25, %23 ], [ 0, %1 ]
  %31 = phi i16 [ %24, %23 ], [ 0, %1 ]
  %32 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 8), align 1
  %33 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 10), align 1
  %34 = tail call fastcc { i16, i16 } @v2_sub(i16 %32, i16 %33, i16 %4, i16 %6)
  %35 = extractvalue { i16, i16 } %34, 0
  %36 = extractvalue { i16, i16 } %34, 1
  %37 = sext i16 %35 to i32
  %38 = mul nsw i32 %37, %37
  %39 = sext i16 %36 to i32
  %40 = mul nsw i32 %39, %39
  %41 = add nuw nsw i32 %40, %38
  %42 = icmp samesign ult i32 %41, 589824
  br i1 %42, label %43, label %49

43:                                               ; preds = %28
  %44 = sext i16 %32 to i32
  %45 = add nsw i32 %29, %44
  %46 = sext i16 %33 to i32
  %47 = add nsw i32 %30, %46
  %48 = add nuw nsw i16 %31, 1
  br label %49

49:                                               ; preds = %43, %28
  %50 = phi i16 [ %31, %28 ], [ %48, %43 ]
  %51 = phi i32 [ %30, %28 ], [ %47, %43 ]
  %52 = phi i32 [ %29, %28 ], [ %45, %43 ]
  %53 = icmp eq i8 %0, 2
  br i1 %53, label %80, label %54

54:                                               ; preds = %23, %49
  %55 = phi i32 [ %52, %49 ], [ %26, %23 ]
  %56 = phi i32 [ %51, %49 ], [ %25, %23 ]
  %57 = phi i16 [ %50, %49 ], [ %24, %23 ]
  %58 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 16), align 1
  %59 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 18), align 1
  %60 = tail call fastcc { i16, i16 } @v2_sub(i16 %58, i16 %59, i16 %4, i16 %6)
  %61 = extractvalue { i16, i16 } %60, 0
  %62 = extractvalue { i16, i16 } %60, 1
  %63 = sext i16 %61 to i32
  %64 = mul nsw i32 %63, %63
  %65 = sext i16 %62 to i32
  %66 = mul nsw i32 %65, %65
  %67 = add nuw nsw i32 %66, %64
  %68 = icmp samesign ult i32 %67, 589824
  br i1 %68, label %69, label %75

69:                                               ; preds = %54
  %70 = sext i16 %58 to i32
  %71 = add nsw i32 %55, %70
  %72 = sext i16 %59 to i32
  %73 = add nsw i32 %56, %72
  %74 = add nuw nsw i16 %57, 1
  br label %75

75:                                               ; preds = %69, %54
  %76 = phi i16 [ %57, %54 ], [ %74, %69 ]
  %77 = phi i32 [ %56, %54 ], [ %73, %69 ]
  %78 = phi i32 [ %55, %54 ], [ %71, %69 ]
  %79 = icmp eq i8 %0, 3
  br i1 %79, label %106, label %80

80:                                               ; preds = %49, %75
  %81 = phi i32 [ %78, %75 ], [ %52, %49 ]
  %82 = phi i32 [ %77, %75 ], [ %51, %49 ]
  %83 = phi i16 [ %76, %75 ], [ %50, %49 ]
  %84 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 24), align 1
  %85 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 26), align 1
  %86 = tail call fastcc { i16, i16 } @v2_sub(i16 %84, i16 %85, i16 %4, i16 %6)
  %87 = extractvalue { i16, i16 } %86, 0
  %88 = extractvalue { i16, i16 } %86, 1
  %89 = sext i16 %87 to i32
  %90 = mul nsw i32 %89, %89
  %91 = sext i16 %88 to i32
  %92 = mul nsw i32 %91, %91
  %93 = add nuw nsw i32 %92, %90
  %94 = icmp samesign ult i32 %93, 589824
  br i1 %94, label %95, label %101

95:                                               ; preds = %80
  %96 = sext i16 %84 to i32
  %97 = add nsw i32 %81, %96
  %98 = sext i16 %85 to i32
  %99 = add nsw i32 %82, %98
  %100 = add nuw nsw i16 %83, 1
  br label %101

101:                                              ; preds = %95, %80
  %102 = phi i16 [ %83, %80 ], [ %100, %95 ]
  %103 = phi i32 [ %82, %80 ], [ %99, %95 ]
  %104 = phi i32 [ %81, %80 ], [ %97, %95 ]
  %105 = icmp eq i8 %0, 4
  br i1 %105, label %132, label %106

106:                                              ; preds = %75, %101
  %107 = phi i32 [ %104, %101 ], [ %78, %75 ]
  %108 = phi i32 [ %103, %101 ], [ %77, %75 ]
  %109 = phi i16 [ %102, %101 ], [ %76, %75 ]
  %110 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 32), align 1
  %111 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 34), align 1
  %112 = tail call fastcc { i16, i16 } @v2_sub(i16 %110, i16 %111, i16 %4, i16 %6)
  %113 = extractvalue { i16, i16 } %112, 0
  %114 = extractvalue { i16, i16 } %112, 1
  %115 = sext i16 %113 to i32
  %116 = mul nsw i32 %115, %115
  %117 = sext i16 %114 to i32
  %118 = mul nsw i32 %117, %117
  %119 = add nuw nsw i32 %118, %116
  %120 = icmp samesign ult i32 %119, 589824
  br i1 %120, label %121, label %127

121:                                              ; preds = %106
  %122 = sext i16 %110 to i32
  %123 = add nsw i32 %107, %122
  %124 = sext i16 %111 to i32
  %125 = add nsw i32 %108, %124
  %126 = add nuw nsw i16 %109, 1
  br label %127

127:                                              ; preds = %121, %106
  %128 = phi i16 [ %109, %106 ], [ %126, %121 ]
  %129 = phi i32 [ %108, %106 ], [ %125, %121 ]
  %130 = phi i32 [ %107, %106 ], [ %123, %121 ]
  %131 = icmp eq i8 %0, 5
  br i1 %131, label %158, label %132

132:                                              ; preds = %101, %127
  %133 = phi i32 [ %130, %127 ], [ %104, %101 ]
  %134 = phi i32 [ %129, %127 ], [ %103, %101 ]
  %135 = phi i16 [ %128, %127 ], [ %102, %101 ]
  %136 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 40), align 1
  %137 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 42), align 1
  %138 = tail call fastcc { i16, i16 } @v2_sub(i16 %136, i16 %137, i16 %4, i16 %6)
  %139 = extractvalue { i16, i16 } %138, 0
  %140 = extractvalue { i16, i16 } %138, 1
  %141 = sext i16 %139 to i32
  %142 = mul nsw i32 %141, %141
  %143 = sext i16 %140 to i32
  %144 = mul nsw i32 %143, %143
  %145 = add nuw nsw i32 %144, %142
  %146 = icmp samesign ult i32 %145, 589824
  br i1 %146, label %147, label %153

147:                                              ; preds = %132
  %148 = sext i16 %136 to i32
  %149 = add nsw i32 %133, %148
  %150 = sext i16 %137 to i32
  %151 = add nsw i32 %134, %150
  %152 = add nuw nsw i16 %135, 1
  br label %153

153:                                              ; preds = %147, %132
  %154 = phi i16 [ %135, %132 ], [ %152, %147 ]
  %155 = phi i32 [ %134, %132 ], [ %151, %147 ]
  %156 = phi i32 [ %133, %132 ], [ %149, %147 ]
  %157 = icmp eq i8 %0, 6
  br i1 %157, label %184, label %158

158:                                              ; preds = %127, %153
  %159 = phi i32 [ %156, %153 ], [ %130, %127 ]
  %160 = phi i32 [ %155, %153 ], [ %129, %127 ]
  %161 = phi i16 [ %154, %153 ], [ %128, %127 ]
  %162 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 48), align 1
  %163 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 50), align 1
  %164 = tail call fastcc { i16, i16 } @v2_sub(i16 %162, i16 %163, i16 %4, i16 %6)
  %165 = extractvalue { i16, i16 } %164, 0
  %166 = extractvalue { i16, i16 } %164, 1
  %167 = sext i16 %165 to i32
  %168 = mul nsw i32 %167, %167
  %169 = sext i16 %166 to i32
  %170 = mul nsw i32 %169, %169
  %171 = add nuw nsw i32 %170, %168
  %172 = icmp samesign ult i32 %171, 589824
  br i1 %172, label %173, label %179

173:                                              ; preds = %158
  %174 = sext i16 %162 to i32
  %175 = add nsw i32 %159, %174
  %176 = sext i16 %163 to i32
  %177 = add nsw i32 %160, %176
  %178 = add nuw nsw i16 %161, 1
  br label %179

179:                                              ; preds = %173, %158
  %180 = phi i16 [ %161, %158 ], [ %178, %173 ]
  %181 = phi i32 [ %160, %158 ], [ %177, %173 ]
  %182 = phi i32 [ %159, %158 ], [ %175, %173 ]
  %183 = icmp eq i8 %0, 7
  br i1 %183, label %205, label %184

184:                                              ; preds = %153, %179
  %185 = phi i32 [ %182, %179 ], [ %156, %153 ]
  %186 = phi i32 [ %181, %179 ], [ %155, %153 ]
  %187 = phi i16 [ %180, %179 ], [ %154, %153 ]
  %188 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 56), align 1
  %189 = load i16, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 58), align 1
  %190 = tail call fastcc { i16, i16 } @v2_sub(i16 %188, i16 %189, i16 %4, i16 %6)
  %191 = extractvalue { i16, i16 } %190, 0
  %192 = extractvalue { i16, i16 } %190, 1
  %193 = sext i16 %191 to i32
  %194 = mul nsw i32 %193, %193
  %195 = sext i16 %192 to i32
  %196 = mul nsw i32 %195, %195
  %197 = add nuw nsw i32 %196, %194
  %198 = icmp samesign ult i32 %197, 589824
  br i1 %198, label %199, label %205

199:                                              ; preds = %184
  %200 = sext i16 %188 to i32
  %201 = add nsw i32 %185, %200
  %202 = sext i16 %189 to i32
  %203 = add nsw i32 %186, %202
  %204 = add nuw nsw i16 %187, 1
  br label %210

205:                                              ; preds = %184, %179
  %206 = phi i16 [ %180, %179 ], [ %187, %184 ]
  %207 = phi i32 [ %181, %179 ], [ %186, %184 ]
  %208 = phi i32 [ %182, %179 ], [ %185, %184 ]
  %209 = icmp eq i16 %206, 0
  br i1 %209, label %225, label %210

210:                                              ; preds = %199, %205
  %211 = phi i32 [ %201, %199 ], [ %208, %205 ]
  %212 = phi i32 [ %203, %199 ], [ %207, %205 ]
  %213 = phi i16 [ %204, %199 ], [ %206, %205 ]
  %214 = zext nneg i16 %213 to i32
  %215 = sdiv i32 %211, %214
  %216 = trunc i32 %215 to i16
  %217 = sdiv i32 %212, %214
  %218 = trunc i32 %217 to i16
  %219 = tail call fastcc { i16, i16 } @v2_sub(i16 %216, i16 %218, i16 %4, i16 %6)
  %220 = extractvalue { i16, i16 } %219, 0
  %221 = extractvalue { i16, i16 } %219, 1
  %222 = tail call fastcc { i16, i16 } @v2_scale(i16 %220, i16 %221, i16 noundef 40)
  %223 = extractvalue { i16, i16 } %222, 0
  %224 = extractvalue { i16, i16 } %222, 1
  br label %225

225:                                              ; preds = %205, %210
  %226 = phi i16 [ %224, %210 ], [ 0, %205 ]
  %227 = phi i16 [ %223, %210 ], [ 0, %205 ]
  %228 = insertvalue { i16, i16 } poison, i16 %227, 0
  %229 = insertvalue { i16, i16 } %228, i16 %226, 1
  ret { i16, i16 } %229
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
attributes #1 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(read, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(read, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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

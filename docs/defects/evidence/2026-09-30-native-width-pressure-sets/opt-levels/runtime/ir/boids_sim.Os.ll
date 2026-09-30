; ModuleID = '/work/examples/snes/corpus/boids_sim.c'
source_filename = "/work/examples/snes/corpus/boids_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Boid = type { %struct.vec2, %struct.vec2 }
%struct.vec2 = type { i16, i16 }

@corpus_result = dso_local global i16 0, align 1
@boids_gate_crc.gf = internal unnamed_addr global [8 x %struct.Boid] zeroinitializer, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca [4 x i16], align 1
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
  br label %2

2:                                                ; preds = %53, %0
  %3 = phi i8 [ 0, %0 ], [ %54, %53 ]
  br label %8

4:                                                ; preds = %53
  %5 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %6 = getelementptr inbounds nuw i8, ptr %1, i16 4
  %7 = getelementptr inbounds nuw i8, ptr %1, i16 6
  br label %56

8:                                                ; preds = %48, %2
  %9 = phi i8 [ %52, %48 ], [ 0, %2 ]
  %10 = phi i8 [ %50, %48 ], [ 0, %2 ]
  %11 = tail call fastcc { i16, i16 } @boid_acc(i8 noundef zeroext %10) #6
  %12 = extractvalue { i16, i16 } %11, 0
  %13 = extractvalue { i16, i16 } %11, 1
  %14 = zext nneg i8 %9 to i16
  %15 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %14
  %16 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %14
  %17 = load i16, ptr %16, align 1
  %18 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %14
  %19 = load i16, ptr %18, align 1
  %20 = tail call fastcc { i16, i16 } @v2_add(i16 %17, i16 %19, i16 %12, i16 %13) #6
  %21 = extractvalue { i16, i16 } %20, 0
  %22 = extractvalue { i16, i16 } %20, 1
  %23 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %21, i16 %22, i16 noundef 40) #6
  %24 = extractvalue { i16, i16 } %23, 0
  %25 = extractvalue { i16, i16 } %23, 1
  store i16 %24, ptr %16, align 1, !tbaa !2
  store i16 %25, ptr %18, align 1, !tbaa !2
  %26 = load i16, ptr %15, align 1
  %27 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %14
  %28 = load i16, ptr %27, align 1
  %29 = tail call fastcc { i16, i16 } @v2_add(i16 %26, i16 %28, i16 %24, i16 %25) #6
  %30 = extractvalue { i16, i16 } %29, 0
  %31 = extractvalue { i16, i16 } %29, 1
  %32 = icmp slt i16 %30, 0
  br i1 %32, label %33, label %35

33:                                               ; preds = %8
  %34 = add nsw i16 %30, 4096
  br label %39

35:                                               ; preds = %8
  %36 = icmp samesign ult i16 %30, 4096
  br i1 %36, label %39, label %37

37:                                               ; preds = %35
  %38 = add nsw i16 %30, -4096
  br label %39

39:                                               ; preds = %37, %35, %33
  %40 = phi i16 [ %34, %33 ], [ %38, %37 ], [ %30, %35 ]
  %41 = icmp slt i16 %31, 0
  br i1 %41, label %42, label %44

42:                                               ; preds = %39
  %43 = add nsw i16 %31, 3584
  br label %48

44:                                               ; preds = %39
  %45 = icmp samesign ult i16 %31, 3584
  br i1 %45, label %48, label %46

46:                                               ; preds = %44
  %47 = add nsw i16 %31, -3584
  br label %48

48:                                               ; preds = %46, %44, %42
  %49 = phi i16 [ %43, %42 ], [ %47, %46 ], [ %31, %44 ]
  store i16 %40, ptr %15, align 1, !tbaa !2
  store i16 %49, ptr %27, align 1, !tbaa !2
  %50 = add nuw nsw i8 %10, 1
  %51 = icmp eq i8 %50, 8
  %52 = add nuw nsw i8 %9, 8
  br i1 %51, label %53, label %8, !llvm.loop !12

53:                                               ; preds = %48
  %54 = add nuw nsw i8 %3, 1
  %55 = icmp eq i8 %54, 12
  br i1 %55, label %4, label %2, !llvm.loop !14

56:                                               ; preds = %69, %4
  %57 = phi i8 [ 0, %4 ], [ %72, %69 ]
  %58 = phi i8 [ 0, %4 ], [ %70, %69 ]
  %59 = phi i16 [ 0, %4 ], [ %81, %69 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #7
  %60 = zext nneg i8 %57 to i16
  %61 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %60
  %62 = load i16, ptr %61, align 1, !tbaa !6
  store i16 %62, ptr %1, align 1, !tbaa !2
  %63 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %60
  %64 = load i16, ptr %63, align 1, !tbaa !9
  store i16 %64, ptr %5, align 1, !tbaa !2
  %65 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %60
  %66 = load i16, ptr %65, align 1, !tbaa !10
  store i16 %66, ptr %6, align 1, !tbaa !2
  %67 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %60
  %68 = load i16, ptr %67, align 1, !tbaa !11
  store i16 %68, ptr %7, align 1, !tbaa !2
  br label %73

69:                                               ; preds = %73
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #7
  %70 = add nuw nsw i8 %58, 1
  %71 = icmp eq i8 %70, 8
  %72 = add nuw nsw i8 %57, 8
  br i1 %71, label %85, label %56, !llvm.loop !15

73:                                               ; preds = %73, %56
  %74 = phi i8 [ 0, %56 ], [ %84, %73 ]
  %75 = phi i8 [ 0, %56 ], [ %82, %73 ]
  %76 = phi i16 [ %59, %56 ], [ %81, %73 ]
  %77 = tail call i16 @llvm.fshl.i16(i16 %76, i16 %76, i16 1)
  %78 = zext nneg i8 %74 to i16
  %79 = getelementptr i8, ptr %1, i16 %78
  %80 = load i16, ptr %79, align 1, !tbaa !2
  %81 = xor i16 %80, %77
  %82 = add nuw nsw i8 %75, 1
  %83 = icmp eq i8 %82, 4
  %84 = add nuw nsw i8 %74, 2
  br i1 %83, label %69, label %73, !llvm.loop !16

85:                                               ; preds = %69
  store volatile i16 %81, ptr @corpus_result, align 1, !tbaa !2
  br label %86

86:                                               ; preds = %86, %85
  tail call void asm sideeffect "wai", ""() #7, !srcloc !17
  br label %86
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(read, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_acc(i8 noundef zeroext %0) unnamed_addr #2 {
  %2 = tail call fastcc { i16, i16 } @boid_separation(i8 noundef zeroext %0) #6
  %3 = extractvalue { i16, i16 } %2, 0
  %4 = extractvalue { i16, i16 } %2, 1
  %5 = tail call fastcc { i16, i16 } @boid_alignment(i8 noundef zeroext %0) #6
  %6 = extractvalue { i16, i16 } %5, 0
  %7 = extractvalue { i16, i16 } %5, 1
  %8 = tail call fastcc { i16, i16 } @boid_cohesion(i8 noundef zeroext %0) #6
  %9 = extractvalue { i16, i16 } %8, 0
  %10 = extractvalue { i16, i16 } %8, 1
  %11 = tail call fastcc { i16, i16 } @v2_add(i16 %3, i16 %4, i16 %6, i16 %7) #6
  %12 = extractvalue { i16, i16 } %11, 0
  %13 = extractvalue { i16, i16 } %11, 1
  %14 = tail call fastcc { i16, i16 } @v2_add(i16 %12, i16 %13, i16 %9, i16 %10) #6
  %15 = extractvalue { i16, i16 } %14, 0
  %16 = extractvalue { i16, i16 } %14, 1
  %17 = zext i8 %0 to i16
  %18 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %17
  %19 = load i16, ptr %18, align 1
  %20 = getelementptr inbounds nuw i8, ptr %18, i16 2
  %21 = load i16, ptr %20, align 1
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 2048, i16 1792, i16 %19, i16 %21) #6
  %23 = extractvalue { i16, i16 } %22, 0
  %24 = extractvalue { i16, i16 } %22, 1
  %25 = tail call fastcc { i16, i16 } @v2_scale(i16 %23, i16 %24, i16 noundef 256) #6
  %26 = extractvalue { i16, i16 } %25, 0
  %27 = extractvalue { i16, i16 } %25, 1
  %28 = tail call fastcc { i16, i16 } @v2_add(i16 %15, i16 %16, i16 %26, i16 %27) #6
  %29 = extractvalue { i16, i16 } %28, 0
  %30 = extractvalue { i16, i16 } %28, 1
  %31 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %29, i16 %30, i16 noundef 14) #6
  ret { i16, i16 } %31
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_clampbox(i16 %0, i16 %1, i16 noundef range(i16 14, 41) %2) unnamed_addr #3 {
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

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_add(i16 %0, i16 %1, i16 range(i16 -2048, 2048) %2, i16 range(i16 -2048, 2048) %3) unnamed_addr #3 {
  %5 = add i16 %2, %0
  %6 = add i16 %3, %1
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_separation(i8 noundef zeroext %0) unnamed_addr #4 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %9

7:                                                ; preds = %33
  %8 = tail call fastcc { i16, i16 } @v2_scale(i16 %35, i16 %34, i16 noundef 40) #6
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
  %21 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %18, i16 %20) #6
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
  br i1 %37, label %7, label %9, !llvm.loop !18
}

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_alignment(i8 noundef zeroext %0) unnamed_addr #4 {
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
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 %19, i16 %21, i16 %4, i16 %6) #6
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
  br i1 %46, label %7, label %9, !llvm.loop !19

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
  %58 = tail call fastcc { i16, i16 } @v2_sub(i16 %51, i16 %53, i16 %55, i16 %57) #6
  %59 = extractvalue { i16, i16 } %58, 0
  %60 = extractvalue { i16, i16 } %58, 1
  %61 = tail call fastcc { i16, i16 } @v2_scale(i16 %59, i16 %60, i16 noundef 16) #6
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

; Function Attrs: nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_cohesion(i8 noundef zeroext %0) unnamed_addr #4 {
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
  %22 = tail call fastcc { i16, i16 } @v2_sub(i16 %19, i16 %21, i16 %4, i16 %6) #6
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
  br i1 %42, label %7, label %9, !llvm.loop !20

44:                                               ; preds = %7
  %45 = sext i16 %38 to i32
  %46 = sdiv i32 %40, %45
  %47 = trunc i32 %46 to i16
  %48 = sdiv i32 %39, %45
  %49 = trunc i32 %48 to i16
  %50 = tail call fastcc { i16, i16 } @v2_sub(i16 %47, i16 %49, i16 %4, i16 %6) #6
  %51 = extractvalue { i16, i16 } %50, 0
  %52 = extractvalue { i16, i16 } %50, 1
  %53 = tail call fastcc { i16, i16 } @v2_scale(i16 %51, i16 %52, i16 noundef 40) #6
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

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_scale(i16 %0, i16 %1, i16 noundef range(i16 16, 257) %2) unnamed_addr #3 {
  %4 = sdiv i16 %0, %2
  %5 = sdiv i16 %1, %2
  %6 = insertvalue { i16, i16 } poison, i16 %4, 0
  %7 = insertvalue { i16, i16 } %6, i16 %5, 1
  ret { i16, i16 } %7
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_sub(i16 %0, i16 %1, i16 %2, i16 %3) unnamed_addr #3 {
  %5 = sub i16 %0, %2
  %6 = sub i16 %1, %3
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #5

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nofree noinline norecurse nosync nounwind optsize memory(read, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #4 = { nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #5 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #6 = { optsize }
attributes #7 = { nounwind }

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
!15 = distinct !{!15, !13}
!16 = distinct !{!16, !13}
!17 = !{i64 957}
!18 = distinct !{!18, !13}
!19 = distinct !{!19, !13}
!20 = distinct !{!20, !13}

; ModuleID = '/work/examples/snes/corpus/boids_sim.c'
source_filename = "/work/examples/snes/corpus/boids_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Boid = type { %struct.vec2, %struct.vec2 }
%struct.vec2 = type { i16, i16 }

@corpus_result = dso_local global i16 0, align 1
@boids_gate_crc.gf = internal unnamed_addr global [8 x %struct.Boid] zeroinitializer, align 1

; Function Attrs: minsize noreturn nounwind optsize
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

2:                                                ; preds = %55, %0
  %3 = phi i8 [ 0, %0 ], [ %56, %55 ]
  %4 = icmp eq i8 %3, 12
  br i1 %4, label %5, label %9

5:                                                ; preds = %2
  %6 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %7 = getelementptr inbounds nuw i8, ptr %1, i16 4
  %8 = getelementptr inbounds nuw i8, ptr %1, i16 6
  br label %57

9:                                                ; preds = %2, %51
  %10 = phi i8 [ %54, %51 ], [ 0, %2 ]
  %11 = phi i8 [ %53, %51 ], [ 0, %2 ]
  %12 = icmp eq i8 %11, 8
  br i1 %12, label %55, label %13

13:                                               ; preds = %9
  %14 = tail call fastcc { i16, i16 } @boid_acc(i8 noundef zeroext %11) #6
  %15 = extractvalue { i16, i16 } %14, 0
  %16 = extractvalue { i16, i16 } %14, 1
  %17 = zext nneg i8 %10 to i16
  %18 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %17
  %19 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %17
  %20 = load i16, ptr %19, align 1
  %21 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %17
  %22 = load i16, ptr %21, align 1
  %23 = tail call fastcc { i16, i16 } @v2_add(i16 %20, i16 %22, i16 %15, i16 %16) #6
  %24 = extractvalue { i16, i16 } %23, 0
  %25 = extractvalue { i16, i16 } %23, 1
  %26 = tail call fastcc { i16, i16 } @v2_clampbox(i16 %24, i16 %25, i16 noundef 40) #6
  %27 = extractvalue { i16, i16 } %26, 0
  %28 = extractvalue { i16, i16 } %26, 1
  store i16 %27, ptr %19, align 1, !tbaa !2
  store i16 %28, ptr %21, align 1, !tbaa !2
  %29 = load i16, ptr %18, align 1
  %30 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %17
  %31 = load i16, ptr %30, align 1
  %32 = tail call fastcc { i16, i16 } @v2_add(i16 %29, i16 %31, i16 %27, i16 %28) #6
  %33 = extractvalue { i16, i16 } %32, 0
  %34 = extractvalue { i16, i16 } %32, 1
  %35 = icmp slt i16 %33, 0
  br i1 %35, label %36, label %38

36:                                               ; preds = %13
  %37 = add nsw i16 %33, 4096
  br label %42

38:                                               ; preds = %13
  %39 = icmp samesign ult i16 %33, 4096
  br i1 %39, label %42, label %40

40:                                               ; preds = %38
  %41 = add nsw i16 %33, -4096
  br label %42

42:                                               ; preds = %40, %38, %36
  %43 = phi i16 [ %37, %36 ], [ %41, %40 ], [ %33, %38 ]
  %44 = icmp slt i16 %34, 0
  br i1 %44, label %45, label %47

45:                                               ; preds = %42
  %46 = add nsw i16 %34, 3584
  br label %51

47:                                               ; preds = %42
  %48 = icmp samesign ult i16 %34, 3584
  br i1 %48, label %51, label %49

49:                                               ; preds = %47
  %50 = add nsw i16 %34, -3584
  br label %51

51:                                               ; preds = %49, %47, %45
  %52 = phi i16 [ %46, %45 ], [ %50, %49 ], [ %34, %47 ]
  store i16 %43, ptr %18, align 1, !tbaa !2
  store i16 %52, ptr %30, align 1, !tbaa !2
  %53 = add nuw nsw i8 %11, 1
  %54 = add nuw nsw i8 %10, 8
  br label %9, !llvm.loop !12

55:                                               ; preds = %9
  %56 = add nuw nsw i8 %3, 1
  br label %2, !llvm.loop !14

57:                                               ; preds = %77, %5
  %58 = phi i8 [ 0, %5 ], [ %79, %77 ]
  %59 = phi i16 [ 0, %5 ], [ %74, %77 ]
  %60 = phi i8 [ 0, %5 ], [ %78, %77 ]
  %61 = icmp eq i8 %60, 8
  br i1 %61, label %88, label %62

62:                                               ; preds = %57
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #7
  %63 = zext nneg i8 %58 to i16
  %64 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %63
  %65 = load i16, ptr %64, align 1, !tbaa !6
  store i16 %65, ptr %1, align 1, !tbaa !2
  %66 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %63
  %67 = load i16, ptr %66, align 1, !tbaa !9
  store i16 %67, ptr %6, align 1, !tbaa !2
  %68 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %63
  %69 = load i16, ptr %68, align 1, !tbaa !10
  store i16 %69, ptr %7, align 1, !tbaa !2
  %70 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %63
  %71 = load i16, ptr %70, align 1, !tbaa !11
  store i16 %71, ptr %8, align 1, !tbaa !2
  br label %72

72:                                               ; preds = %80, %62
  %73 = phi i8 [ %87, %80 ], [ 0, %62 ]
  %74 = phi i16 [ %85, %80 ], [ %59, %62 ]
  %75 = phi i8 [ %86, %80 ], [ 0, %62 ]
  %76 = icmp eq i8 %75, 4
  br i1 %76, label %77, label %80

77:                                               ; preds = %72
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #7
  %78 = add nuw nsw i8 %60, 1
  %79 = add nuw nsw i8 %58, 8
  br label %57, !llvm.loop !15

80:                                               ; preds = %72
  %81 = tail call i16 @llvm.fshl.i16(i16 %74, i16 %74, i16 1)
  %82 = zext nneg i8 %73 to i16
  %83 = getelementptr i8, ptr %1, i16 %82
  %84 = load i16, ptr %83, align 1, !tbaa !2
  %85 = xor i16 %84, %81
  %86 = add nuw nsw i8 %75, 1
  %87 = add nuw nsw i8 %73, 2
  br label %72, !llvm.loop !16

88:                                               ; preds = %57
  store volatile i16 %59, ptr @corpus_result, align 1, !tbaa !2
  br label %89

89:                                               ; preds = %89, %88
  tail call void asm sideeffect "wai", ""() #7, !srcloc !17
  br label %89
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: minsize nofree noinline norecurse nosync nounwind optsize memory(read, inaccessiblemem: none, target_mem: none)
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

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
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

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_add(i16 %0, i16 %1, i16 range(i16 -2048, 2048) %2, i16 range(i16 -2048, 2048) %3) unnamed_addr #3 {
  %5 = add i16 %2, %0
  %6 = add i16 %3, %1
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: minsize nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_separation(i8 noundef zeroext %0) unnamed_addr #4 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %7

7:                                                ; preds = %35, %1
  %8 = phi i8 [ %39, %35 ], [ 0, %1 ]
  %9 = phi i8 [ %38, %35 ], [ 0, %1 ]
  %10 = phi i16 [ %36, %35 ], [ 0, %1 ]
  %11 = phi i16 [ %37, %35 ], [ 0, %1 ]
  %12 = icmp eq i8 %9, 8
  br i1 %12, label %13, label %15

13:                                               ; preds = %7
  %14 = tail call fastcc { i16, i16 } @v2_scale(i16 %11, i16 %10, i16 noundef 40) #6
  ret { i16, i16 } %14

15:                                               ; preds = %7
  %16 = icmp eq i8 %9, %0
  br i1 %16, label %35, label %17

17:                                               ; preds = %15
  %18 = zext nneg i8 %8 to i16
  %19 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %18
  %20 = load i16, ptr %19, align 1
  %21 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %18
  %22 = load i16, ptr %21, align 1
  %23 = tail call fastcc { i16, i16 } @v2_sub(i16 %4, i16 %6, i16 %20, i16 %22) #6
  %24 = extractvalue { i16, i16 } %23, 0
  %25 = extractvalue { i16, i16 } %23, 1
  %26 = sext i16 %24 to i32
  %27 = mul nsw i32 %26, %26
  %28 = sext i16 %25 to i32
  %29 = mul nsw i32 %28, %28
  %30 = add nuw nsw i32 %29, %27
  %31 = icmp samesign ult i32 %30, 65536
  br i1 %31, label %32, label %35

32:                                               ; preds = %17
  %33 = add i16 %24, %11
  %34 = add i16 %25, %10
  br label %35

35:                                               ; preds = %17, %32, %15
  %36 = phi i16 [ %10, %15 ], [ %34, %32 ], [ %10, %17 ]
  %37 = phi i16 [ %11, %15 ], [ %33, %32 ], [ %11, %17 ]
  %38 = add nuw nsw i8 %9, 1
  %39 = add nuw nsw i8 %8, 8
  br label %7, !llvm.loop !18
}

; Function Attrs: minsize nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_alignment(i8 noundef zeroext %0) unnamed_addr #4 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %7

7:                                                ; preds = %43, %1
  %8 = phi i8 [ %48, %43 ], [ 0, %1 ]
  %9 = phi i8 [ %47, %43 ], [ 0, %1 ]
  %10 = phi i16 [ %44, %43 ], [ 0, %1 ]
  %11 = phi i32 [ %45, %43 ], [ 0, %1 ]
  %12 = phi i32 [ %46, %43 ], [ 0, %1 ]
  %13 = icmp eq i8 %9, 8
  br i1 %13, label %14, label %16

14:                                               ; preds = %7
  %15 = icmp eq i16 %10, 0
  br i1 %15, label %65, label %49

16:                                               ; preds = %7
  %17 = icmp eq i8 %9, %0
  br i1 %17, label %43, label %18

18:                                               ; preds = %16
  %19 = zext nneg i8 %8 to i16
  %20 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %19
  %21 = load i16, ptr %20, align 1
  %22 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %19
  %23 = load i16, ptr %22, align 1
  %24 = tail call fastcc { i16, i16 } @v2_sub(i16 %21, i16 %23, i16 %4, i16 %6) #6
  %25 = extractvalue { i16, i16 } %24, 0
  %26 = extractvalue { i16, i16 } %24, 1
  %27 = sext i16 %25 to i32
  %28 = mul nsw i32 %27, %27
  %29 = sext i16 %26 to i32
  %30 = mul nsw i32 %29, %29
  %31 = add nuw nsw i32 %30, %28
  %32 = icmp samesign ult i32 %31, 589824
  br i1 %32, label %33, label %43

33:                                               ; preds = %18
  %34 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 4), i16 %19
  %35 = load i16, ptr %34, align 1, !tbaa !10
  %36 = sext i16 %35 to i32
  %37 = add nsw i32 %12, %36
  %38 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 6), i16 %19
  %39 = load i16, ptr %38, align 1, !tbaa !11
  %40 = sext i16 %39 to i32
  %41 = add nsw i32 %11, %40
  %42 = add nsw i16 %10, 1
  br label %43

43:                                               ; preds = %18, %33, %16
  %44 = phi i16 [ %10, %16 ], [ %42, %33 ], [ %10, %18 ]
  %45 = phi i32 [ %11, %16 ], [ %41, %33 ], [ %11, %18 ]
  %46 = phi i32 [ %12, %16 ], [ %37, %33 ], [ %12, %18 ]
  %47 = add nuw nsw i8 %9, 1
  %48 = add nuw nsw i8 %8, 8
  br label %7, !llvm.loop !19

49:                                               ; preds = %14
  %50 = sext i16 %10 to i32
  %51 = sdiv i32 %12, %50
  %52 = trunc i32 %51 to i16
  %53 = sdiv i32 %11, %50
  %54 = trunc i32 %53 to i16
  %55 = getelementptr inbounds nuw i8, ptr %3, i16 4
  %56 = load i16, ptr %55, align 1
  %57 = getelementptr inbounds nuw i8, ptr %3, i16 6
  %58 = load i16, ptr %57, align 1
  %59 = tail call fastcc { i16, i16 } @v2_sub(i16 %52, i16 %54, i16 %56, i16 %58) #6
  %60 = extractvalue { i16, i16 } %59, 0
  %61 = extractvalue { i16, i16 } %59, 1
  %62 = tail call fastcc { i16, i16 } @v2_scale(i16 %60, i16 %61, i16 noundef 16) #6
  %63 = extractvalue { i16, i16 } %62, 0
  %64 = extractvalue { i16, i16 } %62, 1
  br label %65

65:                                               ; preds = %14, %49
  %66 = phi i16 [ %64, %49 ], [ 0, %14 ]
  %67 = phi i16 [ %63, %49 ], [ 0, %14 ]
  %68 = insertvalue { i16, i16 } poison, i16 %67, 0
  %69 = insertvalue { i16, i16 } %68, i16 %66, 1
  ret { i16, i16 } %69
}

; Function Attrs: minsize nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc { i16, i16 } @boid_cohesion(i8 noundef zeroext %0) unnamed_addr #4 {
  %2 = zext i8 %0 to i16
  %3 = getelementptr inbounds nuw [8 x i8], ptr @boids_gate_crc.gf, i16 %2
  %4 = load i16, ptr %3, align 1, !tbaa !2
  %5 = getelementptr inbounds nuw i8, ptr %3, i16 2
  %6 = load i16, ptr %5, align 1, !tbaa !2
  br label %7

7:                                                ; preds = %39, %1
  %8 = phi i8 [ %44, %39 ], [ 0, %1 ]
  %9 = phi i8 [ %43, %39 ], [ 0, %1 ]
  %10 = phi i16 [ %40, %39 ], [ 0, %1 ]
  %11 = phi i32 [ %41, %39 ], [ 0, %1 ]
  %12 = phi i32 [ %42, %39 ], [ 0, %1 ]
  %13 = icmp eq i8 %9, 8
  br i1 %13, label %14, label %16

14:                                               ; preds = %7
  %15 = icmp eq i16 %10, 0
  br i1 %15, label %57, label %45

16:                                               ; preds = %7
  %17 = icmp eq i8 %9, %0
  br i1 %17, label %39, label %18

18:                                               ; preds = %16
  %19 = zext nneg i8 %8 to i16
  %20 = getelementptr i8, ptr @boids_gate_crc.gf, i16 %19
  %21 = load i16, ptr %20, align 1
  %22 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @boids_gate_crc.gf, i16 2), i16 %19
  %23 = load i16, ptr %22, align 1
  %24 = tail call fastcc { i16, i16 } @v2_sub(i16 %21, i16 %23, i16 %4, i16 %6) #6
  %25 = extractvalue { i16, i16 } %24, 0
  %26 = extractvalue { i16, i16 } %24, 1
  %27 = sext i16 %25 to i32
  %28 = mul nsw i32 %27, %27
  %29 = sext i16 %26 to i32
  %30 = mul nsw i32 %29, %29
  %31 = add nuw nsw i32 %30, %28
  %32 = icmp samesign ult i32 %31, 589824
  br i1 %32, label %33, label %39

33:                                               ; preds = %18
  %34 = sext i16 %21 to i32
  %35 = add nsw i32 %12, %34
  %36 = sext i16 %23 to i32
  %37 = add nsw i32 %11, %36
  %38 = add nsw i16 %10, 1
  br label %39

39:                                               ; preds = %18, %33, %16
  %40 = phi i16 [ %10, %16 ], [ %38, %33 ], [ %10, %18 ]
  %41 = phi i32 [ %11, %16 ], [ %37, %33 ], [ %11, %18 ]
  %42 = phi i32 [ %12, %16 ], [ %35, %33 ], [ %12, %18 ]
  %43 = add nuw nsw i8 %9, 1
  %44 = add nuw nsw i8 %8, 8
  br label %7, !llvm.loop !20

45:                                               ; preds = %14
  %46 = sext i16 %10 to i32
  %47 = sdiv i32 %12, %46
  %48 = trunc i32 %47 to i16
  %49 = sdiv i32 %11, %46
  %50 = trunc i32 %49 to i16
  %51 = tail call fastcc { i16, i16 } @v2_sub(i16 %48, i16 %50, i16 %4, i16 %6) #6
  %52 = extractvalue { i16, i16 } %51, 0
  %53 = extractvalue { i16, i16 } %51, 1
  %54 = tail call fastcc { i16, i16 } @v2_scale(i16 %52, i16 %53, i16 noundef 40) #6
  %55 = extractvalue { i16, i16 } %54, 0
  %56 = extractvalue { i16, i16 } %54, 1
  br label %57

57:                                               ; preds = %14, %45
  %58 = phi i16 [ %56, %45 ], [ 0, %14 ]
  %59 = phi i16 [ %55, %45 ], [ 0, %14 ]
  %60 = insertvalue { i16, i16 } poison, i16 %59, 0
  %61 = insertvalue { i16, i16 } %60, i16 %58, 1
  ret { i16, i16 } %61
}

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_scale(i16 %0, i16 %1, i16 noundef range(i16 16, 257) %2) unnamed_addr #3 {
  %4 = sdiv i16 %0, %2
  %5 = sdiv i16 %1, %2
  %6 = insertvalue { i16, i16 } poison, i16 %4, 0
  %7 = insertvalue { i16, i16 } %6, i16 %5, 1
  ret { i16, i16 } %7
}

; Function Attrs: minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc { i16, i16 } @v2_sub(i16 %0, i16 %1, i16 %2, i16 %3) unnamed_addr #3 {
  %5 = sub i16 %0, %2
  %6 = sub i16 %1, %3
  %7 = insertvalue { i16, i16 } poison, i16 %5, 0
  %8 = insertvalue { i16, i16 } %7, i16 %6, 1
  ret { i16, i16 } %8
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #5

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { minsize nofree noinline norecurse nosync nounwind optsize memory(read, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { minsize mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #4 = { minsize nofree noinline norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #5 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #6 = { minsize optsize }
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

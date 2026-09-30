; ModuleID = '/work/examples/snes/corpus/perlin_sim.c'
source_filename = "/work/examples/snes/corpus/perlin_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@pn_ready = internal unnamed_addr global i1 false, align 1
@PN_PERM = internal unnamed_addr global [512 x i8] zeroinitializer, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = load i1, ptr @pn_ready, align 1
  br i1 %1, label %33, label %2

2:                                                ; preds = %0, %2
  %3 = phi i16 [ %6, %2 ], [ 0, %0 ]
  %4 = trunc nuw i16 %3 to i8
  %5 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %3
  store i8 %4, ptr %5, align 1, !tbaa !6
  %6 = add nuw nsw i16 %3, 1
  %7 = icmp eq i16 %6, 256
  br i1 %7, label %8, label %2, !llvm.loop !7

8:                                                ; preds = %2, %8
  %9 = phi i16 [ %16, %8 ], [ 10861, %2 ]
  %10 = phi i16 [ %23, %8 ], [ 255, %2 ]
  %11 = shl i16 %9, 7
  %12 = xor i16 %11, %9
  %13 = lshr i16 %12, 9
  %14 = xor i16 %13, %12
  %15 = shl i16 %14, 8
  %16 = xor i16 %15, %14
  %17 = add nuw nsw i16 %10, 1
  %18 = urem i16 %16, %17
  %19 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %10
  %20 = load i8, ptr %19, align 1, !tbaa !6
  %21 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %18
  %22 = load i8, ptr %21, align 1, !tbaa !6
  store i8 %22, ptr %19, align 1, !tbaa !6
  store i8 %20, ptr %21, align 1, !tbaa !6
  %23 = add nsw i16 %10, -1
  %24 = icmp eq i16 %23, 0
  br i1 %24, label %25, label %8, !llvm.loop !9

25:                                               ; preds = %8, %25
  %26 = phi i16 [ %30, %25 ], [ 0, %8 ]
  %27 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %26
  %28 = load i8, ptr %27, align 1, !tbaa !6
  %29 = getelementptr inbounds nuw i8, ptr %27, i16 256
  store i8 %28, ptr %29, align 1, !tbaa !6
  %30 = add nuw nsw i16 %26, 1
  %31 = icmp eq i16 %30, 256
  br i1 %31, label %32, label %25, !llvm.loop !10

32:                                               ; preds = %25
  store i1 true, ptr @pn_ready, align 1
  br label %33

33:                                               ; preds = %32, %0
  br label %34

34:                                               ; preds = %33, %113
  %35 = phi i16 [ %166, %113 ], [ 0, %33 ]
  %36 = phi i16 [ %167, %113 ], [ 0, %33 ]
  %37 = mul nuw nsw i16 %36, 96
  %38 = zext nneg i16 %37 to i32
  %39 = mul nuw nsw i16 %36, 53
  %40 = add nuw nsw i16 %39, 128
  %41 = zext nneg i16 %40 to i32
  %42 = lshr i16 %37, 8
  %43 = lshr i32 %41, 8
  %44 = and i32 %38, 224
  %45 = and i32 %41, 255
  %46 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %42
  %47 = load i8, ptr %46, align 1, !tbaa !6
  %48 = zext i8 %47 to i32
  %49 = add nuw nsw i32 %43, %48
  %50 = trunc nuw nsw i32 %49 to i16
  %51 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %50
  %52 = load i8, ptr %51, align 1, !tbaa !6
  %53 = getelementptr inbounds nuw i8, ptr %51, i16 1
  %54 = load i8, ptr %53, align 1, !tbaa !6
  %55 = getelementptr inbounds nuw i8, ptr %46, i16 1
  %56 = load i8, ptr %55, align 1, !tbaa !6
  %57 = zext i8 %56 to i32
  %58 = add nuw nsw i32 %43, %57
  %59 = trunc nuw nsw i32 %58 to i16
  %60 = getelementptr inbounds nuw i8, ptr @PN_PERM, i16 %59
  %61 = load i8, ptr %60, align 1, !tbaa !6
  %62 = getelementptr inbounds nuw i8, ptr %60, i16 1
  %63 = load i8, ptr %62, align 1, !tbaa !6
  %64 = and i8 %52, 3
  switch i8 %64, label %71 [
    i8 0, label %65
    i8 1, label %67
    i8 2, label %69
    i8 3, label %72
  ]

65:                                               ; preds = %34
  %66 = add nuw nsw i32 %45, %44
  br label %75

67:                                               ; preds = %34
  %68 = sub nsw i32 %45, %44
  br label %75

69:                                               ; preds = %34
  %70 = sub nsw i32 %44, %45
  br label %75

71:                                               ; preds = %101, %88, %75, %34
  unreachable

72:                                               ; preds = %34
  %73 = add nuw nsw i32 %44, %45
  %74 = sub nsw i32 0, %73
  br label %75

75:                                               ; preds = %72, %69, %67, %65
  %76 = phi i32 [ %74, %72 ], [ %66, %65 ], [ %68, %67 ], [ %70, %69 ]
  %77 = or i32 %38, -256
  %78 = and i8 %61, 3
  switch i8 %78, label %71 [
    i8 0, label %79
    i8 1, label %81
    i8 2, label %83
    i8 3, label %85
  ]

79:                                               ; preds = %75
  %80 = add nsw i32 %45, %77
  br label %88

81:                                               ; preds = %75
  %82 = sub nsw i32 %45, %77
  br label %88

83:                                               ; preds = %75
  %84 = sub nuw nsw i32 %77, %45
  br label %88

85:                                               ; preds = %75
  %86 = add nsw i32 %77, %45
  %87 = sub nsw i32 0, %86
  br label %88

88:                                               ; preds = %85, %83, %81, %79
  %89 = phi i32 [ %87, %85 ], [ %80, %79 ], [ %82, %81 ], [ %84, %83 ]
  %90 = or i32 %41, -256
  %91 = and i8 %54, 3
  switch i8 %91, label %71 [
    i8 0, label %92
    i8 1, label %94
    i8 2, label %96
    i8 3, label %98
  ]

92:                                               ; preds = %88
  %93 = add nsw i32 %90, %44
  br label %101

94:                                               ; preds = %88
  %95 = sub nuw nsw i32 %90, %44
  br label %101

96:                                               ; preds = %88
  %97 = sub nsw i32 %44, %90
  br label %101

98:                                               ; preds = %88
  %99 = add nsw i32 %44, %90
  %100 = sub nsw i32 0, %99
  br label %101

101:                                              ; preds = %98, %96, %94, %92
  %102 = phi i32 [ %100, %98 ], [ %93, %92 ], [ %95, %94 ], [ %97, %96 ]
  %103 = and i8 %63, 3
  switch i8 %103, label %71 [
    i8 0, label %104
    i8 1, label %106
    i8 2, label %108
    i8 3, label %110
  ]

104:                                              ; preds = %101
  %105 = add nsw i32 %90, %77
  br label %113

106:                                              ; preds = %101
  %107 = sub nsw i32 %90, %77
  br label %113

108:                                              ; preds = %101
  %109 = sub nsw i32 %77, %90
  br label %113

110:                                              ; preds = %101
  %111 = add nsw i32 %77, %90
  %112 = sub nsw i32 0, %111
  br label %113

113:                                              ; preds = %110, %108, %106, %104
  %114 = phi i32 [ %112, %110 ], [ %105, %104 ], [ %107, %106 ], [ %109, %108 ]
  %115 = sub nsw i32 %89, %76
  %116 = mul nuw nsw i32 %44, 6
  %117 = add nuw nsw i32 %116, -3840
  %118 = mul nsw i32 %117, %44
  %119 = ashr exact i32 %118, 8
  %120 = add nsw i32 %119, 2560
  %121 = mul nuw nsw i32 %44, %44
  %122 = lshr exact i32 %121, 8
  %123 = mul nuw nsw i32 %122, %44
  %124 = lshr i32 %123, 8
  %125 = mul nsw i32 %120, %124
  %126 = ashr i32 %125, 8
  %127 = mul nsw i32 %115, %126
  %128 = ashr i32 %127, 8
  %129 = add nsw i32 %128, %76
  %130 = mul nuw nsw i32 %45, 6
  %131 = add nuw nsw i32 %130, -3840
  %132 = mul nsw i32 %131, %45
  %133 = ashr i32 %132, 8
  %134 = add nsw i32 %133, 2560
  %135 = mul nuw nsw i32 %45, %45
  %136 = lshr i32 %135, 8
  %137 = mul nuw nsw i32 %136, %45
  %138 = lshr i32 %137, 8
  %139 = mul nsw i32 %134, %138
  %140 = lshr i32 %139, 8
  %141 = sub nsw i32 %114, %102
  %142 = mul nsw i32 %141, %126
  %143 = lshr i32 %142, 8
  %144 = sub nsw i32 %102, %129
  %145 = add nsw i32 %144, %143
  %146 = mul i32 %145, %140
  %147 = lshr i32 %146, 8
  %148 = add nsw i32 %147, %129
  %149 = trunc i32 %148 to i16
  %150 = tail call i16 @llvm.fshl.i16(i16 %35, i16 %35, i16 1)
  %151 = xor i16 %150, %149
  %152 = zext nneg i16 %36 to i32
  %153 = mul nuw nsw i32 %152, %152
  %154 = lshr i32 %153, 8
  %155 = mul nuw nsw i32 %154, %152
  %156 = lshr i32 %155, 8
  %157 = mul nuw nsw i32 %152, 6
  %158 = add nuw nsw i32 %157, -3840
  %159 = mul nsw i32 %158, %152
  %160 = lshr i32 %159, 8
  %161 = add nuw nsw i32 %160, 2560
  %162 = mul nuw nsw i32 %161, %156
  %163 = lshr i32 %162, 8
  %164 = trunc i32 %163 to i16
  %165 = tail call i16 @llvm.fshl.i16(i16 %151, i16 %151, i16 1)
  %166 = xor i16 %165, %164
  %167 = add nuw nsw i16 %36, 1
  %168 = icmp eq i16 %167, 120
  br i1 %168, label %169, label %34, !llvm.loop !11

169:                                              ; preds = %113
  store volatile i16 %166, ptr @corpus_result, align 1, !tbaa !2
  br label %170

170:                                              ; preds = %170, %169
  tail call void asm sideeffect "wai", ""() #2, !srcloc !12
  br label %170
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind }

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
!11 = distinct !{!11, !8}
!12 = !{i64 344}

; ModuleID = '/work/examples/snes/corpus/grid3d_sim.c'
source_filename = "/work/examples/snes/corpus/grid3d_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@g3_a = internal unnamed_addr global [6 x [6 x [6 x i8]]] zeroinitializer, align 1
@g3_b = internal unnamed_addr global [6 x [6 x [6 x i8]]] zeroinitializer, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  tail call void @llvm.memset.p0.i16(ptr noundef nonnull align 1 dereferenceable(216) @g3_a, i8 0, i16 216, i1 false), !tbaa !6
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i8 [ %21, %1 ], [ 0, %0 ]
  %3 = phi i16 [ %9, %1 ], [ 4660, %0 ]
  %4 = shl i16 %3, 7
  %5 = xor i16 %4, %3
  %6 = lshr i16 %5, 9
  %7 = xor i16 %6, %5
  %8 = shl i16 %7, 8
  %9 = xor i16 %8, %7
  %10 = trunc i16 %7 to i8
  %11 = lshr i8 %10, 3
  %12 = and i8 %11, 3
  %13 = lshr i8 %10, 6
  %14 = zext nneg i8 %13 to i16
  %15 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %14
  %16 = zext nneg i8 %12 to i16
  %17 = getelementptr inbounds nuw [6 x i8], ptr %15, i16 %16
  %18 = and i16 %7, 3
  %19 = getelementptr inbounds nuw i8, ptr %17, i16 %18
  %20 = getelementptr inbounds nuw i8, ptr %19, i16 43
  store i8 1, ptr %20, align 1, !tbaa !6
  %21 = add nuw nsw i8 %2, 1
  %22 = icmp eq i8 %21, 60
  br i1 %22, label %23, label %1, !llvm.loop !7

23:                                               ; preds = %1, %143
  %24 = phi i16 [ %145, %143 ], [ 0, %1 ]
  %25 = phi i16 [ %146, %143 ], [ 0, %1 ]
  br label %26

26:                                               ; preds = %38, %23
  %27 = phi i8 [ %46, %38 ], [ 0, %23 ]
  %28 = phi ptr [ %45, %38 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %23 ]
  %29 = phi ptr [ %44, %38 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), %23 ]
  %30 = phi ptr [ %43, %38 ], [ @g3_b, %23 ]
  %31 = phi ptr [ %42, %38 ], [ @g3_a, %23 ]
  %32 = phi i8 [ %39, %38 ], [ 0, %23 ]
  br label %33

33:                                               ; preds = %49, %26
  %34 = phi i8 [ %55, %49 ], [ 0, %26 ]
  %35 = phi ptr [ %53, %49 ], [ %30, %26 ]
  %36 = phi ptr [ %52, %49 ], [ %31, %26 ]
  %37 = phi i8 [ %50, %49 ], [ 0, %26 ]
  br label %47

38:                                               ; preds = %49
  %39 = add nuw nsw i8 %32, 1
  %40 = icmp eq i8 %39, 6
  %41 = zext i8 %27 to i16
  %42 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %41
  %43 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %41
  %44 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 42), i16 %41
  %45 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %41
  %46 = add nuw i8 %27, 36
  br i1 %40, label %134, label %26, !llvm.loop !9

47:                                               ; preds = %128, %33
  %48 = phi i8 [ 0, %33 ], [ %132, %128 ]
  br label %56

49:                                               ; preds = %128
  %50 = add nuw nsw i8 %37, 1
  %51 = zext nneg i8 %34 to i16
  %52 = getelementptr i8, ptr %29, i16 %51
  %53 = getelementptr i8, ptr %28, i16 %51
  %54 = icmp eq i8 %50, 6
  %55 = add nuw nsw i8 %34, 6
  br i1 %54, label %38, label %33, !llvm.loop !10

56:                                               ; preds = %75, %47
  %57 = phi i8 [ %112, %75 ], [ 0, %47 ]
  %58 = phi i8 [ %76, %75 ], [ -1, %47 ]
  %59 = add nsw i8 %58, %32
  %60 = icmp slt i8 %59, 0
  %61 = add nsw i8 %59, -6
  %62 = add nsw i8 %59, 6
  %63 = icmp slt i8 %59, 6
  %64 = select i1 %60, i8 %62, i8 %59
  br label %65

65:                                               ; preds = %78, %56
  %66 = phi i8 [ %57, %56 ], [ %112, %78 ]
  %67 = phi i8 [ -1, %56 ], [ %79, %78 ]
  %68 = add nsw i8 %67, %37
  %69 = icmp slt i8 %68, 0
  %70 = add nsw i8 %68, -6
  %71 = add nsw i8 %68, 6
  %72 = or i8 %67, %58
  %73 = icmp slt i8 %68, 6
  %74 = select i1 %69, i8 %71, i8 %68
  br label %81

75:                                               ; preds = %78
  %76 = add nsw i8 %58, 1
  %77 = icmp eq i8 %76, 2
  br i1 %77, label %115, label %56, !llvm.loop !11

78:                                               ; preds = %111
  %79 = add nsw i8 %67, 1
  %80 = icmp eq i8 %79, 2
  br i1 %80, label %75, label %65, !llvm.loop !12

81:                                               ; preds = %111, %65
  %82 = phi i8 [ %66, %65 ], [ %112, %111 ]
  %83 = phi i8 [ -1, %65 ], [ %113, %111 ]
  %84 = or i8 %72, %83
  %85 = icmp eq i8 %84, 0
  br i1 %85, label %111, label %86

86:                                               ; preds = %81
  br i1 %63, label %88, label %87

87:                                               ; preds = %86
  br label %88

88:                                               ; preds = %87, %86
  %89 = phi i8 [ %64, %86 ], [ %61, %87 ]
  br i1 %73, label %91, label %90

90:                                               ; preds = %88
  br label %91

91:                                               ; preds = %90, %88
  %92 = phi i8 [ %74, %88 ], [ %70, %90 ]
  %93 = add nsw i8 %83, %48
  %94 = icmp slt i8 %93, 0
  br i1 %94, label %95, label %97

95:                                               ; preds = %91
  %96 = add nsw i8 %93, 6
  br label %101

97:                                               ; preds = %91
  %98 = icmp samesign ugt i8 %93, 5
  br i1 %98, label %99, label %101

99:                                               ; preds = %97
  %100 = add nsw i8 %93, -6
  br label %101

101:                                              ; preds = %99, %97, %95
  %102 = phi i8 [ %96, %95 ], [ %100, %99 ], [ %93, %97 ]
  %103 = zext i8 %89 to i16
  %104 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %103
  %105 = zext i8 %92 to i16
  %106 = getelementptr inbounds nuw [6 x i8], ptr %104, i16 %105
  %107 = zext i8 %102 to i16
  %108 = getelementptr inbounds nuw i8, ptr %106, i16 %107
  %109 = load i8, ptr %108, align 1, !tbaa !6
  %110 = add i8 %109, %82
  br label %111

111:                                              ; preds = %101, %81
  %112 = phi i8 [ %82, %81 ], [ %110, %101 ]
  %113 = add nsw i8 %83, 1
  %114 = icmp eq i8 %113, 2
  br i1 %114, label %78, label %81, !llvm.loop !13

115:                                              ; preds = %75
  %116 = zext nneg i8 %48 to i16
  %117 = getelementptr i8, ptr %36, i16 %116
  %118 = load i8, ptr %117, align 1, !tbaa !6
  %119 = icmp eq i8 %118, 0
  br i1 %119, label %124, label %120

120:                                              ; preds = %115
  %121 = icmp ugt i8 %112, 3
  br i1 %121, label %122, label %128

122:                                              ; preds = %120
  %123 = icmp ult i8 %112, 8
  br label %128

124:                                              ; preds = %115
  %125 = icmp ugt i8 %112, 4
  br i1 %125, label %126, label %128

126:                                              ; preds = %124
  %127 = icmp ult i8 %112, 7
  br label %128

128:                                              ; preds = %126, %124, %122, %120
  %129 = phi i1 [ %123, %122 ], [ false, %120 ], [ false, %124 ], [ %127, %126 ]
  %130 = zext i1 %129 to i8
  %131 = getelementptr i8, ptr %35, i16 %116
  store i8 %130, ptr %131, align 1, !tbaa !6
  %132 = add nuw nsw i8 %48, 1
  %133 = icmp eq i8 %132, 6
  br i1 %133, label %49, label %47, !llvm.loop !14

134:                                              ; preds = %38, %157
  %135 = phi ptr [ %164, %157 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %38 ]
  %136 = phi ptr [ %160, %157 ], [ @g3_b, %38 ]
  %137 = phi i8 [ %163, %157 ], [ 0, %38 ]
  %138 = phi ptr [ %161, %157 ], [ @g3_a, %38 ]
  %139 = phi i16 [ %184, %157 ], [ %24, %38 ]
  %140 = phi i8 [ %158, %157 ], [ 0, %38 ]
  %141 = phi i16 [ %179, %157 ], [ 0, %38 ]
  %142 = zext nneg i8 %140 to i16
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(36) %138, ptr noundef nonnull align 1 dereferenceable(36) %136, i16 36, i1 false), !tbaa !6
  br label %148

143:                                              ; preds = %157
  %144 = tail call i16 @llvm.fshl.i16(i16 %184, i16 %184, i16 1)
  %145 = xor i16 %144, %179
  %146 = add nuw nsw i16 %25, 1
  %147 = icmp eq i16 %146, 3
  br i1 %147, label %187, label %23, !llvm.loop !15

148:                                              ; preds = %165, %134
  %149 = phi i8 [ %170, %165 ], [ 0, %134 ]
  %150 = phi ptr [ %168, %165 ], [ %136, %134 ]
  %151 = phi i16 [ %184, %165 ], [ %139, %134 ]
  %152 = phi i8 [ %166, %165 ], [ 0, %134 ]
  %153 = phi i16 [ %179, %165 ], [ %141, %134 ]
  %154 = zext nneg i8 %152 to i16
  %155 = shl nuw nsw i16 %154, 4
  %156 = add nuw nsw i16 %155, %142
  br label %171

157:                                              ; preds = %165
  %158 = add nuw nsw i8 %140, 1
  %159 = zext i8 %137 to i16
  %160 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %159
  %161 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %159
  %162 = icmp eq i8 %158, 6
  %163 = add nuw i8 %137, 36
  %164 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %159
  br i1 %162, label %143, label %134, !llvm.loop !16

165:                                              ; preds = %171
  %166 = add nuw nsw i8 %152, 1
  %167 = zext nneg i8 %149 to i16
  %168 = getelementptr i8, ptr %135, i16 %167
  %169 = icmp eq i8 %166, 6
  %170 = add nuw nsw i8 %149, 6
  br i1 %169, label %157, label %148, !llvm.loop !17

171:                                              ; preds = %171, %148
  %172 = phi i16 [ %151, %148 ], [ %184, %171 ]
  %173 = phi i8 [ 0, %148 ], [ %185, %171 ]
  %174 = phi i16 [ %153, %148 ], [ %179, %171 ]
  %175 = zext nneg i8 %173 to i16
  %176 = getelementptr i8, ptr %150, i16 %175
  %177 = load i8, ptr %176, align 1, !tbaa !6
  %178 = zext i8 %177 to i16
  %179 = add i16 %174, %178
  %180 = shl nuw nsw i16 %175, 8
  %181 = add nuw nsw i16 %156, %180
  %182 = tail call i16 @llvm.fshl.i16(i16 %172, i16 %172, i16 1)
  %183 = xor i16 %181, %182
  %184 = xor i16 %183, %178
  %185 = add nuw nsw i8 %173, 1
  %186 = icmp eq i8 %185, 6
  br i1 %186, label %165, label %171, !llvm.loop !18

187:                                              ; preds = %143
  store volatile i16 %145, ptr @corpus_result, align 1, !tbaa !2
  br label %188

188:                                              ; preds = %188, %187
  tail call void asm sideeffect "wai", ""() #4, !srcloc !19
  br label %188
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #2

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i16(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i16, i1 immarg) #3

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #3 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #4 = { nounwind }

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
!12 = distinct !{!12, !8}
!13 = distinct !{!13, !8}
!14 = distinct !{!14, !8}
!15 = distinct !{!15, !8}
!16 = distinct !{!16, !8}
!17 = distinct !{!17, !8}
!18 = distinct !{!18, !8}
!19 = !{i64 309}

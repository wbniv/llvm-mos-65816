; ModuleID = '/work/examples/snes/corpus/grid3d_sim.c'
source_filename = "/work/examples/snes/corpus/grid3d_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@g3_a = internal unnamed_addr global [6 x [6 x [6 x i8]]] zeroinitializer, align 1
@g3_b = internal unnamed_addr global [6 x [6 x [6 x i8]]] zeroinitializer, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %12, %0
  %2 = phi i8 [ %17, %12 ], [ 0, %0 ]
  %3 = phi ptr [ %16, %12 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), %0 ]
  %4 = phi ptr [ %15, %12 ], [ @g3_a, %0 ]
  %5 = phi i8 [ %13, %12 ], [ 0, %0 ]
  %6 = icmp eq i8 %5, 6
  br i1 %6, label %30, label %7

7:                                                ; preds = %1, %21
  %8 = phi i8 [ %25, %21 ], [ 0, %1 ]
  %9 = phi ptr [ %24, %21 ], [ %4, %1 ]
  %10 = phi i8 [ %22, %21 ], [ 0, %1 ]
  %11 = icmp eq i8 %10, 6
  br i1 %11, label %12, label %18

12:                                               ; preds = %7
  %13 = add nuw nsw i8 %5, 1
  %14 = zext i8 %2 to i16
  %15 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %14
  %16 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 42), i16 %14
  %17 = add nuw i8 %2, 36
  br label %1, !llvm.loop !6

18:                                               ; preds = %7, %26
  %19 = phi i8 [ %29, %26 ], [ 0, %7 ]
  %20 = icmp eq i8 %19, 6
  br i1 %20, label %21, label %26

21:                                               ; preds = %18
  %22 = add nuw nsw i8 %10, 1
  %23 = zext nneg i8 %8 to i16
  %24 = getelementptr i8, ptr %3, i16 %23
  %25 = add nuw nsw i8 %8, 6
  br label %7, !llvm.loop !8

26:                                               ; preds = %18
  %27 = zext nneg i8 %19 to i16
  %28 = getelementptr i8, ptr %9, i16 %27
  store i8 0, ptr %28, align 1, !tbaa !9
  %29 = add nuw nsw i8 %19, 1
  br label %18, !llvm.loop !10

30:                                               ; preds = %1, %34
  %31 = phi i16 [ %40, %34 ], [ 4660, %1 ]
  %32 = phi i8 [ %52, %34 ], [ 0, %1 ]
  %33 = icmp eq i8 %32, 60
  br i1 %33, label %53, label %34

34:                                               ; preds = %30
  %35 = shl i16 %31, 7
  %36 = xor i16 %35, %31
  %37 = lshr i16 %36, 9
  %38 = xor i16 %37, %36
  %39 = shl i16 %38, 8
  %40 = xor i16 %39, %38
  %41 = trunc i16 %38 to i8
  %42 = lshr i8 %41, 3
  %43 = and i8 %42, 3
  %44 = lshr i8 %41, 6
  %45 = zext nneg i8 %44 to i16
  %46 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %45
  %47 = zext nneg i8 %43 to i16
  %48 = getelementptr inbounds nuw [6 x i8], ptr %46, i16 %47
  %49 = and i16 %38, 3
  %50 = getelementptr inbounds nuw i8, ptr %48, i16 %49
  %51 = getelementptr inbounds nuw i8, ptr %50, i16 43
  store i8 1, ptr %51, align 1, !tbaa !9
  %52 = add nuw nsw i8 %32, 1
  br label %30, !llvm.loop !11

53:                                               ; preds = %30, %179
  %54 = phi i16 [ %182, %179 ], [ 0, %30 ]
  %55 = phi i16 [ %181, %179 ], [ 0, %30 ]
  %56 = icmp eq i16 %54, 3
  br i1 %56, label %227, label %57

57:                                               ; preds = %53, %71
  %58 = phi i8 [ %78, %71 ], [ 0, %53 ]
  %59 = phi ptr [ %77, %71 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %53 ]
  %60 = phi ptr [ %76, %71 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), %53 ]
  %61 = phi ptr [ %75, %71 ], [ @g3_b, %53 ]
  %62 = phi ptr [ %74, %71 ], [ @g3_a, %53 ]
  %63 = phi i8 [ %72, %71 ], [ 0, %53 ]
  %64 = icmp eq i8 %63, 6
  br i1 %64, label %168, label %65

65:                                               ; preds = %57, %82
  %66 = phi i8 [ %87, %82 ], [ 0, %57 ]
  %67 = phi ptr [ %86, %82 ], [ %61, %57 ]
  %68 = phi ptr [ %85, %82 ], [ %62, %57 ]
  %69 = phi i8 [ %83, %82 ], [ 0, %57 ]
  %70 = icmp eq i8 %69, 6
  br i1 %70, label %71, label %79

71:                                               ; preds = %65
  %72 = add nuw nsw i8 %63, 1
  %73 = zext i8 %58 to i16
  %74 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %73
  %75 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %73
  %76 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 42), i16 %73
  %77 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %73
  %78 = add nuw i8 %58, 36
  br label %57, !llvm.loop !12

79:                                               ; preds = %65, %163
  %80 = phi i8 [ %167, %163 ], [ 0, %65 ]
  %81 = icmp eq i8 %80, 6
  br i1 %81, label %82, label %88

82:                                               ; preds = %79
  %83 = add nuw nsw i8 %69, 1
  %84 = zext nneg i8 %66 to i16
  %85 = getelementptr i8, ptr %60, i16 %84
  %86 = getelementptr i8, ptr %59, i16 %84
  %87 = add nuw nsw i8 %66, 6
  br label %65, !llvm.loop !13

88:                                               ; preds = %79, %111
  %89 = phi i8 [ %112, %111 ], [ -1, %79 ]
  %90 = phi i8 [ %101, %111 ], [ 0, %79 ]
  %91 = icmp eq i8 %89, 2
  br i1 %91, label %150, label %92

92:                                               ; preds = %88
  %93 = add nsw i8 %89, %63
  %94 = icmp slt i8 %93, 0
  %95 = add nsw i8 %93, -6
  %96 = add nsw i8 %93, 6
  %97 = icmp slt i8 %93, 6
  %98 = select i1 %94, i8 %96, i8 %93
  br label %99

99:                                               ; preds = %117, %92
  %100 = phi i8 [ %118, %117 ], [ -1, %92 ]
  %101 = phi i8 [ %115, %117 ], [ %90, %92 ]
  %102 = icmp eq i8 %100, 2
  br i1 %102, label %111, label %103

103:                                              ; preds = %99
  %104 = add nsw i8 %100, %69
  %105 = icmp slt i8 %104, 0
  %106 = add nsw i8 %104, -6
  %107 = add nsw i8 %104, 6
  %108 = or i8 %100, %89
  %109 = icmp slt i8 %104, 6
  %110 = select i1 %105, i8 %107, i8 %104
  br label %113

111:                                              ; preds = %99
  %112 = add nsw i8 %89, 1
  br label %88, !llvm.loop !14

113:                                              ; preds = %147, %103
  %114 = phi i8 [ %149, %147 ], [ -1, %103 ]
  %115 = phi i8 [ %148, %147 ], [ %101, %103 ]
  %116 = icmp eq i8 %114, 2
  br i1 %116, label %117, label %119

117:                                              ; preds = %113
  %118 = add nsw i8 %100, 1
  br label %99, !llvm.loop !15

119:                                              ; preds = %113
  %120 = or i8 %108, %114
  %121 = icmp eq i8 %120, 0
  br i1 %121, label %147, label %122

122:                                              ; preds = %119
  br i1 %97, label %124, label %123

123:                                              ; preds = %122
  br label %124

124:                                              ; preds = %123, %122
  %125 = phi i8 [ %98, %122 ], [ %95, %123 ]
  br i1 %109, label %127, label %126

126:                                              ; preds = %124
  br label %127

127:                                              ; preds = %126, %124
  %128 = phi i8 [ %110, %124 ], [ %106, %126 ]
  %129 = add nsw i8 %114, %80
  %130 = icmp slt i8 %129, 0
  br i1 %130, label %131, label %133

131:                                              ; preds = %127
  %132 = add nsw i8 %129, 6
  br label %137

133:                                              ; preds = %127
  %134 = icmp samesign ugt i8 %129, 5
  br i1 %134, label %135, label %137

135:                                              ; preds = %133
  %136 = add nsw i8 %129, -6
  br label %137

137:                                              ; preds = %135, %133, %131
  %138 = phi i8 [ %132, %131 ], [ %136, %135 ], [ %129, %133 ]
  %139 = zext i8 %125 to i16
  %140 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %139
  %141 = zext i8 %128 to i16
  %142 = getelementptr inbounds nuw [6 x i8], ptr %140, i16 %141
  %143 = zext i8 %138 to i16
  %144 = getelementptr inbounds nuw i8, ptr %142, i16 %143
  %145 = load i8, ptr %144, align 1, !tbaa !9
  %146 = add i8 %145, %115
  br label %147

147:                                              ; preds = %137, %119
  %148 = phi i8 [ %115, %119 ], [ %146, %137 ]
  %149 = add nsw i8 %114, 1
  br label %113, !llvm.loop !16

150:                                              ; preds = %88
  %151 = zext nneg i8 %80 to i16
  %152 = getelementptr i8, ptr %68, i16 %151
  %153 = load i8, ptr %152, align 1, !tbaa !9
  %154 = icmp eq i8 %153, 0
  br i1 %154, label %159, label %155

155:                                              ; preds = %150
  %156 = icmp ugt i8 %90, 3
  br i1 %156, label %157, label %163

157:                                              ; preds = %155
  %158 = icmp ult i8 %90, 8
  br label %163

159:                                              ; preds = %150
  %160 = icmp ugt i8 %90, 4
  br i1 %160, label %161, label %163

161:                                              ; preds = %159
  %162 = icmp ult i8 %90, 7
  br label %163

163:                                              ; preds = %161, %159, %157, %155
  %164 = phi i1 [ %158, %157 ], [ false, %155 ], [ false, %159 ], [ %162, %161 ]
  %165 = zext i1 %164 to i8
  %166 = getelementptr i8, ptr %67, i16 %151
  store i8 %165, ptr %166, align 1, !tbaa !9
  %167 = add nuw nsw i8 %80, 1
  br label %79, !llvm.loop !17

168:                                              ; preds = %57, %195
  %169 = phi i8 [ %202, %195 ], [ 0, %57 ]
  %170 = phi ptr [ %201, %195 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), %57 ]
  %171 = phi ptr [ %200, %195 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %57 ]
  %172 = phi ptr [ %199, %195 ], [ @g3_a, %57 ]
  %173 = phi ptr [ %198, %195 ], [ @g3_b, %57 ]
  %174 = phi i16 [ %187, %195 ], [ 0, %57 ]
  %175 = phi i8 [ %196, %195 ], [ 0, %57 ]
  %176 = phi i16 [ %189, %195 ], [ %55, %57 ]
  %177 = zext nneg i8 %175 to i16
  %178 = icmp eq i8 %175, 6
  br i1 %178, label %179, label %183

179:                                              ; preds = %168
  %180 = tail call i16 @llvm.fshl.i16(i16 %176, i16 %176, i16 1)
  %181 = xor i16 %180, %174
  %182 = add nuw nsw i16 %54, 1
  br label %53, !llvm.loop !18

183:                                              ; preds = %168, %208
  %184 = phi i8 [ %213, %208 ], [ 0, %168 ]
  %185 = phi ptr [ %212, %208 ], [ %172, %168 ]
  %186 = phi ptr [ %211, %208 ], [ %173, %168 ]
  %187 = phi i16 [ %204, %208 ], [ %174, %168 ]
  %188 = phi i8 [ %209, %208 ], [ 0, %168 ]
  %189 = phi i16 [ %206, %208 ], [ %176, %168 ]
  %190 = icmp eq i8 %188, 6
  br i1 %190, label %195, label %191

191:                                              ; preds = %183
  %192 = zext nneg i8 %188 to i16
  %193 = shl nuw nsw i16 %192, 4
  %194 = add nuw nsw i16 %193, %177
  br label %203

195:                                              ; preds = %183
  %196 = add nuw nsw i8 %175, 1
  %197 = zext i8 %169 to i16
  %198 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %197
  %199 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %197
  %200 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %197
  %201 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 42), i16 %197
  %202 = add nuw i8 %169, 36
  br label %168, !llvm.loop !19

203:                                              ; preds = %214, %191
  %204 = phi i16 [ %219, %214 ], [ %187, %191 ]
  %205 = phi i8 [ %226, %214 ], [ 0, %191 ]
  %206 = phi i16 [ %224, %214 ], [ %189, %191 ]
  %207 = icmp eq i8 %205, 6
  br i1 %207, label %208, label %214

208:                                              ; preds = %203
  %209 = add nuw nsw i8 %188, 1
  %210 = zext nneg i8 %184 to i16
  %211 = getelementptr i8, ptr %171, i16 %210
  %212 = getelementptr i8, ptr %170, i16 %210
  %213 = add nuw nsw i8 %184, 6
  br label %183, !llvm.loop !20

214:                                              ; preds = %203
  %215 = zext nneg i8 %205 to i16
  %216 = getelementptr i8, ptr %186, i16 %215
  %217 = load i8, ptr %216, align 1, !tbaa !9
  %218 = zext i8 %217 to i16
  %219 = add i16 %204, %218
  %220 = shl nuw nsw i16 %215, 8
  %221 = add nuw nsw i16 %220, %194
  %222 = tail call i16 @llvm.fshl.i16(i16 %206, i16 %206, i16 1)
  %223 = xor i16 %221, %222
  %224 = xor i16 %223, %218
  %225 = getelementptr i8, ptr %185, i16 %215
  store i8 %217, ptr %225, align 1, !tbaa !9
  %226 = add nuw nsw i8 %205, 1
  br label %203, !llvm.loop !21

227:                                              ; preds = %53
  store volatile i16 %55, ptr @corpus_result, align 1, !tbaa !2
  br label %228

228:                                              ; preds = %228, %227
  tail call void asm sideeffect "wai", ""() #2, !srcloc !22
  br label %228
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = distinct !{!8, !7}
!9 = !{!4, !4, i64 0}
!10 = distinct !{!10, !7}
!11 = distinct !{!11, !7}
!12 = distinct !{!12, !7}
!13 = distinct !{!13, !7}
!14 = distinct !{!14, !7}
!15 = distinct !{!15, !7}
!16 = distinct !{!16, !7}
!17 = distinct !{!17, !7}
!18 = distinct !{!18, !7}
!19 = distinct !{!19, !7}
!20 = distinct !{!20, !7}
!21 = distinct !{!21, !7}
!22 = !{i64 309}

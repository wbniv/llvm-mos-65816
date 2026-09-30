; ModuleID = '/work/examples/snes/corpus/grid3d_sim.c'
source_filename = "/work/examples/snes/corpus/grid3d_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@g3_a = internal unnamed_addr global [6 x [6 x [6 x i8]]] zeroinitializer, align 1
@g3_b = internal unnamed_addr global [6 x [6 x [6 x i8]]] zeroinitializer, align 1

; Function Attrs: noreturn nounwind
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

23:                                               ; preds = %1, %210
  %24 = phi i16 [ %212, %210 ], [ 0, %1 ]
  %25 = phi i16 [ %213, %210 ], [ 0, %1 ]
  br label %26

26:                                               ; preds = %49, %23
  %27 = phi i8 [ %57, %49 ], [ 0, %23 ]
  %28 = phi ptr [ %56, %49 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %23 ]
  %29 = phi ptr [ %55, %49 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), %23 ]
  %30 = phi ptr [ %54, %49 ], [ @g3_b, %23 ]
  %31 = phi ptr [ %53, %49 ], [ @g3_a, %23 ]
  %32 = phi i8 [ %50, %49 ], [ 0, %23 ]
  br label %33

33:                                               ; preds = %58, %26
  %34 = phi ptr [ %60, %58 ], [ %30, %26 ]
  %35 = phi ptr [ %59, %58 ], [ %31, %26 ]
  %36 = phi ptr [ %62, %58 ], [ @g3_a, %26 ]
  %37 = phi i8 [ %63, %58 ], [ 0, %26 ]
  %38 = phi i8 [ %45, %58 ], [ 0, %26 ]
  %39 = add nsw i8 %38, -1
  %40 = icmp eq i8 %38, 0
  %41 = select i1 %40, i8 5, i8 %39
  %42 = zext i8 %41 to i16
  %43 = zext nneg i8 %37 to i16
  %44 = getelementptr i8, ptr @g3_a, i16 %43
  %45 = add nuw nsw i8 %38, 1
  %46 = add nsw i8 %38, -5
  %47 = icmp samesign ult i8 %38, 5
  %48 = getelementptr inbounds nuw [6 x i8], ptr @g3_a, i16 %42
  br label %64

49:                                               ; preds = %58
  %50 = add nuw nsw i8 %32, 1
  %51 = icmp eq i8 %50, 6
  %52 = zext i8 %27 to i16
  %53 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %52
  %54 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %52
  %55 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 42), i16 %52
  %56 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %52
  %57 = add nuw i8 %27, 36
  br i1 %51, label %194, label %26, !llvm.loop !9

58:                                               ; preds = %189
  %59 = getelementptr i8, ptr %29, i16 %43
  %60 = getelementptr i8, ptr %28, i16 %43
  %61 = icmp eq i8 %45, 6
  %62 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), i16 %43
  %63 = add nuw nsw i8 %37, 6
  br i1 %61, label %49, label %33, !llvm.loop !10

64:                                               ; preds = %189, %33
  %65 = phi i8 [ 0, %33 ], [ %68, %189 ]
  %66 = add nsw i8 %65, -1
  %67 = icmp eq i8 %65, 0
  %68 = add nuw nsw i8 %65, 1
  %69 = select i1 %67, i8 5, i8 %66
  %70 = zext i8 %69 to i16
  %71 = icmp eq i8 %65, 5
  %72 = zext nneg i8 %65 to i16
  %73 = getelementptr inbounds nuw i8, ptr %44, i16 %70
  %74 = getelementptr inbounds nuw i8, ptr %48, i16 %70
  %75 = getelementptr i8, ptr %48, i16 %72
  %76 = getelementptr i8, ptr %36, i16 %72
  br label %77

77:                                               ; preds = %165, %64
  %78 = phi i8 [ 0, %64 ], [ %174, %165 ]
  %79 = phi i8 [ -1, %64 ], [ %175, %165 ]
  %80 = add nsw i8 %79, %32
  %81 = icmp slt i8 %80, 0
  %82 = add nsw i8 %80, -6
  %83 = add nsw i8 %80, 6
  %84 = icmp slt i8 %80, 6
  %85 = select i1 %81, i8 %83, i8 %80
  %86 = select i1 %84, i8 %85, i8 %82
  %87 = zext i8 %86 to i16
  %88 = getelementptr inbounds nuw [36 x i8], ptr %74, i16 %87
  %89 = load i8, ptr %88, align 1, !tbaa !6
  %90 = add i8 %89, %78
  %91 = getelementptr inbounds nuw [36 x i8], ptr %75, i16 %87
  %92 = load i8, ptr %91, align 1, !tbaa !6
  %93 = add i8 %90, %92
  br i1 %71, label %94, label %95

94:                                               ; preds = %77
  br label %95

95:                                               ; preds = %94, %77
  %96 = phi i8 [ %68, %77 ], [ 0, %94 ]
  %97 = getelementptr inbounds nuw [36 x i8], ptr %48, i16 %87
  %98 = zext i8 %96 to i16
  %99 = getelementptr inbounds nuw i8, ptr %97, i16 %98
  %100 = load i8, ptr %99, align 1, !tbaa !6
  %101 = add i8 %93, %100
  %102 = icmp eq i8 %79, 0
  br i1 %84, label %103, label %108

103:                                              ; preds = %95
  %104 = zext i8 %85 to i16
  %105 = getelementptr inbounds nuw [36 x i8], ptr %73, i16 %104
  %106 = load i8, ptr %105, align 1, !tbaa !6
  %107 = add i8 %106, %101
  br i1 %102, label %120, label %113

108:                                              ; preds = %95
  %109 = zext nneg i8 %82 to i16
  %110 = getelementptr inbounds nuw [36 x i8], ptr %73, i16 %109
  %111 = load i8, ptr %110, align 1, !tbaa !6
  %112 = add i8 %111, %101
  br i1 %102, label %120, label %113

113:                                              ; preds = %108, %103
  %114 = phi i16 [ %104, %103 ], [ %109, %108 ]
  %115 = phi i8 [ %107, %103 ], [ %112, %108 ]
  %116 = phi i8 [ %85, %103 ], [ %82, %108 ]
  %117 = getelementptr inbounds nuw [36 x i8], ptr %76, i16 %114
  %118 = load i8, ptr %117, align 1, !tbaa !6
  %119 = add i8 %118, %115
  br label %120

120:                                              ; preds = %113, %108, %103
  %121 = phi i8 [ %112, %108 ], [ %107, %103 ], [ %119, %113 ]
  %122 = phi i8 [ %82, %108 ], [ %85, %103 ], [ %116, %113 ]
  br i1 %71, label %123, label %124

123:                                              ; preds = %120
  br label %124

124:                                              ; preds = %123, %120
  %125 = phi i8 [ %68, %120 ], [ 0, %123 ]
  %126 = zext i8 %122 to i16
  %127 = getelementptr inbounds nuw [36 x i8], ptr %44, i16 %126
  %128 = zext i8 %125 to i16
  %129 = getelementptr inbounds nuw i8, ptr %127, i16 %128
  %130 = load i8, ptr %129, align 1, !tbaa !6
  %131 = add i8 %130, %121
  br i1 %84, label %133, label %132

132:                                              ; preds = %124
  br label %133

133:                                              ; preds = %132, %124
  %134 = phi i8 [ %85, %124 ], [ %82, %132 ]
  br i1 %47, label %136, label %135

135:                                              ; preds = %133
  br label %136

136:                                              ; preds = %135, %133
  %137 = phi i8 [ %45, %133 ], [ %46, %135 ]
  %138 = zext i8 %134 to i16
  %139 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %138
  %140 = zext i8 %137 to i16
  %141 = getelementptr inbounds nuw [6 x i8], ptr %139, i16 %140
  %142 = getelementptr inbounds nuw i8, ptr %141, i16 %70
  %143 = load i8, ptr %142, align 1, !tbaa !6
  %144 = add i8 %131, %143
  br i1 %84, label %146, label %145

145:                                              ; preds = %136
  br label %146

146:                                              ; preds = %145, %136
  %147 = phi i8 [ %85, %136 ], [ %82, %145 ]
  br i1 %47, label %149, label %148

148:                                              ; preds = %146
  br label %149

149:                                              ; preds = %148, %146
  %150 = phi i8 [ %45, %146 ], [ %46, %148 ]
  %151 = zext i8 %147 to i16
  %152 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %151
  %153 = zext i8 %150 to i16
  %154 = getelementptr inbounds nuw [6 x i8], ptr %152, i16 %153
  %155 = getelementptr inbounds nuw i8, ptr %154, i16 %72
  %156 = load i8, ptr %155, align 1, !tbaa !6
  %157 = add i8 %144, %156
  br i1 %84, label %159, label %158

158:                                              ; preds = %149
  br label %159

159:                                              ; preds = %158, %149
  %160 = phi i8 [ %85, %149 ], [ %82, %158 ]
  br i1 %47, label %162, label %161

161:                                              ; preds = %159
  br label %162

162:                                              ; preds = %161, %159
  %163 = phi i8 [ %45, %159 ], [ %46, %161 ]
  br i1 %71, label %164, label %165

164:                                              ; preds = %162
  br label %165

165:                                              ; preds = %164, %162
  %166 = phi i8 [ %68, %162 ], [ 0, %164 ]
  %167 = zext i8 %160 to i16
  %168 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %167
  %169 = zext i8 %163 to i16
  %170 = getelementptr inbounds nuw [6 x i8], ptr %168, i16 %169
  %171 = zext i8 %166 to i16
  %172 = getelementptr inbounds nuw i8, ptr %170, i16 %171
  %173 = load i8, ptr %172, align 1, !tbaa !6
  %174 = add i8 %157, %173
  %175 = add nsw i8 %79, 1
  %176 = icmp eq i8 %175, 2
  br i1 %176, label %177, label %77, !llvm.loop !11

177:                                              ; preds = %165
  %178 = getelementptr i8, ptr %35, i16 %72
  %179 = load i8, ptr %178, align 1, !tbaa !6
  %180 = icmp eq i8 %179, 0
  br i1 %180, label %185, label %181

181:                                              ; preds = %177
  %182 = icmp ugt i8 %174, 3
  br i1 %182, label %183, label %189

183:                                              ; preds = %181
  %184 = icmp ult i8 %174, 8
  br label %189

185:                                              ; preds = %177
  %186 = icmp ugt i8 %174, 4
  br i1 %186, label %187, label %189

187:                                              ; preds = %185
  %188 = icmp ult i8 %174, 7
  br label %189

189:                                              ; preds = %187, %185, %183, %181
  %190 = phi i1 [ %184, %183 ], [ false, %181 ], [ false, %185 ], [ %188, %187 ]
  %191 = zext i1 %190 to i8
  %192 = getelementptr i8, ptr %34, i16 %72
  store i8 %191, ptr %192, align 1, !tbaa !6
  %193 = icmp eq i8 %68, 6
  br i1 %193, label %58, label %64, !llvm.loop !12

194:                                              ; preds = %49, %275
  %195 = phi ptr [ %283, %275 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %49 ]
  %196 = phi ptr [ %282, %275 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 5), %49 ]
  %197 = phi ptr [ %281, %275 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 4), %49 ]
  %198 = phi ptr [ %280, %275 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 3), %49 ]
  %199 = phi ptr [ %279, %275 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 2), %49 ]
  %200 = phi ptr [ %278, %275 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 1), %49 ]
  %201 = phi i8 [ %285, %275 ], [ 0, %49 ]
  %202 = phi ptr [ %277, %275 ], [ @g3_b, %49 ]
  %203 = phi i16 [ %270, %275 ], [ %24, %49 ]
  %204 = phi i8 [ %276, %275 ], [ 0, %49 ]
  %205 = phi i16 [ %266, %275 ], [ 0, %49 ]
  %206 = zext nneg i8 %204 to i16
  %207 = zext i8 %201 to i16
  %208 = getelementptr i8, ptr @g3_a, i16 %207
  %209 = getelementptr i8, ptr @g3_b, i16 %207
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(36) %208, ptr noundef nonnull align 1 dereferenceable(36) %209, i16 36, i1 false), !tbaa !6
  br label %215

210:                                              ; preds = %275
  %211 = tail call i16 @llvm.fshl.i16(i16 %270, i16 %270, i16 1)
  %212 = xor i16 %211, %266
  %213 = add nuw nsw i16 %25, 1
  %214 = icmp eq i16 %213, 3
  br i1 %214, label %286, label %23, !llvm.loop !13

215:                                              ; preds = %215, %194
  %216 = phi i8 [ 0, %194 ], [ %274, %215 ]
  %217 = phi ptr [ %202, %194 ], [ %272, %215 ]
  %218 = phi i16 [ %203, %194 ], [ %270, %215 ]
  %219 = phi i8 [ 0, %194 ], [ %271, %215 ]
  %220 = phi i16 [ %205, %194 ], [ %266, %215 ]
  %221 = zext nneg i8 %219 to i16
  %222 = shl nuw nsw i16 %221, 4
  %223 = add nuw nsw i16 %222, %206
  %224 = load i8, ptr %217, align 1, !tbaa !6
  %225 = zext i8 %224 to i16
  %226 = add i16 %220, %225
  %227 = tail call i16 @llvm.fshl.i16(i16 %218, i16 %218, i16 1)
  %228 = xor i16 %223, %227
  %229 = xor i16 %228, %225
  %230 = zext nneg i8 %216 to i16
  %231 = getelementptr i8, ptr %200, i16 %230
  %232 = load i8, ptr %231, align 1, !tbaa !6
  %233 = zext i8 %232 to i16
  %234 = add i16 %226, %233
  %235 = add nuw nsw i16 %223, 256
  %236 = tail call i16 @llvm.fshl.i16(i16 %229, i16 %229, i16 1)
  %237 = xor i16 %235, %236
  %238 = xor i16 %237, %233
  %239 = getelementptr i8, ptr %199, i16 %230
  %240 = load i8, ptr %239, align 1, !tbaa !6
  %241 = zext i8 %240 to i16
  %242 = add i16 %234, %241
  %243 = add nuw nsw i16 %223, 512
  %244 = tail call i16 @llvm.fshl.i16(i16 %238, i16 %238, i16 1)
  %245 = xor i16 %243, %244
  %246 = xor i16 %245, %241
  %247 = getelementptr i8, ptr %198, i16 %230
  %248 = load i8, ptr %247, align 1, !tbaa !6
  %249 = zext i8 %248 to i16
  %250 = add i16 %242, %249
  %251 = add nuw nsw i16 %223, 768
  %252 = tail call i16 @llvm.fshl.i16(i16 %246, i16 %246, i16 1)
  %253 = xor i16 %251, %252
  %254 = xor i16 %253, %249
  %255 = getelementptr i8, ptr %197, i16 %230
  %256 = load i8, ptr %255, align 1, !tbaa !6
  %257 = zext i8 %256 to i16
  %258 = add i16 %250, %257
  %259 = add nuw nsw i16 %223, 1024
  %260 = tail call i16 @llvm.fshl.i16(i16 %254, i16 %254, i16 1)
  %261 = xor i16 %259, %260
  %262 = xor i16 %261, %257
  %263 = getelementptr i8, ptr %196, i16 %230
  %264 = load i8, ptr %263, align 1, !tbaa !6
  %265 = zext i8 %264 to i16
  %266 = add i16 %258, %265
  %267 = add nuw nsw i16 %223, 1280
  %268 = tail call i16 @llvm.fshl.i16(i16 %262, i16 %262, i16 1)
  %269 = xor i16 %267, %268
  %270 = xor i16 %269, %265
  %271 = add nuw nsw i8 %219, 1
  %272 = getelementptr i8, ptr %195, i16 %230
  %273 = icmp eq i8 %271, 6
  %274 = add nuw nsw i8 %216, 6
  br i1 %273, label %275, label %215, !llvm.loop !14

275:                                              ; preds = %215
  %276 = add nuw nsw i8 %204, 1
  %277 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %207
  %278 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 37), i16 %207
  %279 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 38), i16 %207
  %280 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 39), i16 %207
  %281 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 40), i16 %207
  %282 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 41), i16 %207
  %283 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %207
  %284 = icmp eq i8 %276, 6
  %285 = add nuw i8 %201, 36
  br i1 %284, label %210, label %194, !llvm.loop !15

286:                                              ; preds = %210
  store volatile i16 %212, ptr @corpus_result, align 1, !tbaa !2
  br label %287

287:                                              ; preds = %287, %286
  tail call void asm sideeffect "wai", ""() #4, !srcloc !16
  br label %287
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i16(ptr writeonly captures(none), i8, i16, i1 immarg) #2

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i16(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i16, i1 immarg) #3

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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
!16 = !{i64 309}

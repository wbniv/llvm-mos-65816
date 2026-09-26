; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@one = dso_local global i16 1, align 1

; Function Attrs: nounwind optsize
define dso_local noundef i16 @main(i16 noundef %0, ptr noundef readnone captures(none) %1) local_unnamed_addr #0 {
  %3 = alloca <8 x i16>, align 16
  %4 = alloca <8 x i16>, align 16
  %5 = alloca <4 x float>, align 16
  %6 = alloca <4 x float>, align 16
  %7 = alloca <2 x double>, align 16
  %8 = alloca <2 x double>, align 16
  call void @llvm.lifetime.start.p0(ptr nonnull %3) #3
  %9 = load volatile i16, ptr @one, align 1, !tbaa !2
  %10 = insertelement <8 x i16> <i16 poison, i16 1, i16 2, i16 3, i16 4, i16 5, i16 6, i16 7>, i16 %9, i64 0
  store <8 x i16> %10, ptr %3, align 16, !tbaa !6
  call void @llvm.lifetime.start.p0(ptr nonnull %4) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %5) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %6) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %7) #3
  call void @llvm.lifetime.start.p0(ptr nonnull %8) #3
  %11 = add i16 %9, 2
  %12 = insertelement <8 x i16> <i16 poison, i16 3, i16 4, i16 5, i16 6, i16 7, i16 8, i16 9>, i16 %11, i64 0
  store <8 x i16> %12, ptr %4, align 16, !tbaa !6
  br label %17

13:                                               ; preds = %17
  %14 = add nuw nsw i16 %19, 1
  %15 = icmp eq i16 %14, 8
  %16 = add nuw nsw i8 %18, 2
  br i1 %15, label %28, label %17, !llvm.loop !7

17:                                               ; preds = %2, %13
  %18 = phi i8 [ 0, %2 ], [ %16, %13 ]
  %19 = phi i16 [ 0, %2 ], [ %14, %13 ]
  %20 = zext nneg i8 %18 to i16
  %21 = getelementptr i8, ptr %4, i16 %20
  %22 = load i16, ptr %21, align 2, !tbaa !9
  %23 = getelementptr i8, ptr %3, i16 %20
  %24 = load i16, ptr %23, align 2, !tbaa !9
  %25 = add nsw i16 %24, 2
  %26 = icmp eq i16 %22, %25
  br i1 %26, label %13, label %27

27:                                               ; preds = %17
  tail call void @abort() #4
  unreachable

28:                                               ; preds = %13
  %29 = sub i16 2, %9
  %30 = insertelement <8 x i16> <i16 poison, i16 1, i16 0, i16 -1, i16 -2, i16 -3, i16 -4, i16 -5>, i16 %29, i64 0
  store <8 x i16> %30, ptr %4, align 16, !tbaa !6
  br label %35

31:                                               ; preds = %35
  %32 = add nuw nsw i16 %37, 1
  %33 = icmp eq i16 %32, 8
  %34 = add nuw nsw i8 %36, 2
  br i1 %33, label %46, label %35, !llvm.loop !11

35:                                               ; preds = %28, %31
  %36 = phi i8 [ 0, %28 ], [ %34, %31 ]
  %37 = phi i16 [ 0, %28 ], [ %32, %31 ]
  %38 = zext nneg i8 %36 to i16
  %39 = getelementptr i8, ptr %4, i16 %38
  %40 = load i16, ptr %39, align 2, !tbaa !9
  %41 = getelementptr i8, ptr %3, i16 %38
  %42 = load i16, ptr %41, align 2, !tbaa !9
  %43 = sub nsw i16 2, %42
  %44 = icmp eq i16 %40, %43
  br i1 %44, label %31, label %45

45:                                               ; preds = %35
  tail call void @abort() #4
  unreachable

46:                                               ; preds = %31
  %47 = shl i16 %9, 1
  %48 = insertelement <8 x i16> <i16 poison, i16 2, i16 4, i16 6, i16 8, i16 10, i16 12, i16 14>, i16 %47, i64 0
  store <8 x i16> %48, ptr %4, align 16, !tbaa !6
  br label %53

49:                                               ; preds = %53
  %50 = add nuw nsw i16 %55, 1
  %51 = icmp eq i16 %50, 8
  %52 = add nuw nsw i8 %54, 2
  br i1 %51, label %64, label %53, !llvm.loop !12

53:                                               ; preds = %46, %49
  %54 = phi i8 [ 0, %46 ], [ %52, %49 ]
  %55 = phi i16 [ 0, %46 ], [ %50, %49 ]
  %56 = zext nneg i8 %54 to i16
  %57 = getelementptr i8, ptr %4, i16 %56
  %58 = load i16, ptr %57, align 2, !tbaa !9
  %59 = getelementptr i8, ptr %3, i16 %56
  %60 = load i16, ptr %59, align 2, !tbaa !9
  %61 = shl nsw i16 %60, 1
  %62 = icmp eq i16 %58, %61
  br i1 %62, label %49, label %63

63:                                               ; preds = %53
  tail call void @abort() #4
  unreachable

64:                                               ; preds = %49
  %65 = sdiv i16 2, %9
  %66 = srem i16 2, %9
  %67 = insertelement <8 x i16> <i16 poison, i16 2, i16 1, i16 0, i16 0, i16 0, i16 0, i16 0>, i16 %65, i64 0
  store <8 x i16> %67, ptr %4, align 16, !tbaa !6
  br label %72

68:                                               ; preds = %72
  %69 = add nuw nsw i16 %74, 1
  %70 = icmp eq i16 %69, 8
  %71 = add nuw nsw i8 %73, 2
  br i1 %70, label %83, label %72, !llvm.loop !13

72:                                               ; preds = %64, %68
  %73 = phi i8 [ 0, %64 ], [ %71, %68 ]
  %74 = phi i16 [ 0, %64 ], [ %69, %68 ]
  %75 = zext nneg i8 %73 to i16
  %76 = getelementptr i8, ptr %4, i16 %75
  %77 = load i16, ptr %76, align 2, !tbaa !9
  %78 = getelementptr i8, ptr %3, i16 %75
  %79 = load i16, ptr %78, align 2, !tbaa !9
  %80 = sdiv i16 2, %79
  %81 = icmp eq i16 %77, %80
  br i1 %81, label %68, label %82

82:                                               ; preds = %72
  tail call void @abort() #4
  unreachable

83:                                               ; preds = %68
  %84 = insertelement <8 x i16> <i16 poison, i16 0, i16 0, i16 2, i16 2, i16 2, i16 2, i16 2>, i16 %66, i64 0
  store <8 x i16> %84, ptr %4, align 16, !tbaa !6
  br label %89

85:                                               ; preds = %89
  %86 = add nuw nsw i16 %91, 1
  %87 = icmp eq i16 %86, 8
  %88 = add nuw nsw i8 %90, 2
  br i1 %87, label %100, label %89, !llvm.loop !14

89:                                               ; preds = %83, %85
  %90 = phi i8 [ 0, %83 ], [ %88, %85 ]
  %91 = phi i16 [ 0, %83 ], [ %86, %85 ]
  %92 = zext nneg i8 %90 to i16
  %93 = getelementptr i8, ptr %4, i16 %92
  %94 = load i16, ptr %93, align 2, !tbaa !9
  %95 = getelementptr i8, ptr %3, i16 %92
  %96 = load i16, ptr %95, align 2, !tbaa !9
  %97 = srem i16 2, %96
  %98 = icmp eq i16 %94, %97
  br i1 %98, label %85, label %99

99:                                               ; preds = %89
  tail call void @abort() #4
  unreachable

100:                                              ; preds = %85
  %101 = xor i16 %9, 2
  %102 = insertelement <8 x i16> <i16 poison, i16 3, i16 0, i16 1, i16 6, i16 7, i16 4, i16 5>, i16 %101, i64 0
  store <8 x i16> %102, ptr %4, align 16, !tbaa !6
  br label %107

103:                                              ; preds = %107
  %104 = add nuw nsw i16 %109, 1
  %105 = icmp eq i16 %104, 8
  %106 = add nuw nsw i8 %108, 2
  br i1 %105, label %118, label %107, !llvm.loop !15

107:                                              ; preds = %100, %103
  %108 = phi i8 [ 0, %100 ], [ %106, %103 ]
  %109 = phi i16 [ 0, %100 ], [ %104, %103 ]
  %110 = zext nneg i8 %108 to i16
  %111 = getelementptr i8, ptr %4, i16 %110
  %112 = load i16, ptr %111, align 2, !tbaa !9
  %113 = getelementptr i8, ptr %3, i16 %110
  %114 = load i16, ptr %113, align 2, !tbaa !9
  %115 = xor i16 %114, %112
  %116 = icmp eq i16 %115, 2
  br i1 %116, label %103, label %117

117:                                              ; preds = %107
  tail call void @abort() #4
  unreachable

118:                                              ; preds = %103
  %119 = and i16 %9, 2
  %120 = insertelement <8 x i16> <i16 poison, i16 0, i16 2, i16 2, i16 0, i16 0, i16 2, i16 2>, i16 %119, i64 0
  store <8 x i16> %120, ptr %4, align 16, !tbaa !6
  br label %125

121:                                              ; preds = %125
  %122 = add nuw nsw i16 %127, 1
  %123 = icmp eq i16 %122, 8
  %124 = add nuw nsw i8 %126, 2
  br i1 %123, label %136, label %125, !llvm.loop !16

125:                                              ; preds = %118, %121
  %126 = phi i8 [ 0, %118 ], [ %124, %121 ]
  %127 = phi i16 [ 0, %118 ], [ %122, %121 ]
  %128 = zext nneg i8 %126 to i16
  %129 = getelementptr i8, ptr %4, i16 %128
  %130 = load i16, ptr %129, align 2, !tbaa !9
  %131 = getelementptr i8, ptr %3, i16 %128
  %132 = load i16, ptr %131, align 2, !tbaa !9
  %133 = and i16 %132, 2
  %134 = icmp eq i16 %130, %133
  br i1 %134, label %121, label %135

135:                                              ; preds = %125
  tail call void @abort() #4
  unreachable

136:                                              ; preds = %121
  %137 = or i16 %9, 2
  %138 = insertelement <8 x i16> <i16 poison, i16 3, i16 2, i16 3, i16 6, i16 7, i16 6, i16 7>, i16 %137, i64 0
  store <8 x i16> %138, ptr %4, align 16, !tbaa !6
  br label %143

139:                                              ; preds = %143
  %140 = add nuw nsw i16 %145, 1
  %141 = icmp eq i16 %140, 8
  %142 = add nuw nsw i8 %144, 2
  br i1 %141, label %154, label %143, !llvm.loop !17

143:                                              ; preds = %136, %139
  %144 = phi i8 [ 0, %136 ], [ %142, %139 ]
  %145 = phi i16 [ 0, %136 ], [ %140, %139 ]
  %146 = zext nneg i8 %144 to i16
  %147 = getelementptr i8, ptr %4, i16 %146
  %148 = load i16, ptr %147, align 2, !tbaa !9
  %149 = getelementptr i8, ptr %3, i16 %146
  %150 = load i16, ptr %149, align 2, !tbaa !9
  %151 = or i16 %150, 2
  %152 = icmp eq i16 %148, %151
  br i1 %152, label %139, label %153

153:                                              ; preds = %143
  tail call void @abort() #4
  unreachable

154:                                              ; preds = %139
  %155 = shl i16 2, %9
  %156 = insertelement <8 x i16> <i16 poison, i16 4, i16 8, i16 16, i16 32, i16 64, i16 128, i16 256>, i16 %155, i64 0
  store <8 x i16> %156, ptr %4, align 16, !tbaa !6
  br label %161

157:                                              ; preds = %161
  %158 = add nuw nsw i16 %163, 1
  %159 = icmp eq i16 %158, 8
  %160 = add nuw nsw i8 %162, 2
  br i1 %159, label %172, label %161, !llvm.loop !18

161:                                              ; preds = %154, %157
  %162 = phi i8 [ 0, %154 ], [ %160, %157 ]
  %163 = phi i16 [ 0, %154 ], [ %158, %157 ]
  %164 = zext nneg i8 %162 to i16
  %165 = getelementptr i8, ptr %4, i16 %164
  %166 = load i16, ptr %165, align 2, !tbaa !9
  %167 = getelementptr i8, ptr %3, i16 %164
  %168 = load i16, ptr %167, align 2, !tbaa !9
  %169 = shl i16 2, %168
  %170 = icmp eq i16 %166, %169
  br i1 %170, label %157, label %171

171:                                              ; preds = %161
  tail call void @abort() #4
  unreachable

172:                                              ; preds = %157
  %173 = lshr i16 2, %9
  %174 = insertelement <8 x i16> <i16 poison, i16 1, i16 0, i16 0, i16 0, i16 0, i16 0, i16 0>, i16 %173, i64 0
  store <8 x i16> %174, ptr %4, align 16, !tbaa !6
  br label %179

175:                                              ; preds = %179
  %176 = add nuw nsw i16 %181, 1
  %177 = icmp eq i16 %176, 8
  %178 = add nuw nsw i8 %180, 2
  br i1 %177, label %190, label %179, !llvm.loop !19

179:                                              ; preds = %172, %175
  %180 = phi i8 [ 0, %172 ], [ %178, %175 ]
  %181 = phi i16 [ 0, %172 ], [ %176, %175 ]
  %182 = zext nneg i8 %180 to i16
  %183 = getelementptr i8, ptr %4, i16 %182
  %184 = load i16, ptr %183, align 2, !tbaa !9
  %185 = getelementptr i8, ptr %3, i16 %182
  %186 = load i16, ptr %185, align 2, !tbaa !9
  %187 = lshr i16 2, %186
  %188 = icmp eq i16 %184, %187
  br i1 %188, label %175, label %189

189:                                              ; preds = %179
  tail call void @abort() #4
  unreachable

190:                                              ; preds = %175
  store <8 x i16> %12, ptr %4, align 16, !tbaa !6
  br label %195

191:                                              ; preds = %195
  %192 = add nuw nsw i16 %197, 1
  %193 = icmp eq i16 %192, 8
  %194 = add nuw nsw i8 %196, 2
  br i1 %193, label %206, label %195, !llvm.loop !20

195:                                              ; preds = %190, %191
  %196 = phi i8 [ 0, %190 ], [ %194, %191 ]
  %197 = phi i16 [ 0, %190 ], [ %192, %191 ]
  %198 = zext nneg i8 %196 to i16
  %199 = getelementptr i8, ptr %4, i16 %198
  %200 = load i16, ptr %199, align 2, !tbaa !9
  %201 = getelementptr i8, ptr %3, i16 %198
  %202 = load i16, ptr %201, align 2, !tbaa !9
  %203 = add nsw i16 %202, 2
  %204 = icmp eq i16 %200, %203
  br i1 %204, label %191, label %205

205:                                              ; preds = %195
  tail call void @abort() #4
  unreachable

206:                                              ; preds = %191
  %207 = add i16 %9, -2
  %208 = insertelement <8 x i16> <i16 poison, i16 -1, i16 0, i16 1, i16 2, i16 3, i16 4, i16 5>, i16 %207, i64 0
  store <8 x i16> %208, ptr %4, align 16, !tbaa !6
  br label %213

209:                                              ; preds = %213
  %210 = add nuw nsw i16 %215, 1
  %211 = icmp eq i16 %210, 8
  %212 = add nuw nsw i8 %214, 2
  br i1 %211, label %224, label %213, !llvm.loop !21

213:                                              ; preds = %206, %209
  %214 = phi i8 [ 0, %206 ], [ %212, %209 ]
  %215 = phi i16 [ 0, %206 ], [ %210, %209 ]
  %216 = zext nneg i8 %214 to i16
  %217 = getelementptr i8, ptr %4, i16 %216
  %218 = load i16, ptr %217, align 2, !tbaa !9
  %219 = getelementptr i8, ptr %3, i16 %216
  %220 = load i16, ptr %219, align 2, !tbaa !9
  %221 = add nsw i16 %220, -2
  %222 = icmp eq i16 %218, %221
  br i1 %222, label %209, label %223

223:                                              ; preds = %213
  tail call void @abort() #4
  unreachable

224:                                              ; preds = %209
  store <8 x i16> %48, ptr %4, align 16, !tbaa !6
  br label %229

225:                                              ; preds = %229
  %226 = add nuw nsw i16 %231, 1
  %227 = icmp eq i16 %226, 8
  %228 = add nuw nsw i8 %230, 2
  br i1 %227, label %240, label %229, !llvm.loop !22

229:                                              ; preds = %224, %225
  %230 = phi i8 [ 0, %224 ], [ %228, %225 ]
  %231 = phi i16 [ 0, %224 ], [ %226, %225 ]
  %232 = zext nneg i8 %230 to i16
  %233 = getelementptr i8, ptr %4, i16 %232
  %234 = load i16, ptr %233, align 2, !tbaa !9
  %235 = getelementptr i8, ptr %3, i16 %232
  %236 = load i16, ptr %235, align 2, !tbaa !9
  %237 = shl nsw i16 %236, 1
  %238 = icmp eq i16 %234, %237
  br i1 %238, label %225, label %239

239:                                              ; preds = %229
  tail call void @abort() #4
  unreachable

240:                                              ; preds = %225
  %241 = sdiv i16 %9, 2
  %242 = srem i16 %9, 2
  %243 = insertelement <8 x i16> <i16 poison, i16 0, i16 1, i16 1, i16 2, i16 2, i16 3, i16 3>, i16 %241, i64 0
  store <8 x i16> %243, ptr %4, align 16, !tbaa !6
  br label %248

244:                                              ; preds = %248
  %245 = add nuw nsw i16 %250, 1
  %246 = icmp eq i16 %245, 8
  %247 = add nuw nsw i8 %249, 2
  br i1 %246, label %259, label %248, !llvm.loop !23

248:                                              ; preds = %240, %244
  %249 = phi i8 [ 0, %240 ], [ %247, %244 ]
  %250 = phi i16 [ 0, %240 ], [ %245, %244 ]
  %251 = zext nneg i8 %249 to i16
  %252 = getelementptr i8, ptr %4, i16 %251
  %253 = load i16, ptr %252, align 2, !tbaa !9
  %254 = getelementptr i8, ptr %3, i16 %251
  %255 = load i16, ptr %254, align 2, !tbaa !9
  %256 = sdiv i16 %255, 2
  %257 = icmp eq i16 %253, %256
  br i1 %257, label %244, label %258

258:                                              ; preds = %248
  tail call void @abort() #4
  unreachable

259:                                              ; preds = %244
  %260 = insertelement <8 x i16> <i16 poison, i16 1, i16 0, i16 1, i16 0, i16 1, i16 0, i16 1>, i16 %242, i64 0
  store <8 x i16> %260, ptr %4, align 16, !tbaa !6
  br label %265

261:                                              ; preds = %265
  %262 = add nuw nsw i16 %267, 1
  %263 = icmp eq i16 %262, 8
  %264 = add nuw nsw i8 %266, 2
  br i1 %263, label %276, label %265, !llvm.loop !24

265:                                              ; preds = %259, %261
  %266 = phi i8 [ 0, %259 ], [ %264, %261 ]
  %267 = phi i16 [ 0, %259 ], [ %262, %261 ]
  %268 = zext nneg i8 %266 to i16
  %269 = getelementptr i8, ptr %4, i16 %268
  %270 = load i16, ptr %269, align 2, !tbaa !9
  %271 = getelementptr i8, ptr %3, i16 %268
  %272 = load i16, ptr %271, align 2, !tbaa !9
  %273 = srem i16 %272, 2
  %274 = icmp eq i16 %270, %273
  br i1 %274, label %261, label %275

275:                                              ; preds = %265
  tail call void @abort() #4
  unreachable

276:                                              ; preds = %261
  store <8 x i16> %102, ptr %4, align 16, !tbaa !6
  br label %281

277:                                              ; preds = %281
  %278 = add nuw nsw i16 %283, 1
  %279 = icmp eq i16 %278, 8
  %280 = add nuw nsw i8 %282, 2
  br i1 %279, label %292, label %281, !llvm.loop !25

281:                                              ; preds = %276, %277
  %282 = phi i8 [ 0, %276 ], [ %280, %277 ]
  %283 = phi i16 [ 0, %276 ], [ %278, %277 ]
  %284 = zext nneg i8 %282 to i16
  %285 = getelementptr i8, ptr %4, i16 %284
  %286 = load i16, ptr %285, align 2, !tbaa !9
  %287 = getelementptr i8, ptr %3, i16 %284
  %288 = load i16, ptr %287, align 2, !tbaa !9
  %289 = xor i16 %288, %286
  %290 = icmp eq i16 %289, 2
  br i1 %290, label %277, label %291

291:                                              ; preds = %281
  tail call void @abort() #4
  unreachable

292:                                              ; preds = %277
  store <8 x i16> %120, ptr %4, align 16, !tbaa !6
  br label %297

293:                                              ; preds = %297
  %294 = add nuw nsw i16 %299, 1
  %295 = icmp eq i16 %294, 8
  %296 = add nuw nsw i8 %298, 2
  br i1 %295, label %308, label %297, !llvm.loop !26

297:                                              ; preds = %292, %293
  %298 = phi i8 [ 0, %292 ], [ %296, %293 ]
  %299 = phi i16 [ 0, %292 ], [ %294, %293 ]
  %300 = zext nneg i8 %298 to i16
  %301 = getelementptr i8, ptr %4, i16 %300
  %302 = load i16, ptr %301, align 2, !tbaa !9
  %303 = getelementptr i8, ptr %3, i16 %300
  %304 = load i16, ptr %303, align 2, !tbaa !9
  %305 = and i16 %304, 2
  %306 = icmp eq i16 %302, %305
  br i1 %306, label %293, label %307

307:                                              ; preds = %297
  tail call void @abort() #4
  unreachable

308:                                              ; preds = %293
  store <8 x i16> %138, ptr %4, align 16, !tbaa !6
  br label %313

309:                                              ; preds = %313
  %310 = add nuw nsw i16 %315, 1
  %311 = icmp eq i16 %310, 8
  %312 = add nuw nsw i8 %314, 2
  br i1 %311, label %324, label %313, !llvm.loop !27

313:                                              ; preds = %308, %309
  %314 = phi i8 [ 0, %308 ], [ %312, %309 ]
  %315 = phi i16 [ 0, %308 ], [ %310, %309 ]
  %316 = zext nneg i8 %314 to i16
  %317 = getelementptr i8, ptr %4, i16 %316
  %318 = load i16, ptr %317, align 2, !tbaa !9
  %319 = getelementptr i8, ptr %3, i16 %316
  %320 = load i16, ptr %319, align 2, !tbaa !9
  %321 = or i16 %320, 2
  %322 = icmp eq i16 %318, %321
  br i1 %322, label %309, label %323

323:                                              ; preds = %313
  tail call void @abort() #4
  unreachable

324:                                              ; preds = %309
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %329

325:                                              ; preds = %329
  %326 = add nuw nsw i16 %331, 1
  %327 = icmp eq i16 %326, 4
  %328 = add nuw nsw i8 %330, 4
  br i1 %327, label %339, label %329, !llvm.loop !28

329:                                              ; preds = %324, %325
  %330 = phi i8 [ 0, %324 ], [ %328, %325 ]
  %331 = phi i16 [ 0, %324 ], [ %326, %325 ]
  %332 = zext nneg i8 %330 to i16
  %333 = getelementptr i8, ptr %5, i16 %332
  %334 = load float, ptr %333, align 4, !tbaa !29
  %335 = getelementptr i8, ptr %6, i16 %332
  %336 = load float, ptr %335, align 4, !tbaa !29
  %337 = fcmp une float %334, %336
  br i1 %337, label %338, label %325

338:                                              ; preds = %329
  tail call void @abort() #4
  unreachable

339:                                              ; preds = %325
  store <4 x float> <float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float -2.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float -2.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %344

340:                                              ; preds = %344
  %341 = add nuw nsw i16 %346, 1
  %342 = icmp eq i16 %341, 4
  %343 = add nuw nsw i8 %345, 4
  br i1 %342, label %354, label %344, !llvm.loop !31

344:                                              ; preds = %339, %340
  %345 = phi i8 [ 0, %339 ], [ %343, %340 ]
  %346 = phi i16 [ 0, %339 ], [ %341, %340 ]
  %347 = zext nneg i8 %345 to i16
  %348 = getelementptr i8, ptr %5, i16 %347
  %349 = load float, ptr %348, align 4, !tbaa !29
  %350 = getelementptr i8, ptr %6, i16 %347
  %351 = load float, ptr %350, align 4, !tbaa !29
  %352 = fcmp une float %349, %351
  br i1 %352, label %353, label %340

353:                                              ; preds = %344
  tail call void @abort() #4
  unreachable

354:                                              ; preds = %340
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %359

355:                                              ; preds = %359
  %356 = add nuw nsw i16 %361, 1
  %357 = icmp eq i16 %356, 4
  %358 = add nuw nsw i8 %360, 4
  br i1 %357, label %369, label %359, !llvm.loop !32

359:                                              ; preds = %354, %355
  %360 = phi i8 [ 0, %354 ], [ %358, %355 ]
  %361 = phi i16 [ 0, %354 ], [ %356, %355 ]
  %362 = zext nneg i8 %360 to i16
  %363 = getelementptr i8, ptr %5, i16 %362
  %364 = load float, ptr %363, align 4, !tbaa !29
  %365 = getelementptr i8, ptr %6, i16 %362
  %366 = load float, ptr %365, align 4, !tbaa !29
  %367 = fcmp une float %364, %366
  br i1 %367, label %368, label %355

368:                                              ; preds = %359
  tail call void @abort() #4
  unreachable

369:                                              ; preds = %355
  store <4 x float> <float 2.000000e+00, float 1.000000e+00, float 0x3FE5555560000000, float 5.000000e-01>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 2.000000e+00, float 1.000000e+00, float 0x3FE5555560000000, float 5.000000e-01>, ptr %6, align 16, !tbaa !6
  br label %374

370:                                              ; preds = %374
  %371 = add nuw nsw i16 %376, 1
  %372 = icmp eq i16 %371, 4
  %373 = add nuw nsw i8 %375, 4
  br i1 %372, label %384, label %374, !llvm.loop !33

374:                                              ; preds = %369, %370
  %375 = phi i8 [ 0, %369 ], [ %373, %370 ]
  %376 = phi i16 [ 0, %369 ], [ %371, %370 ]
  %377 = zext nneg i8 %375 to i16
  %378 = getelementptr i8, ptr %5, i16 %377
  %379 = load float, ptr %378, align 4, !tbaa !29
  %380 = getelementptr i8, ptr %6, i16 %377
  %381 = load float, ptr %380, align 4, !tbaa !29
  %382 = fcmp une float %379, %381
  br i1 %382, label %383, label %370

383:                                              ; preds = %374
  tail call void @abort() #4
  unreachable

384:                                              ; preds = %370
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 3.000000e+00, float 4.000000e+00, float 5.000000e+00, float 6.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %389

385:                                              ; preds = %389
  %386 = add nuw nsw i16 %391, 1
  %387 = icmp eq i16 %386, 4
  %388 = add nuw nsw i8 %390, 4
  br i1 %387, label %399, label %389, !llvm.loop !34

389:                                              ; preds = %384, %385
  %390 = phi i8 [ 0, %384 ], [ %388, %385 ]
  %391 = phi i16 [ 0, %384 ], [ %386, %385 ]
  %392 = zext nneg i8 %390 to i16
  %393 = getelementptr i8, ptr %5, i16 %392
  %394 = load float, ptr %393, align 4, !tbaa !29
  %395 = getelementptr i8, ptr %6, i16 %392
  %396 = load float, ptr %395, align 4, !tbaa !29
  %397 = fcmp une float %394, %396
  br i1 %397, label %398, label %385

398:                                              ; preds = %389
  tail call void @abort() #4
  unreachable

399:                                              ; preds = %385
  store <4 x float> <float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 2.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 2.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %404

400:                                              ; preds = %404
  %401 = add nuw nsw i16 %406, 1
  %402 = icmp eq i16 %401, 4
  %403 = add nuw nsw i8 %405, 4
  br i1 %402, label %414, label %404, !llvm.loop !35

404:                                              ; preds = %399, %400
  %405 = phi i8 [ 0, %399 ], [ %403, %400 ]
  %406 = phi i16 [ 0, %399 ], [ %401, %400 ]
  %407 = zext nneg i8 %405 to i16
  %408 = getelementptr i8, ptr %5, i16 %407
  %409 = load float, ptr %408, align 4, !tbaa !29
  %410 = getelementptr i8, ptr %6, i16 %407
  %411 = load float, ptr %410, align 4, !tbaa !29
  %412 = fcmp une float %409, %411
  br i1 %412, label %413, label %400

413:                                              ; preds = %404
  tail call void @abort() #4
  unreachable

414:                                              ; preds = %400
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 2.000000e+00, float 4.000000e+00, float 6.000000e+00, float 8.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %419

415:                                              ; preds = %419
  %416 = add nuw nsw i16 %421, 1
  %417 = icmp eq i16 %416, 4
  %418 = add nuw nsw i8 %420, 4
  br i1 %417, label %429, label %419, !llvm.loop !36

419:                                              ; preds = %414, %415
  %420 = phi i8 [ 0, %414 ], [ %418, %415 ]
  %421 = phi i16 [ 0, %414 ], [ %416, %415 ]
  %422 = zext nneg i8 %420 to i16
  %423 = getelementptr i8, ptr %5, i16 %422
  %424 = load float, ptr %423, align 4, !tbaa !29
  %425 = getelementptr i8, ptr %6, i16 %422
  %426 = load float, ptr %425, align 4, !tbaa !29
  %427 = fcmp une float %424, %426
  br i1 %427, label %428, label %415

428:                                              ; preds = %419
  tail call void @abort() #4
  unreachable

429:                                              ; preds = %415
  store <4 x float> <float 5.000000e-01, float 1.000000e+00, float 1.500000e+00, float 2.000000e+00>, ptr %5, align 16, !tbaa !6
  store <4 x float> <float 5.000000e-01, float 1.000000e+00, float 1.500000e+00, float 2.000000e+00>, ptr %6, align 16, !tbaa !6
  br label %434

430:                                              ; preds = %434
  %431 = add nuw nsw i16 %436, 1
  %432 = icmp eq i16 %431, 4
  %433 = add nuw nsw i8 %435, 4
  br i1 %432, label %444, label %434, !llvm.loop !37

434:                                              ; preds = %429, %430
  %435 = phi i8 [ 0, %429 ], [ %433, %430 ]
  %436 = phi i16 [ 0, %429 ], [ %431, %430 ]
  %437 = zext nneg i8 %435 to i16
  %438 = getelementptr i8, ptr %5, i16 %437
  %439 = load float, ptr %438, align 4, !tbaa !29
  %440 = getelementptr i8, ptr %6, i16 %437
  %441 = load float, ptr %440, align 4, !tbaa !29
  %442 = fcmp une float %439, %441
  br i1 %442, label %443, label %430

443:                                              ; preds = %434
  tail call void @abort() #4
  unreachable

444:                                              ; preds = %430
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %447

445:                                              ; preds = %447
  %446 = add nuw nsw i8 %448, 8
  br i1 %449, label %447, label %457, !llvm.loop !38

447:                                              ; preds = %444, %445
  %448 = phi i8 [ 0, %444 ], [ %446, %445 ]
  %449 = phi i1 [ true, %444 ], [ false, %445 ]
  %450 = zext nneg i8 %448 to i16
  %451 = getelementptr i8, ptr %7, i16 %450
  %452 = load double, ptr %451, align 8, !tbaa !39
  %453 = getelementptr i8, ptr %8, i16 %450
  %454 = load double, ptr %453, align 8, !tbaa !39
  %455 = fcmp une double %452, %454
  br i1 %455, label %456, label %445

456:                                              ; preds = %447
  tail call void @abort() #4
  unreachable

457:                                              ; preds = %445
  store <2 x double> <double 1.000000e+00, double 0.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 1.000000e+00, double 0.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %460

458:                                              ; preds = %460
  %459 = add nuw nsw i8 %461, 8
  br i1 %462, label %460, label %470, !llvm.loop !41

460:                                              ; preds = %457, %458
  %461 = phi i8 [ 0, %457 ], [ %459, %458 ]
  %462 = phi i1 [ true, %457 ], [ false, %458 ]
  %463 = zext nneg i8 %461 to i16
  %464 = getelementptr i8, ptr %7, i16 %463
  %465 = load double, ptr %464, align 8, !tbaa !39
  %466 = getelementptr i8, ptr %8, i16 %463
  %467 = load double, ptr %466, align 8, !tbaa !39
  %468 = fcmp une double %465, %467
  br i1 %468, label %469, label %458

469:                                              ; preds = %460
  tail call void @abort() #4
  unreachable

470:                                              ; preds = %458
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %473

471:                                              ; preds = %473
  %472 = add nuw nsw i8 %474, 8
  br i1 %475, label %473, label %483, !llvm.loop !42

473:                                              ; preds = %470, %471
  %474 = phi i8 [ 0, %470 ], [ %472, %471 ]
  %475 = phi i1 [ true, %470 ], [ false, %471 ]
  %476 = zext nneg i8 %474 to i16
  %477 = getelementptr i8, ptr %7, i16 %476
  %478 = load double, ptr %477, align 8, !tbaa !39
  %479 = getelementptr i8, ptr %8, i16 %476
  %480 = load double, ptr %479, align 8, !tbaa !39
  %481 = fcmp une double %478, %480
  br i1 %481, label %482, label %471

482:                                              ; preds = %473
  tail call void @abort() #4
  unreachable

483:                                              ; preds = %471
  store <2 x double> <double 2.000000e+00, double 1.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 2.000000e+00, double 1.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %486

484:                                              ; preds = %486
  %485 = add nuw nsw i8 %487, 8
  br i1 %488, label %486, label %496, !llvm.loop !43

486:                                              ; preds = %483, %484
  %487 = phi i8 [ 0, %483 ], [ %485, %484 ]
  %488 = phi i1 [ true, %483 ], [ false, %484 ]
  %489 = zext nneg i8 %487 to i16
  %490 = getelementptr i8, ptr %7, i16 %489
  %491 = load double, ptr %490, align 8, !tbaa !39
  %492 = getelementptr i8, ptr %8, i16 %489
  %493 = load double, ptr %492, align 8, !tbaa !39
  %494 = fcmp une double %491, %493
  br i1 %494, label %495, label %484

495:                                              ; preds = %486
  tail call void @abort() #4
  unreachable

496:                                              ; preds = %484
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 3.000000e+00, double 4.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %499

497:                                              ; preds = %499
  %498 = add nuw nsw i8 %500, 8
  br i1 %501, label %499, label %509, !llvm.loop !44

499:                                              ; preds = %496, %497
  %500 = phi i8 [ 0, %496 ], [ %498, %497 ]
  %501 = phi i1 [ true, %496 ], [ false, %497 ]
  %502 = zext nneg i8 %500 to i16
  %503 = getelementptr i8, ptr %7, i16 %502
  %504 = load double, ptr %503, align 8, !tbaa !39
  %505 = getelementptr i8, ptr %8, i16 %502
  %506 = load double, ptr %505, align 8, !tbaa !39
  %507 = fcmp une double %504, %506
  br i1 %507, label %508, label %497

508:                                              ; preds = %499
  tail call void @abort() #4
  unreachable

509:                                              ; preds = %497
  store <2 x double> <double -1.000000e+00, double 0.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double -1.000000e+00, double 0.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %512

510:                                              ; preds = %512
  %511 = add nuw nsw i8 %513, 8
  br i1 %514, label %512, label %522, !llvm.loop !45

512:                                              ; preds = %509, %510
  %513 = phi i8 [ 0, %509 ], [ %511, %510 ]
  %514 = phi i1 [ true, %509 ], [ false, %510 ]
  %515 = zext nneg i8 %513 to i16
  %516 = getelementptr i8, ptr %7, i16 %515
  %517 = load double, ptr %516, align 8, !tbaa !39
  %518 = getelementptr i8, ptr %8, i16 %515
  %519 = load double, ptr %518, align 8, !tbaa !39
  %520 = fcmp une double %517, %519
  br i1 %520, label %521, label %510

521:                                              ; preds = %512
  tail call void @abort() #4
  unreachable

522:                                              ; preds = %510
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 2.000000e+00, double 4.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %525

523:                                              ; preds = %525
  %524 = add nuw nsw i8 %526, 8
  br i1 %527, label %525, label %535, !llvm.loop !46

525:                                              ; preds = %522, %523
  %526 = phi i8 [ 0, %522 ], [ %524, %523 ]
  %527 = phi i1 [ true, %522 ], [ false, %523 ]
  %528 = zext nneg i8 %526 to i16
  %529 = getelementptr i8, ptr %7, i16 %528
  %530 = load double, ptr %529, align 8, !tbaa !39
  %531 = getelementptr i8, ptr %8, i16 %528
  %532 = load double, ptr %531, align 8, !tbaa !39
  %533 = fcmp une double %530, %532
  br i1 %533, label %534, label %523

534:                                              ; preds = %525
  tail call void @abort() #4
  unreachable

535:                                              ; preds = %523
  store <2 x double> <double 5.000000e-01, double 1.000000e+00>, ptr %7, align 16, !tbaa !6
  store <2 x double> <double 5.000000e-01, double 1.000000e+00>, ptr %8, align 16, !tbaa !6
  br label %538

536:                                              ; preds = %538
  %537 = add nuw nsw i8 %539, 8
  br i1 %540, label %538, label %548, !llvm.loop !47

538:                                              ; preds = %535, %536
  %539 = phi i8 [ 0, %535 ], [ %537, %536 ]
  %540 = phi i1 [ true, %535 ], [ false, %536 ]
  %541 = zext nneg i8 %539 to i16
  %542 = getelementptr i8, ptr %7, i16 %541
  %543 = load double, ptr %542, align 8, !tbaa !39
  %544 = getelementptr i8, ptr %8, i16 %541
  %545 = load double, ptr %544, align 8, !tbaa !39
  %546 = fcmp une double %543, %545
  br i1 %546, label %547, label %536

547:                                              ; preds = %538
  tail call void @abort() #4
  unreachable

548:                                              ; preds = %536
  call void @llvm.lifetime.end.p0(ptr nonnull %8) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %7) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %6) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %5) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %4) #3
  call void @llvm.lifetime.end.p0(ptr nonnull %3) #3
  ret i16 0
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: noreturn nounwind optsize
declare dso_local void @abort() local_unnamed_addr #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

attributes #0 = { nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #3 = { nounwind }
attributes #4 = { noreturn nounwind optsize }

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
!9 = !{!10, !10, i64 0}
!10 = !{!"short", !4, i64 0}
!11 = distinct !{!11, !8}
!12 = distinct !{!12, !8}
!13 = distinct !{!13, !8}
!14 = distinct !{!14, !8}
!15 = distinct !{!15, !8}
!16 = distinct !{!16, !8}
!17 = distinct !{!17, !8}
!18 = distinct !{!18, !8}
!19 = distinct !{!19, !8}
!20 = distinct !{!20, !8}
!21 = distinct !{!21, !8}
!22 = distinct !{!22, !8}
!23 = distinct !{!23, !8}
!24 = distinct !{!24, !8}
!25 = distinct !{!25, !8}
!26 = distinct !{!26, !8}
!27 = distinct !{!27, !8}
!28 = distinct !{!28, !8}
!29 = !{!30, !30, i64 0}
!30 = !{!"float", !4, i64 0}
!31 = distinct !{!31, !8}
!32 = distinct !{!32, !8}
!33 = distinct !{!33, !8}
!34 = distinct !{!34, !8}
!35 = distinct !{!35, !8}
!36 = distinct !{!36, !8}
!37 = distinct !{!37, !8}
!38 = distinct !{!38, !8}
!39 = !{!40, !40, i64 0}
!40 = !{!"double", !4, i64 0}
!41 = distinct !{!41, !8}
!42 = distinct !{!42, !8}
!43 = distinct !{!43, !8}
!44 = distinct !{!44, !8}
!45 = distinct !{!45, !8}
!46 = distinct !{!46, !8}
!47 = distinct !{!47, !8}

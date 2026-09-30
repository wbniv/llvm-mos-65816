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

23:                                               ; preds = %1, %671
  %24 = phi i16 [ %673, %671 ], [ 0, %1 ]
  %25 = phi i16 [ %674, %671 ], [ 0, %1 ]
  br label %26

26:                                               ; preds = %110, %23
  %27 = phi ptr [ %128, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), %23 ]
  %28 = phi ptr [ %127, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 187), %23 ]
  %29 = phi ptr [ %126, %110 ], [ getelementptr (i8, ptr @g3_a, i16 217), %23 ]
  %30 = phi ptr [ %125, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %23 ]
  %31 = phi ptr [ %117, %110 ], [ getelementptr (i8, ptr @g3_a, i16 221), %23 ]
  %32 = phi ptr [ %112, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 216), %23 ]
  %33 = phi ptr [ %116, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 186), %23 ]
  %34 = phi ptr [ %124, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 211), %23 ]
  %35 = phi ptr [ %115, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 181), %23 ]
  %36 = phi ptr [ %123, %110 ], [ @g3_b, %23 ]
  %37 = phi ptr [ %121, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 1), %23 ]
  %38 = phi ptr [ %120, %110 ], [ @g3_a, %23 ]
  %39 = phi ptr [ %111, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 180), %23 ]
  %40 = phi i8 [ %122, %110 ], [ -1, %23 ]
  %41 = phi i8 [ %119, %110 ], [ 0, %23 ]
  %42 = phi ptr [ %114, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 215), %23 ]
  %43 = phi ptr [ %113, %110 ], [ getelementptr inbounds nuw (i8, ptr @g3_a, i16 210), %23 ]
  %44 = phi i8 [ %54, %110 ], [ 0, %23 ]
  %45 = zext i8 %40 to i16
  %46 = mul nuw nsw i16 %45, 36
  %47 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), i16 %46
  %48 = getelementptr i8, ptr @g3_a, i16 %46
  %49 = add nsw i8 %44, -1
  %50 = icmp eq i8 %44, 0
  %51 = zext nneg i8 %44 to i16
  %52 = zext i8 %41 to i16
  %53 = getelementptr i8, ptr @g3_a, i16 %52
  %54 = add nuw nsw i8 %44, 1
  %55 = icmp samesign ugt i8 %44, 4
  %56 = add nsw i8 %44, -5
  %57 = select i1 %55, i8 %56, i8 %54
  %58 = zext i8 %57 to i16
  %59 = zext i8 %49 to i16
  %60 = mul nuw nsw i16 %58, 36
  %61 = getelementptr i8, ptr @g3_a, i16 %60
  %62 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %59
  %63 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 6), i16 %60
  br label %64

64:                                               ; preds = %130, %26
  %65 = phi ptr [ %137, %130 ], [ %35, %26 ]
  %66 = phi ptr [ %136, %130 ], [ %34, %26 ]
  %67 = phi ptr [ %135, %130 ], [ %36, %26 ]
  %68 = phi ptr [ %138, %130 ], [ %38, %26 ]
  %69 = phi ptr [ %142, %130 ], [ %61, %26 ]
  %70 = phi ptr [ %141, %130 ], [ %48, %26 ]
  %71 = phi i8 [ %140, %130 ], [ 0, %26 ]
  %72 = phi ptr [ %134, %130 ], [ %42, %26 ]
  %73 = phi ptr [ %133, %130 ], [ %43, %26 ]
  %74 = phi ptr [ %132, %130 ], [ %39, %26 ]
  %75 = phi i8 [ %131, %130 ], [ -1, %26 ]
  %76 = phi i8 [ %84, %130 ], [ 0, %26 ]
  %77 = zext i8 %75 to i16
  %78 = mul nuw nsw i16 %77, 6
  %79 = getelementptr i8, ptr %35, i16 %78
  %80 = getelementptr i8, ptr %39, i16 %78
  %81 = add nsw i8 %76, -1
  %82 = icmp eq i8 %76, 0
  %83 = select i1 %82, i8 5, i8 %81
  %84 = add nuw nsw i8 %76, 1
  %85 = icmp eq i8 %76, 5
  %86 = zext i8 %83 to i16
  %87 = getelementptr [6 x i8], ptr @g3_a, i16 %86
  %88 = zext nneg i8 %71 to i16
  %89 = getelementptr i8, ptr @g3_a, i16 %88
  %90 = getelementptr inbounds nuw [36 x i8], ptr %87, i16 %51
  %91 = getelementptr i8, ptr %38, i16 %88
  %92 = select i1 %85, i8 0, i8 %84
  %93 = zext nneg i8 %92 to i16
  %94 = getelementptr inbounds nuw [6 x i8], ptr %53, i16 %93
  %95 = getelementptr inbounds nuw [36 x i8], ptr %87, i16 %58
  %96 = getelementptr i8, ptr %61, i16 %88
  %97 = getelementptr inbounds nuw [36 x i8], ptr %87, i16 %59
  %98 = getelementptr i8, ptr %48, i16 %88
  %99 = getelementptr inbounds nuw [6 x i8], ptr %39, i16 %93
  %100 = mul nuw nsw i16 %86, 6
  %101 = mul nuw nsw i16 %93, 6
  %102 = getelementptr i8, ptr %61, i16 %100
  %103 = getelementptr inbounds nuw [6 x i8], ptr %62, i16 %93
  %104 = getelementptr i8, ptr %48, i16 %100
  %105 = getelementptr i8, ptr %48, i16 %101
  %106 = getelementptr i8, ptr %39, i16 %101
  %107 = getelementptr i8, ptr %38, i16 %100
  %108 = getelementptr i8, ptr %37, i16 %100
  %109 = getelementptr i8, ptr %38, i16 %101
  br label %143

110:                                              ; preds = %130
  %111 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 216), i16 %52
  %112 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 252), i16 %52
  %113 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 246), i16 %52
  %114 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 251), i16 %52
  %115 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 217), i16 %52
  %116 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 222), i16 %52
  %117 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 257), i16 %52
  %118 = icmp eq i8 %54, 6
  %119 = add nuw i8 %41, 36
  %120 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 36), i16 %52
  %121 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 37), i16 %52
  %122 = add nsw i8 %40, 1
  %123 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %52
  %124 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 247), i16 %52
  %125 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %52
  %126 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 253), i16 %52
  %127 = getelementptr i8, ptr getelementptr (i8, ptr @g3_a, i16 223), i16 %52
  %128 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_a, i16 42), i16 %52
  br i1 %118, label %129, label %26, !llvm.loop !9

129:                                              ; preds = %110
  tail call void @llvm.memcpy.p0.p0.i16(ptr noundef nonnull align 1 dereferenceable(216) @g3_a, ptr noundef nonnull align 1 dereferenceable(216) @g3_b, i16 216, i1 false), !tbaa !6
  br label %367

130:                                              ; preds = %358
  %131 = add nsw i8 %75, 1
  %132 = getelementptr i8, ptr %33, i16 %88
  %133 = getelementptr i8, ptr %32, i16 %88
  %134 = getelementptr i8, ptr %31, i16 %88
  %135 = getelementptr i8, ptr %30, i16 %88
  %136 = getelementptr i8, ptr %29, i16 %88
  %137 = getelementptr i8, ptr %28, i16 %88
  %138 = getelementptr i8, ptr %27, i16 %88
  %139 = icmp eq i8 %84, 6
  %140 = add nuw nsw i8 %71, 6
  %141 = getelementptr i8, ptr %47, i16 %88
  %142 = getelementptr i8, ptr %63, i16 %88
  br i1 %139, label %110, label %64, !llvm.loop !10

143:                                              ; preds = %358, %64
  %144 = phi ptr [ %74, %64 ], [ %365, %358 ]
  %145 = phi ptr [ %73, %64 ], [ %364, %358 ]
  %146 = phi i8 [ -1, %64 ], [ %363, %358 ]
  %147 = phi ptr [ %80, %64 ], [ %362, %358 ]
  %148 = phi i8 [ 0, %64 ], [ %153, %358 ]
  %149 = zext i8 %146 to i16
  %150 = getelementptr i8, ptr %73, i16 %149
  %151 = add nsw i8 %148, -1
  %152 = icmp eq i8 %148, 0
  %153 = add nuw nsw i8 %148, 1
  %154 = select i1 %152, i8 5, i8 %151
  %155 = zext i8 %154 to i16
  %156 = getelementptr inbounds nuw i8, ptr %87, i16 %155
  %157 = zext nneg i8 %148 to i16
  %158 = icmp eq i8 %148, 5
  %159 = getelementptr inbounds nuw i8, ptr %89, i16 %155
  %160 = getelementptr i8, ptr %80, i16 %155
  %161 = getelementptr i8, ptr %74, i16 %155
  br i1 %50, label %162, label %317

162:                                              ; preds = %143
  br i1 %82, label %194, label %164

163:                                              ; preds = %164
  br label %168

164:                                              ; preds = %162
  %165 = load i8, ptr %160, align 1, !tbaa !6
  %166 = load i8, ptr %147, align 1, !tbaa !6
  %167 = add i8 %166, %165
  br i1 %158, label %163, label %168

168:                                              ; preds = %202, %199, %196, %164, %163
  %169 = phi i8 [ 0, %202 ], [ %153, %199 ], [ %153, %164 ], [ 0, %163 ], [ 1, %196 ]
  %170 = phi ptr [ %73, %202 ], [ %73, %199 ], [ %80, %164 ], [ %80, %163 ], [ %73, %196 ]
  %171 = phi i8 [ %201, %202 ], [ %201, %199 ], [ %167, %164 ], [ %167, %163 ], [ %198, %196 ]
  %172 = zext i8 %169 to i16
  %173 = getelementptr inbounds nuw i8, ptr %170, i16 %172
  %174 = load i8, ptr %173, align 1, !tbaa !6
  %175 = add i8 %174, %171
  %176 = load i8, ptr %161, align 1, !tbaa !6
  %177 = add i8 %175, %176
  %178 = load i8, ptr %144, align 1, !tbaa !6
  %179 = add i8 %177, %178
  br i1 %158, label %180, label %181

180:                                              ; preds = %168
  br label %181

181:                                              ; preds = %180, %168
  %182 = phi i8 [ %153, %168 ], [ 0, %180 ]
  %183 = zext i8 %182 to i16
  %184 = getelementptr inbounds nuw i8, ptr %74, i16 %183
  %185 = load i8, ptr %184, align 1, !tbaa !6
  %186 = add i8 %179, %185
  %187 = getelementptr inbounds nuw i8, ptr %99, i16 %155
  %188 = load i8, ptr %187, align 1, !tbaa !6
  %189 = add i8 %186, %188
  %190 = getelementptr i8, ptr %106, i16 %157
  %191 = load i8, ptr %190, align 1, !tbaa !6
  %192 = add i8 %189, %191
  br i1 %158, label %193, label %203

193:                                              ; preds = %181
  br label %203

194:                                              ; preds = %162
  %195 = load i8, ptr %145, align 1, !tbaa !6
  br i1 %152, label %196, label %199

196:                                              ; preds = %194
  %197 = load i8, ptr %72, align 1, !tbaa !6
  %198 = add i8 %197, %195
  br label %168

199:                                              ; preds = %194
  %200 = load i8, ptr %150, align 1, !tbaa !6
  %201 = add i8 %200, %195
  br i1 %158, label %202, label %168

202:                                              ; preds = %199
  br label %168

203:                                              ; preds = %337, %349, %193, %181
  %204 = phi ptr [ %39, %181 ], [ %39, %193 ], [ %62, %349 ], [ %62, %337 ]
  %205 = phi i8 [ %153, %181 ], [ 0, %193 ], [ 0, %349 ], [ %153, %337 ]
  %206 = phi i8 [ %192, %181 ], [ %192, %193 ], [ %348, %349 ], [ %348, %337 ]
  %207 = getelementptr inbounds nuw [6 x i8], ptr %204, i16 %93
  %208 = zext i8 %205 to i16
  %209 = getelementptr inbounds nuw i8, ptr %207, i16 %208
  %210 = load i8, ptr %209, align 1, !tbaa !6
  %211 = add i8 %210, %206
  %212 = getelementptr inbounds nuw [36 x i8], ptr %156, i16 %51
  %213 = load i8, ptr %212, align 1, !tbaa !6
  %214 = add i8 %211, %213
  %215 = getelementptr i8, ptr %107, i16 %157
  %216 = load i8, ptr %215, align 1, !tbaa !6
  %217 = add i8 %214, %216
  br i1 %158, label %220, label %218

218:                                              ; preds = %203
  %219 = getelementptr i8, ptr %108, i16 %157
  br label %220

220:                                              ; preds = %203, %218
  %221 = phi ptr [ %219, %218 ], [ %90, %203 ]
  %222 = phi i8 [ %153, %218 ], [ 0, %203 ]
  %223 = load i8, ptr %221, align 1, !tbaa !6
  %224 = add i8 %217, %223
  %225 = getelementptr inbounds nuw [36 x i8], ptr %159, i16 %51
  %226 = load i8, ptr %225, align 1, !tbaa !6
  %227 = add i8 %224, %226
  %228 = zext i8 %222 to i16
  %229 = getelementptr inbounds nuw i8, ptr %91, i16 %228
  %230 = load i8, ptr %229, align 1, !tbaa !6
  %231 = add i8 %227, %230
  %232 = getelementptr inbounds nuw i8, ptr %94, i16 %155
  %233 = load i8, ptr %232, align 1, !tbaa !6
  %234 = add i8 %231, %233
  %235 = getelementptr i8, ptr %109, i16 %157
  %236 = load i8, ptr %235, align 1, !tbaa !6
  %237 = add i8 %234, %236
  br i1 %158, label %238, label %239

238:                                              ; preds = %220
  br label %239

239:                                              ; preds = %238, %220
  %240 = phi i8 [ %153, %220 ], [ 0, %238 ]
  %241 = zext i8 %240 to i16
  %242 = getelementptr inbounds nuw i8, ptr %94, i16 %241
  %243 = load i8, ptr %242, align 1, !tbaa !6
  %244 = add i8 %237, %243
  %245 = getelementptr inbounds nuw [36 x i8], ptr %156, i16 %58
  %246 = load i8, ptr %245, align 1, !tbaa !6
  %247 = add i8 %244, %246
  %248 = getelementptr i8, ptr %102, i16 %157
  %249 = load i8, ptr %248, align 1, !tbaa !6
  %250 = add i8 %247, %249
  br i1 %158, label %251, label %252

251:                                              ; preds = %239
  br label %252

252:                                              ; preds = %251, %239
  %253 = phi i8 [ %153, %239 ], [ 0, %251 ]
  %254 = zext i8 %253 to i16
  %255 = getelementptr inbounds nuw i8, ptr %95, i16 %254
  %256 = load i8, ptr %255, align 1, !tbaa !6
  %257 = add i8 %250, %256
  %258 = getelementptr inbounds nuw [36 x i8], ptr %159, i16 %58
  %259 = load i8, ptr %258, align 1, !tbaa !6
  %260 = add i8 %257, %259
  %261 = getelementptr i8, ptr %69, i16 %157
  %262 = load i8, ptr %261, align 1, !tbaa !6
  %263 = add i8 %260, %262
  br i1 %158, label %264, label %265

264:                                              ; preds = %252
  br label %265

265:                                              ; preds = %264, %252
  %266 = phi i8 [ %153, %252 ], [ 0, %264 ]
  %267 = zext i8 %266 to i16
  %268 = getelementptr inbounds nuw i8, ptr %96, i16 %267
  %269 = load i8, ptr %268, align 1, !tbaa !6
  %270 = add i8 %263, %269
  br i1 %55, label %271, label %272

271:                                              ; preds = %265
  br label %272

272:                                              ; preds = %271, %265
  %273 = phi i8 [ %54, %265 ], [ %56, %271 ]
  br i1 %85, label %274, label %275

274:                                              ; preds = %272
  br label %275

275:                                              ; preds = %274, %272
  %276 = phi i8 [ %84, %272 ], [ 0, %274 ]
  %277 = zext nneg i8 %273 to i16
  %278 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %277
  %279 = zext i8 %276 to i16
  %280 = getelementptr inbounds nuw [6 x i8], ptr %278, i16 %279
  %281 = getelementptr inbounds nuw i8, ptr %280, i16 %155
  %282 = load i8, ptr %281, align 1, !tbaa !6
  %283 = add i8 %270, %282
  br i1 %55, label %284, label %285

284:                                              ; preds = %275
  br label %285

285:                                              ; preds = %284, %275
  %286 = phi i8 [ %54, %275 ], [ %56, %284 ]
  br i1 %85, label %287, label %288

287:                                              ; preds = %285
  br label %288

288:                                              ; preds = %287, %285
  %289 = phi i8 [ %84, %285 ], [ 0, %287 ]
  %290 = zext nneg i8 %286 to i16
  %291 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %290
  %292 = zext i8 %289 to i16
  %293 = getelementptr inbounds nuw [6 x i8], ptr %291, i16 %292
  %294 = getelementptr inbounds nuw i8, ptr %293, i16 %157
  %295 = load i8, ptr %294, align 1, !tbaa !6
  %296 = add i8 %283, %295
  br i1 %55, label %297, label %298

297:                                              ; preds = %288
  br label %298

298:                                              ; preds = %297, %288
  %299 = phi i8 [ %54, %288 ], [ %56, %297 ]
  br i1 %85, label %300, label %301

300:                                              ; preds = %298
  br label %301

301:                                              ; preds = %300, %298
  %302 = phi i8 [ %84, %298 ], [ 0, %300 ]
  br i1 %158, label %303, label %304

303:                                              ; preds = %301
  br label %304

304:                                              ; preds = %303, %301
  %305 = phi i8 [ %153, %301 ], [ 0, %303 ]
  %306 = zext nneg i8 %299 to i16
  %307 = getelementptr inbounds nuw [36 x i8], ptr @g3_a, i16 %306
  %308 = zext i8 %302 to i16
  %309 = getelementptr inbounds nuw [6 x i8], ptr %307, i16 %308
  %310 = zext i8 %305 to i16
  %311 = getelementptr inbounds nuw i8, ptr %309, i16 %310
  %312 = load i8, ptr %311, align 1, !tbaa !6
  %313 = add i8 %296, %312
  %314 = getelementptr i8, ptr %68, i16 %157
  %315 = load i8, ptr %314, align 1, !tbaa !6
  %316 = icmp eq i8 %315, 0
  br i1 %316, label %354, label %350

317:                                              ; preds = %143
  %318 = getelementptr inbounds nuw [36 x i8], ptr %156, i16 %59
  %319 = load i8, ptr %318, align 1, !tbaa !6
  %320 = getelementptr i8, ptr %104, i16 %157
  %321 = load i8, ptr %320, align 1, !tbaa !6
  %322 = add i8 %321, %319
  br i1 %158, label %323, label %324

323:                                              ; preds = %317
  br label %324

324:                                              ; preds = %323, %317
  %325 = phi i8 [ %153, %317 ], [ 0, %323 ]
  %326 = zext i8 %325 to i16
  %327 = getelementptr inbounds nuw i8, ptr %97, i16 %326
  %328 = load i8, ptr %327, align 1, !tbaa !6
  %329 = add i8 %322, %328
  %330 = getelementptr inbounds nuw [36 x i8], ptr %159, i16 %59
  %331 = load i8, ptr %330, align 1, !tbaa !6
  %332 = add i8 %329, %331
  %333 = getelementptr i8, ptr %70, i16 %157
  %334 = load i8, ptr %333, align 1, !tbaa !6
  %335 = add i8 %332, %334
  br i1 %158, label %336, label %337

336:                                              ; preds = %324
  br label %337

337:                                              ; preds = %336, %324
  %338 = phi i8 [ %153, %324 ], [ 0, %336 ]
  %339 = zext i8 %338 to i16
  %340 = getelementptr inbounds nuw i8, ptr %98, i16 %339
  %341 = load i8, ptr %340, align 1, !tbaa !6
  %342 = add i8 %335, %341
  %343 = getelementptr inbounds nuw i8, ptr %103, i16 %155
  %344 = load i8, ptr %343, align 1, !tbaa !6
  %345 = add i8 %342, %344
  %346 = getelementptr i8, ptr %105, i16 %157
  %347 = load i8, ptr %346, align 1, !tbaa !6
  %348 = add i8 %345, %347
  br i1 %158, label %349, label %203

349:                                              ; preds = %337
  br label %203

350:                                              ; preds = %304
  %351 = icmp ugt i8 %313, 3
  br i1 %351, label %352, label %358

352:                                              ; preds = %350
  %353 = icmp ult i8 %313, 8
  br label %358

354:                                              ; preds = %304
  %355 = icmp ugt i8 %313, 4
  br i1 %355, label %356, label %358

356:                                              ; preds = %354
  %357 = icmp ult i8 %313, 7
  br label %358

358:                                              ; preds = %356, %354, %352, %350
  %359 = phi i1 [ %353, %352 ], [ false, %350 ], [ false, %354 ], [ %357, %356 ]
  %360 = zext i1 %359 to i8
  %361 = getelementptr i8, ptr %67, i16 %157
  store i8 %360, ptr %361, align 1, !tbaa !6
  %362 = getelementptr i8, ptr %79, i16 %157
  %363 = add nsw i8 %146, 1
  %364 = getelementptr i8, ptr %66, i16 %157
  %365 = getelementptr i8, ptr %65, i16 %157
  %366 = icmp eq i8 %153, 6
  br i1 %366, label %130, label %143, !llvm.loop !11

367:                                              ; preds = %367, %129
  %368 = phi i8 [ 0, %129 ], [ %670, %367 ]
  %369 = phi ptr [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 6), %129 ], [ %668, %367 ]
  %370 = phi ptr [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 5), %129 ], [ %667, %367 ]
  %371 = phi ptr [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 4), %129 ], [ %666, %367 ]
  %372 = phi ptr [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 3), %129 ], [ %665, %367 ]
  %373 = phi ptr [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 2), %129 ], [ %664, %367 ]
  %374 = phi ptr [ getelementptr inbounds nuw (i8, ptr @g3_b, i16 1), %129 ], [ %663, %367 ]
  %375 = phi ptr [ @g3_b, %129 ], [ %662, %367 ]
  %376 = phi i16 [ %24, %129 ], [ %660, %367 ]
  %377 = phi i8 [ 0, %129 ], [ %661, %367 ]
  %378 = phi i16 [ 0, %129 ], [ %656, %367 ]
  %379 = zext nneg i8 %377 to i16
  %380 = load i8, ptr %375, align 1, !tbaa !6
  %381 = zext i8 %380 to i16
  %382 = add i16 %378, %381
  %383 = tail call i16 @llvm.fshl.i16(i16 %376, i16 %376, i16 1)
  %384 = xor i16 %383, %379
  %385 = xor i16 %384, %381
  %386 = load i8, ptr %374, align 1, !tbaa !6
  %387 = zext i8 %386 to i16
  %388 = add i16 %382, %387
  %389 = or disjoint i16 %379, 256
  %390 = tail call i16 @llvm.fshl.i16(i16 %385, i16 %385, i16 1)
  %391 = xor i16 %389, %390
  %392 = xor i16 %391, %387
  %393 = load i8, ptr %373, align 1, !tbaa !6
  %394 = zext i8 %393 to i16
  %395 = add i16 %388, %394
  %396 = or disjoint i16 %379, 512
  %397 = tail call i16 @llvm.fshl.i16(i16 %392, i16 %392, i16 1)
  %398 = xor i16 %396, %397
  %399 = xor i16 %398, %394
  %400 = load i8, ptr %372, align 1, !tbaa !6
  %401 = zext i8 %400 to i16
  %402 = add i16 %395, %401
  %403 = or disjoint i16 %379, 768
  %404 = tail call i16 @llvm.fshl.i16(i16 %399, i16 %399, i16 1)
  %405 = xor i16 %403, %404
  %406 = xor i16 %405, %401
  %407 = load i8, ptr %371, align 1, !tbaa !6
  %408 = zext i8 %407 to i16
  %409 = add i16 %402, %408
  %410 = or disjoint i16 %379, 1024
  %411 = tail call i16 @llvm.fshl.i16(i16 %406, i16 %406, i16 1)
  %412 = xor i16 %410, %411
  %413 = xor i16 %412, %408
  %414 = load i8, ptr %370, align 1, !tbaa !6
  %415 = zext i8 %414 to i16
  %416 = add i16 %409, %415
  %417 = or disjoint i16 %379, 1280
  %418 = tail call i16 @llvm.fshl.i16(i16 %413, i16 %413, i16 1)
  %419 = xor i16 %417, %418
  %420 = xor i16 %419, %415
  %421 = add nuw nsw i16 %379, 16
  %422 = load i8, ptr %369, align 1, !tbaa !6
  %423 = zext i8 %422 to i16
  %424 = add i16 %416, %423
  %425 = tail call i16 @llvm.fshl.i16(i16 %420, i16 %420, i16 1)
  %426 = xor i16 %421, %425
  %427 = xor i16 %426, %423
  %428 = zext i8 %368 to i16
  %429 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 7), i16 %428
  %430 = load i8, ptr %429, align 1, !tbaa !6
  %431 = zext i8 %430 to i16
  %432 = add i16 %424, %431
  %433 = add nuw nsw i16 %379, 272
  %434 = tail call i16 @llvm.fshl.i16(i16 %427, i16 %427, i16 1)
  %435 = xor i16 %433, %434
  %436 = xor i16 %435, %431
  %437 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 8), i16 %428
  %438 = load i8, ptr %437, align 1, !tbaa !6
  %439 = zext i8 %438 to i16
  %440 = add i16 %432, %439
  %441 = add nuw nsw i16 %379, 528
  %442 = tail call i16 @llvm.fshl.i16(i16 %436, i16 %436, i16 1)
  %443 = xor i16 %441, %442
  %444 = xor i16 %443, %439
  %445 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 9), i16 %428
  %446 = load i8, ptr %445, align 1, !tbaa !6
  %447 = zext i8 %446 to i16
  %448 = add i16 %440, %447
  %449 = add nuw nsw i16 %379, 784
  %450 = tail call i16 @llvm.fshl.i16(i16 %444, i16 %444, i16 1)
  %451 = xor i16 %449, %450
  %452 = xor i16 %451, %447
  %453 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 10), i16 %428
  %454 = load i8, ptr %453, align 1, !tbaa !6
  %455 = zext i8 %454 to i16
  %456 = add i16 %448, %455
  %457 = add nuw nsw i16 %379, 1040
  %458 = tail call i16 @llvm.fshl.i16(i16 %452, i16 %452, i16 1)
  %459 = xor i16 %457, %458
  %460 = xor i16 %459, %455
  %461 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 11), i16 %428
  %462 = load i8, ptr %461, align 1, !tbaa !6
  %463 = zext i8 %462 to i16
  %464 = add i16 %456, %463
  %465 = add nuw nsw i16 %379, 1296
  %466 = tail call i16 @llvm.fshl.i16(i16 %460, i16 %460, i16 1)
  %467 = xor i16 %465, %466
  %468 = xor i16 %467, %463
  %469 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 12), i16 %428
  %470 = add nuw nsw i16 %379, 32
  %471 = load i8, ptr %469, align 1, !tbaa !6
  %472 = zext i8 %471 to i16
  %473 = add i16 %464, %472
  %474 = tail call i16 @llvm.fshl.i16(i16 %468, i16 %468, i16 1)
  %475 = xor i16 %470, %474
  %476 = xor i16 %475, %472
  %477 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 13), i16 %428
  %478 = load i8, ptr %477, align 1, !tbaa !6
  %479 = zext i8 %478 to i16
  %480 = add i16 %473, %479
  %481 = add nuw nsw i16 %379, 288
  %482 = tail call i16 @llvm.fshl.i16(i16 %476, i16 %476, i16 1)
  %483 = xor i16 %481, %482
  %484 = xor i16 %483, %479
  %485 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 14), i16 %428
  %486 = load i8, ptr %485, align 1, !tbaa !6
  %487 = zext i8 %486 to i16
  %488 = add i16 %480, %487
  %489 = add nuw nsw i16 %379, 544
  %490 = tail call i16 @llvm.fshl.i16(i16 %484, i16 %484, i16 1)
  %491 = xor i16 %489, %490
  %492 = xor i16 %491, %487
  %493 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 15), i16 %428
  %494 = load i8, ptr %493, align 1, !tbaa !6
  %495 = zext i8 %494 to i16
  %496 = add i16 %488, %495
  %497 = add nuw nsw i16 %379, 800
  %498 = tail call i16 @llvm.fshl.i16(i16 %492, i16 %492, i16 1)
  %499 = xor i16 %497, %498
  %500 = xor i16 %499, %495
  %501 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 16), i16 %428
  %502 = load i8, ptr %501, align 1, !tbaa !6
  %503 = zext i8 %502 to i16
  %504 = add i16 %496, %503
  %505 = add nuw nsw i16 %379, 1056
  %506 = tail call i16 @llvm.fshl.i16(i16 %500, i16 %500, i16 1)
  %507 = xor i16 %505, %506
  %508 = xor i16 %507, %503
  %509 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 17), i16 %428
  %510 = load i8, ptr %509, align 1, !tbaa !6
  %511 = zext i8 %510 to i16
  %512 = add i16 %504, %511
  %513 = add nuw nsw i16 %379, 1312
  %514 = tail call i16 @llvm.fshl.i16(i16 %508, i16 %508, i16 1)
  %515 = xor i16 %513, %514
  %516 = xor i16 %515, %511
  %517 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 18), i16 %428
  %518 = add nuw nsw i16 %379, 48
  %519 = load i8, ptr %517, align 1, !tbaa !6
  %520 = zext i8 %519 to i16
  %521 = add i16 %512, %520
  %522 = tail call i16 @llvm.fshl.i16(i16 %516, i16 %516, i16 1)
  %523 = xor i16 %518, %522
  %524 = xor i16 %523, %520
  %525 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 19), i16 %428
  %526 = load i8, ptr %525, align 1, !tbaa !6
  %527 = zext i8 %526 to i16
  %528 = add i16 %521, %527
  %529 = add nuw nsw i16 %379, 304
  %530 = tail call i16 @llvm.fshl.i16(i16 %524, i16 %524, i16 1)
  %531 = xor i16 %529, %530
  %532 = xor i16 %531, %527
  %533 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 20), i16 %428
  %534 = load i8, ptr %533, align 1, !tbaa !6
  %535 = zext i8 %534 to i16
  %536 = add i16 %528, %535
  %537 = add nuw nsw i16 %379, 560
  %538 = tail call i16 @llvm.fshl.i16(i16 %532, i16 %532, i16 1)
  %539 = xor i16 %537, %538
  %540 = xor i16 %539, %535
  %541 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 21), i16 %428
  %542 = load i8, ptr %541, align 1, !tbaa !6
  %543 = zext i8 %542 to i16
  %544 = add i16 %536, %543
  %545 = add nuw nsw i16 %379, 816
  %546 = tail call i16 @llvm.fshl.i16(i16 %540, i16 %540, i16 1)
  %547 = xor i16 %545, %546
  %548 = xor i16 %547, %543
  %549 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 22), i16 %428
  %550 = load i8, ptr %549, align 1, !tbaa !6
  %551 = zext i8 %550 to i16
  %552 = add i16 %544, %551
  %553 = add nuw nsw i16 %379, 1072
  %554 = tail call i16 @llvm.fshl.i16(i16 %548, i16 %548, i16 1)
  %555 = xor i16 %553, %554
  %556 = xor i16 %555, %551
  %557 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 23), i16 %428
  %558 = load i8, ptr %557, align 1, !tbaa !6
  %559 = zext i8 %558 to i16
  %560 = add i16 %552, %559
  %561 = add nuw nsw i16 %379, 1328
  %562 = tail call i16 @llvm.fshl.i16(i16 %556, i16 %556, i16 1)
  %563 = xor i16 %561, %562
  %564 = xor i16 %563, %559
  %565 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 24), i16 %428
  %566 = add nuw nsw i16 %379, 64
  %567 = load i8, ptr %565, align 1, !tbaa !6
  %568 = zext i8 %567 to i16
  %569 = add i16 %560, %568
  %570 = tail call i16 @llvm.fshl.i16(i16 %564, i16 %564, i16 1)
  %571 = xor i16 %566, %570
  %572 = xor i16 %571, %568
  %573 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 25), i16 %428
  %574 = load i8, ptr %573, align 1, !tbaa !6
  %575 = zext i8 %574 to i16
  %576 = add i16 %569, %575
  %577 = add nuw nsw i16 %379, 320
  %578 = tail call i16 @llvm.fshl.i16(i16 %572, i16 %572, i16 1)
  %579 = xor i16 %577, %578
  %580 = xor i16 %579, %575
  %581 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 26), i16 %428
  %582 = load i8, ptr %581, align 1, !tbaa !6
  %583 = zext i8 %582 to i16
  %584 = add i16 %576, %583
  %585 = add nuw nsw i16 %379, 576
  %586 = tail call i16 @llvm.fshl.i16(i16 %580, i16 %580, i16 1)
  %587 = xor i16 %585, %586
  %588 = xor i16 %587, %583
  %589 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 27), i16 %428
  %590 = load i8, ptr %589, align 1, !tbaa !6
  %591 = zext i8 %590 to i16
  %592 = add i16 %584, %591
  %593 = add nuw nsw i16 %379, 832
  %594 = tail call i16 @llvm.fshl.i16(i16 %588, i16 %588, i16 1)
  %595 = xor i16 %593, %594
  %596 = xor i16 %595, %591
  %597 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 28), i16 %428
  %598 = load i8, ptr %597, align 1, !tbaa !6
  %599 = zext i8 %598 to i16
  %600 = add i16 %592, %599
  %601 = add nuw nsw i16 %379, 1088
  %602 = tail call i16 @llvm.fshl.i16(i16 %596, i16 %596, i16 1)
  %603 = xor i16 %601, %602
  %604 = xor i16 %603, %599
  %605 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 29), i16 %428
  %606 = load i8, ptr %605, align 1, !tbaa !6
  %607 = zext i8 %606 to i16
  %608 = add i16 %600, %607
  %609 = add nuw nsw i16 %379, 1344
  %610 = tail call i16 @llvm.fshl.i16(i16 %604, i16 %604, i16 1)
  %611 = xor i16 %609, %610
  %612 = xor i16 %611, %607
  %613 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 30), i16 %428
  %614 = add nuw nsw i16 %379, 80
  %615 = load i8, ptr %613, align 1, !tbaa !6
  %616 = zext i8 %615 to i16
  %617 = add i16 %608, %616
  %618 = tail call i16 @llvm.fshl.i16(i16 %612, i16 %612, i16 1)
  %619 = xor i16 %614, %618
  %620 = xor i16 %619, %616
  %621 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 31), i16 %428
  %622 = load i8, ptr %621, align 1, !tbaa !6
  %623 = zext i8 %622 to i16
  %624 = add i16 %617, %623
  %625 = add nuw nsw i16 %379, 336
  %626 = tail call i16 @llvm.fshl.i16(i16 %620, i16 %620, i16 1)
  %627 = xor i16 %625, %626
  %628 = xor i16 %627, %623
  %629 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 32), i16 %428
  %630 = load i8, ptr %629, align 1, !tbaa !6
  %631 = zext i8 %630 to i16
  %632 = add i16 %624, %631
  %633 = add nuw nsw i16 %379, 592
  %634 = tail call i16 @llvm.fshl.i16(i16 %628, i16 %628, i16 1)
  %635 = xor i16 %633, %634
  %636 = xor i16 %635, %631
  %637 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 33), i16 %428
  %638 = load i8, ptr %637, align 1, !tbaa !6
  %639 = zext i8 %638 to i16
  %640 = add i16 %632, %639
  %641 = add nuw nsw i16 %379, 848
  %642 = tail call i16 @llvm.fshl.i16(i16 %636, i16 %636, i16 1)
  %643 = xor i16 %641, %642
  %644 = xor i16 %643, %639
  %645 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 34), i16 %428
  %646 = load i8, ptr %645, align 1, !tbaa !6
  %647 = zext i8 %646 to i16
  %648 = add i16 %640, %647
  %649 = add nuw nsw i16 %379, 1104
  %650 = tail call i16 @llvm.fshl.i16(i16 %644, i16 %644, i16 1)
  %651 = xor i16 %649, %650
  %652 = xor i16 %651, %647
  %653 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 35), i16 %428
  %654 = load i8, ptr %653, align 1, !tbaa !6
  %655 = zext i8 %654 to i16
  %656 = add i16 %648, %655
  %657 = add nuw nsw i16 %379, 1360
  %658 = tail call i16 @llvm.fshl.i16(i16 %652, i16 %652, i16 1)
  %659 = xor i16 %657, %658
  %660 = xor i16 %659, %655
  %661 = add nuw nsw i8 %377, 1
  %662 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 36), i16 %428
  %663 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 37), i16 %428
  %664 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 38), i16 %428
  %665 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 39), i16 %428
  %666 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 40), i16 %428
  %667 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 41), i16 %428
  %668 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @g3_b, i16 42), i16 %428
  %669 = icmp eq i8 %661, 6
  %670 = add nuw i8 %368, 36
  br i1 %669, label %671, label %367, !llvm.loop !12

671:                                              ; preds = %367
  %672 = tail call i16 @llvm.fshl.i16(i16 %660, i16 %660, i16 1)
  %673 = xor i16 %672, %656
  %674 = add nuw nsw i16 %25, 1
  %675 = icmp eq i16 %674, 3
  br i1 %675, label %676, label %23, !llvm.loop !13

676:                                              ; preds = %671
  store volatile i16 %673, ptr @corpus_result, align 1, !tbaa !2
  br label %677

677:                                              ; preds = %677, %676
  tail call void asm sideeffect "wai", ""() #4, !srcloc !14
  br label %677
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
!14 = !{i64 309}

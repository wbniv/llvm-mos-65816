; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@one = dso_local global i16 1, align 1

; Function Attrs: noinline nounwind optnone
define dso_local i16 @main(i16 noundef %0, ptr noundef %1) #0 {
  %3 = alloca i16, align 1
  %4 = alloca i16, align 1
  %5 = alloca ptr, align 1
  %6 = alloca <8 x i16>, align 16
  %7 = alloca <8 x i16>, align 16
  %8 = alloca <4 x float>, align 16
  %9 = alloca <4 x float>, align 16
  %10 = alloca <4 x float>, align 16
  %11 = alloca <2 x double>, align 16
  %12 = alloca <2 x double>, align 16
  %13 = alloca <2 x double>, align 16
  %14 = alloca i16, align 1
  %15 = alloca i16, align 1
  %16 = alloca i16, align 1
  %17 = alloca i16, align 1
  %18 = alloca i16, align 1
  %19 = alloca i16, align 1
  %20 = alloca i16, align 1
  %21 = alloca i16, align 1
  %22 = alloca i16, align 1
  %23 = alloca i16, align 1
  %24 = alloca i16, align 1
  %25 = alloca i16, align 1
  %26 = alloca i16, align 1
  %27 = alloca i16, align 1
  %28 = alloca i16, align 1
  %29 = alloca i16, align 1
  %30 = alloca i16, align 1
  %31 = alloca i16, align 1
  %32 = alloca <4 x float>, align 16
  %33 = alloca i16, align 1
  %34 = alloca <4 x float>, align 16
  %35 = alloca i16, align 1
  %36 = alloca <4 x float>, align 16
  %37 = alloca i16, align 1
  %38 = alloca <4 x float>, align 16
  %39 = alloca i16, align 1
  %40 = alloca <4 x float>, align 16
  %41 = alloca i16, align 1
  %42 = alloca <4 x float>, align 16
  %43 = alloca i16, align 1
  %44 = alloca <4 x float>, align 16
  %45 = alloca i16, align 1
  %46 = alloca <4 x float>, align 16
  %47 = alloca i16, align 1
  %48 = alloca <2 x double>, align 16
  %49 = alloca i16, align 1
  %50 = alloca <2 x double>, align 16
  %51 = alloca i16, align 1
  %52 = alloca <2 x double>, align 16
  %53 = alloca i16, align 1
  %54 = alloca <2 x double>, align 16
  %55 = alloca i16, align 1
  %56 = alloca <2 x double>, align 16
  %57 = alloca i16, align 1
  %58 = alloca <2 x double>, align 16
  %59 = alloca i16, align 1
  %60 = alloca <2 x double>, align 16
  %61 = alloca i16, align 1
  %62 = alloca <2 x double>, align 16
  %63 = alloca i16, align 1
  store i16 0, ptr %3, align 1
  store i16 %0, ptr %4, align 1
  store ptr %1, ptr %5, align 1
  %64 = load volatile i16, ptr @one, align 1
  %65 = insertelement <8 x i16> poison, i16 %64, i32 0
  %66 = insertelement <8 x i16> %65, i16 1, i32 1
  %67 = insertelement <8 x i16> %66, i16 2, i32 2
  %68 = insertelement <8 x i16> %67, i16 3, i32 3
  %69 = insertelement <8 x i16> %68, i16 4, i32 4
  %70 = insertelement <8 x i16> %69, i16 5, i32 5
  %71 = insertelement <8 x i16> %70, i16 6, i32 6
  %72 = insertelement <8 x i16> %71, i16 7, i32 7
  store <8 x i16> %72, ptr %6, align 16
  store <4 x float> <float 1.000000e+00, float 2.000000e+00, float 3.000000e+00, float 4.000000e+00>, ptr %8, align 16
  store <2 x double> <double 1.000000e+00, double 2.000000e+00>, ptr %11, align 16
  %73 = load <8 x i16>, ptr %6, align 16
  %74 = add <8 x i16> splat (i16 2), %73
  store <8 x i16> %74, ptr %7, align 16
  br label %75

75:                                               ; preds = %2
  store i16 0, ptr %14, align 1
  br label %76

76:                                               ; preds = %90, %75
  %77 = load i16, ptr %14, align 1
  %78 = icmp slt i16 %77, 8
  br i1 %78, label %79, label %93

79:                                               ; preds = %76
  %80 = load i16, ptr %14, align 1
  %81 = getelementptr inbounds i16, ptr %7, i16 %80
  %82 = load i16, ptr %81, align 2
  %83 = load i16, ptr %14, align 1
  %84 = getelementptr inbounds i16, ptr %6, i16 %83
  %85 = load i16, ptr %84, align 2
  %86 = add nsw i16 2, %85
  %87 = icmp ne i16 %82, %86
  br i1 %87, label %88, label %89

88:                                               ; preds = %79
  call void @abort() #2
  unreachable

89:                                               ; preds = %79
  br label %90

90:                                               ; preds = %89
  %91 = load i16, ptr %14, align 1
  %92 = add nsw i16 %91, 1
  store i16 %92, ptr %14, align 1
  br label %76, !llvm.loop !2

93:                                               ; preds = %76
  br label %94

94:                                               ; preds = %93
  %95 = load <8 x i16>, ptr %6, align 16
  %96 = sub <8 x i16> splat (i16 2), %95
  store <8 x i16> %96, ptr %7, align 16
  br label %97

97:                                               ; preds = %94
  store i16 0, ptr %15, align 1
  br label %98

98:                                               ; preds = %112, %97
  %99 = load i16, ptr %15, align 1
  %100 = icmp slt i16 %99, 8
  br i1 %100, label %101, label %115

101:                                              ; preds = %98
  %102 = load i16, ptr %15, align 1
  %103 = getelementptr inbounds i16, ptr %7, i16 %102
  %104 = load i16, ptr %103, align 2
  %105 = load i16, ptr %15, align 1
  %106 = getelementptr inbounds i16, ptr %6, i16 %105
  %107 = load i16, ptr %106, align 2
  %108 = sub nsw i16 2, %107
  %109 = icmp ne i16 %104, %108
  br i1 %109, label %110, label %111

110:                                              ; preds = %101
  call void @abort() #2
  unreachable

111:                                              ; preds = %101
  br label %112

112:                                              ; preds = %111
  %113 = load i16, ptr %15, align 1
  %114 = add nsw i16 %113, 1
  store i16 %114, ptr %15, align 1
  br label %98, !llvm.loop !4

115:                                              ; preds = %98
  br label %116

116:                                              ; preds = %115
  %117 = load <8 x i16>, ptr %6, align 16
  %118 = mul <8 x i16> splat (i16 2), %117
  store <8 x i16> %118, ptr %7, align 16
  br label %119

119:                                              ; preds = %116
  store i16 0, ptr %16, align 1
  br label %120

120:                                              ; preds = %134, %119
  %121 = load i16, ptr %16, align 1
  %122 = icmp slt i16 %121, 8
  br i1 %122, label %123, label %137

123:                                              ; preds = %120
  %124 = load i16, ptr %16, align 1
  %125 = getelementptr inbounds i16, ptr %7, i16 %124
  %126 = load i16, ptr %125, align 2
  %127 = load i16, ptr %16, align 1
  %128 = getelementptr inbounds i16, ptr %6, i16 %127
  %129 = load i16, ptr %128, align 2
  %130 = mul nsw i16 2, %129
  %131 = icmp ne i16 %126, %130
  br i1 %131, label %132, label %133

132:                                              ; preds = %123
  call void @abort() #2
  unreachable

133:                                              ; preds = %123
  br label %134

134:                                              ; preds = %133
  %135 = load i16, ptr %16, align 1
  %136 = add nsw i16 %135, 1
  store i16 %136, ptr %16, align 1
  br label %120, !llvm.loop !5

137:                                              ; preds = %120
  br label %138

138:                                              ; preds = %137
  %139 = load <8 x i16>, ptr %6, align 16
  %140 = sdiv <8 x i16> splat (i16 2), %139
  store <8 x i16> %140, ptr %7, align 16
  br label %141

141:                                              ; preds = %138
  store i16 0, ptr %17, align 1
  br label %142

142:                                              ; preds = %156, %141
  %143 = load i16, ptr %17, align 1
  %144 = icmp slt i16 %143, 8
  br i1 %144, label %145, label %159

145:                                              ; preds = %142
  %146 = load i16, ptr %17, align 1
  %147 = getelementptr inbounds i16, ptr %7, i16 %146
  %148 = load i16, ptr %147, align 2
  %149 = load i16, ptr %17, align 1
  %150 = getelementptr inbounds i16, ptr %6, i16 %149
  %151 = load i16, ptr %150, align 2
  %152 = sdiv i16 2, %151
  %153 = icmp ne i16 %148, %152
  br i1 %153, label %154, label %155

154:                                              ; preds = %145
  call void @abort() #2
  unreachable

155:                                              ; preds = %145
  br label %156

156:                                              ; preds = %155
  %157 = load i16, ptr %17, align 1
  %158 = add nsw i16 %157, 1
  store i16 %158, ptr %17, align 1
  br label %142, !llvm.loop !6

159:                                              ; preds = %142
  br label %160

160:                                              ; preds = %159
  %161 = load <8 x i16>, ptr %6, align 16
  %162 = srem <8 x i16> splat (i16 2), %161
  store <8 x i16> %162, ptr %7, align 16
  br label %163

163:                                              ; preds = %160
  store i16 0, ptr %18, align 1
  br label %164

164:                                              ; preds = %178, %163
  %165 = load i16, ptr %18, align 1
  %166 = icmp slt i16 %165, 8
  br i1 %166, label %167, label %181

167:                                              ; preds = %164
  %168 = load i16, ptr %18, align 1
  %169 = getelementptr inbounds i16, ptr %7, i16 %168
  %170 = load i16, ptr %169, align 2
  %171 = load i16, ptr %18, align 1
  %172 = getelementptr inbounds i16, ptr %6, i16 %171
  %173 = load i16, ptr %172, align 2
  %174 = srem i16 2, %173
  %175 = icmp ne i16 %170, %174
  br i1 %175, label %176, label %177

176:                                              ; preds = %167
  call void @abort() #2
  unreachable

177:                                              ; preds = %167
  br label %178

178:                                              ; preds = %177
  %179 = load i16, ptr %18, align 1
  %180 = add nsw i16 %179, 1
  store i16 %180, ptr %18, align 1
  br label %164, !llvm.loop !7

181:                                              ; preds = %164
  br label %182

182:                                              ; preds = %181
  %183 = load <8 x i16>, ptr %6, align 16
  %184 = xor <8 x i16> splat (i16 2), %183
  store <8 x i16> %184, ptr %7, align 16
  br label %185

185:                                              ; preds = %182
  store i16 0, ptr %19, align 1
  br label %186

186:                                              ; preds = %200, %185
  %187 = load i16, ptr %19, align 1
  %188 = icmp slt i16 %187, 8
  br i1 %188, label %189, label %203

189:                                              ; preds = %186
  %190 = load i16, ptr %19, align 1
  %191 = getelementptr inbounds i16, ptr %7, i16 %190
  %192 = load i16, ptr %191, align 2
  %193 = load i16, ptr %19, align 1
  %194 = getelementptr inbounds i16, ptr %6, i16 %193
  %195 = load i16, ptr %194, align 2
  %196 = xor i16 2, %195
  %197 = icmp ne i16 %192, %196
  br i1 %197, label %198, label %199

198:                                              ; preds = %189
  call void @abort() #2
  unreachable

199:                                              ; preds = %189
  br label %200

200:                                              ; preds = %199
  %201 = load i16, ptr %19, align 1
  %202 = add nsw i16 %201, 1
  store i16 %202, ptr %19, align 1
  br label %186, !llvm.loop !8

203:                                              ; preds = %186
  br label %204

204:                                              ; preds = %203
  %205 = load <8 x i16>, ptr %6, align 16
  %206 = and <8 x i16> splat (i16 2), %205
  store <8 x i16> %206, ptr %7, align 16
  br label %207

207:                                              ; preds = %204
  store i16 0, ptr %20, align 1
  br label %208

208:                                              ; preds = %222, %207
  %209 = load i16, ptr %20, align 1
  %210 = icmp slt i16 %209, 8
  br i1 %210, label %211, label %225

211:                                              ; preds = %208
  %212 = load i16, ptr %20, align 1
  %213 = getelementptr inbounds i16, ptr %7, i16 %212
  %214 = load i16, ptr %213, align 2
  %215 = load i16, ptr %20, align 1
  %216 = getelementptr inbounds i16, ptr %6, i16 %215
  %217 = load i16, ptr %216, align 2
  %218 = and i16 2, %217
  %219 = icmp ne i16 %214, %218
  br i1 %219, label %220, label %221

220:                                              ; preds = %211
  call void @abort() #2
  unreachable

221:                                              ; preds = %211
  br label %222

222:                                              ; preds = %221
  %223 = load i16, ptr %20, align 1
  %224 = add nsw i16 %223, 1
  store i16 %224, ptr %20, align 1
  br label %208, !llvm.loop !9

225:                                              ; preds = %208
  br label %226

226:                                              ; preds = %225
  %227 = load <8 x i16>, ptr %6, align 16
  %228 = or <8 x i16> splat (i16 2), %227
  store <8 x i16> %228, ptr %7, align 16
  br label %229

229:                                              ; preds = %226
  store i16 0, ptr %21, align 1
  br label %230

230:                                              ; preds = %244, %229
  %231 = load i16, ptr %21, align 1
  %232 = icmp slt i16 %231, 8
  br i1 %232, label %233, label %247

233:                                              ; preds = %230
  %234 = load i16, ptr %21, align 1
  %235 = getelementptr inbounds i16, ptr %7, i16 %234
  %236 = load i16, ptr %235, align 2
  %237 = load i16, ptr %21, align 1
  %238 = getelementptr inbounds i16, ptr %6, i16 %237
  %239 = load i16, ptr %238, align 2
  %240 = or i16 2, %239
  %241 = icmp ne i16 %236, %240
  br i1 %241, label %242, label %243

242:                                              ; preds = %233
  call void @abort() #2
  unreachable

243:                                              ; preds = %233
  br label %244

244:                                              ; preds = %243
  %245 = load i16, ptr %21, align 1
  %246 = add nsw i16 %245, 1
  store i16 %246, ptr %21, align 1
  br label %230, !llvm.loop !10

247:                                              ; preds = %230
  br label %248

248:                                              ; preds = %247
  %249 = load <8 x i16>, ptr %6, align 16
  %250 = shl <8 x i16> splat (i16 2), %249
  store <8 x i16> %250, ptr %7, align 16
  br label %251

251:                                              ; preds = %248
  store i16 0, ptr %22, align 1
  br label %252

252:                                              ; preds = %266, %251
  %253 = load i16, ptr %22, align 1
  %254 = icmp slt i16 %253, 8
  br i1 %254, label %255, label %269

255:                                              ; preds = %252
  %256 = load i16, ptr %22, align 1
  %257 = getelementptr inbounds i16, ptr %7, i16 %256
  %258 = load i16, ptr %257, align 2
  %259 = load i16, ptr %22, align 1
  %260 = getelementptr inbounds i16, ptr %6, i16 %259
  %261 = load i16, ptr %260, align 2
  %262 = shl i16 2, %261
  %263 = icmp ne i16 %258, %262
  br i1 %263, label %264, label %265

264:                                              ; preds = %255
  call void @abort() #2
  unreachable

265:                                              ; preds = %255
  br label %266

266:                                              ; preds = %265
  %267 = load i16, ptr %22, align 1
  %268 = add nsw i16 %267, 1
  store i16 %268, ptr %22, align 1
  br label %252, !llvm.loop !11

269:                                              ; preds = %252
  br label %270

270:                                              ; preds = %269
  %271 = load <8 x i16>, ptr %6, align 16
  %272 = ashr <8 x i16> splat (i16 2), %271
  store <8 x i16> %272, ptr %7, align 16
  br label %273

273:                                              ; preds = %270
  store i16 0, ptr %23, align 1
  br label %274

274:                                              ; preds = %288, %273
  %275 = load i16, ptr %23, align 1
  %276 = icmp slt i16 %275, 8
  br i1 %276, label %277, label %291

277:                                              ; preds = %274
  %278 = load i16, ptr %23, align 1
  %279 = getelementptr inbounds i16, ptr %7, i16 %278
  %280 = load i16, ptr %279, align 2
  %281 = load i16, ptr %23, align 1
  %282 = getelementptr inbounds i16, ptr %6, i16 %281
  %283 = load i16, ptr %282, align 2
  %284 = ashr i16 2, %283
  %285 = icmp ne i16 %280, %284
  br i1 %285, label %286, label %287

286:                                              ; preds = %277
  call void @abort() #2
  unreachable

287:                                              ; preds = %277
  br label %288

288:                                              ; preds = %287
  %289 = load i16, ptr %23, align 1
  %290 = add nsw i16 %289, 1
  store i16 %290, ptr %23, align 1
  br label %274, !llvm.loop !12

291:                                              ; preds = %274
  br label %292

292:                                              ; preds = %291
  %293 = load <8 x i16>, ptr %6, align 16
  %294 = add <8 x i16> %293, splat (i16 2)
  store <8 x i16> %294, ptr %7, align 16
  br label %295

295:                                              ; preds = %292
  store i16 0, ptr %24, align 1
  br label %296

296:                                              ; preds = %310, %295
  %297 = load i16, ptr %24, align 1
  %298 = icmp slt i16 %297, 8
  br i1 %298, label %299, label %313

299:                                              ; preds = %296
  %300 = load i16, ptr %24, align 1
  %301 = getelementptr inbounds i16, ptr %7, i16 %300
  %302 = load i16, ptr %301, align 2
  %303 = load i16, ptr %24, align 1
  %304 = getelementptr inbounds i16, ptr %6, i16 %303
  %305 = load i16, ptr %304, align 2
  %306 = add nsw i16 %305, 2
  %307 = icmp ne i16 %302, %306
  br i1 %307, label %308, label %309

308:                                              ; preds = %299
  call void @abort() #2
  unreachable

309:                                              ; preds = %299
  br label %310

310:                                              ; preds = %309
  %311 = load i16, ptr %24, align 1
  %312 = add nsw i16 %311, 1
  store i16 %312, ptr %24, align 1
  br label %296, !llvm.loop !13

313:                                              ; preds = %296
  br label %314

314:                                              ; preds = %313
  %315 = load <8 x i16>, ptr %6, align 16
  %316 = sub <8 x i16> %315, splat (i16 2)
  store <8 x i16> %316, ptr %7, align 16
  br label %317

317:                                              ; preds = %314
  store i16 0, ptr %25, align 1
  br label %318

318:                                              ; preds = %332, %317
  %319 = load i16, ptr %25, align 1
  %320 = icmp slt i16 %319, 8
  br i1 %320, label %321, label %335

321:                                              ; preds = %318
  %322 = load i16, ptr %25, align 1
  %323 = getelementptr inbounds i16, ptr %7, i16 %322
  %324 = load i16, ptr %323, align 2
  %325 = load i16, ptr %25, align 1
  %326 = getelementptr inbounds i16, ptr %6, i16 %325
  %327 = load i16, ptr %326, align 2
  %328 = sub nsw i16 %327, 2
  %329 = icmp ne i16 %324, %328
  br i1 %329, label %330, label %331

330:                                              ; preds = %321
  call void @abort() #2
  unreachable

331:                                              ; preds = %321
  br label %332

332:                                              ; preds = %331
  %333 = load i16, ptr %25, align 1
  %334 = add nsw i16 %333, 1
  store i16 %334, ptr %25, align 1
  br label %318, !llvm.loop !14

335:                                              ; preds = %318
  br label %336

336:                                              ; preds = %335
  %337 = load <8 x i16>, ptr %6, align 16
  %338 = mul <8 x i16> %337, splat (i16 2)
  store <8 x i16> %338, ptr %7, align 16
  br label %339

339:                                              ; preds = %336
  store i16 0, ptr %26, align 1
  br label %340

340:                                              ; preds = %354, %339
  %341 = load i16, ptr %26, align 1
  %342 = icmp slt i16 %341, 8
  br i1 %342, label %343, label %357

343:                                              ; preds = %340
  %344 = load i16, ptr %26, align 1
  %345 = getelementptr inbounds i16, ptr %7, i16 %344
  %346 = load i16, ptr %345, align 2
  %347 = load i16, ptr %26, align 1
  %348 = getelementptr inbounds i16, ptr %6, i16 %347
  %349 = load i16, ptr %348, align 2
  %350 = mul nsw i16 %349, 2
  %351 = icmp ne i16 %346, %350
  br i1 %351, label %352, label %353

352:                                              ; preds = %343
  call void @abort() #2
  unreachable

353:                                              ; preds = %343
  br label %354

354:                                              ; preds = %353
  %355 = load i16, ptr %26, align 1
  %356 = add nsw i16 %355, 1
  store i16 %356, ptr %26, align 1
  br label %340, !llvm.loop !15

357:                                              ; preds = %340
  br label %358

358:                                              ; preds = %357
  %359 = load <8 x i16>, ptr %6, align 16
  %360 = sdiv <8 x i16> %359, splat (i16 2)
  store <8 x i16> %360, ptr %7, align 16
  br label %361

361:                                              ; preds = %358
  store i16 0, ptr %27, align 1
  br label %362

362:                                              ; preds = %376, %361
  %363 = load i16, ptr %27, align 1
  %364 = icmp slt i16 %363, 8
  br i1 %364, label %365, label %379

365:                                              ; preds = %362
  %366 = load i16, ptr %27, align 1
  %367 = getelementptr inbounds i16, ptr %7, i16 %366
  %368 = load i16, ptr %367, align 2
  %369 = load i16, ptr %27, align 1
  %370 = getelementptr inbounds i16, ptr %6, i16 %369
  %371 = load i16, ptr %370, align 2
  %372 = sdiv i16 %371, 2
  %373 = icmp ne i16 %368, %372
  br i1 %373, label %374, label %375

374:                                              ; preds = %365
  call void @abort() #2
  unreachable

375:                                              ; preds = %365
  br label %376

376:                                              ; preds = %375
  %377 = load i16, ptr %27, align 1
  %378 = add nsw i16 %377, 1
  store i16 %378, ptr %27, align 1
  br label %362, !llvm.loop !16

379:                                              ; preds = %362
  br label %380

380:                                              ; preds = %379
  %381 = load <8 x i16>, ptr %6, align 16
  %382 = srem <8 x i16> %381, splat (i16 2)
  store <8 x i16> %382, ptr %7, align 16
  br label %383

383:                                              ; preds = %380
  store i16 0, ptr %28, align 1
  br label %384

384:                                              ; preds = %398, %383
  %385 = load i16, ptr %28, align 1
  %386 = icmp slt i16 %385, 8
  br i1 %386, label %387, label %401

387:                                              ; preds = %384
  %388 = load i16, ptr %28, align 1
  %389 = getelementptr inbounds i16, ptr %7, i16 %388
  %390 = load i16, ptr %389, align 2
  %391 = load i16, ptr %28, align 1
  %392 = getelementptr inbounds i16, ptr %6, i16 %391
  %393 = load i16, ptr %392, align 2
  %394 = srem i16 %393, 2
  %395 = icmp ne i16 %390, %394
  br i1 %395, label %396, label %397

396:                                              ; preds = %387
  call void @abort() #2
  unreachable

397:                                              ; preds = %387
  br label %398

398:                                              ; preds = %397
  %399 = load i16, ptr %28, align 1
  %400 = add nsw i16 %399, 1
  store i16 %400, ptr %28, align 1
  br label %384, !llvm.loop !17

401:                                              ; preds = %384
  br label %402

402:                                              ; preds = %401
  %403 = load <8 x i16>, ptr %6, align 16
  %404 = xor <8 x i16> %403, splat (i16 2)
  store <8 x i16> %404, ptr %7, align 16
  br label %405

405:                                              ; preds = %402
  store i16 0, ptr %29, align 1
  br label %406

406:                                              ; preds = %420, %405
  %407 = load i16, ptr %29, align 1
  %408 = icmp slt i16 %407, 8
  br i1 %408, label %409, label %423

409:                                              ; preds = %406
  %410 = load i16, ptr %29, align 1
  %411 = getelementptr inbounds i16, ptr %7, i16 %410
  %412 = load i16, ptr %411, align 2
  %413 = load i16, ptr %29, align 1
  %414 = getelementptr inbounds i16, ptr %6, i16 %413
  %415 = load i16, ptr %414, align 2
  %416 = xor i16 %415, 2
  %417 = icmp ne i16 %412, %416
  br i1 %417, label %418, label %419

418:                                              ; preds = %409
  call void @abort() #2
  unreachable

419:                                              ; preds = %409
  br label %420

420:                                              ; preds = %419
  %421 = load i16, ptr %29, align 1
  %422 = add nsw i16 %421, 1
  store i16 %422, ptr %29, align 1
  br label %406, !llvm.loop !18

423:                                              ; preds = %406
  br label %424

424:                                              ; preds = %423
  %425 = load <8 x i16>, ptr %6, align 16
  %426 = and <8 x i16> %425, splat (i16 2)
  store <8 x i16> %426, ptr %7, align 16
  br label %427

427:                                              ; preds = %424
  store i16 0, ptr %30, align 1
  br label %428

428:                                              ; preds = %442, %427
  %429 = load i16, ptr %30, align 1
  %430 = icmp slt i16 %429, 8
  br i1 %430, label %431, label %445

431:                                              ; preds = %428
  %432 = load i16, ptr %30, align 1
  %433 = getelementptr inbounds i16, ptr %7, i16 %432
  %434 = load i16, ptr %433, align 2
  %435 = load i16, ptr %30, align 1
  %436 = getelementptr inbounds i16, ptr %6, i16 %435
  %437 = load i16, ptr %436, align 2
  %438 = and i16 %437, 2
  %439 = icmp ne i16 %434, %438
  br i1 %439, label %440, label %441

440:                                              ; preds = %431
  call void @abort() #2
  unreachable

441:                                              ; preds = %431
  br label %442

442:                                              ; preds = %441
  %443 = load i16, ptr %30, align 1
  %444 = add nsw i16 %443, 1
  store i16 %444, ptr %30, align 1
  br label %428, !llvm.loop !19

445:                                              ; preds = %428
  br label %446

446:                                              ; preds = %445
  %447 = load <8 x i16>, ptr %6, align 16
  %448 = or <8 x i16> %447, splat (i16 2)
  store <8 x i16> %448, ptr %7, align 16
  br label %449

449:                                              ; preds = %446
  store i16 0, ptr %31, align 1
  br label %450

450:                                              ; preds = %464, %449
  %451 = load i16, ptr %31, align 1
  %452 = icmp slt i16 %451, 8
  br i1 %452, label %453, label %467

453:                                              ; preds = %450
  %454 = load i16, ptr %31, align 1
  %455 = getelementptr inbounds i16, ptr %7, i16 %454
  %456 = load i16, ptr %455, align 2
  %457 = load i16, ptr %31, align 1
  %458 = getelementptr inbounds i16, ptr %6, i16 %457
  %459 = load i16, ptr %458, align 2
  %460 = or i16 %459, 2
  %461 = icmp ne i16 %456, %460
  br i1 %461, label %462, label %463

462:                                              ; preds = %453
  call void @abort() #2
  unreachable

463:                                              ; preds = %453
  br label %464

464:                                              ; preds = %463
  %465 = load i16, ptr %31, align 1
  %466 = add nsw i16 %465, 1
  store i16 %466, ptr %31, align 1
  br label %450, !llvm.loop !20

467:                                              ; preds = %450
  br label %468

468:                                              ; preds = %467
  %469 = load <4 x float>, ptr %8, align 16
  %470 = fadd <4 x float> splat (float 2.000000e+00), %469
  store <4 x float> %470, ptr %9, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %32, align 16
  %471 = load <4 x float>, ptr %32, align 16
  %472 = load <4 x float>, ptr %8, align 16
  %473 = fadd <4 x float> %471, %472
  store <4 x float> %473, ptr %10, align 16
  br label %474

474:                                              ; preds = %468
  store i16 0, ptr %33, align 1
  br label %475

475:                                              ; preds = %488, %474
  %476 = load i16, ptr %33, align 1
  %477 = icmp slt i16 %476, 4
  br i1 %477, label %478, label %491

478:                                              ; preds = %475
  %479 = load i16, ptr %33, align 1
  %480 = getelementptr inbounds float, ptr %9, i16 %479
  %481 = load float, ptr %480, align 4
  %482 = load i16, ptr %33, align 1
  %483 = getelementptr inbounds float, ptr %10, i16 %482
  %484 = load float, ptr %483, align 4
  %485 = fcmp une float %481, %484
  br i1 %485, label %486, label %487

486:                                              ; preds = %478
  call void @abort() #2
  unreachable

487:                                              ; preds = %478
  br label %488

488:                                              ; preds = %487
  %489 = load i16, ptr %33, align 1
  %490 = add nsw i16 %489, 1
  store i16 %490, ptr %33, align 1
  br label %475, !llvm.loop !21

491:                                              ; preds = %475
  br label %492

492:                                              ; preds = %491
  %493 = load <4 x float>, ptr %8, align 16
  %494 = fsub <4 x float> splat (float 2.000000e+00), %493
  store <4 x float> %494, ptr %9, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %34, align 16
  %495 = load <4 x float>, ptr %34, align 16
  %496 = load <4 x float>, ptr %8, align 16
  %497 = fsub <4 x float> %495, %496
  store <4 x float> %497, ptr %10, align 16
  br label %498

498:                                              ; preds = %492
  store i16 0, ptr %35, align 1
  br label %499

499:                                              ; preds = %512, %498
  %500 = load i16, ptr %35, align 1
  %501 = icmp slt i16 %500, 4
  br i1 %501, label %502, label %515

502:                                              ; preds = %499
  %503 = load i16, ptr %35, align 1
  %504 = getelementptr inbounds float, ptr %9, i16 %503
  %505 = load float, ptr %504, align 4
  %506 = load i16, ptr %35, align 1
  %507 = getelementptr inbounds float, ptr %10, i16 %506
  %508 = load float, ptr %507, align 4
  %509 = fcmp une float %505, %508
  br i1 %509, label %510, label %511

510:                                              ; preds = %502
  call void @abort() #2
  unreachable

511:                                              ; preds = %502
  br label %512

512:                                              ; preds = %511
  %513 = load i16, ptr %35, align 1
  %514 = add nsw i16 %513, 1
  store i16 %514, ptr %35, align 1
  br label %499, !llvm.loop !22

515:                                              ; preds = %499
  br label %516

516:                                              ; preds = %515
  %517 = load <4 x float>, ptr %8, align 16
  %518 = fmul <4 x float> splat (float 2.000000e+00), %517
  store <4 x float> %518, ptr %9, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %36, align 16
  %519 = load <4 x float>, ptr %36, align 16
  %520 = load <4 x float>, ptr %8, align 16
  %521 = fmul <4 x float> %519, %520
  store <4 x float> %521, ptr %10, align 16
  br label %522

522:                                              ; preds = %516
  store i16 0, ptr %37, align 1
  br label %523

523:                                              ; preds = %536, %522
  %524 = load i16, ptr %37, align 1
  %525 = icmp slt i16 %524, 4
  br i1 %525, label %526, label %539

526:                                              ; preds = %523
  %527 = load i16, ptr %37, align 1
  %528 = getelementptr inbounds float, ptr %9, i16 %527
  %529 = load float, ptr %528, align 4
  %530 = load i16, ptr %37, align 1
  %531 = getelementptr inbounds float, ptr %10, i16 %530
  %532 = load float, ptr %531, align 4
  %533 = fcmp une float %529, %532
  br i1 %533, label %534, label %535

534:                                              ; preds = %526
  call void @abort() #2
  unreachable

535:                                              ; preds = %526
  br label %536

536:                                              ; preds = %535
  %537 = load i16, ptr %37, align 1
  %538 = add nsw i16 %537, 1
  store i16 %538, ptr %37, align 1
  br label %523, !llvm.loop !23

539:                                              ; preds = %523
  br label %540

540:                                              ; preds = %539
  %541 = load <4 x float>, ptr %8, align 16
  %542 = fdiv <4 x float> splat (float 2.000000e+00), %541
  store <4 x float> %542, ptr %9, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %38, align 16
  %543 = load <4 x float>, ptr %38, align 16
  %544 = load <4 x float>, ptr %8, align 16
  %545 = fdiv <4 x float> %543, %544
  store <4 x float> %545, ptr %10, align 16
  br label %546

546:                                              ; preds = %540
  store i16 0, ptr %39, align 1
  br label %547

547:                                              ; preds = %560, %546
  %548 = load i16, ptr %39, align 1
  %549 = icmp slt i16 %548, 4
  br i1 %549, label %550, label %563

550:                                              ; preds = %547
  %551 = load i16, ptr %39, align 1
  %552 = getelementptr inbounds float, ptr %9, i16 %551
  %553 = load float, ptr %552, align 4
  %554 = load i16, ptr %39, align 1
  %555 = getelementptr inbounds float, ptr %10, i16 %554
  %556 = load float, ptr %555, align 4
  %557 = fcmp une float %553, %556
  br i1 %557, label %558, label %559

558:                                              ; preds = %550
  call void @abort() #2
  unreachable

559:                                              ; preds = %550
  br label %560

560:                                              ; preds = %559
  %561 = load i16, ptr %39, align 1
  %562 = add nsw i16 %561, 1
  store i16 %562, ptr %39, align 1
  br label %547, !llvm.loop !24

563:                                              ; preds = %547
  br label %564

564:                                              ; preds = %563
  %565 = load <4 x float>, ptr %8, align 16
  %566 = fadd <4 x float> %565, splat (float 2.000000e+00)
  store <4 x float> %566, ptr %9, align 16
  %567 = load <4 x float>, ptr %8, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %40, align 16
  %568 = load <4 x float>, ptr %40, align 16
  %569 = fadd <4 x float> %567, %568
  store <4 x float> %569, ptr %10, align 16
  br label %570

570:                                              ; preds = %564
  store i16 0, ptr %41, align 1
  br label %571

571:                                              ; preds = %584, %570
  %572 = load i16, ptr %41, align 1
  %573 = icmp slt i16 %572, 4
  br i1 %573, label %574, label %587

574:                                              ; preds = %571
  %575 = load i16, ptr %41, align 1
  %576 = getelementptr inbounds float, ptr %9, i16 %575
  %577 = load float, ptr %576, align 4
  %578 = load i16, ptr %41, align 1
  %579 = getelementptr inbounds float, ptr %10, i16 %578
  %580 = load float, ptr %579, align 4
  %581 = fcmp une float %577, %580
  br i1 %581, label %582, label %583

582:                                              ; preds = %574
  call void @abort() #2
  unreachable

583:                                              ; preds = %574
  br label %584

584:                                              ; preds = %583
  %585 = load i16, ptr %41, align 1
  %586 = add nsw i16 %585, 1
  store i16 %586, ptr %41, align 1
  br label %571, !llvm.loop !25

587:                                              ; preds = %571
  br label %588

588:                                              ; preds = %587
  %589 = load <4 x float>, ptr %8, align 16
  %590 = fsub <4 x float> %589, splat (float 2.000000e+00)
  store <4 x float> %590, ptr %9, align 16
  %591 = load <4 x float>, ptr %8, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %42, align 16
  %592 = load <4 x float>, ptr %42, align 16
  %593 = fsub <4 x float> %591, %592
  store <4 x float> %593, ptr %10, align 16
  br label %594

594:                                              ; preds = %588
  store i16 0, ptr %43, align 1
  br label %595

595:                                              ; preds = %608, %594
  %596 = load i16, ptr %43, align 1
  %597 = icmp slt i16 %596, 4
  br i1 %597, label %598, label %611

598:                                              ; preds = %595
  %599 = load i16, ptr %43, align 1
  %600 = getelementptr inbounds float, ptr %9, i16 %599
  %601 = load float, ptr %600, align 4
  %602 = load i16, ptr %43, align 1
  %603 = getelementptr inbounds float, ptr %10, i16 %602
  %604 = load float, ptr %603, align 4
  %605 = fcmp une float %601, %604
  br i1 %605, label %606, label %607

606:                                              ; preds = %598
  call void @abort() #2
  unreachable

607:                                              ; preds = %598
  br label %608

608:                                              ; preds = %607
  %609 = load i16, ptr %43, align 1
  %610 = add nsw i16 %609, 1
  store i16 %610, ptr %43, align 1
  br label %595, !llvm.loop !26

611:                                              ; preds = %595
  br label %612

612:                                              ; preds = %611
  %613 = load <4 x float>, ptr %8, align 16
  %614 = fmul <4 x float> %613, splat (float 2.000000e+00)
  store <4 x float> %614, ptr %9, align 16
  %615 = load <4 x float>, ptr %8, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %44, align 16
  %616 = load <4 x float>, ptr %44, align 16
  %617 = fmul <4 x float> %615, %616
  store <4 x float> %617, ptr %10, align 16
  br label %618

618:                                              ; preds = %612
  store i16 0, ptr %45, align 1
  br label %619

619:                                              ; preds = %632, %618
  %620 = load i16, ptr %45, align 1
  %621 = icmp slt i16 %620, 4
  br i1 %621, label %622, label %635

622:                                              ; preds = %619
  %623 = load i16, ptr %45, align 1
  %624 = getelementptr inbounds float, ptr %9, i16 %623
  %625 = load float, ptr %624, align 4
  %626 = load i16, ptr %45, align 1
  %627 = getelementptr inbounds float, ptr %10, i16 %626
  %628 = load float, ptr %627, align 4
  %629 = fcmp une float %625, %628
  br i1 %629, label %630, label %631

630:                                              ; preds = %622
  call void @abort() #2
  unreachable

631:                                              ; preds = %622
  br label %632

632:                                              ; preds = %631
  %633 = load i16, ptr %45, align 1
  %634 = add nsw i16 %633, 1
  store i16 %634, ptr %45, align 1
  br label %619, !llvm.loop !27

635:                                              ; preds = %619
  br label %636

636:                                              ; preds = %635
  %637 = load <4 x float>, ptr %8, align 16
  %638 = fdiv <4 x float> %637, splat (float 2.000000e+00)
  store <4 x float> %638, ptr %9, align 16
  %639 = load <4 x float>, ptr %8, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %46, align 16
  %640 = load <4 x float>, ptr %46, align 16
  %641 = fdiv <4 x float> %639, %640
  store <4 x float> %641, ptr %10, align 16
  br label %642

642:                                              ; preds = %636
  store i16 0, ptr %47, align 1
  br label %643

643:                                              ; preds = %656, %642
  %644 = load i16, ptr %47, align 1
  %645 = icmp slt i16 %644, 4
  br i1 %645, label %646, label %659

646:                                              ; preds = %643
  %647 = load i16, ptr %47, align 1
  %648 = getelementptr inbounds float, ptr %9, i16 %647
  %649 = load float, ptr %648, align 4
  %650 = load i16, ptr %47, align 1
  %651 = getelementptr inbounds float, ptr %10, i16 %650
  %652 = load float, ptr %651, align 4
  %653 = fcmp une float %649, %652
  br i1 %653, label %654, label %655

654:                                              ; preds = %646
  call void @abort() #2
  unreachable

655:                                              ; preds = %646
  br label %656

656:                                              ; preds = %655
  %657 = load i16, ptr %47, align 1
  %658 = add nsw i16 %657, 1
  store i16 %658, ptr %47, align 1
  br label %643, !llvm.loop !28

659:                                              ; preds = %643
  br label %660

660:                                              ; preds = %659
  %661 = load <2 x double>, ptr %11, align 16
  %662 = fadd <2 x double> splat (double 2.000000e+00), %661
  store <2 x double> %662, ptr %12, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %48, align 16
  %663 = load <2 x double>, ptr %48, align 16
  %664 = load <2 x double>, ptr %11, align 16
  %665 = fadd <2 x double> %663, %664
  store <2 x double> %665, ptr %13, align 16
  br label %666

666:                                              ; preds = %660
  store i16 0, ptr %49, align 1
  br label %667

667:                                              ; preds = %680, %666
  %668 = load i16, ptr %49, align 1
  %669 = icmp slt i16 %668, 2
  br i1 %669, label %670, label %683

670:                                              ; preds = %667
  %671 = load i16, ptr %49, align 1
  %672 = getelementptr inbounds double, ptr %12, i16 %671
  %673 = load double, ptr %672, align 8
  %674 = load i16, ptr %49, align 1
  %675 = getelementptr inbounds double, ptr %13, i16 %674
  %676 = load double, ptr %675, align 8
  %677 = fcmp une double %673, %676
  br i1 %677, label %678, label %679

678:                                              ; preds = %670
  call void @abort() #2
  unreachable

679:                                              ; preds = %670
  br label %680

680:                                              ; preds = %679
  %681 = load i16, ptr %49, align 1
  %682 = add nsw i16 %681, 1
  store i16 %682, ptr %49, align 1
  br label %667, !llvm.loop !29

683:                                              ; preds = %667
  br label %684

684:                                              ; preds = %683
  %685 = load <2 x double>, ptr %11, align 16
  %686 = fsub <2 x double> splat (double 2.000000e+00), %685
  store <2 x double> %686, ptr %12, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %50, align 16
  %687 = load <2 x double>, ptr %50, align 16
  %688 = load <2 x double>, ptr %11, align 16
  %689 = fsub <2 x double> %687, %688
  store <2 x double> %689, ptr %13, align 16
  br label %690

690:                                              ; preds = %684
  store i16 0, ptr %51, align 1
  br label %691

691:                                              ; preds = %704, %690
  %692 = load i16, ptr %51, align 1
  %693 = icmp slt i16 %692, 2
  br i1 %693, label %694, label %707

694:                                              ; preds = %691
  %695 = load i16, ptr %51, align 1
  %696 = getelementptr inbounds double, ptr %12, i16 %695
  %697 = load double, ptr %696, align 8
  %698 = load i16, ptr %51, align 1
  %699 = getelementptr inbounds double, ptr %13, i16 %698
  %700 = load double, ptr %699, align 8
  %701 = fcmp une double %697, %700
  br i1 %701, label %702, label %703

702:                                              ; preds = %694
  call void @abort() #2
  unreachable

703:                                              ; preds = %694
  br label %704

704:                                              ; preds = %703
  %705 = load i16, ptr %51, align 1
  %706 = add nsw i16 %705, 1
  store i16 %706, ptr %51, align 1
  br label %691, !llvm.loop !30

707:                                              ; preds = %691
  br label %708

708:                                              ; preds = %707
  %709 = load <2 x double>, ptr %11, align 16
  %710 = fmul <2 x double> splat (double 2.000000e+00), %709
  store <2 x double> %710, ptr %12, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %52, align 16
  %711 = load <2 x double>, ptr %52, align 16
  %712 = load <2 x double>, ptr %11, align 16
  %713 = fmul <2 x double> %711, %712
  store <2 x double> %713, ptr %13, align 16
  br label %714

714:                                              ; preds = %708
  store i16 0, ptr %53, align 1
  br label %715

715:                                              ; preds = %728, %714
  %716 = load i16, ptr %53, align 1
  %717 = icmp slt i16 %716, 2
  br i1 %717, label %718, label %731

718:                                              ; preds = %715
  %719 = load i16, ptr %53, align 1
  %720 = getelementptr inbounds double, ptr %12, i16 %719
  %721 = load double, ptr %720, align 8
  %722 = load i16, ptr %53, align 1
  %723 = getelementptr inbounds double, ptr %13, i16 %722
  %724 = load double, ptr %723, align 8
  %725 = fcmp une double %721, %724
  br i1 %725, label %726, label %727

726:                                              ; preds = %718
  call void @abort() #2
  unreachable

727:                                              ; preds = %718
  br label %728

728:                                              ; preds = %727
  %729 = load i16, ptr %53, align 1
  %730 = add nsw i16 %729, 1
  store i16 %730, ptr %53, align 1
  br label %715, !llvm.loop !31

731:                                              ; preds = %715
  br label %732

732:                                              ; preds = %731
  %733 = load <2 x double>, ptr %11, align 16
  %734 = fdiv <2 x double> splat (double 2.000000e+00), %733
  store <2 x double> %734, ptr %12, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %54, align 16
  %735 = load <2 x double>, ptr %54, align 16
  %736 = load <2 x double>, ptr %11, align 16
  %737 = fdiv <2 x double> %735, %736
  store <2 x double> %737, ptr %13, align 16
  br label %738

738:                                              ; preds = %732
  store i16 0, ptr %55, align 1
  br label %739

739:                                              ; preds = %752, %738
  %740 = load i16, ptr %55, align 1
  %741 = icmp slt i16 %740, 2
  br i1 %741, label %742, label %755

742:                                              ; preds = %739
  %743 = load i16, ptr %55, align 1
  %744 = getelementptr inbounds double, ptr %12, i16 %743
  %745 = load double, ptr %744, align 8
  %746 = load i16, ptr %55, align 1
  %747 = getelementptr inbounds double, ptr %13, i16 %746
  %748 = load double, ptr %747, align 8
  %749 = fcmp une double %745, %748
  br i1 %749, label %750, label %751

750:                                              ; preds = %742
  call void @abort() #2
  unreachable

751:                                              ; preds = %742
  br label %752

752:                                              ; preds = %751
  %753 = load i16, ptr %55, align 1
  %754 = add nsw i16 %753, 1
  store i16 %754, ptr %55, align 1
  br label %739, !llvm.loop !32

755:                                              ; preds = %739
  br label %756

756:                                              ; preds = %755
  %757 = load <2 x double>, ptr %11, align 16
  %758 = fadd <2 x double> %757, splat (double 2.000000e+00)
  store <2 x double> %758, ptr %12, align 16
  %759 = load <2 x double>, ptr %11, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %56, align 16
  %760 = load <2 x double>, ptr %56, align 16
  %761 = fadd <2 x double> %759, %760
  store <2 x double> %761, ptr %13, align 16
  br label %762

762:                                              ; preds = %756
  store i16 0, ptr %57, align 1
  br label %763

763:                                              ; preds = %776, %762
  %764 = load i16, ptr %57, align 1
  %765 = icmp slt i16 %764, 2
  br i1 %765, label %766, label %779

766:                                              ; preds = %763
  %767 = load i16, ptr %57, align 1
  %768 = getelementptr inbounds double, ptr %12, i16 %767
  %769 = load double, ptr %768, align 8
  %770 = load i16, ptr %57, align 1
  %771 = getelementptr inbounds double, ptr %13, i16 %770
  %772 = load double, ptr %771, align 8
  %773 = fcmp une double %769, %772
  br i1 %773, label %774, label %775

774:                                              ; preds = %766
  call void @abort() #2
  unreachable

775:                                              ; preds = %766
  br label %776

776:                                              ; preds = %775
  %777 = load i16, ptr %57, align 1
  %778 = add nsw i16 %777, 1
  store i16 %778, ptr %57, align 1
  br label %763, !llvm.loop !33

779:                                              ; preds = %763
  br label %780

780:                                              ; preds = %779
  %781 = load <2 x double>, ptr %11, align 16
  %782 = fsub <2 x double> %781, splat (double 2.000000e+00)
  store <2 x double> %782, ptr %12, align 16
  %783 = load <2 x double>, ptr %11, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %58, align 16
  %784 = load <2 x double>, ptr %58, align 16
  %785 = fsub <2 x double> %783, %784
  store <2 x double> %785, ptr %13, align 16
  br label %786

786:                                              ; preds = %780
  store i16 0, ptr %59, align 1
  br label %787

787:                                              ; preds = %800, %786
  %788 = load i16, ptr %59, align 1
  %789 = icmp slt i16 %788, 2
  br i1 %789, label %790, label %803

790:                                              ; preds = %787
  %791 = load i16, ptr %59, align 1
  %792 = getelementptr inbounds double, ptr %12, i16 %791
  %793 = load double, ptr %792, align 8
  %794 = load i16, ptr %59, align 1
  %795 = getelementptr inbounds double, ptr %13, i16 %794
  %796 = load double, ptr %795, align 8
  %797 = fcmp une double %793, %796
  br i1 %797, label %798, label %799

798:                                              ; preds = %790
  call void @abort() #2
  unreachable

799:                                              ; preds = %790
  br label %800

800:                                              ; preds = %799
  %801 = load i16, ptr %59, align 1
  %802 = add nsw i16 %801, 1
  store i16 %802, ptr %59, align 1
  br label %787, !llvm.loop !34

803:                                              ; preds = %787
  br label %804

804:                                              ; preds = %803
  %805 = load <2 x double>, ptr %11, align 16
  %806 = fmul <2 x double> %805, splat (double 2.000000e+00)
  store <2 x double> %806, ptr %12, align 16
  %807 = load <2 x double>, ptr %11, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %60, align 16
  %808 = load <2 x double>, ptr %60, align 16
  %809 = fmul <2 x double> %807, %808
  store <2 x double> %809, ptr %13, align 16
  br label %810

810:                                              ; preds = %804
  store i16 0, ptr %61, align 1
  br label %811

811:                                              ; preds = %824, %810
  %812 = load i16, ptr %61, align 1
  %813 = icmp slt i16 %812, 2
  br i1 %813, label %814, label %827

814:                                              ; preds = %811
  %815 = load i16, ptr %61, align 1
  %816 = getelementptr inbounds double, ptr %12, i16 %815
  %817 = load double, ptr %816, align 8
  %818 = load i16, ptr %61, align 1
  %819 = getelementptr inbounds double, ptr %13, i16 %818
  %820 = load double, ptr %819, align 8
  %821 = fcmp une double %817, %820
  br i1 %821, label %822, label %823

822:                                              ; preds = %814
  call void @abort() #2
  unreachable

823:                                              ; preds = %814
  br label %824

824:                                              ; preds = %823
  %825 = load i16, ptr %61, align 1
  %826 = add nsw i16 %825, 1
  store i16 %826, ptr %61, align 1
  br label %811, !llvm.loop !35

827:                                              ; preds = %811
  br label %828

828:                                              ; preds = %827
  %829 = load <2 x double>, ptr %11, align 16
  %830 = fdiv <2 x double> %829, splat (double 2.000000e+00)
  store <2 x double> %830, ptr %12, align 16
  %831 = load <2 x double>, ptr %11, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %62, align 16
  %832 = load <2 x double>, ptr %62, align 16
  %833 = fdiv <2 x double> %831, %832
  store <2 x double> %833, ptr %13, align 16
  br label %834

834:                                              ; preds = %828
  store i16 0, ptr %63, align 1
  br label %835

835:                                              ; preds = %848, %834
  %836 = load i16, ptr %63, align 1
  %837 = icmp slt i16 %836, 2
  br i1 %837, label %838, label %851

838:                                              ; preds = %835
  %839 = load i16, ptr %63, align 1
  %840 = getelementptr inbounds double, ptr %12, i16 %839
  %841 = load double, ptr %840, align 8
  %842 = load i16, ptr %63, align 1
  %843 = getelementptr inbounds double, ptr %13, i16 %842
  %844 = load double, ptr %843, align 8
  %845 = fcmp une double %841, %844
  br i1 %845, label %846, label %847

846:                                              ; preds = %838
  call void @abort() #2
  unreachable

847:                                              ; preds = %838
  br label %848

848:                                              ; preds = %847
  %849 = load i16, ptr %63, align 1
  %850 = add nsw i16 %849, 1
  store i16 %850, ptr %63, align 1
  br label %835, !llvm.loop !36

851:                                              ; preds = %835
  br label %852

852:                                              ; preds = %851
  ret i16 0
}

; Function Attrs: noreturn nounwind
declare dso_local void @abort() #1

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #2 = { noreturn nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = distinct !{!2, !3}
!3 = !{!"llvm.loop.mustprogress"}
!4 = distinct !{!4, !3}
!5 = distinct !{!5, !3}
!6 = distinct !{!6, !3}
!7 = distinct !{!7, !3}
!8 = distinct !{!8, !3}
!9 = distinct !{!9, !3}
!10 = distinct !{!10, !3}
!11 = distinct !{!11, !3}
!12 = distinct !{!12, !3}
!13 = distinct !{!13, !3}
!14 = distinct !{!14, !3}
!15 = distinct !{!15, !3}
!16 = distinct !{!16, !3}
!17 = distinct !{!17, !3}
!18 = distinct !{!18, !3}
!19 = distinct !{!19, !3}
!20 = distinct !{!20, !3}
!21 = distinct !{!21, !3}
!22 = distinct !{!22, !3}
!23 = distinct !{!23, !3}
!24 = distinct !{!24, !3}
!25 = distinct !{!25, !3}
!26 = distinct !{!26, !3}
!27 = distinct !{!27, !3}
!28 = distinct !{!28, !3}
!29 = distinct !{!29, !3}
!30 = distinct !{!30, !3}
!31 = distinct !{!31, !3}
!32 = distinct !{!32, !3}
!33 = distinct !{!33, !3}
!34 = distinct !{!34, !3}
!35 = distinct !{!35, !3}
!36 = distinct !{!36, !3}

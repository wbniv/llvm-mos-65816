; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec3.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/scal-to-vec3.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: noinline nounwind optnone
define dso_local i16 @main(i16 noundef %0, ptr noundef %1) #0 {
  %3 = alloca i16, align 1
  %4 = alloca i16, align 1
  %5 = alloca ptr, align 1
  %6 = alloca <4 x float>, align 16
  %7 = alloca <4 x float>, align 16
  %8 = alloca <4 x float>, align 16
  %9 = alloca <2 x double>, align 16
  %10 = alloca <2 x double>, align 16
  %11 = alloca <2 x double>, align 16
  %12 = alloca <4 x float>, align 16
  %13 = alloca i16, align 1
  %14 = alloca <4 x float>, align 16
  %15 = alloca i16, align 1
  %16 = alloca <4 x float>, align 16
  %17 = alloca i16, align 1
  %18 = alloca <4 x float>, align 16
  %19 = alloca i16, align 1
  %20 = alloca <4 x float>, align 16
  %21 = alloca i16, align 1
  %22 = alloca <4 x float>, align 16
  %23 = alloca i16, align 1
  %24 = alloca <4 x float>, align 16
  %25 = alloca i16, align 1
  %26 = alloca <4 x float>, align 16
  %27 = alloca i16, align 1
  %28 = alloca <2 x double>, align 16
  %29 = alloca i16, align 1
  %30 = alloca <2 x double>, align 16
  %31 = alloca i16, align 1
  %32 = alloca <2 x double>, align 16
  %33 = alloca i16, align 1
  %34 = alloca <2 x double>, align 16
  %35 = alloca i16, align 1
  %36 = alloca <2 x double>, align 16
  %37 = alloca i16, align 1
  %38 = alloca <2 x double>, align 16
  %39 = alloca i16, align 1
  %40 = alloca <2 x double>, align 16
  %41 = alloca i16, align 1
  %42 = alloca <2 x double>, align 16
  %43 = alloca i16, align 1
  store i16 0, ptr %3, align 1
  store i16 %0, ptr %4, align 1
  store ptr %1, ptr %5, align 1
  store <4 x float> <float 1.000000e+00, float 2.000000e+00, float 3.000000e+00, float 4.000000e+00>, ptr %6, align 16
  store <2 x double> <double 1.000000e+00, double 2.000000e+00>, ptr %9, align 16
  %44 = load <4 x float>, ptr %6, align 16
  %45 = fadd <4 x float> splat (float 2.000000e+00), %44
  store <4 x float> %45, ptr %7, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %12, align 16
  %46 = load <4 x float>, ptr %12, align 16
  %47 = load <4 x float>, ptr %6, align 16
  %48 = fadd <4 x float> %46, %47
  store <4 x float> %48, ptr %8, align 16
  br label %49

49:                                               ; preds = %2
  store i16 0, ptr %13, align 1
  br label %50

50:                                               ; preds = %63, %49
  %51 = load i16, ptr %13, align 1
  %52 = icmp slt i16 %51, 4
  br i1 %52, label %53, label %66

53:                                               ; preds = %50
  %54 = load i16, ptr %13, align 1
  %55 = getelementptr inbounds float, ptr %7, i16 %54
  %56 = load float, ptr %55, align 4
  %57 = load i16, ptr %13, align 1
  %58 = getelementptr inbounds float, ptr %8, i16 %57
  %59 = load float, ptr %58, align 4
  %60 = fcmp une float %56, %59
  br i1 %60, label %61, label %62

61:                                               ; preds = %53
  call void @abort() #2
  unreachable

62:                                               ; preds = %53
  br label %63

63:                                               ; preds = %62
  %64 = load i16, ptr %13, align 1
  %65 = add nsw i16 %64, 1
  store i16 %65, ptr %13, align 1
  br label %50, !llvm.loop !2

66:                                               ; preds = %50
  br label %67

67:                                               ; preds = %66
  %68 = load <4 x float>, ptr %6, align 16
  %69 = fsub <4 x float> splat (float 2.000000e+00), %68
  store <4 x float> %69, ptr %7, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %14, align 16
  %70 = load <4 x float>, ptr %14, align 16
  %71 = load <4 x float>, ptr %6, align 16
  %72 = fsub <4 x float> %70, %71
  store <4 x float> %72, ptr %8, align 16
  br label %73

73:                                               ; preds = %67
  store i16 0, ptr %15, align 1
  br label %74

74:                                               ; preds = %87, %73
  %75 = load i16, ptr %15, align 1
  %76 = icmp slt i16 %75, 4
  br i1 %76, label %77, label %90

77:                                               ; preds = %74
  %78 = load i16, ptr %15, align 1
  %79 = getelementptr inbounds float, ptr %7, i16 %78
  %80 = load float, ptr %79, align 4
  %81 = load i16, ptr %15, align 1
  %82 = getelementptr inbounds float, ptr %8, i16 %81
  %83 = load float, ptr %82, align 4
  %84 = fcmp une float %80, %83
  br i1 %84, label %85, label %86

85:                                               ; preds = %77
  call void @abort() #2
  unreachable

86:                                               ; preds = %77
  br label %87

87:                                               ; preds = %86
  %88 = load i16, ptr %15, align 1
  %89 = add nsw i16 %88, 1
  store i16 %89, ptr %15, align 1
  br label %74, !llvm.loop !4

90:                                               ; preds = %74
  br label %91

91:                                               ; preds = %90
  %92 = load <4 x float>, ptr %6, align 16
  %93 = fmul <4 x float> splat (float 2.000000e+00), %92
  store <4 x float> %93, ptr %7, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %16, align 16
  %94 = load <4 x float>, ptr %16, align 16
  %95 = load <4 x float>, ptr %6, align 16
  %96 = fmul <4 x float> %94, %95
  store <4 x float> %96, ptr %8, align 16
  br label %97

97:                                               ; preds = %91
  store i16 0, ptr %17, align 1
  br label %98

98:                                               ; preds = %111, %97
  %99 = load i16, ptr %17, align 1
  %100 = icmp slt i16 %99, 4
  br i1 %100, label %101, label %114

101:                                              ; preds = %98
  %102 = load i16, ptr %17, align 1
  %103 = getelementptr inbounds float, ptr %7, i16 %102
  %104 = load float, ptr %103, align 4
  %105 = load i16, ptr %17, align 1
  %106 = getelementptr inbounds float, ptr %8, i16 %105
  %107 = load float, ptr %106, align 4
  %108 = fcmp une float %104, %107
  br i1 %108, label %109, label %110

109:                                              ; preds = %101
  call void @abort() #2
  unreachable

110:                                              ; preds = %101
  br label %111

111:                                              ; preds = %110
  %112 = load i16, ptr %17, align 1
  %113 = add nsw i16 %112, 1
  store i16 %113, ptr %17, align 1
  br label %98, !llvm.loop !5

114:                                              ; preds = %98
  br label %115

115:                                              ; preds = %114
  %116 = load <4 x float>, ptr %6, align 16
  %117 = fdiv <4 x float> splat (float 2.000000e+00), %116
  store <4 x float> %117, ptr %7, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %18, align 16
  %118 = load <4 x float>, ptr %18, align 16
  %119 = load <4 x float>, ptr %6, align 16
  %120 = fdiv <4 x float> %118, %119
  store <4 x float> %120, ptr %8, align 16
  br label %121

121:                                              ; preds = %115
  store i16 0, ptr %19, align 1
  br label %122

122:                                              ; preds = %135, %121
  %123 = load i16, ptr %19, align 1
  %124 = icmp slt i16 %123, 4
  br i1 %124, label %125, label %138

125:                                              ; preds = %122
  %126 = load i16, ptr %19, align 1
  %127 = getelementptr inbounds float, ptr %7, i16 %126
  %128 = load float, ptr %127, align 4
  %129 = load i16, ptr %19, align 1
  %130 = getelementptr inbounds float, ptr %8, i16 %129
  %131 = load float, ptr %130, align 4
  %132 = fcmp une float %128, %131
  br i1 %132, label %133, label %134

133:                                              ; preds = %125
  call void @abort() #2
  unreachable

134:                                              ; preds = %125
  br label %135

135:                                              ; preds = %134
  %136 = load i16, ptr %19, align 1
  %137 = add nsw i16 %136, 1
  store i16 %137, ptr %19, align 1
  br label %122, !llvm.loop !6

138:                                              ; preds = %122
  br label %139

139:                                              ; preds = %138
  %140 = load <4 x float>, ptr %6, align 16
  %141 = fadd <4 x float> %140, splat (float 2.000000e+00)
  store <4 x float> %141, ptr %7, align 16
  %142 = load <4 x float>, ptr %6, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %20, align 16
  %143 = load <4 x float>, ptr %20, align 16
  %144 = fadd <4 x float> %142, %143
  store <4 x float> %144, ptr %8, align 16
  br label %145

145:                                              ; preds = %139
  store i16 0, ptr %21, align 1
  br label %146

146:                                              ; preds = %159, %145
  %147 = load i16, ptr %21, align 1
  %148 = icmp slt i16 %147, 4
  br i1 %148, label %149, label %162

149:                                              ; preds = %146
  %150 = load i16, ptr %21, align 1
  %151 = getelementptr inbounds float, ptr %7, i16 %150
  %152 = load float, ptr %151, align 4
  %153 = load i16, ptr %21, align 1
  %154 = getelementptr inbounds float, ptr %8, i16 %153
  %155 = load float, ptr %154, align 4
  %156 = fcmp une float %152, %155
  br i1 %156, label %157, label %158

157:                                              ; preds = %149
  call void @abort() #2
  unreachable

158:                                              ; preds = %149
  br label %159

159:                                              ; preds = %158
  %160 = load i16, ptr %21, align 1
  %161 = add nsw i16 %160, 1
  store i16 %161, ptr %21, align 1
  br label %146, !llvm.loop !7

162:                                              ; preds = %146
  br label %163

163:                                              ; preds = %162
  %164 = load <4 x float>, ptr %6, align 16
  %165 = fsub <4 x float> %164, splat (float 2.000000e+00)
  store <4 x float> %165, ptr %7, align 16
  %166 = load <4 x float>, ptr %6, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %22, align 16
  %167 = load <4 x float>, ptr %22, align 16
  %168 = fsub <4 x float> %166, %167
  store <4 x float> %168, ptr %8, align 16
  br label %169

169:                                              ; preds = %163
  store i16 0, ptr %23, align 1
  br label %170

170:                                              ; preds = %183, %169
  %171 = load i16, ptr %23, align 1
  %172 = icmp slt i16 %171, 4
  br i1 %172, label %173, label %186

173:                                              ; preds = %170
  %174 = load i16, ptr %23, align 1
  %175 = getelementptr inbounds float, ptr %7, i16 %174
  %176 = load float, ptr %175, align 4
  %177 = load i16, ptr %23, align 1
  %178 = getelementptr inbounds float, ptr %8, i16 %177
  %179 = load float, ptr %178, align 4
  %180 = fcmp une float %176, %179
  br i1 %180, label %181, label %182

181:                                              ; preds = %173
  call void @abort() #2
  unreachable

182:                                              ; preds = %173
  br label %183

183:                                              ; preds = %182
  %184 = load i16, ptr %23, align 1
  %185 = add nsw i16 %184, 1
  store i16 %185, ptr %23, align 1
  br label %170, !llvm.loop !8

186:                                              ; preds = %170
  br label %187

187:                                              ; preds = %186
  %188 = load <4 x float>, ptr %6, align 16
  %189 = fmul <4 x float> %188, splat (float 2.000000e+00)
  store <4 x float> %189, ptr %7, align 16
  %190 = load <4 x float>, ptr %6, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %24, align 16
  %191 = load <4 x float>, ptr %24, align 16
  %192 = fmul <4 x float> %190, %191
  store <4 x float> %192, ptr %8, align 16
  br label %193

193:                                              ; preds = %187
  store i16 0, ptr %25, align 1
  br label %194

194:                                              ; preds = %207, %193
  %195 = load i16, ptr %25, align 1
  %196 = icmp slt i16 %195, 4
  br i1 %196, label %197, label %210

197:                                              ; preds = %194
  %198 = load i16, ptr %25, align 1
  %199 = getelementptr inbounds float, ptr %7, i16 %198
  %200 = load float, ptr %199, align 4
  %201 = load i16, ptr %25, align 1
  %202 = getelementptr inbounds float, ptr %8, i16 %201
  %203 = load float, ptr %202, align 4
  %204 = fcmp une float %200, %203
  br i1 %204, label %205, label %206

205:                                              ; preds = %197
  call void @abort() #2
  unreachable

206:                                              ; preds = %197
  br label %207

207:                                              ; preds = %206
  %208 = load i16, ptr %25, align 1
  %209 = add nsw i16 %208, 1
  store i16 %209, ptr %25, align 1
  br label %194, !llvm.loop !9

210:                                              ; preds = %194
  br label %211

211:                                              ; preds = %210
  %212 = load <4 x float>, ptr %6, align 16
  %213 = fdiv <4 x float> %212, splat (float 2.000000e+00)
  store <4 x float> %213, ptr %7, align 16
  %214 = load <4 x float>, ptr %6, align 16
  store <4 x float> splat (float 2.000000e+00), ptr %26, align 16
  %215 = load <4 x float>, ptr %26, align 16
  %216 = fdiv <4 x float> %214, %215
  store <4 x float> %216, ptr %8, align 16
  br label %217

217:                                              ; preds = %211
  store i16 0, ptr %27, align 1
  br label %218

218:                                              ; preds = %231, %217
  %219 = load i16, ptr %27, align 1
  %220 = icmp slt i16 %219, 4
  br i1 %220, label %221, label %234

221:                                              ; preds = %218
  %222 = load i16, ptr %27, align 1
  %223 = getelementptr inbounds float, ptr %7, i16 %222
  %224 = load float, ptr %223, align 4
  %225 = load i16, ptr %27, align 1
  %226 = getelementptr inbounds float, ptr %8, i16 %225
  %227 = load float, ptr %226, align 4
  %228 = fcmp une float %224, %227
  br i1 %228, label %229, label %230

229:                                              ; preds = %221
  call void @abort() #2
  unreachable

230:                                              ; preds = %221
  br label %231

231:                                              ; preds = %230
  %232 = load i16, ptr %27, align 1
  %233 = add nsw i16 %232, 1
  store i16 %233, ptr %27, align 1
  br label %218, !llvm.loop !10

234:                                              ; preds = %218
  br label %235

235:                                              ; preds = %234
  %236 = load <2 x double>, ptr %9, align 16
  %237 = fadd <2 x double> splat (double 2.000000e+00), %236
  store <2 x double> %237, ptr %10, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %28, align 16
  %238 = load <2 x double>, ptr %28, align 16
  %239 = load <2 x double>, ptr %9, align 16
  %240 = fadd <2 x double> %238, %239
  store <2 x double> %240, ptr %11, align 16
  br label %241

241:                                              ; preds = %235
  store i16 0, ptr %29, align 1
  br label %242

242:                                              ; preds = %255, %241
  %243 = load i16, ptr %29, align 1
  %244 = icmp slt i16 %243, 2
  br i1 %244, label %245, label %258

245:                                              ; preds = %242
  %246 = load i16, ptr %29, align 1
  %247 = getelementptr inbounds double, ptr %10, i16 %246
  %248 = load double, ptr %247, align 8
  %249 = load i16, ptr %29, align 1
  %250 = getelementptr inbounds double, ptr %11, i16 %249
  %251 = load double, ptr %250, align 8
  %252 = fcmp une double %248, %251
  br i1 %252, label %253, label %254

253:                                              ; preds = %245
  call void @abort() #2
  unreachable

254:                                              ; preds = %245
  br label %255

255:                                              ; preds = %254
  %256 = load i16, ptr %29, align 1
  %257 = add nsw i16 %256, 1
  store i16 %257, ptr %29, align 1
  br label %242, !llvm.loop !11

258:                                              ; preds = %242
  br label %259

259:                                              ; preds = %258
  %260 = load <2 x double>, ptr %9, align 16
  %261 = fsub <2 x double> splat (double 2.000000e+00), %260
  store <2 x double> %261, ptr %10, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %30, align 16
  %262 = load <2 x double>, ptr %30, align 16
  %263 = load <2 x double>, ptr %9, align 16
  %264 = fsub <2 x double> %262, %263
  store <2 x double> %264, ptr %11, align 16
  br label %265

265:                                              ; preds = %259
  store i16 0, ptr %31, align 1
  br label %266

266:                                              ; preds = %279, %265
  %267 = load i16, ptr %31, align 1
  %268 = icmp slt i16 %267, 2
  br i1 %268, label %269, label %282

269:                                              ; preds = %266
  %270 = load i16, ptr %31, align 1
  %271 = getelementptr inbounds double, ptr %10, i16 %270
  %272 = load double, ptr %271, align 8
  %273 = load i16, ptr %31, align 1
  %274 = getelementptr inbounds double, ptr %11, i16 %273
  %275 = load double, ptr %274, align 8
  %276 = fcmp une double %272, %275
  br i1 %276, label %277, label %278

277:                                              ; preds = %269
  call void @abort() #2
  unreachable

278:                                              ; preds = %269
  br label %279

279:                                              ; preds = %278
  %280 = load i16, ptr %31, align 1
  %281 = add nsw i16 %280, 1
  store i16 %281, ptr %31, align 1
  br label %266, !llvm.loop !12

282:                                              ; preds = %266
  br label %283

283:                                              ; preds = %282
  %284 = load <2 x double>, ptr %9, align 16
  %285 = fmul <2 x double> splat (double 2.000000e+00), %284
  store <2 x double> %285, ptr %10, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %32, align 16
  %286 = load <2 x double>, ptr %32, align 16
  %287 = load <2 x double>, ptr %9, align 16
  %288 = fmul <2 x double> %286, %287
  store <2 x double> %288, ptr %11, align 16
  br label %289

289:                                              ; preds = %283
  store i16 0, ptr %33, align 1
  br label %290

290:                                              ; preds = %303, %289
  %291 = load i16, ptr %33, align 1
  %292 = icmp slt i16 %291, 2
  br i1 %292, label %293, label %306

293:                                              ; preds = %290
  %294 = load i16, ptr %33, align 1
  %295 = getelementptr inbounds double, ptr %10, i16 %294
  %296 = load double, ptr %295, align 8
  %297 = load i16, ptr %33, align 1
  %298 = getelementptr inbounds double, ptr %11, i16 %297
  %299 = load double, ptr %298, align 8
  %300 = fcmp une double %296, %299
  br i1 %300, label %301, label %302

301:                                              ; preds = %293
  call void @abort() #2
  unreachable

302:                                              ; preds = %293
  br label %303

303:                                              ; preds = %302
  %304 = load i16, ptr %33, align 1
  %305 = add nsw i16 %304, 1
  store i16 %305, ptr %33, align 1
  br label %290, !llvm.loop !13

306:                                              ; preds = %290
  br label %307

307:                                              ; preds = %306
  %308 = load <2 x double>, ptr %9, align 16
  %309 = fdiv <2 x double> splat (double 2.000000e+00), %308
  store <2 x double> %309, ptr %10, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %34, align 16
  %310 = load <2 x double>, ptr %34, align 16
  %311 = load <2 x double>, ptr %9, align 16
  %312 = fdiv <2 x double> %310, %311
  store <2 x double> %312, ptr %11, align 16
  br label %313

313:                                              ; preds = %307
  store i16 0, ptr %35, align 1
  br label %314

314:                                              ; preds = %327, %313
  %315 = load i16, ptr %35, align 1
  %316 = icmp slt i16 %315, 2
  br i1 %316, label %317, label %330

317:                                              ; preds = %314
  %318 = load i16, ptr %35, align 1
  %319 = getelementptr inbounds double, ptr %10, i16 %318
  %320 = load double, ptr %319, align 8
  %321 = load i16, ptr %35, align 1
  %322 = getelementptr inbounds double, ptr %11, i16 %321
  %323 = load double, ptr %322, align 8
  %324 = fcmp une double %320, %323
  br i1 %324, label %325, label %326

325:                                              ; preds = %317
  call void @abort() #2
  unreachable

326:                                              ; preds = %317
  br label %327

327:                                              ; preds = %326
  %328 = load i16, ptr %35, align 1
  %329 = add nsw i16 %328, 1
  store i16 %329, ptr %35, align 1
  br label %314, !llvm.loop !14

330:                                              ; preds = %314
  br label %331

331:                                              ; preds = %330
  %332 = load <2 x double>, ptr %9, align 16
  %333 = fadd <2 x double> %332, splat (double 2.000000e+00)
  store <2 x double> %333, ptr %10, align 16
  %334 = load <2 x double>, ptr %9, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %36, align 16
  %335 = load <2 x double>, ptr %36, align 16
  %336 = fadd <2 x double> %334, %335
  store <2 x double> %336, ptr %11, align 16
  br label %337

337:                                              ; preds = %331
  store i16 0, ptr %37, align 1
  br label %338

338:                                              ; preds = %351, %337
  %339 = load i16, ptr %37, align 1
  %340 = icmp slt i16 %339, 2
  br i1 %340, label %341, label %354

341:                                              ; preds = %338
  %342 = load i16, ptr %37, align 1
  %343 = getelementptr inbounds double, ptr %10, i16 %342
  %344 = load double, ptr %343, align 8
  %345 = load i16, ptr %37, align 1
  %346 = getelementptr inbounds double, ptr %11, i16 %345
  %347 = load double, ptr %346, align 8
  %348 = fcmp une double %344, %347
  br i1 %348, label %349, label %350

349:                                              ; preds = %341
  call void @abort() #2
  unreachable

350:                                              ; preds = %341
  br label %351

351:                                              ; preds = %350
  %352 = load i16, ptr %37, align 1
  %353 = add nsw i16 %352, 1
  store i16 %353, ptr %37, align 1
  br label %338, !llvm.loop !15

354:                                              ; preds = %338
  br label %355

355:                                              ; preds = %354
  %356 = load <2 x double>, ptr %9, align 16
  %357 = fsub <2 x double> %356, splat (double 2.000000e+00)
  store <2 x double> %357, ptr %10, align 16
  %358 = load <2 x double>, ptr %9, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %38, align 16
  %359 = load <2 x double>, ptr %38, align 16
  %360 = fsub <2 x double> %358, %359
  store <2 x double> %360, ptr %11, align 16
  br label %361

361:                                              ; preds = %355
  store i16 0, ptr %39, align 1
  br label %362

362:                                              ; preds = %375, %361
  %363 = load i16, ptr %39, align 1
  %364 = icmp slt i16 %363, 2
  br i1 %364, label %365, label %378

365:                                              ; preds = %362
  %366 = load i16, ptr %39, align 1
  %367 = getelementptr inbounds double, ptr %10, i16 %366
  %368 = load double, ptr %367, align 8
  %369 = load i16, ptr %39, align 1
  %370 = getelementptr inbounds double, ptr %11, i16 %369
  %371 = load double, ptr %370, align 8
  %372 = fcmp une double %368, %371
  br i1 %372, label %373, label %374

373:                                              ; preds = %365
  call void @abort() #2
  unreachable

374:                                              ; preds = %365
  br label %375

375:                                              ; preds = %374
  %376 = load i16, ptr %39, align 1
  %377 = add nsw i16 %376, 1
  store i16 %377, ptr %39, align 1
  br label %362, !llvm.loop !16

378:                                              ; preds = %362
  br label %379

379:                                              ; preds = %378
  %380 = load <2 x double>, ptr %9, align 16
  %381 = fmul <2 x double> %380, splat (double 2.000000e+00)
  store <2 x double> %381, ptr %10, align 16
  %382 = load <2 x double>, ptr %9, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %40, align 16
  %383 = load <2 x double>, ptr %40, align 16
  %384 = fmul <2 x double> %382, %383
  store <2 x double> %384, ptr %11, align 16
  br label %385

385:                                              ; preds = %379
  store i16 0, ptr %41, align 1
  br label %386

386:                                              ; preds = %399, %385
  %387 = load i16, ptr %41, align 1
  %388 = icmp slt i16 %387, 2
  br i1 %388, label %389, label %402

389:                                              ; preds = %386
  %390 = load i16, ptr %41, align 1
  %391 = getelementptr inbounds double, ptr %10, i16 %390
  %392 = load double, ptr %391, align 8
  %393 = load i16, ptr %41, align 1
  %394 = getelementptr inbounds double, ptr %11, i16 %393
  %395 = load double, ptr %394, align 8
  %396 = fcmp une double %392, %395
  br i1 %396, label %397, label %398

397:                                              ; preds = %389
  call void @abort() #2
  unreachable

398:                                              ; preds = %389
  br label %399

399:                                              ; preds = %398
  %400 = load i16, ptr %41, align 1
  %401 = add nsw i16 %400, 1
  store i16 %401, ptr %41, align 1
  br label %386, !llvm.loop !17

402:                                              ; preds = %386
  br label %403

403:                                              ; preds = %402
  %404 = load <2 x double>, ptr %9, align 16
  %405 = fdiv <2 x double> %404, splat (double 2.000000e+00)
  store <2 x double> %405, ptr %10, align 16
  %406 = load <2 x double>, ptr %9, align 16
  store <2 x double> splat (double 2.000000e+00), ptr %42, align 16
  %407 = load <2 x double>, ptr %42, align 16
  %408 = fdiv <2 x double> %406, %407
  store <2 x double> %408, ptr %11, align 16
  br label %409

409:                                              ; preds = %403
  store i16 0, ptr %43, align 1
  br label %410

410:                                              ; preds = %423, %409
  %411 = load i16, ptr %43, align 1
  %412 = icmp slt i16 %411, 2
  br i1 %412, label %413, label %426

413:                                              ; preds = %410
  %414 = load i16, ptr %43, align 1
  %415 = getelementptr inbounds double, ptr %10, i16 %414
  %416 = load double, ptr %415, align 8
  %417 = load i16, ptr %43, align 1
  %418 = getelementptr inbounds double, ptr %11, i16 %417
  %419 = load double, ptr %418, align 8
  %420 = fcmp une double %416, %419
  br i1 %420, label %421, label %422

421:                                              ; preds = %413
  call void @abort() #2
  unreachable

422:                                              ; preds = %413
  br label %423

423:                                              ; preds = %422
  %424 = load i16, ptr %43, align 1
  %425 = add nsw i16 %424, 1
  store i16 %425, ptr %43, align 1
  br label %410, !llvm.loop !18

426:                                              ; preds = %410
  br label %427

427:                                              ; preds = %426
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

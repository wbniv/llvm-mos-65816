; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20060420-1.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-mos-correctness/baseline/20060420-1.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@buffer = dso_local global [64 x float] zeroinitializer, align 1

; Function Attrs: noinline nounwind optnone
define dso_local void @foo(ptr noundef %0, ptr noundef %1, i16 noundef %2, i16 noundef %3) #0 {
  %5 = alloca ptr, align 1
  %6 = alloca ptr, align 1
  %7 = alloca i16, align 1
  %8 = alloca i16, align 1
  %9 = alloca i16, align 1
  %10 = alloca i16, align 1
  %11 = alloca i16, align 1
  %12 = alloca i16, align 1
  %13 = alloca float, align 1
  %14 = alloca <4 x float>, align 16
  %15 = alloca <4 x float>, align 16
  %16 = alloca <4 x float>, align 16
  %17 = alloca <4 x float>, align 16
  %18 = alloca float, align 1
  store ptr %0, ptr %5, align 1
  store ptr %1, ptr %6, align 1
  store i16 %2, ptr %7, align 1
  store i16 %3, ptr %8, align 1
  store i16 4, ptr %11, align 1
  store i16 15, ptr %12, align 1
  store i16 0, ptr %10, align 1
  br label %19

19:                                               ; preds = %64, %4
  %20 = load i16, ptr %10, align 1
  %21 = load i16, ptr %8, align 1
  %22 = icmp slt i16 %20, %21
  br i1 %22, label %23, label %33

23:                                               ; preds = %19
  %24 = load ptr, ptr %5, align 1
  %25 = ptrtoint ptr %24 to i32
  %26 = load i16, ptr %10, align 1
  %27 = sext i16 %26 to i32
  %28 = add i32 %25, %27
  %29 = load i16, ptr %12, align 1
  %30 = zext i16 %29 to i32
  %31 = and i32 %28, %30
  %32 = icmp ne i32 %31, 0
  br label %33

33:                                               ; preds = %23, %19
  %34 = phi i1 [ false, %19 ], [ %32, %23 ]
  br i1 %34, label %35, label %67

35:                                               ; preds = %33
  %36 = load ptr, ptr %6, align 1
  %37 = getelementptr inbounds ptr, ptr %36, i16 0
  %38 = load ptr, ptr %37, align 1
  %39 = load i16, ptr %10, align 1
  %40 = getelementptr inbounds float, ptr %38, i16 %39
  %41 = load float, ptr %40, align 1
  store float %41, ptr %13, align 1
  store i16 1, ptr %9, align 1
  br label %42

42:                                               ; preds = %56, %35
  %43 = load i16, ptr %9, align 1
  %44 = load i16, ptr %7, align 1
  %45 = icmp slt i16 %43, %44
  br i1 %45, label %46, label %59

46:                                               ; preds = %42
  %47 = load ptr, ptr %6, align 1
  %48 = load i16, ptr %9, align 1
  %49 = getelementptr inbounds ptr, ptr %47, i16 %48
  %50 = load ptr, ptr %49, align 1
  %51 = load i16, ptr %10, align 1
  %52 = getelementptr inbounds float, ptr %50, i16 %51
  %53 = load float, ptr %52, align 1
  %54 = load float, ptr %13, align 1
  %55 = fadd float %54, %53
  store float %55, ptr %13, align 1
  br label %56

56:                                               ; preds = %46
  %57 = load i16, ptr %9, align 1
  %58 = add nsw i16 %57, 1
  store i16 %58, ptr %9, align 1
  br label %42, !llvm.loop !2

59:                                               ; preds = %42
  %60 = load float, ptr %13, align 1
  %61 = load ptr, ptr %5, align 1
  %62 = load i16, ptr %10, align 1
  %63 = getelementptr inbounds float, ptr %61, i16 %62
  store float %60, ptr %63, align 1
  br label %64

64:                                               ; preds = %59
  %65 = load i16, ptr %10, align 1
  %66 = add nsw i16 %65, 1
  store i16 %66, ptr %10, align 1
  br label %19, !llvm.loop !4

67:                                               ; preds = %33
  br label %68

68:                                               ; preds = %198, %67
  %69 = load i16, ptr %10, align 1
  %70 = load i16, ptr %8, align 1
  %71 = load i16, ptr %11, align 1
  %72 = mul nsw i16 4, %71
  %73 = sub nsw i16 %72, 1
  %74 = sub nsw i16 %70, %73
  %75 = icmp slt i16 %69, %74
  br i1 %75, label %76, label %203

76:                                               ; preds = %68
  %77 = load ptr, ptr %6, align 1
  %78 = getelementptr inbounds ptr, ptr %77, i16 0
  %79 = load ptr, ptr %78, align 1
  %80 = load i16, ptr %10, align 1
  %81 = getelementptr inbounds float, ptr %79, i16 %80
  %82 = load i16, ptr %11, align 1
  %83 = mul nsw i16 0, %82
  %84 = getelementptr inbounds float, ptr %81, i16 %83
  %85 = load <4 x float>, ptr %84, align 16
  store <4 x float> %85, ptr %14, align 16
  %86 = load ptr, ptr %6, align 1
  %87 = getelementptr inbounds ptr, ptr %86, i16 0
  %88 = load ptr, ptr %87, align 1
  %89 = load i16, ptr %10, align 1
  %90 = getelementptr inbounds float, ptr %88, i16 %89
  %91 = load i16, ptr %11, align 1
  %92 = mul nsw i16 1, %91
  %93 = getelementptr inbounds float, ptr %90, i16 %92
  %94 = load <4 x float>, ptr %93, align 16
  store <4 x float> %94, ptr %15, align 16
  %95 = load ptr, ptr %6, align 1
  %96 = getelementptr inbounds ptr, ptr %95, i16 0
  %97 = load ptr, ptr %96, align 1
  %98 = load i16, ptr %10, align 1
  %99 = getelementptr inbounds float, ptr %97, i16 %98
  %100 = load i16, ptr %11, align 1
  %101 = mul nsw i16 2, %100
  %102 = getelementptr inbounds float, ptr %99, i16 %101
  %103 = load <4 x float>, ptr %102, align 16
  store <4 x float> %103, ptr %16, align 16
  %104 = load ptr, ptr %6, align 1
  %105 = getelementptr inbounds ptr, ptr %104, i16 0
  %106 = load ptr, ptr %105, align 1
  %107 = load i16, ptr %10, align 1
  %108 = getelementptr inbounds float, ptr %106, i16 %107
  %109 = load i16, ptr %11, align 1
  %110 = mul nsw i16 3, %109
  %111 = getelementptr inbounds float, ptr %108, i16 %110
  %112 = load <4 x float>, ptr %111, align 16
  store <4 x float> %112, ptr %17, align 16
  store i16 1, ptr %9, align 1
  br label %113

113:                                              ; preds = %166, %76
  %114 = load i16, ptr %9, align 1
  %115 = load i16, ptr %7, align 1
  %116 = icmp slt i16 %114, %115
  br i1 %116, label %117, label %169

117:                                              ; preds = %113
  %118 = load ptr, ptr %6, align 1
  %119 = load i16, ptr %9, align 1
  %120 = getelementptr inbounds ptr, ptr %118, i16 %119
  %121 = load ptr, ptr %120, align 1
  %122 = load i16, ptr %10, align 1
  %123 = getelementptr inbounds float, ptr %121, i16 %122
  %124 = load i16, ptr %11, align 1
  %125 = mul nsw i16 0, %124
  %126 = getelementptr inbounds float, ptr %123, i16 %125
  %127 = load <4 x float>, ptr %126, align 16
  %128 = load <4 x float>, ptr %14, align 16
  %129 = fadd <4 x float> %128, %127
  store <4 x float> %129, ptr %14, align 16
  %130 = load ptr, ptr %6, align 1
  %131 = load i16, ptr %9, align 1
  %132 = getelementptr inbounds ptr, ptr %130, i16 %131
  %133 = load ptr, ptr %132, align 1
  %134 = load i16, ptr %10, align 1
  %135 = getelementptr inbounds float, ptr %133, i16 %134
  %136 = load i16, ptr %11, align 1
  %137 = mul nsw i16 1, %136
  %138 = getelementptr inbounds float, ptr %135, i16 %137
  %139 = load <4 x float>, ptr %138, align 16
  %140 = load <4 x float>, ptr %15, align 16
  %141 = fadd <4 x float> %140, %139
  store <4 x float> %141, ptr %15, align 16
  %142 = load ptr, ptr %6, align 1
  %143 = load i16, ptr %9, align 1
  %144 = getelementptr inbounds ptr, ptr %142, i16 %143
  %145 = load ptr, ptr %144, align 1
  %146 = load i16, ptr %10, align 1
  %147 = getelementptr inbounds float, ptr %145, i16 %146
  %148 = load i16, ptr %11, align 1
  %149 = mul nsw i16 2, %148
  %150 = getelementptr inbounds float, ptr %147, i16 %149
  %151 = load <4 x float>, ptr %150, align 16
  %152 = load <4 x float>, ptr %16, align 16
  %153 = fadd <4 x float> %152, %151
  store <4 x float> %153, ptr %16, align 16
  %154 = load ptr, ptr %6, align 1
  %155 = load i16, ptr %9, align 1
  %156 = getelementptr inbounds ptr, ptr %154, i16 %155
  %157 = load ptr, ptr %156, align 1
  %158 = load i16, ptr %10, align 1
  %159 = getelementptr inbounds float, ptr %157, i16 %158
  %160 = load i16, ptr %11, align 1
  %161 = mul nsw i16 3, %160
  %162 = getelementptr inbounds float, ptr %159, i16 %161
  %163 = load <4 x float>, ptr %162, align 16
  %164 = load <4 x float>, ptr %17, align 16
  %165 = fadd <4 x float> %164, %163
  store <4 x float> %165, ptr %17, align 16
  br label %166

166:                                              ; preds = %117
  %167 = load i16, ptr %9, align 1
  %168 = add nsw i16 %167, 1
  store i16 %168, ptr %9, align 1
  br label %113, !llvm.loop !5

169:                                              ; preds = %113
  %170 = load <4 x float>, ptr %14, align 16
  %171 = load ptr, ptr %5, align 1
  %172 = load i16, ptr %10, align 1
  %173 = getelementptr inbounds float, ptr %171, i16 %172
  %174 = load i16, ptr %11, align 1
  %175 = mul nsw i16 0, %174
  %176 = getelementptr inbounds float, ptr %173, i16 %175
  store <4 x float> %170, ptr %176, align 16
  %177 = load <4 x float>, ptr %15, align 16
  %178 = load ptr, ptr %5, align 1
  %179 = load i16, ptr %10, align 1
  %180 = getelementptr inbounds float, ptr %178, i16 %179
  %181 = load i16, ptr %11, align 1
  %182 = mul nsw i16 1, %181
  %183 = getelementptr inbounds float, ptr %180, i16 %182
  store <4 x float> %177, ptr %183, align 16
  %184 = load <4 x float>, ptr %16, align 16
  %185 = load ptr, ptr %5, align 1
  %186 = load i16, ptr %10, align 1
  %187 = getelementptr inbounds float, ptr %185, i16 %186
  %188 = load i16, ptr %11, align 1
  %189 = mul nsw i16 2, %188
  %190 = getelementptr inbounds float, ptr %187, i16 %189
  store <4 x float> %184, ptr %190, align 16
  %191 = load <4 x float>, ptr %17, align 16
  %192 = load ptr, ptr %5, align 1
  %193 = load i16, ptr %10, align 1
  %194 = getelementptr inbounds float, ptr %192, i16 %193
  %195 = load i16, ptr %11, align 1
  %196 = mul nsw i16 3, %195
  %197 = getelementptr inbounds float, ptr %194, i16 %196
  store <4 x float> %191, ptr %197, align 16
  br label %198

198:                                              ; preds = %169
  %199 = load i16, ptr %11, align 1
  %200 = mul nsw i16 4, %199
  %201 = load i16, ptr %10, align 1
  %202 = add nsw i16 %201, %200
  store i16 %202, ptr %10, align 1
  br label %68, !llvm.loop !6

203:                                              ; preds = %68
  br label %204

204:                                              ; preds = %237, %203
  %205 = load i16, ptr %10, align 1
  %206 = load i16, ptr %8, align 1
  %207 = icmp slt i16 %205, %206
  br i1 %207, label %208, label %240

208:                                              ; preds = %204
  %209 = load ptr, ptr %6, align 1
  %210 = getelementptr inbounds ptr, ptr %209, i16 0
  %211 = load ptr, ptr %210, align 1
  %212 = load i16, ptr %10, align 1
  %213 = getelementptr inbounds float, ptr %211, i16 %212
  %214 = load float, ptr %213, align 1
  store float %214, ptr %18, align 1
  store i16 1, ptr %9, align 1
  br label %215

215:                                              ; preds = %229, %208
  %216 = load i16, ptr %9, align 1
  %217 = load i16, ptr %7, align 1
  %218 = icmp slt i16 %216, %217
  br i1 %218, label %219, label %232

219:                                              ; preds = %215
  %220 = load ptr, ptr %6, align 1
  %221 = load i16, ptr %9, align 1
  %222 = getelementptr inbounds ptr, ptr %220, i16 %221
  %223 = load ptr, ptr %222, align 1
  %224 = load i16, ptr %10, align 1
  %225 = getelementptr inbounds float, ptr %223, i16 %224
  %226 = load float, ptr %225, align 1
  %227 = load float, ptr %18, align 1
  %228 = fadd float %227, %226
  store float %228, ptr %18, align 1
  br label %229

229:                                              ; preds = %219
  %230 = load i16, ptr %9, align 1
  %231 = add nsw i16 %230, 1
  store i16 %231, ptr %9, align 1
  br label %215, !llvm.loop !7

232:                                              ; preds = %215
  %233 = load float, ptr %18, align 1
  %234 = load ptr, ptr %5, align 1
  %235 = load i16, ptr %10, align 1
  %236 = getelementptr inbounds float, ptr %234, i16 %235
  store float %233, ptr %236, align 1
  br label %237

237:                                              ; preds = %232
  %238 = load i16, ptr %10, align 1
  %239 = add nsw i16 %238, 1
  store i16 %239, ptr %10, align 1
  br label %204, !llvm.loop !8

240:                                              ; preds = %204
  ret void
}

; Function Attrs: noinline nounwind optnone
define dso_local i16 @main() #0 {
  %1 = alloca i16, align 1
  %2 = alloca i16, align 1
  %3 = alloca ptr, align 1
  %4 = alloca [2 x ptr], align 1
  %5 = alloca ptr, align 1
  %6 = alloca float, align 1
  store i16 0, ptr %1, align 1
  store ptr @buffer, ptr %5, align 1
  %7 = and i32 sub (i32 0, i32 ptrtoint (ptr @buffer to i32)), 63
  %8 = load ptr, ptr %5, align 1
  %9 = trunc i32 %7 to i16
  %10 = getelementptr inbounds i8, ptr %8, i16 %9
  store ptr %10, ptr %5, align 1
  %11 = load ptr, ptr %5, align 1
  store ptr %11, ptr %3, align 1
  %12 = load ptr, ptr %3, align 1
  %13 = getelementptr inbounds float, ptr %12, i16 16
  %14 = getelementptr inbounds [2 x ptr], ptr %4, i16 0, i16 0
  store ptr %13, ptr %14, align 1
  %15 = load ptr, ptr %3, align 1
  %16 = getelementptr inbounds float, ptr %15, i16 32
  %17 = getelementptr inbounds [2 x ptr], ptr %4, i16 0, i16 1
  store ptr %16, ptr %17, align 1
  store i16 0, ptr %2, align 1
  br label %18

18:                                               ; preds = %40, %0
  %19 = load i16, ptr %2, align 1
  %20 = icmp slt i16 %19, 16
  br i1 %20, label %21, label %43

21:                                               ; preds = %18
  %22 = load i16, ptr %2, align 1
  %23 = sitofp i16 %22 to float
  %24 = load i16, ptr %2, align 1
  %25 = sitofp i16 %24 to float
  %26 = call float @llvm.fmuladd.f32(float 1.100000e+01, float %25, float %23)
  %27 = getelementptr inbounds [2 x ptr], ptr %4, i16 0, i16 0
  %28 = load ptr, ptr %27, align 1
  %29 = load i16, ptr %2, align 1
  %30 = getelementptr inbounds float, ptr %28, i16 %29
  store float %26, ptr %30, align 1
  %31 = load i16, ptr %2, align 1
  %32 = sitofp i16 %31 to float
  %33 = load i16, ptr %2, align 1
  %34 = sitofp i16 %33 to float
  %35 = call float @llvm.fmuladd.f32(float 1.200000e+01, float %34, float %32)
  %36 = getelementptr inbounds [2 x ptr], ptr %4, i16 0, i16 1
  %37 = load ptr, ptr %36, align 1
  %38 = load i16, ptr %2, align 1
  %39 = getelementptr inbounds float, ptr %37, i16 %38
  store float %35, ptr %39, align 1
  br label %40

40:                                               ; preds = %21
  %41 = load i16, ptr %2, align 1
  %42 = add nsw i16 %41, 1
  store i16 %42, ptr %2, align 1
  br label %18, !llvm.loop !9

43:                                               ; preds = %18
  %44 = load ptr, ptr %3, align 1
  %45 = getelementptr inbounds [2 x ptr], ptr %4, i16 0, i16 0
  call void @foo(ptr noundef %44, ptr noundef %45, i16 noundef 2, i16 noundef 16)
  store i16 0, ptr %2, align 1
  br label %46

46:                                               ; preds = %69, %43
  %47 = load i16, ptr %2, align 1
  %48 = icmp slt i16 %47, 16
  br i1 %48, label %49, label %72

49:                                               ; preds = %46
  %50 = load i16, ptr %2, align 1
  %51 = sitofp i16 %50 to float
  %52 = load i16, ptr %2, align 1
  %53 = sitofp i16 %52 to float
  %54 = call float @llvm.fmuladd.f32(float 1.100000e+01, float %53, float %51)
  %55 = load i16, ptr %2, align 1
  %56 = sitofp i16 %55 to float
  %57 = fadd float %54, %56
  %58 = load i16, ptr %2, align 1
  %59 = sitofp i16 %58 to float
  %60 = call float @llvm.fmuladd.f32(float 1.200000e+01, float %59, float %57)
  store float %60, ptr %6, align 1
  %61 = load ptr, ptr %3, align 1
  %62 = load i16, ptr %2, align 1
  %63 = getelementptr inbounds float, ptr %61, i16 %62
  %64 = load float, ptr %63, align 1
  %65 = load float, ptr %6, align 1
  %66 = fcmp une float %64, %65
  br i1 %66, label %67, label %68

67:                                               ; preds = %49
  call void @abort() #3
  unreachable

68:                                               ; preds = %49
  br label %69

69:                                               ; preds = %68
  %70 = load i16, ptr %2, align 1
  %71 = add nsw i16 %70, 1
  store i16 %71, ptr %2, align 1
  br label %46, !llvm.loop !10

72:                                               ; preds = %46
  ret i16 0
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.fmuladd.f32(float, float, float) #1

; Function Attrs: noreturn nounwind
declare dso_local void @abort() #2

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #3 = { noreturn nounwind }

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

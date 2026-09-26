; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: noinline nounwind optnone
define dso_local void @newton_step(ptr noundef %0, ptr noundef %1) #0 {
  %3 = alloca ptr, align 1
  %4 = alloca ptr, align 1
  %5 = alloca i16, align 1
  %6 = alloca i16, align 1
  %7 = alloca i16, align 1
  %8 = alloca i16, align 1
  %9 = alloca i16, align 1
  %10 = alloca i16, align 1
  %11 = alloca i16, align 1
  %12 = alloca i16, align 1
  %13 = alloca i16, align 1
  %14 = alloca i16, align 1
  %15 = alloca i32, align 1
  %16 = alloca i32, align 1
  %17 = alloca i32, align 1
  %18 = alloca i32, align 1
  %19 = alloca i32, align 1
  %20 = alloca i32, align 1
  %21 = alloca i32, align 1
  store ptr %0, ptr %3, align 1
  store ptr %1, ptr %4, align 1
  %22 = load ptr, ptr %3, align 1
  %23 = load i16, ptr %22, align 1
  store i16 %23, ptr %5, align 1
  %24 = load ptr, ptr %4, align 1
  %25 = load i16, ptr %24, align 1
  store i16 %25, ptr %6, align 1
  %26 = load i16, ptr %5, align 1
  %27 = sext i16 %26 to i32
  %28 = load i16, ptr %5, align 1
  %29 = sext i16 %28 to i32
  %30 = mul nsw i32 %27, %29
  %31 = load i16, ptr %6, align 1
  %32 = sext i16 %31 to i32
  %33 = load i16, ptr %6, align 1
  %34 = sext i16 %33 to i32
  %35 = mul nsw i32 %32, %34
  %36 = sub nsw i32 %30, %35
  %37 = ashr i32 %36, 8
  %38 = trunc i32 %37 to i16
  store i16 %38, ptr %7, align 1
  %39 = load i16, ptr %5, align 1
  %40 = sext i16 %39 to i32
  %41 = load i16, ptr %6, align 1
  %42 = sext i16 %41 to i32
  %43 = mul nsw i32 %40, %42
  %44 = ashr i32 %43, 7
  %45 = trunc i32 %44 to i16
  store i16 %45, ptr %8, align 1
  %46 = load i16, ptr %7, align 1
  %47 = sext i16 %46 to i32
  %48 = load i16, ptr %5, align 1
  %49 = sext i16 %48 to i32
  %50 = mul nsw i32 %47, %49
  %51 = load i16, ptr %8, align 1
  %52 = sext i16 %51 to i32
  %53 = load i16, ptr %6, align 1
  %54 = sext i16 %53 to i32
  %55 = mul nsw i32 %52, %54
  %56 = sub nsw i32 %50, %55
  %57 = ashr i32 %56, 8
  %58 = trunc i32 %57 to i16
  store i16 %58, ptr %9, align 1
  %59 = load i16, ptr %7, align 1
  %60 = sext i16 %59 to i32
  %61 = load i16, ptr %6, align 1
  %62 = sext i16 %61 to i32
  %63 = mul nsw i32 %60, %62
  %64 = load i16, ptr %8, align 1
  %65 = sext i16 %64 to i32
  %66 = load i16, ptr %5, align 1
  %67 = sext i16 %66 to i32
  %68 = mul nsw i32 %65, %67
  %69 = add nsw i32 %63, %68
  %70 = ashr i32 %69, 8
  %71 = trunc i32 %70 to i16
  store i16 %71, ptr %10, align 1
  %72 = load i16, ptr %9, align 1
  %73 = sub nsw i16 %72, 256
  store i16 %73, ptr %11, align 1
  %74 = load i16, ptr %10, align 1
  store i16 %74, ptr %12, align 1
  %75 = load i16, ptr %7, align 1
  %76 = sext i16 %75 to i32
  %77 = mul nsw i32 3, %76
  %78 = trunc i32 %77 to i16
  store i16 %78, ptr %13, align 1
  %79 = load i16, ptr %8, align 1
  %80 = sext i16 %79 to i32
  %81 = mul nsw i32 3, %80
  %82 = trunc i32 %81 to i16
  store i16 %82, ptr %14, align 1
  %83 = load i16, ptr %11, align 1
  %84 = sext i16 %83 to i32
  %85 = ashr i32 %84, 1
  store i32 %85, ptr %15, align 1
  %86 = load i16, ptr %12, align 1
  %87 = sext i16 %86 to i32
  %88 = ashr i32 %87, 1
  store i32 %88, ptr %16, align 1
  %89 = load i16, ptr %13, align 1
  %90 = sext i16 %89 to i32
  %91 = ashr i32 %90, 1
  store i32 %91, ptr %17, align 1
  %92 = load i16, ptr %14, align 1
  %93 = sext i16 %92 to i32
  %94 = ashr i32 %93, 1
  store i32 %94, ptr %18, align 1
  %95 = load i32, ptr %17, align 1
  %96 = load i32, ptr %17, align 1
  %97 = mul nsw i32 %95, %96
  %98 = load i32, ptr %18, align 1
  %99 = load i32, ptr %18, align 1
  %100 = mul nsw i32 %98, %99
  %101 = add nsw i32 %97, %100
  store i32 %101, ptr %19, align 1
  %102 = load i32, ptr %19, align 1
  %103 = icmp eq i32 %102, 0
  br i1 %103, label %104, label %105

104:                                              ; preds = %2
  br label %152

105:                                              ; preds = %2
  %106 = load i32, ptr %15, align 1
  %107 = load i32, ptr %17, align 1
  %108 = mul nsw i32 %106, %107
  %109 = load i32, ptr %16, align 1
  %110 = load i32, ptr %18, align 1
  %111 = mul nsw i32 %109, %110
  %112 = add nsw i32 %108, %111
  %113 = shl i32 %112, 8
  %114 = load i32, ptr %19, align 1
  %115 = sdiv i32 %113, %114
  store i32 %115, ptr %20, align 1
  %116 = load i32, ptr %16, align 1
  %117 = load i32, ptr %17, align 1
  %118 = mul nsw i32 %116, %117
  %119 = load i32, ptr %15, align 1
  %120 = load i32, ptr %18, align 1
  %121 = mul nsw i32 %119, %120
  %122 = sub nsw i32 %118, %121
  %123 = shl i32 %122, 8
  %124 = load i32, ptr %19, align 1
  %125 = sdiv i32 %123, %124
  store i32 %125, ptr %21, align 1
  %126 = load i32, ptr %20, align 1
  %127 = icmp sgt i32 %126, 512
  br i1 %127, label %128, label %129

128:                                              ; preds = %105
  store i32 512, ptr %20, align 1
  br label %129

129:                                              ; preds = %128, %105
  %130 = load i32, ptr %20, align 1
  %131 = icmp slt i32 %130, -512
  br i1 %131, label %132, label %133

132:                                              ; preds = %129
  store i32 -512, ptr %20, align 1
  br label %133

133:                                              ; preds = %132, %129
  %134 = load i32, ptr %21, align 1
  %135 = icmp sgt i32 %134, 512
  br i1 %135, label %136, label %137

136:                                              ; preds = %133
  store i32 512, ptr %21, align 1
  br label %137

137:                                              ; preds = %136, %133
  %138 = load i32, ptr %21, align 1
  %139 = icmp slt i32 %138, -512
  br i1 %139, label %140, label %141

140:                                              ; preds = %137
  store i32 -512, ptr %21, align 1
  br label %141

141:                                              ; preds = %140, %137
  %142 = load i16, ptr %5, align 1
  %143 = load i32, ptr %20, align 1
  %144 = trunc i32 %143 to i16
  %145 = sub nsw i16 %142, %144
  %146 = load ptr, ptr %3, align 1
  store i16 %145, ptr %146, align 1
  %147 = load i16, ptr %6, align 1
  %148 = load i32, ptr %21, align 1
  %149 = trunc i32 %148 to i16
  %150 = sub nsw i16 %147, %149
  %151 = load ptr, ptr %4, align 1
  store i16 %150, ptr %151, align 1
  br label %152

152:                                              ; preds = %141, %104
  ret void
}

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (/home/will/llvm-mos 742d554bf08042b8df93d791c335260fadd16643)"}

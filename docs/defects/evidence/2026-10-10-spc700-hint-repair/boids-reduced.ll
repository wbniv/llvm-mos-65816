target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

define i16 @main(ptr %0) {
  br label %2

2:                                                ; preds = %2, %1
  %3 = load ptr, ptr %0, align 1
  tail call void %3(ptr null, ptr null)
  br label %2
}

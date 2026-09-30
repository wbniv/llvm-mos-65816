target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

define i16 @main() {
  br label %1

1:                                                ; preds = %0
  call void (ptr, ptr, ...) @mini_sprintf(ptr null, ptr null, i16 0, i16 0)
  ret i16 0
}

declare void @mini_sprintf(ptr, ptr, ...)

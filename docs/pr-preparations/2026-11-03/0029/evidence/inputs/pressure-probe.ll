target triple = "mos"
@input = external global [16 x i8]
@output = external global [32 x i8]
define void @pressure_probe() "nonreentrant" {
entry:
  %v0 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 0), align 1
  %v1 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 1), align 1
  %v2 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 2), align 1
  %v3 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 3), align 1
  %v4 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 4), align 1
  %v5 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 5), align 1
  %v6 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 6), align 1
  %v7 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 7), align 1
  %v8 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 8), align 1
  %v9 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 9), align 1
  %v10 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 10), align 1
  %v11 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 11), align 1
  %v12 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 12), align 1
  %v13 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 13), align 1
  %v14 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 14), align 1
  %v15 = load volatile i8, ptr getelementptr ([16 x i8], ptr @input, i16 0, i16 15), align 1
  store volatile i8 %v5, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 0), align 1
  store volatile i8 %v0, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 1), align 1
  store volatile i8 %v15, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 2), align 1
  store volatile i8 %v3, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 3), align 1
  store volatile i8 %v9, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 4), align 1
  store volatile i8 %v1, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 5), align 1
  store volatile i8 %v14, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 6), align 1
  store volatile i8 %v6, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 7), align 1
  store volatile i8 %v12, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 8), align 1
  store volatile i8 %v2, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 9), align 1
  store volatile i8 %v10, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 10), align 1
  store volatile i8 %v4, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 11), align 1
  store volatile i8 %v13, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 12), align 1
  store volatile i8 %v8, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 13), align 1
  store volatile i8 %v7, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 14), align 1
  store volatile i8 %v11, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 15), align 1
  store volatile i8 %v11, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 16), align 1
  store volatile i8 %v7, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 17), align 1
  store volatile i8 %v8, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 18), align 1
  store volatile i8 %v13, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 19), align 1
  store volatile i8 %v4, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 20), align 1
  store volatile i8 %v10, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 21), align 1
  store volatile i8 %v2, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 22), align 1
  store volatile i8 %v12, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 23), align 1
  store volatile i8 %v6, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 24), align 1
  store volatile i8 %v14, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 25), align 1
  store volatile i8 %v1, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 26), align 1
  store volatile i8 %v9, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 27), align 1
  store volatile i8 %v3, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 28), align 1
  store volatile i8 %v15, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 29), align 1
  store volatile i8 %v0, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 30), align 1
  store volatile i8 %v5, ptr getelementptr ([32 x i8], ptr @output, i16 0, i16 31), align 1
  ret void
}

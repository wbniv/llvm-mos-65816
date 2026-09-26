; ModuleID = '<bc file>'
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@bitboard64_state.0 = external global i64

define fastcc i16 @bitboard64_step(i64 %0, i64 %1, i8 %2) {
  %4 = load i64, ptr null, align 8
  %5 = tail call i64 @llvm.ctpop.i64(i64 %0)
  %6 = trunc i64 %0 to i8
  %7 = add i8 7, 0
  %8 = mul i8 %2, 7
  %9 = and i8 %8, 63
  %10 = shl i64 1, %0
  %11 = zext i8 %9 to i64
  store volatile i64 %11, ptr null, align 8
  ret i16 0
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctpop.i64(i64) #0

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.cttz.i64(i64, i1 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctlz.i64(i64, i1 immarg) #1

attributes #0 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

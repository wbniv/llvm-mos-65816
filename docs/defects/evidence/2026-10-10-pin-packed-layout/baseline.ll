; ModuleID = '/home/will/llvm-mos-65816/examples/snes/corpus/arith.c'
source_filename = "/home/will/llvm-mos-65816/examples/snes/corpus/arith.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@a8 = dso_local global i8 -16, align 1
@b8 = dso_local global i8 15, align 1
@a16 = dso_local global i16 1000, align 1
@b16 = dso_local global i16 7, align 1
@a32 = dso_local global i32 100000, align 1
@b32 = dso_local global i32 3, align 1
@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
entry:
  %0 = load volatile i8, ptr @a8, align 1, !tbaa !7
  %conv = zext i8 %0 to i16
  %1 = load volatile i8, ptr @b8, align 1, !tbaa !7
  %conv1 = zext i8 %1 to i16
  %add = add nuw nsw i16 %conv1, %conv
  %2 = load volatile i8, ptr @a8, align 1, !tbaa !7
  %3 = load volatile i8, ptr @b8, align 1, !tbaa !7
  %and34 = and i8 %3, %2
  %and = zext i8 %and34 to i16
  %add5 = add nuw nsw i16 %add, %and
  %4 = load volatile i8, ptr @a8, align 1, !tbaa !7
  %5 = load volatile i8, ptr @b8, align 1, !tbaa !7
  %or35 = or i8 %5, %4
  %or = zext i8 %or35 to i16
  %add8 = add nuw nsw i16 %add5, %or
  %6 = load volatile i8, ptr @a8, align 1, !tbaa !7
  %7 = load volatile i8, ptr @b8, align 1, !tbaa !7
  %xor36 = xor i8 %7, %6
  %xor = zext i8 %xor36 to i16
  %add11 = add nuw nsw i16 %add8, %xor
  %8 = load volatile i16, ptr @a16, align 1, !tbaa !8
  %9 = load volatile i16, ptr @b16, align 1, !tbaa !8
  %mul = mul i16 %9, %8
  %add12 = add i16 %add11, %mul
  %10 = load volatile i16, ptr @a16, align 1, !tbaa !8
  %11 = load volatile i16, ptr @b16, align 1, !tbaa !8
  %div = udiv i16 %10, %11
  %add13 = add i16 %add12, %div
  %12 = load volatile i16, ptr @a16, align 1, !tbaa !8
  %13 = load volatile i16, ptr @b16, align 1, !tbaa !8
  %rem = urem i16 %12, %13
  %add14 = add i16 %add13, %rem
  %14 = load volatile i32, ptr @a32, align 1, !tbaa !9
  %15 = load volatile i32, ptr @b32, align 1, !tbaa !9
  %div15 = udiv i32 %14, %15
  %conv16 = trunc i32 %div15 to i16
  %add17 = add i16 %add14, %conv16
  %16 = load volatile i32, ptr @a32, align 1, !tbaa !9
  %17 = load volatile i32, ptr @b32, align 1, !tbaa !9
  %rem18 = urem i32 %16, %17
  %conv19 = trunc i32 %rem18 to i16
  %add20 = add i16 %add17, %conv19
  %18 = load volatile i16, ptr @a16, align 1, !tbaa !8
  %shl = shl i16 %18, 1
  %add21 = add i16 %add20, %shl
  %19 = load volatile i16, ptr @a16, align 1, !tbaa !8
  %shr = lshr i16 %19, 2
  %add22 = add i16 %add21, %shr
  store volatile i16 %add22, ptr @corpus_result, align 1, !tbaa !8
  br label %for.cond

for.cond:                                         ; preds = %for.cond, %entry
  tail call void asm sideeffect "wai", ""() #1, !srcloc !11
  br label %for.cond
}

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }
attributes #1 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (/home/will/llvm-mos-65816/.scratch/upstream-pin-2026-10-09/source/clang f24948c7d1a4b9f162d4d0192ccceecab1e441ff)"}
!2 = !{!3, !4, i64 0}
!3 = !{!"__libc_errno", !4, i64 0}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!5, !5, i64 0}
!8 = !{!4, !4, i64 0}
!9 = !{!10, !10, i64 0}
!10 = !{!"long", !5, i64 0}
!11 = !{i64 2556}

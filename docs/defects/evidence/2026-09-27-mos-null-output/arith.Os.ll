; ModuleID = '/home/will/llvm-mos-65816/.scratch/carry-pr/inputs/arith.c'
source_filename = "/home/will/llvm-mos-65816/.scratch/carry-pr/inputs/arith.c"
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
  %1 = load volatile i8, ptr @a8, align 1, !tbaa !6
  %2 = zext i8 %1 to i16
  %3 = load volatile i8, ptr @b8, align 1, !tbaa !6
  %4 = zext i8 %3 to i16
  %5 = add nuw nsw i16 %4, %2
  %6 = load volatile i8, ptr @a8, align 1, !tbaa !6
  %7 = load volatile i8, ptr @b8, align 1, !tbaa !6
  %8 = and i8 %7, %6
  %9 = zext i8 %8 to i16
  %10 = add nuw nsw i16 %5, %9
  %11 = load volatile i8, ptr @a8, align 1, !tbaa !6
  %12 = load volatile i8, ptr @b8, align 1, !tbaa !6
  %13 = or i8 %12, %11
  %14 = zext i8 %13 to i16
  %15 = add nuw nsw i16 %10, %14
  %16 = load volatile i8, ptr @a8, align 1, !tbaa !6
  %17 = load volatile i8, ptr @b8, align 1, !tbaa !6
  %18 = xor i8 %17, %16
  %19 = zext i8 %18 to i16
  %20 = add nuw nsw i16 %15, %19
  %21 = load volatile i16, ptr @a16, align 1, !tbaa !2
  %22 = load volatile i16, ptr @b16, align 1, !tbaa !2
  %23 = mul i16 %22, %21
  %24 = add i16 %20, %23
  %25 = load volatile i16, ptr @a16, align 1, !tbaa !2
  %26 = load volatile i16, ptr @b16, align 1, !tbaa !2
  %27 = udiv i16 %25, %26
  %28 = add i16 %24, %27
  %29 = load volatile i16, ptr @a16, align 1, !tbaa !2
  %30 = load volatile i16, ptr @b16, align 1, !tbaa !2
  %31 = urem i16 %29, %30
  %32 = add i16 %28, %31
  %33 = load volatile i32, ptr @a32, align 1, !tbaa !7
  %34 = load volatile i32, ptr @b32, align 1, !tbaa !7
  %35 = udiv i32 %33, %34
  %36 = trunc i32 %35 to i16
  %37 = add i16 %32, %36
  %38 = load volatile i32, ptr @a32, align 1, !tbaa !7
  %39 = load volatile i32, ptr @b32, align 1, !tbaa !7
  %40 = urem i32 %38, %39
  %41 = trunc i32 %40 to i16
  %42 = add i16 %37, %41
  %43 = load volatile i16, ptr @a16, align 1, !tbaa !2
  %44 = shl i16 %43, 1
  %45 = add i16 %42, %44
  %46 = load volatile i16, ptr @a16, align 1, !tbaa !2
  %47 = lshr i16 %46, 2
  %48 = add i16 %45, %47
  store volatile i16 %48, ptr @corpus_result, align 1, !tbaa !2
  br label %49

49:                                               ; preds = %49, %0
  tail call void asm sideeffect "", ""() #1, !srcloc !9
  br label %49
}

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mos6502" }
attributes #1 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (/upstream 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!4, !4, i64 0}
!7 = !{!8, !8, i64 0}
!8 = !{!"long", !4, i64 0}
!9 = !{i64 1141}

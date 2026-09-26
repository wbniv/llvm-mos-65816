; ModuleID = '/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c'
source_filename = "/home/will/llvm-mos-65816/docs/defects/evidence/2026-09-25-coalescing-0015/original/rcundef.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(argmem: readwrite)
define dso_local void @newton_step(ptr noundef captures(none) %0, ptr noundef captures(none) %1) local_unnamed_addr #0 {
  %3 = load i16, ptr %0, align 1, !tbaa !2
  %4 = load i16, ptr %1, align 1, !tbaa !2
  %5 = sext i16 %3 to i32
  %6 = sext i16 %4 to i32
  %7 = add nsw i32 %6, %5
  %8 = sub nsw i32 %5, %6
  %9 = shl nsw i32 %8, 8
  %10 = mul i32 %9, %7
  %11 = ashr i32 %10, 16
  %12 = shl nsw i32 %5, 9
  %13 = mul i32 %12, %6
  %14 = ashr i32 %13, 16
  %15 = trunc nsw i32 %11 to i16
  %16 = mul i16 %15, 3
  %17 = trunc nsw i32 %14 to i16
  %18 = mul i16 %17, 3
  %19 = ashr i16 %16, 1
  %20 = sext i16 %19 to i32
  %21 = ashr i16 %18, 1
  %22 = sext i16 %21 to i32
  %23 = mul nsw i32 %20, %20
  %24 = mul nsw i32 %22, %22
  %25 = add nuw nsw i32 %23, %24
  %26 = icmp eq i32 %25, 0
  br i1 %26, label %67, label %27

27:                                               ; preds = %2
  %28 = mul nsw i32 %11, %6
  %29 = mul nsw i32 %14, %5
  %30 = add nsw i32 %28, %29
  %31 = shl i32 %30, 8
  %32 = ashr i32 %31, 17
  %33 = mul nsw i32 %11, %5
  %34 = mul nsw i32 %14, %6
  %35 = sub nsw i32 %33, %34
  %36 = lshr i32 %35, 8
  %37 = trunc i32 %36 to i16
  %38 = add nsw i16 %37, -256
  %39 = ashr i16 %38, 1
  %40 = sext i16 %39 to i32
  %41 = mul nsw i32 %40, %20
  %42 = mul nsw i32 %32, %22
  %43 = add nsw i32 %41, %42
  %44 = shl i32 %43, 8
  %45 = sdiv i32 %44, %25
  %46 = mul nsw i32 %32, %20
  %47 = mul nsw i32 %40, %22
  %48 = sub nsw i32 %46, %47
  %49 = shl i32 %48, 8
  %50 = sdiv i32 %49, %25
  %51 = icmp sgt i32 %45, 512
  br i1 %51, label %56, label %52

52:                                               ; preds = %27
  %53 = icmp slt i32 %45, -512
  %54 = trunc nsw i32 %45 to i16
  br i1 %53, label %55, label %56

55:                                               ; preds = %52
  br label %56

56:                                               ; preds = %27, %55, %52
  %57 = phi i16 [ -512, %55 ], [ %54, %52 ], [ 512, %27 ]
  %58 = icmp sgt i32 %50, 512
  br i1 %58, label %63, label %59

59:                                               ; preds = %56
  %60 = icmp slt i32 %50, -512
  %61 = trunc nsw i32 %50 to i16
  br i1 %60, label %62, label %63

62:                                               ; preds = %59
  br label %63

63:                                               ; preds = %56, %62, %59
  %64 = phi i16 [ -512, %62 ], [ %61, %59 ], [ 512, %56 ]
  %65 = sub nsw i16 %3, %57
  store i16 %65, ptr %0, align 1, !tbaa !2
  %66 = sub nsw i16 %4, %64
  store i16 %66, ptr %1, align 1, !tbaa !2
  br label %67

67:                                               ; preds = %2, %63
  ret void
}

attributes #0 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(argmem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}

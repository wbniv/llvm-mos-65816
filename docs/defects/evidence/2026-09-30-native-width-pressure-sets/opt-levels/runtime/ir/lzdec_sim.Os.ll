; ModuleID = '/work/examples/snes/corpus/lzdec_sim.c'
source_filename = "/work/examples/snes/corpus/lzdec_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@lzdec_gate_crc.out = internal unnamed_addr global [256 x i8] zeroinitializer, align 1
@LZ_STREAM = internal unnamed_addr constant [56 x i8] c"\10\00\03\02\01\04\02\01\02\03?\04\01\0F\05\0D\02\04\00\0F\05\1E\03\00\01\FB\0F\05/\04\00@\0F@\0F@\0F@\0F@\05\7F \0D@\0D`\0D@\0F@\0F@\0F@\07", align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %12, %0
  %2 = phi i16 [ 0, %0 ], [ %59, %12 ]
  %3 = phi i16 [ 0, %0 ], [ %58, %12 ]
  %4 = icmp samesign ult i16 %2, 55
  br i1 %4, label %7, label %5

5:                                                ; preds = %12, %1
  %6 = phi i16 [ %3, %1 ], [ %58, %12 ]
  br label %66

7:                                                ; preds = %1
  %8 = add nuw nsw i16 %2, 1
  %9 = getelementptr inbounds nuw i8, ptr @LZ_STREAM, i16 %2
  %10 = load i8, ptr %9, align 1, !tbaa !6
  %11 = zext i8 %10 to i16
  br label %14

12:                                               ; preds = %57
  %13 = select i1 %62, i1 %64, i1 false
  br i1 %13, label %1, label %5, !llvm.loop !7

14:                                               ; preds = %57, %7
  %15 = phi i16 [ %8, %7 ], [ %59, %57 ]
  %16 = phi i16 [ %3, %7 ], [ %58, %57 ]
  %17 = phi i8 [ 0, %7 ], [ %60, %57 ]
  %18 = zext nneg i8 %17 to i16
  %19 = shl nuw nsw i16 1, %18
  %20 = and i16 %19, %11
  %21 = icmp eq i16 %20, 0
  br i1 %21, label %49, label %22

22:                                               ; preds = %14
  %23 = getelementptr inbounds nuw i8, ptr @LZ_STREAM, i16 %15
  %24 = getelementptr inbounds nuw i8, ptr %23, i16 1
  %25 = load i8, ptr %24, align 1, !tbaa !6
  %26 = and i8 %25, 15
  %27 = add nuw nsw i8 %26, 3
  %28 = load i8, ptr %23, align 1, !tbaa !6
  %29 = zext i8 %28 to i16
  %30 = zext i8 %25 to i16
  %31 = shl nuw nsw i16 %30, 4
  %32 = and i16 %31, 3840
  %33 = or disjoint i16 %32, %29
  %34 = sub nsw i16 %16, %33
  %35 = getelementptr i8, ptr @lzdec_gate_crc.out, i16 %34
  %36 = getelementptr i8, ptr @lzdec_gate_crc.out, i16 %16
  br label %37

37:                                               ; preds = %37, %22
  %38 = phi i8 [ %45, %37 ], [ 0, %22 ]
  %39 = phi i16 [ %43, %37 ], [ %16, %22 ]
  %40 = zext nneg i8 %38 to i16
  %41 = getelementptr i8, ptr %35, i16 %40
  %42 = load i8, ptr %41, align 1, !tbaa !6
  %43 = add nuw nsw i16 %39, 1
  %44 = getelementptr i8, ptr %36, i16 %40
  store i8 %42, ptr %44, align 1, !tbaa !6
  %45 = add nuw nsw i8 %38, 1
  %46 = icmp samesign ult i8 %45, %27
  %47 = icmp samesign ult i16 %39, 255
  %48 = and i1 %46, %47
  br i1 %48, label %37, label %55, !llvm.loop !9

49:                                               ; preds = %14
  %50 = add nuw nsw i16 %15, 1
  %51 = getelementptr inbounds nuw i8, ptr @LZ_STREAM, i16 %15
  %52 = load i8, ptr %51, align 1, !tbaa !6
  %53 = add nuw nsw i16 %16, 1
  %54 = getelementptr inbounds nuw i8, ptr @lzdec_gate_crc.out, i16 %16
  store i8 %52, ptr %54, align 1, !tbaa !6
  br label %57

55:                                               ; preds = %37
  %56 = add nuw nsw i16 %15, 2
  br label %57

57:                                               ; preds = %55, %49
  %58 = phi i16 [ %53, %49 ], [ %43, %55 ]
  %59 = phi i16 [ %50, %49 ], [ %56, %55 ]
  %60 = add nuw nsw i8 %17, 1
  %61 = icmp samesign ult i8 %17, 7
  %62 = icmp samesign ult i16 %59, 56
  %63 = select i1 %61, i1 %62, i1 false
  %64 = icmp samesign ult i16 %58, 256
  %65 = select i1 %63, i1 %64, i1 false
  br i1 %65, label %14, label %12, !llvm.loop !10

66:                                               ; preds = %5, %66
  %67 = phi i16 [ %74, %66 ], [ 0, %5 ]
  %68 = phi i16 [ %73, %66 ], [ %6, %5 ]
  %69 = getelementptr inbounds nuw i8, ptr @lzdec_gate_crc.out, i16 %67
  %70 = load i8, ptr %69, align 1, !tbaa !6
  %71 = zext i8 %70 to i16
  %72 = tail call i16 @llvm.fshl.i16(i16 %68, i16 %68, i16 1)
  %73 = xor i16 %72, %71
  %74 = add nuw nsw i16 %67, 1
  %75 = icmp eq i16 %74, 256
  br i1 %75, label %76, label %66, !llvm.loop !11

76:                                               ; preds = %66
  store volatile i16 %73, ptr @corpus_result, align 1, !tbaa !2
  br label %77

77:                                               ; preds = %77, %76
  tail call void asm sideeffect "wai", ""() #2, !srcloc !12
  br label %77
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!4, !4, i64 0}
!7 = distinct !{!7, !8}
!8 = !{!"llvm.loop.mustprogress"}
!9 = distinct !{!9, !8}
!10 = distinct !{!10, !8}
!11 = distinct !{!11, !8}
!12 = !{i64 397}

; ModuleID = '/work/examples/snes/corpus/lzdec_sim.c'
source_filename = "/work/examples/snes/corpus/lzdec_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@lzdec_gate_crc.out = internal unnamed_addr global [256 x i8] zeroinitializer, align 1
@LZ_STREAM = internal unnamed_addr constant [56 x i8] c"\10\00\03\02\01\04\02\01\02\03?\04\01\0F\05\0D\02\04\00\0F\05\1E\03\00\01\FB\0F\05/\04\00@\0F@\0F@\0F@\0F@\05\7F \0D@\0D`\0D@\0F@\0F@\0F@\07", align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %12, %0
  %2 = phi i16 [ 0, %0 ], [ %14, %12 ]
  %3 = phi i16 [ 0, %0 ], [ %15, %12 ]
  %4 = icmp ult i16 %3, 56
  %5 = icmp ult i16 %2, 256
  %6 = select i1 %4, i1 %5, i1 false
  br i1 %6, label %7, label %66

7:                                                ; preds = %1
  %8 = add nuw nsw i16 %3, 1
  %9 = getelementptr inbounds nuw i8, ptr @LZ_STREAM, i16 %3
  %10 = load i8, ptr %9, align 1, !tbaa !6
  %11 = zext i8 %10 to i16
  br label %12

12:                                               ; preds = %62, %7
  %13 = phi i8 [ 0, %7 ], [ %65, %62 ]
  %14 = phi i16 [ %2, %7 ], [ %63, %62 ]
  %15 = phi i16 [ %8, %7 ], [ %64, %62 ]
  %16 = icmp samesign ult i8 %13, 8
  %17 = icmp ult i16 %15, 56
  %18 = select i1 %16, i1 %17, i1 false
  %19 = icmp samesign ult i16 %14, 256
  %20 = select i1 %18, i1 %19, i1 false
  br i1 %20, label %21, label %1, !llvm.loop !7

21:                                               ; preds = %12
  %22 = zext nneg i8 %13 to i16
  %23 = shl nuw nsw i16 1, %22
  %24 = and i16 %23, %11
  %25 = icmp eq i16 %24, 0
  br i1 %25, label %54, label %26

26:                                               ; preds = %21
  %27 = getelementptr inbounds nuw i8, ptr @LZ_STREAM, i16 %15
  %28 = load i8, ptr %27, align 1, !tbaa !6
  %29 = getelementptr inbounds nuw i8, ptr %27, i16 1
  %30 = load i8, ptr %29, align 1, !tbaa !6
  %31 = zext i8 %30 to i16
  %32 = shl nuw nsw i16 %31, 4
  %33 = and i16 %32, 3840
  %34 = zext i8 %28 to i16
  %35 = and i8 %30, 15
  %36 = add nuw nsw i8 %35, 3
  %37 = getelementptr i8, ptr @lzdec_gate_crc.out, i16 %14
  %38 = or disjoint i16 %33, %34
  %39 = sub nsw i16 %14, %38
  %40 = getelementptr i8, ptr @lzdec_gate_crc.out, i16 %39
  br label %41

41:                                               ; preds = %47, %26
  %42 = phi i16 [ %14, %26 ], [ %51, %47 ]
  %43 = phi i8 [ 0, %26 ], [ %53, %47 ]
  %44 = icmp samesign ult i8 %43, %36
  %45 = icmp samesign ult i16 %42, 256
  %46 = select i1 %44, i1 %45, i1 false
  br i1 %46, label %47, label %60

47:                                               ; preds = %41
  %48 = zext nneg i8 %43 to i16
  %49 = getelementptr i8, ptr %40, i16 %48
  %50 = load i8, ptr %49, align 1, !tbaa !6
  %51 = add nuw nsw i16 %42, 1
  %52 = getelementptr i8, ptr %37, i16 %48
  store i8 %50, ptr %52, align 1, !tbaa !6
  %53 = add nuw nsw i8 %43, 1
  br label %41, !llvm.loop !9

54:                                               ; preds = %21
  %55 = add nuw nsw i16 %15, 1
  %56 = getelementptr inbounds nuw i8, ptr @LZ_STREAM, i16 %15
  %57 = load i8, ptr %56, align 1, !tbaa !6
  %58 = add nuw nsw i16 %14, 1
  %59 = getelementptr inbounds nuw i8, ptr @lzdec_gate_crc.out, i16 %14
  store i8 %57, ptr %59, align 1, !tbaa !6
  br label %62

60:                                               ; preds = %41
  %61 = add nuw nsw i16 %15, 2
  br label %62

62:                                               ; preds = %60, %54
  %63 = phi i16 [ %58, %54 ], [ %42, %60 ]
  %64 = phi i16 [ %55, %54 ], [ %61, %60 ]
  %65 = add nuw nsw i8 %13, 1
  br label %12, !llvm.loop !10

66:                                               ; preds = %1, %70
  %67 = phi i16 [ %75, %70 ], [ %2, %1 ]
  %68 = phi i16 [ %76, %70 ], [ 0, %1 ]
  %69 = icmp eq i16 %68, 256
  br i1 %69, label %77, label %70

70:                                               ; preds = %66
  %71 = getelementptr inbounds nuw i8, ptr @lzdec_gate_crc.out, i16 %68
  %72 = load i8, ptr %71, align 1, !tbaa !6
  %73 = zext i8 %72 to i16
  %74 = tail call i16 @llvm.fshl.i16(i16 %67, i16 %67, i16 1)
  %75 = xor i16 %74, %73
  %76 = add nuw nsw i16 %68, 1
  br label %66, !llvm.loop !11

77:                                               ; preds = %66
  store volatile i16 %67, ptr @corpus_result, align 1, !tbaa !2
  br label %78

78:                                               ; preds = %78, %77
  tail call void asm sideeffect "wai", ""() #2, !srcloc !12
  br label %78
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #1

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
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

; ModuleID = '/work/examples/snes/corpus/fenwick_sim.c'
source_filename = "/work/examples/snes/corpus/fenwick_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

%struct.Fenwick = type { [17 x i16], [17 x i16] }

@corpus_result = dso_local global i16 0, align 1
@fenwick_gate_crc.f = internal unnamed_addr global %struct.Fenwick zeroinitializer, align 1

; Function Attrs: minsize noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  br label %1

1:                                                ; preds = %5, %0
  %2 = phi i8 [ %10, %5 ], [ 0, %0 ]
  %3 = phi i16 [ %9, %5 ], [ 0, %0 ]
  %4 = icmp eq i16 %3, 17
  br i1 %4, label %11, label %5

5:                                                ; preds = %1
  %6 = zext nneg i8 %2 to i16
  %7 = getelementptr i8, ptr @fenwick_gate_crc.f, i16 %6
  store i16 0, ptr %7, align 1, !tbaa !2
  %8 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 34), i16 %6
  store i16 0, ptr %8, align 1, !tbaa !2
  %9 = add nuw nsw i16 %3, 1
  %10 = add nuw nsw i8 %2, 2
  br label %1, !llvm.loop !6

11:                                               ; preds = %1, %56
  %12 = phi i16 [ %57, %56 ], [ 0, %1 ]
  %13 = phi i16 [ %61, %56 ], [ 0, %1 ]
  %14 = icmp eq i16 %12, 120
  br i1 %14, label %89, label %15

15:                                               ; preds = %11
  %16 = and i16 %12, 15
  %17 = add nuw nsw i16 %16, 1
  br label %18

18:                                               ; preds = %49, %15
  %19 = phi i8 [ 0, %15 ], [ %51, %49 ]
  %20 = phi i16 [ 1, %15 ], [ %50, %49 ]
  %21 = icmp eq i16 %20, 17
  br i1 %21, label %52, label %22

22:                                               ; preds = %18
  %23 = icmp samesign ugt i16 %20, %17
  br i1 %23, label %24, label %26

24:                                               ; preds = %22
  %25 = sub nsw i16 %17, %20
  br label %28

26:                                               ; preds = %22
  %27 = sub nsw i16 %20, %17
  br label %28

28:                                               ; preds = %26, %24
  %29 = phi i16 [ %25, %24 ], [ %27, %26 ]
  %30 = icmp sgt i16 %29, -8
  br i1 %30, label %31, label %33

31:                                               ; preds = %28
  %32 = add nsw i16 %29, 8
  br label %33

33:                                               ; preds = %31, %28
  %34 = phi i16 [ %32, %31 ], [ 0, %28 ]
  %35 = zext nneg i8 %19 to i16
  %36 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 36), i16 %35
  %37 = load i16, ptr %36, align 1, !tbaa !2
  %38 = sub i16 %34, %37
  store i16 %34, ptr %36, align 1, !tbaa !2
  br label %39

39:                                               ; preds = %42, %33
  %40 = phi i16 [ %20, %33 ], [ %48, %42 ]
  %41 = icmp ult i16 %40, 17
  br i1 %41, label %42, label %49

42:                                               ; preds = %39
  %43 = getelementptr inbounds nuw [2 x i8], ptr @fenwick_gate_crc.f, i16 %40
  %44 = load i16, ptr %43, align 1, !tbaa !2
  %45 = add nsw i16 %38, %44
  store i16 %45, ptr %43, align 1, !tbaa !2
  %46 = sub nsw i16 0, %40
  %47 = and i16 %40, %46
  %48 = add nuw nsw i16 %47, %40
  br label %39, !llvm.loop !8

49:                                               ; preds = %39
  %50 = add nuw nsw i16 %20, 1
  %51 = add nuw nsw i8 %19, 2
  br label %18, !llvm.loop !9

52:                                               ; preds = %18, %77
  %53 = phi i16 [ %88, %77 ], [ 1, %18 ]
  %54 = phi i16 [ %87, %77 ], [ %13, %18 ]
  %55 = icmp samesign ult i16 %53, 17
  br i1 %55, label %62, label %56

56:                                               ; preds = %52
  %57 = add nuw nsw i16 %12, 1
  %58 = xor i16 %12, -1
  %59 = and i16 %57, %58
  %60 = tail call i16 @llvm.fshl.i16(i16 %54, i16 %54, i16 1)
  %61 = xor i16 %60, %59
  br label %11, !llvm.loop !10

62:                                               ; preds = %52
  %63 = tail call fastcc i16 @fw_prefix(i16 noundef %53) #3
  %64 = add nuw nsw i16 %53, 1
  br label %65

65:                                               ; preds = %70, %62
  %66 = phi i8 [ %76, %70 ], [ 0, %62 ]
  %67 = phi i16 [ %74, %70 ], [ 0, %62 ]
  %68 = phi i16 [ %75, %70 ], [ 1, %62 ]
  %69 = icmp eq i16 %68, %64
  br i1 %69, label %77, label %70

70:                                               ; preds = %65
  %71 = zext nneg i8 %66 to i16
  %72 = getelementptr i8, ptr getelementptr inbounds nuw (i8, ptr @fenwick_gate_crc.f, i16 36), i16 %71
  %73 = load i16, ptr %72, align 1, !tbaa !2
  %74 = add nsw i16 %73, %67
  %75 = add nuw nsw i16 %68, 1
  %76 = add nuw nsw i8 %66, 2
  br label %65, !llvm.loop !11

77:                                               ; preds = %65
  %78 = tail call i16 @llvm.fshl.i16(i16 %54, i16 %54, i16 1)
  %79 = xor i16 %63, %78
  %80 = tail call i16 @llvm.fshl.i16(i16 %79, i16 %79, i16 1)
  %81 = xor i16 %67, %80
  %82 = tail call fastcc i16 @fw_prefix(i16 noundef 16) #3
  %83 = add nsw i16 %53, -1
  %84 = tail call fastcc i16 @fw_prefix(i16 noundef %83) #3
  %85 = sub nsw i16 %82, %84
  %86 = tail call i16 @llvm.fshl.i16(i16 %81, i16 %81, i16 1)
  %87 = xor i16 %85, %86
  %88 = add nuw nsw i16 %53, 5
  br label %52, !llvm.loop !12

89:                                               ; preds = %11
  store volatile i16 %13, ptr @corpus_result, align 1, !tbaa !2
  br label %90

90:                                               ; preds = %90, %89
  tail call void asm sideeffect "wai", ""() #4, !srcloc !13
  br label %90
}

; Function Attrs: minsize nofree norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none)
define internal fastcc i16 @fw_prefix(i16 noundef range(i16 -1, 17) %0) unnamed_addr #1 {
  br label %2

2:                                                ; preds = %6, %1
  %3 = phi i16 [ %0, %1 ], [ %11, %6 ]
  %4 = phi i16 [ 0, %1 ], [ %9, %6 ]
  %5 = icmp eq i16 %3, 0
  br i1 %5, label %12, label %6

6:                                                ; preds = %2
  %7 = getelementptr inbounds nuw [2 x i8], ptr @fenwick_gate_crc.f, i16 %3
  %8 = load i16, ptr %7, align 1, !tbaa !2
  %9 = add nsw i16 %8, %4
  %10 = add i16 %3, -1
  %11 = and i16 %10, %3
  br label %2, !llvm.loop !14

12:                                               ; preds = %2
  ret i16 %4
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { minsize noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { minsize nofree norecurse nosync nounwind optsize memory(read, argmem: none, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { minsize optsize }
attributes #4 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = distinct !{!6, !7}
!7 = !{!"llvm.loop.mustprogress"}
!8 = distinct !{!8, !7}
!9 = distinct !{!9, !7}
!10 = distinct !{!10, !7}
!11 = distinct !{!11, !7}
!12 = distinct !{!12, !7}
!13 = !{i64 334}
!14 = distinct !{!14, !7}

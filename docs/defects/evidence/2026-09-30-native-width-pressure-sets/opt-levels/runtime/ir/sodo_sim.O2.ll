; ModuleID = '/work/examples/snes/corpus/sodo_sim.c'
source_filename = "/work/examples/snes/corpus/sodo_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  %1 = alloca [18 x i8], align 1
  %2 = getelementptr inbounds nuw i8, ptr %1, i16 1
  %3 = getelementptr inbounds nuw i8, ptr %1, i16 2
  %4 = getelementptr inbounds nuw i8, ptr %1, i16 3
  %5 = getelementptr inbounds nuw i8, ptr %1, i16 4
  %6 = getelementptr inbounds nuw i8, ptr %1, i16 5
  %7 = getelementptr inbounds nuw i8, ptr %1, i16 6
  %8 = getelementptr inbounds nuw i8, ptr %1, i16 7
  %9 = getelementptr inbounds nuw i8, ptr %1, i16 8
  %10 = getelementptr inbounds nuw i8, ptr %1, i16 9
  %11 = getelementptr inbounds nuw i8, ptr %1, i16 10
  %12 = getelementptr inbounds nuw i8, ptr %1, i16 11
  %13 = getelementptr inbounds nuw i8, ptr %1, i16 12
  %14 = getelementptr inbounds nuw i8, ptr %1, i16 13
  %15 = getelementptr inbounds nuw i8, ptr %1, i16 14
  %16 = getelementptr inbounds nuw i8, ptr %1, i16 15
  %17 = getelementptr inbounds nuw i8, ptr %1, i16 16
  %18 = getelementptr inbounds nuw i8, ptr %1, i16 17
  br label %19

19:                                               ; preds = %44, %0
  %20 = phi i16 [ 0, %0 ], [ %119, %44 ]
  %21 = phi i16 [ 0, %0 ], [ %120, %44 ]
  %22 = zext nneg i16 %21 to i64
  %23 = mul nuw nsw i64 %22, 41000000000
  %24 = add nsw i64 %23, -620000000000
  call void @llvm.lifetime.start.p0(ptr nonnull %1) #3
  %25 = icmp samesign ult i16 %21, 16
  br i1 %25, label %27, label %26

26:                                               ; preds = %19
  br label %27

27:                                               ; preds = %26, %19
  %28 = phi i8 [ 1, %26 ], [ -1, %19 ]
  br label %29

29:                                               ; preds = %38, %27
  %30 = phi i8 [ 0, %27 ], [ %42, %38 ]
  %31 = phi i64 [ %24, %27 ], [ %33, %38 ]
  %32 = srem i64 %31, 10
  %33 = sdiv i64 %31, 10
  %34 = icmp slt i64 %32, 0
  %35 = trunc nsw i64 %32 to i8
  br i1 %34, label %36, label %38

36:                                               ; preds = %29
  %37 = sub nsw i8 0, %35
  br label %38

38:                                               ; preds = %36, %29
  %39 = phi i8 [ %37, %36 ], [ %35, %29 ]
  %40 = zext nneg i8 %30 to i16
  %41 = getelementptr i8, ptr %1, i16 %40
  store i8 %39, ptr %41, align 1, !tbaa !6
  %42 = add nuw nsw i8 %30, 1
  %43 = icmp eq i8 %42, 18
  br i1 %43, label %44, label %29, !llvm.loop !7

44:                                               ; preds = %38
  %45 = zext i8 %28 to i16
  %46 = mul nuw nsw i16 %45, 10
  %47 = load i8, ptr %1, align 1, !tbaa !6
  %48 = zext i8 %47 to i16
  %49 = add nuw nsw i16 %46, %48
  %50 = mul nuw nsw i16 %49, 10
  %51 = load i8, ptr %2, align 1, !tbaa !6
  %52 = zext i8 %51 to i16
  %53 = add nuw nsw i16 %50, %52
  %54 = mul i16 %53, 10
  %55 = load i8, ptr %3, align 1, !tbaa !6
  %56 = zext i8 %55 to i16
  %57 = add i16 %54, %56
  %58 = mul i16 %57, 10
  %59 = load i8, ptr %4, align 1, !tbaa !6
  %60 = zext i8 %59 to i16
  %61 = add i16 %58, %60
  %62 = mul i16 %61, 10
  %63 = load i8, ptr %5, align 1, !tbaa !6
  %64 = zext i8 %63 to i16
  %65 = add i16 %62, %64
  %66 = mul i16 %65, 10
  %67 = load i8, ptr %6, align 1, !tbaa !6
  %68 = zext i8 %67 to i16
  %69 = add i16 %66, %68
  %70 = mul i16 %69, 10
  %71 = load i8, ptr %7, align 1, !tbaa !6
  %72 = zext i8 %71 to i16
  %73 = add i16 %70, %72
  %74 = mul i16 %73, 10
  %75 = load i8, ptr %8, align 1, !tbaa !6
  %76 = zext i8 %75 to i16
  %77 = add i16 %74, %76
  %78 = mul i16 %77, 10
  %79 = load i8, ptr %9, align 1, !tbaa !6
  %80 = zext i8 %79 to i16
  %81 = add i16 %78, %80
  %82 = mul i16 %81, 10
  %83 = load i8, ptr %10, align 1, !tbaa !6
  %84 = zext i8 %83 to i16
  %85 = add i16 %82, %84
  %86 = mul i16 %85, 10
  %87 = load i8, ptr %11, align 1, !tbaa !6
  %88 = zext i8 %87 to i16
  %89 = add i16 %86, %88
  %90 = mul i16 %89, 10
  %91 = load i8, ptr %12, align 1, !tbaa !6
  %92 = zext i8 %91 to i16
  %93 = add i16 %90, %92
  %94 = mul i16 %93, 10
  %95 = load i8, ptr %13, align 1, !tbaa !6
  %96 = zext i8 %95 to i16
  %97 = add i16 %94, %96
  %98 = mul i16 %97, 10
  %99 = load i8, ptr %14, align 1, !tbaa !6
  %100 = zext i8 %99 to i16
  %101 = add i16 %98, %100
  %102 = mul i16 %101, 10
  %103 = load i8, ptr %15, align 1, !tbaa !6
  %104 = zext i8 %103 to i16
  %105 = add i16 %102, %104
  %106 = mul i16 %105, 10
  %107 = load i8, ptr %16, align 1, !tbaa !6
  %108 = zext i8 %107 to i16
  %109 = add i16 %106, %108
  %110 = mul i16 %109, 10
  %111 = load i8, ptr %17, align 1, !tbaa !6
  %112 = zext i8 %111 to i16
  %113 = add i16 %110, %112
  %114 = mul i16 %113, 10
  %115 = load i8, ptr %18, align 1, !tbaa !6
  %116 = zext i8 %115 to i16
  %117 = add i16 %114, %116
  %118 = tail call i16 @llvm.fshl.i16(i16 %20, i16 %20, i16 1)
  %119 = xor i16 %117, %118
  call void @llvm.lifetime.end.p0(ptr nonnull %1) #3
  %120 = add nuw nsw i16 %21, 1
  %121 = icmp eq i16 %120, 60
  br i1 %121, label %122, label %19, !llvm.loop !9

122:                                              ; preds = %44
  store volatile i16 %119, ptr @corpus_result, align 1, !tbaa !2
  br label %123

123:                                              ; preds = %123, %122
  tail call void asm sideeffect "wai", ""() #3, !srcloc !10
  br label %123
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #2

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nounwind }

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
!10 = !{i64 459}

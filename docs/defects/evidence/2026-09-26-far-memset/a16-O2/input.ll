; ModuleID = '/home/will/llvm-mos-65816/examples/65816/far_memset.c'
source_filename = "/home/will/llvm-mos-65816/examples/65816/far_memset.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1

; Function Attrs: noreturn nounwind
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  tail call void @llvm.memset.p2.i32(ptr addrspace(2) noundef nonnull align 8192 dereferenceable(4096) inttoptr (i32 8265728 to ptr addrspace(2)), i8 66, i32 4096, i1 false), !tbaa !6
  br label %1

1:                                                ; preds = %0, %1
  %2 = phi i16 [ %9, %1 ], [ 0, %0 ]
  %3 = phi i16 [ %8, %1 ], [ 0, %0 ]
  %4 = zext nneg i16 %2 to i32
  %5 = getelementptr inbounds nuw i8, ptr addrspace(2) inttoptr (i32 8265728 to ptr addrspace(2)), i32 %4
  %6 = load i8, ptr addrspace(2) %5, align 1, !tbaa !6
  %7 = zext i8 %6 to i16
  %8 = add i16 %3, %7
  %9 = add nuw nsw i16 %2, 1
  %10 = icmp eq i16 %9, 4096
  br i1 %10, label %11, label %1, !llvm.loop !7

11:                                               ; preds = %1
  store volatile i16 %8, ptr @corpus_result, align 1, !tbaa !2
  br label %12

12:                                               ; preds = %12, %11
  tail call void asm sideeffect "wai", ""() #2, !srcloc !9
  br label %12
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p2.i32(ptr addrspace(2) writeonly captures(none), i8, i32, i1 immarg) #1

attributes #0 = { noreturn nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { nocallback nofree nounwind willreturn memory(argmem: write) }
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
!9 = !{i64 2285}

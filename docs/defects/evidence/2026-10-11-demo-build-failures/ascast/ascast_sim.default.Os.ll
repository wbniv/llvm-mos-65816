; ModuleID = 'examples/snes/corpus/ascast_sim.c'
source_filename = "examples/snes/corpus/ascast_sim.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@corpus_result = dso_local global i16 0, align 1
@ac_data = internal constant [16 x i8] c"\13';ORfz\8E\91\A5\B9\CD\D0\E4\F8\0C", align 1
@ac_opaque = internal global i16 0, align 1

; Function Attrs: noreturn nounwind optsize
define dso_local noundef i16 @main() local_unnamed_addr #0 {
  store volatile i16 ptrtoint (ptr @ac_data to i16), ptr @ac_opaque, align 1, !tbaa !7
  br label %1

1:                                                ; preds = %1, %0
  %2 = phi i16 [ 11617, %0 ], [ %10, %1 ]
  %3 = phi i8 [ 0, %0 ], [ %11, %1 ]
  %4 = zext nneg i8 %3 to i16
  %5 = load volatile i16, ptr @ac_opaque, align 1, !tbaa !7
  %6 = add i16 %5, %4
  %7 = tail call i16 @llvm.fshl.i16(i16 %2, i16 %2, i16 1)
  %8 = tail call fastcc zeroext i8 @ac_read(i16 noundef %6) #4
  %9 = zext i8 %8 to i16
  %10 = xor i16 %7, %9
  %11 = add nuw nsw i8 %3, 1
  %12 = icmp eq i8 %11, 16
  br i1 %12, label %13, label %1, !llvm.loop !8

13:                                               ; preds = %1
  store volatile i16 %10, ptr @corpus_result, align 1, !tbaa !7
  br label %14

14:                                               ; preds = %14, %13
  tail call void asm sideeffect "wai", ""() #5, !srcloc !10
  br label %14
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(read, inaccessiblemem: none, target_mem: none)
define internal fastcc zeroext i8 @ac_read(i16 noundef %0) unnamed_addr #1 {
  %2 = inttoptr i16 %0 to ptr
  %3 = tail call fastcc ptr addrspace(2) @ac_to_far(ptr noundef %2) #4
  %4 = tail call fastcc ptr @ac_to_near(ptr addrspace(2) noundef %3) #4
  %5 = tail call fastcc ptr addrspace(2) @ac_to_far(ptr noundef %4) #4
  %6 = load i8, ptr addrspace(2) %5, align 1, !tbaa !11
  ret i8 %6
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc ptr addrspace(2) @ac_to_far(ptr nofree noundef readnone captures(ret: address, provenance) %0) unnamed_addr #2 {
  %2 = addrspacecast ptr %0 to ptr addrspace(2)
  ret ptr addrspace(2) %2
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none)
define internal fastcc ptr @ac_to_near(ptr addrspace(2) nofree noundef readnone captures(ret: address, provenance) %0) unnamed_addr #2 {
  %2 = addrspacecast ptr addrspace(2) %0 to ptr
  ret ptr %2
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i16 @llvm.fshl.i16(i16, i16, i16) #3

attributes #0 = { noreturn nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }
attributes #1 = { mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(read, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }
attributes #2 = { mustprogress nofree noinline norecurse nosync nounwind optsize willreturn memory(none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { optsize }
attributes #5 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos.git 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63)"}
!2 = !{!3, !4, i64 0}
!3 = !{!"__libc_errno", !4, i64 0}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!4, !4, i64 0}
!8 = distinct !{!8, !9}
!9 = !{!"llvm.loop.mustprogress"}
!10 = !{i64 3229}
!11 = !{!5, !5, i64 0}

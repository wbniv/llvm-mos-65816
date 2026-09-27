; ModuleID = '/home/will/llvm-mos-65816/dev/near-store/indirect.c'
source_filename = "/home/will/llvm-mos-65816/dev/near-store/indirect.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@g = dso_local global i16 0, align 1
@h = dso_local global i16 0, align 1

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local void @simple(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #0 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local void @vol(ptr noundef %0, i16 noundef zeroext %1) local_unnamed_addr #1 {
  store volatile i16 %1, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local noundef zeroext i16 @ret(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef returned zeroext %1) local_unnamed_addr #0 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  ret i16 %1
}

; Function Attrs: nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local void @twice(ptr noundef %0, ptr noundef %1, i16 noundef zeroext %2) local_unnamed_addr #1 {
  store volatile i16 %2, ptr %0, align 1, !tbaa !6
  store volatile i16 %2, ptr %1, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none)
define dso_local void @abs_and_indir(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #2 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  store volatile i16 %1, ptr @g, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local void @offset(ptr noundef writeonly captures(none) initializes((2, 4)) %0, i16 noundef zeroext %1) local_unnamed_addr #0 {
  %3 = getelementptr inbounds nuw i8, ptr %0, i16 2
  store i16 %1, ptr %3, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local void @indexed(ptr noundef writeonly captures(none) %0, i8 noundef zeroext %1, i16 noundef zeroext %2) local_unnamed_addr #0 {
  %4 = zext i8 %1 to i16
  %5 = getelementptr inbounds nuw [2 x i8], ptr %0, i16 %4
  store i16 %2, ptr %5, align 1, !tbaa !6
  ret void
}

; Function Attrs: nounwind optsize
define dso_local void @call(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #3 {
  tail call void @opaque() #7
  store i16 %1, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: optsize
declare dso_local void @opaque() local_unnamed_addr #4

; Function Attrs: nounwind optsize
define dso_local void @conditional(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1, i8 noundef zeroext %2) local_unnamed_addr #3 {
  %4 = icmp eq i8 %2, 0
  br i1 %4, label %6, label %5

5:                                                ; preds = %3
  tail call void @opaque() #7
  br label %6

6:                                                ; preds = %5, %3
  store i16 %1, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: nounwind optsize
define dso_local void @result(ptr noundef writeonly captures(none) initializes((0, 2)) %0) local_unnamed_addr #3 {
  %2 = tail call zeroext i16 @produce() #7
  store i16 %2, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: optsize
declare dso_local zeroext i16 @produce() local_unnamed_addr #4

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local void @add(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #0 {
  %3 = add i16 %1, 42
  store i16 %3, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, target_mem: none)
define dso_local void @copy(ptr noundef %0) local_unnamed_addr #5 {
  %2 = load volatile i16, ptr @g, align 1, !tbaa !6
  store volatile i16 %2, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local noundef zeroext i16 @mixed(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #0 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, 1
  ret i16 %3
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none)
define dso_local void @native_context(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #2 {
  %3 = load volatile i16, ptr @h, align 1, !tbaa !6
  %4 = add i16 %3, 42
  store volatile i16 %4, ptr @h, align 1, !tbaa !6
  store i16 %1, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define dso_local void @loadptr(ptr noundef readonly captures(none) %0, i16 noundef zeroext %1) local_unnamed_addr #6 {
  %3 = load ptr, ptr %0, align 1, !tbaa !8
  store i16 %1, ptr %3, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local void @byte_value(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i8 noundef zeroext %1) local_unnamed_addr #0 {
  %3 = zext i8 %1 to i16
  store i16 %3, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none)
define dso_local void @third(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1, i16 noundef zeroext %2) local_unnamed_addr #2 {
  store i16 %2, ptr %0, align 1, !tbaa !6
  store volatile i16 %1, ptr @g, align 1, !tbaa !6
  ret void
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #2 = { nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #3 = { nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #4 = { optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #5 = { nofree norecurse nounwind optsize memory(readwrite, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #6 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #7 = { nounwind optsize }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}
!llvm.errno.tbaa = !{!2}

!0 = !{i32 7, !"frame-pointer", i32 2}
!1 = !{!"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"}
!2 = !{!3, !3, i64 0}
!3 = !{!"int", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"short", !4, i64 0}
!8 = !{!9, !9, i64 0}
!9 = !{!"p1 short", !10, i64 0}
!10 = !{!"any pointer", !4, i64 0}

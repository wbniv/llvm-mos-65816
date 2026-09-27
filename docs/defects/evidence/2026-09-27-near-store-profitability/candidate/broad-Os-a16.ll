; ModuleID = '/home/will/llvm-mos-65816/dev/near-store/broad.c'
source_filename = "/home/will/llvm-mos-65816/dev/near-store/broad.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-p2:32:8-p3:24:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos"

@g = external dso_local global i16, align 1
@byte = external dso_local global i8, align 1
@h = external dso_local global i16, align 1

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define dso_local noundef zeroext i16 @absolute_decrement(i16 noundef zeroext %0) local_unnamed_addr #0 {
  store volatile i16 %0, ptr @g, align 1, !tbaa !6
  %2 = add i16 %0, -1
  ret i16 %2
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local noundef zeroext i16 @indirect_decrement(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #1 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, -1
  ret i16 %3
}

; Function Attrs: nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local noundef zeroext i16 @volatile_increment(ptr noundef %0, i16 noundef zeroext %1) local_unnamed_addr #2 {
  store volatile i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, 1
  ret i16 %3
}

; Function Attrs: nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local noundef zeroext i16 @volatile_decrement(ptr noundef %0, i16 noundef zeroext %1) local_unnamed_addr #2 {
  store volatile i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, -1
  ret i16 %3
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local noundef zeroext i16 @indirect_add_two(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #1 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, 2
  ret i16 %3
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none)
define dso_local void @indirect_increment_result(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #3 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, 1
  store volatile i16 %3, ptr @g, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none)
define dso_local void @indirect_decrement_result(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i16 noundef zeroext %1) local_unnamed_addr #3 {
  store i16 %1, ptr %0, align 1, !tbaa !6
  %3 = add i16 %1, -1
  store volatile i16 %3, ptr @g, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local noundef zeroext i16 @indirect_twice_increment(ptr noundef %0, ptr noundef %1, i16 noundef zeroext %2) local_unnamed_addr #2 {
  store volatile i16 %2, ptr %0, align 1, !tbaa !6
  store volatile i16 %2, ptr %1, align 1, !tbaa !6
  %4 = add i16 %2, 1
  ret i16 %4
}

; Function Attrs: nounwind optsize
define dso_local zeroext i16 @indirect_return_call(ptr noundef writeonly captures(none) initializes((0, 2)) %0) local_unnamed_addr #4 {
  %2 = tail call zeroext i16 @produce() #9
  store i16 %2, ptr %0, align 1, !tbaa !6
  ret i16 %2
}

; Function Attrs: optsize
declare dso_local zeroext i16 @produce() local_unnamed_addr #5

; Function Attrs: nounwind optsize
define dso_local void @indirect_call_increment(ptr noundef writeonly captures(none) initializes((0, 2)) %0) local_unnamed_addr #4 {
  %2 = tail call zeroext i16 @produce() #9
  %3 = add i16 %2, 1
  store i16 %3, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nounwind optsize willreturn memory(readwrite, argmem: write, target_mem: none)
define dso_local void @indirect_byte_load(ptr noundef writeonly captures(none) initializes((0, 2)) %0) local_unnamed_addr #6 {
  %2 = load volatile i8, ptr @byte, align 1, !tbaa !8
  %3 = zext i8 %2 to i16
  store i16 %3, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nounwind optsize willreturn memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local void @indirect_byte_pointer(ptr noundef writeonly captures(none) initializes((0, 2)) %0, ptr noundef %1) local_unnamed_addr #7 {
  %3 = load volatile i8, ptr %1, align 1, !tbaa !8
  %4 = zext i8 %3 to i16
  store i16 %4, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none)
define dso_local void @indirect_byte_native(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i8 noundef zeroext %1) local_unnamed_addr #3 {
  %3 = load volatile i16, ptr @h, align 1, !tbaa !6
  %4 = add i16 %3, 42
  store volatile i16 %4, ptr @h, align 1, !tbaa !6
  %5 = zext i8 %1 to i16
  store i16 %5, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write)
define dso_local zeroext range(i16 0, 256) i16 @indirect_byte_return(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i8 noundef zeroext %1) local_unnamed_addr #1 {
  %3 = zext i8 %1 to i16
  store i16 %3, ptr %0, align 1, !tbaa !6
  ret i16 %3
}

; Function Attrs: nounwind optsize
define dso_local void @indirect_byte_call(ptr noundef writeonly captures(none) initializes((0, 2)) %0, i8 noundef zeroext %1) local_unnamed_addr #4 {
  tail call void @opaque() #9
  %3 = zext i8 %1 to i16
  store i16 %3, ptr %0, align 1, !tbaa !6
  ret void
}

; Function Attrs: optsize
declare dso_local void @opaque() local_unnamed_addr #5

; Function Attrs: nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite)
define dso_local void @indirect_byte_twice(ptr noundef %0, ptr noundef %1, i8 noundef zeroext %2) local_unnamed_addr #2 {
  %4 = zext i8 %2 to i16
  store volatile i16 %4, ptr %0, align 1, !tbaa !6
  store volatile i16 %4, ptr %1, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define dso_local void @loaded_pointer_byte(ptr noundef readonly captures(none) %0, i8 noundef zeroext %1) local_unnamed_addr #8 {
  %3 = zext i8 %1 to i16
  %4 = load ptr, ptr %0, align 1, !tbaa !9
  store i16 %3, ptr %4, align 1, !tbaa !6
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind optsize willreturn memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none)
define dso_local noundef zeroext i16 @loaded_pointer_increment(ptr noundef readonly captures(none) %0, i16 noundef zeroext %1) local_unnamed_addr #8 {
  %3 = load ptr, ptr %0, align 1, !tbaa !9
  store i16 %1, ptr %3, align 1, !tbaa !6
  %4 = add i16 %1, 1
  ret i16 %4
}

; Function Attrs: nounwind optsize
define dso_local noundef zeroext i16 @absolute_decrement_call(i16 noundef zeroext %0) local_unnamed_addr #4 {
  tail call void @opaque() #9
  store volatile i16 %0, ptr @g, align 1, !tbaa !6
  %2 = add i16 %0, -1
  ret i16 %2
}

; Function Attrs: nofree norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none)
define dso_local noundef zeroext i16 @absolute_decrement_native(i16 noundef zeroext %0) local_unnamed_addr #0 {
  %2 = load volatile i16, ptr @h, align 1, !tbaa !6
  %3 = add i16 %2, 42
  store volatile i16 %3, ptr @h, align 1, !tbaa !6
  store volatile i16 %0, ptr @g, align 1, !tbaa !6
  %4 = add i16 %0, -1
  ret i16 %4
}

attributes #0 = { nofree norecurse nounwind optsize memory(readwrite, argmem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(argmem: write) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #2 = { nofree norecurse nounwind optsize memory(argmem: readwrite, inaccessiblemem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #3 = { nofree norecurse nounwind optsize memory(readwrite, argmem: write, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #4 = { nounwind optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #5 = { optsize "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #6 = { mustprogress nofree norecurse nounwind optsize willreturn memory(readwrite, argmem: write, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #7 = { mustprogress nofree norecurse nounwind optsize willreturn memory(argmem: readwrite, inaccessiblemem: readwrite) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #8 = { mustprogress nofree norecurse nosync nounwind optsize willreturn memory(write, argmem: readwrite, inaccessiblemem: none, target_mem: none) "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="mosw65816" "target-features"="+mos-a16" }
attributes #9 = { nounwind optsize }

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
!8 = !{!4, !4, i64 0}
!9 = !{!10, !10, i64 0}
!10 = !{!"p1 short", !11, i64 0}
!11 = !{!"any pointer", !4, i64 0}

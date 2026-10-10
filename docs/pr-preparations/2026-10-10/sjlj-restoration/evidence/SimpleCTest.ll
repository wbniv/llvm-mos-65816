; ModuleID = '.scratch/sjlj-restoration/test-suite/SingleSource/UnitTests/SetjmpLongjmp/C/SimpleCTest.c'
source_filename = ".scratch/sjlj-restoration/test-suite/SingleSource/UnitTests/SetjmpLongjmp/C/SimpleCTest.c"
target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
target triple = "mos-sim"

%struct.__jmp_buf_tag = type { ptr, i8, ptr, [14 x i8] }

@.str = private unnamed_addr constant [12 x i8] c"Inside baz\0A\00", align 1, !guid !0
@.str.1 = private unnamed_addr constant [13 x i8] c"Inside main\0A\00", align 1, !guid !1
@.str.2 = private unnamed_addr constant [11 x i8] c"ret == 37\0A\00", align 1, !guid !2
@.str.3 = private unnamed_addr constant [32 x i8] c"Unexpected setjmp return value\0A\00", align 1, !guid !3

; Function Attrs: noinline nounwind optnone
define dso_local void @baz(ptr noundef %0) #0 !guid !8 {
  %2 = alloca ptr, align 1
  store ptr %0, ptr %2, align 1
  %3 = call i16 (ptr, ...) @printf(ptr noundef @.str)
  %4 = load ptr, ptr %2, align 1
  call void @longjmp(ptr noundef %4, i16 noundef 37) #4
  unreachable
}

declare dso_local i16 @printf(ptr noundef, ...) #1

; Function Attrs: noreturn
declare dso_local void @longjmp(ptr noundef, i16 noundef) #2

; Function Attrs: noinline nounwind optnone
define dso_local i16 @main() #0 !guid !9 {
  %1 = alloca i16, align 1
  %2 = alloca [1 x %struct.__jmp_buf_tag], align 1
  store i16 0, ptr %1, align 1
  %3 = call i16 (ptr, ...) @printf(ptr noundef @.str.1)
  %4 = getelementptr inbounds [1 x %struct.__jmp_buf_tag], ptr %2, i16 0, i16 0
  %5 = call i16 @setjmp(ptr noundef %4) #5
  switch i16 %5, label %10 [
    i16 0, label %6
    i16 37, label %8
  ]

6:                                                ; preds = %0
  %7 = getelementptr inbounds [1 x %struct.__jmp_buf_tag], ptr %2, i16 0, i16 0
  call void @baz(ptr noundef %7)
  br label %12

8:                                                ; preds = %0
  %9 = call i16 (ptr, ...) @printf(ptr noundef @.str.2)
  br label %12

10:                                               ; preds = %0
  %11 = call i16 (ptr, ...) @printf(ptr noundef @.str.3)
  store i16 1, ptr %1, align 1
  br label %13

12:                                               ; preds = %8, %6
  store i16 0, ptr %1, align 1
  br label %13

13:                                               ; preds = %12, %10
  %14 = load i16, ptr %1, align 1
  ret i16 %14
}

; Function Attrs: nocallback returns_twice
declare dso_local i16 @setjmp(ptr noundef) #3

attributes #0 = { noinline nounwind optnone "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #1 = { "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { noreturn "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nocallback returns_twice "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #4 = { noreturn }
attributes #5 = { nocallback returns_twice }

!llvm.module.flags = !{!4, !5, !6}
!llvm.ident = !{!7}

!0 = !{i64 -6234525910923811246}
!1 = !{i64 -7079957864398258001}
!2 = !{i64 8573432109084065951}
!3 = !{i64 -5843443702693474096}
!4 = !{i32 7, !"frame-pointer", i32 2}
!5 = !{i32 1, !"ThinLTO", i32 0}
!6 = !{i32 1, !"EnableSplitLTOUnit", i32 1}
!7 = !{!"clang version 24.0.0git (https://github.com/llvm-mos/llvm-mos 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63)"}
!8 = !{i64 7546896869197086323}
!9 = !{i64 -2624081020897602054}

^0 = module: (path: "[Regular LTO]", hash: (0, 0, 0, 0, 0))
^1 = gv: (name: "printf") ; guid = 7383291119112528047
^2 = gv: (name: "baz", summaries: (function: (module: ^0, flags: (linkage: external, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), insts: 6, funcFlags: (readNone: 0, readOnly: 0, noRecurse: 0, returnDoesNotAlias: 0, noInline: 1, alwaysInline: 0, noUnwind: 1, mayThrow: 0, hasUnknownCall: 0, mustBeUnreachable: 1), calls: ((callee: ^1), (callee: ^6)), refs: (^7)))) ; guid = 7546896869197086323
^3 = gv: (name: ".str.2", summaries: (variable: (module: ^0, flags: (linkage: private, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 0, constant: 1)))) ; guid = 8573432109084065951
^4 = gv: (name: "setjmp") ; guid = 9832484650759523641
^5 = gv: (name: ".str.1", summaries: (variable: (module: ^0, flags: (linkage: private, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 0, constant: 1)))) ; guid = 11366786209311293615
^6 = gv: (name: "longjmp") ; guid = 12198037595855906571
^7 = gv: (name: ".str", summaries: (variable: (module: ^0, flags: (linkage: private, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 0, constant: 1)))) ; guid = 12212218162785740370
^8 = gv: (name: ".str.3", summaries: (variable: (module: ^0, flags: (linkage: private, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), varFlags: (readonly: 1, writeonly: 0, constant: 1)))) ; guid = 12603300371016077520
^9 = gv: (name: "main", summaries: (function: (module: ^0, flags: (linkage: external, visibility: default, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0, importType: definition, noRenameOnPromotion: 0), insts: 19, funcFlags: (readNone: 0, readOnly: 0, noRecurse: 0, returnDoesNotAlias: 0, noInline: 1, alwaysInline: 0, noUnwind: 1, mayThrow: 0, hasUnknownCall: 0, mustBeUnreachable: 0), calls: ((callee: ^1), (callee: ^4), (callee: ^2)), refs: (^5, ^3, ^8)))) ; guid = 15822663052811949562
^10 = flags: 8
^11 = blockcount: 0

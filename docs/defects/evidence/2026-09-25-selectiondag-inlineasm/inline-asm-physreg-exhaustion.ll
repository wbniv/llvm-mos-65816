; RUN: not llc -mtriple=aarch64 -global-isel=0 -O0 -verify-machineinstrs %s -o /dev/null 2>&1 | FileCheck %s
; RUN: not llc -mtriple=aarch64 -global-isel=0 -O2 -verify-machineinstrs %s -o /dev/null 2>&1 | FileCheck %s

; The condition-code class contains only NZCV, so it cannot hold an i128 value.
; Check each operand form and keep results live to exercise error recovery.
; CHECK-COUNT-7: error: register 'NZCV' allocated for constraint '{cc}' does not match required type
; CHECK-NOT: error:

define i128 @bad_output() {
  %v = call i128 asm sideeffect "", "={cc}"()
  ret i128 %v
}

define void @bad_input(i128 %v) {
  call void asm sideeffect "", "{cc}"(i128 %v)
  ret void
}

define i128 @bad_tied(i128 %v) {
  %r = call i128 asm sideeffect "", "={cc},0"(i128 %v)
  ret i128 %r
}

define void @bad_indirect(ptr %p) {
  call void asm sideeffect "", "=*{cc}"(ptr elementtype(i128) %p)
  ret void
}

; Callbr outputs must remain defined on both the direct and indirect edges
; when the diagnostic handler returns, including aggregate results.
define i128 @bad_callbr() {
entry:
  %r = callbr i128 asm sideeffect "", "={cc},!i"()
          to label %direct [label %indirect]
direct:
  ret i128 %r
indirect:
  ret i128 %r
}

define i64 @bad_callbr_input(i128 %v) {
entry:
  %r = callbr i64 asm sideeffect "", "=r,{cc},!i"(i128 %v)
          to label %direct [label %indirect]
direct:
  ret i64 %r
indirect:
  ret i64 %r
}

define { i64, i128 } @bad_callbr_pair() {
entry:
  %r = callbr { i64, i128 } asm sideeffect "", "=r,={cc},!i"()
          to label %direct [label %indirect]
direct:
  ret { i64, i128 } %r
indirect:
  ret { i64, i128 } %r
}

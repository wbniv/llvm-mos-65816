; RUN: not llc -mtriple=aarch64 -global-isel -global-isel-abort=1 -O0 -verify-machineinstrs %s -o /dev/null 2>&1 | FileCheck %s
; RUN: not llc -mtriple=aarch64 -global-isel -global-isel-abort=1 -O2 -verify-machineinstrs %s -o /dev/null 2>&1 | FileCheck %s
; RUN: not llc -mtriple=aarch64 -global-isel -global-isel-abort=0 -O0 -verify-machineinstrs %s -o /dev/null 2>&1 | FileCheck %s
; RUN: not llc -mtriple=aarch64 -global-isel -global-isel-abort=0 -O2 -verify-machineinstrs %s -o /dev/null 2>&1 | FileCheck %s

; An i128 operand requires two registers, but the condition-code class contains
; only NZCV. Each operand form must diagnose the insufficient physical range.
; The return values remain live so error recovery must define their registers.
; CHECK-COUNT-4: error: not enough registers for inline asm constraint '{cc}'
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

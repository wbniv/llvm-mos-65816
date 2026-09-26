; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 -verify-machineinstrs -stop-after=irtranslator < %s | FileCheck %s
; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O2 -verify-machineinstrs -stop-after=irtranslator < %s | FileCheck %s
; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM
; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM

; An indirect register output ("=*r", what Clang emits for "+g") is stored
; through its pointer argument after the asm instead of being a call result.

define i32 @barrier(i32 %u) {
; CHECK-LABEL: name: barrier
; CHECK: [[P:%[0-9]+]]:_(p0) = G_FRAME_INDEX %stack.0.u.addr
; CHECK: INLINEASM &"", {{.*}} regdef:GPR32common, def [[D:%[0-9]+]], reguse tiedto:$0, %{{[0-9]+}}(tied-def 3)
; CHECK: [[V:%[0-9]+]]:_(i32) = COPY [[D]]
; CHECK: G_STORE [[V]](i32), [[P]](p0) :: (store (i32) into %ir.u.addr)
; ASM-LABEL: barrier:
; ASM: ret
  %u.addr = alloca i32, align 4
  store i32 %u, ptr %u.addr, align 4
  %v = load i32, ptr %u.addr, align 4
  call void asm sideeffect "", "=*imr,0"(ptr nonnull elementtype(i32) %u.addr, i32 %v)
  %r = load i32, ptr %u.addr, align 4
  ret i32 %r
}

define void @indirect_narrow(ptr %p) {
; CHECK-LABEL: name: indirect_narrow
; CHECK: INLINEASM &"", {{.*}} regdef:GPR32common, def [[D:%[0-9]+]]
; CHECK: [[W:%[0-9]+]]:_(i32) = COPY [[D]]
; CHECK: [[V:%[0-9]+]]:_(i8) = G_TRUNC [[W]](i32)
; CHECK: G_STORE [[V]](i8), %{{[0-9]+}}(p0) :: (store (i8) into %ir.p)
; ASM-LABEL: indirect_narrow:
; ASM: strb w{{[0-9]+}}, [x0]
; ASM: ret
  call void asm sideeffect "", "=*r"(ptr elementtype(i8) %p)
  ret void
}

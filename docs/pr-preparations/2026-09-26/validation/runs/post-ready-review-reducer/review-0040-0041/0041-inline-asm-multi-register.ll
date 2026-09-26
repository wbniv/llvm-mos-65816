; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 -stop-after=irtranslator < %s | FileCheck %s
; RUN: llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 < %s | FileCheck %s --check-prefix=ASM

; AArch64 selects GPR32common for "r" whenever the type is not 64-bit, so an
; i128 operand occupies two 32-bit registers and the value is narrowed to their
; combined width -- exactly what SelectionDAG does for the same asm.

define i128 @tied128(i128 %x) {
; CHECK-LABEL: name: tied128
; CHECK: [[W:%[0-9]+]]:_(i64) = G_TRUNC %{{[0-9]+}}(i128)
; CHECK: [[P0:%[0-9]+]]:_(i32) = G_TRUNC [[W]](i64)
; CHECK: [[R0:%[0-9]+]]:gpr32common = COPY [[P0]](i32)
; CHECK: [[C32:%[0-9]+]]:_(i64) = G_CONSTANT i64 32
; CHECK: [[S32:%[0-9]+]]:_(i64) = G_LSHR [[W]], [[C32]](i64)
; CHECK: [[P1:%[0-9]+]]:_(i32) = G_TRUNC [[S32]](i64)
; CHECK: [[R1:%[0-9]+]]:gpr32common = COPY [[P1]](i32)
; CHECK: INLINEASM &"", {{.*}} regdef:GPR32common, def [[D0:%[0-9]+]], def [[D1:%[0-9]+]], reguse tiedto:$0, [[R0]](tied-def 3), [[R1]](tied-def 4)
; CHECK: [[L0:%[0-9]+]]:_(i32) = COPY [[D0]]
; CHECK: [[L1:%[0-9]+]]:_(i32) = COPY [[D1]]
; CHECK: %{{[0-9]+}}:_(i64) = G_MERGE_VALUES [[L0]](i32), [[L1]](i32)
; ASM-LABEL: tied128:
; ASM: lsr x{{[0-9]+}}, x{{[0-9]+}}, #32
; ASM: bfi x0, x{{[0-9]+}}, #32, #32
; ASM: ret
  %r = call i128 asm "", "=r,0"(i128 %x)
  ret i128 %r
}

define i128 @out128() {
; CHECK-LABEL: name: out128
; CHECK: INLINEASM &"", {{.*}} regdef:GPR32common, def [[D0:%[0-9]+]], def [[D1:%[0-9]+]]
; CHECK: [[L0:%[0-9]+]]:_(i32) = COPY [[D0]]
; CHECK: [[L1:%[0-9]+]]:_(i32) = COPY [[D1]]
; CHECK: %{{[0-9]+}}:_(i64) = G_MERGE_VALUES [[L0]](i32), [[L1]](i32)
; ASM-LABEL: out128:
; ASM: bfi x0, x{{[0-9]+}}, #32, #32
; ASM: ret
  %r = call i128 asm "", "=r"()
  ret i128 %r
}

; An early-clobber multi-register output beside a multi-register input.
define i128 @multi_reg_input(i128 %x) {
; CHECK-LABEL: name: multi_reg_input
; CHECK: [[R0:%[0-9]+]]:gpr32common = COPY %{{[0-9]+}}(i32)
; CHECK: [[R1:%[0-9]+]]:gpr32common = COPY %{{[0-9]+}}(i32)
; CHECK: INLINEASM &"/* $0 $1 */", {{.*}} regdef-ec:GPR32common, def early-clobber [[D0:%[0-9]+]], def early-clobber [[D1:%[0-9]+]], reguse:GPR32common, [[R0]], [[R1]]
; CHECK: [[L0:%[0-9]+]]:_(i32) = COPY [[D0]]
; CHECK: [[L1:%[0-9]+]]:_(i32) = COPY [[D1]]
; CHECK: %{{[0-9]+}}:_(i64) = G_MERGE_VALUES [[L0]](i32), [[L1]](i32)
; ASM-LABEL: multi_reg_input:
; ASM: lsr x{{[0-9]+}}, x0, #32
; ASM: bfi x0, x{{[0-9]+}}, #32, #32
; ASM: ret
  %r = call i128 asm sideeffect "/* $0 $1 */", "=&r,r"(i128 %x)
  ret i128 %r
}

define void @in128(i128 %x) {
; CHECK-LABEL: name: in128
; CHECK: [[W:%[0-9]+]]:_(i64) = G_TRUNC %{{[0-9]+}}(i128)
; CHECK: [[P0:%[0-9]+]]:_(i32) = G_TRUNC [[W]](i64)
; CHECK: [[R0:%[0-9]+]]:gpr32common = COPY [[P0]](i32)
; CHECK: INLINEASM &"", {{.*}} reguse:GPR32common, [[R0]], %{{[0-9]+}}
; ASM-LABEL: in128:
; ASM: lsr x{{[0-9]+}}, x0, #32
; ASM: ret
  call void asm sideeffect "", "r"(i128 %x)
  ret void
}

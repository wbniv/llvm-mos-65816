; RUN: split-file %s %t
; RUN: llc -mtriple=mos -mcpu=mos6502 -verify-machineinstrs %t/ok.ll -o - | FileCheck %s
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/wide_a.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-A
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/wide_x.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-X
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/wide_y.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-Y
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/wide_R.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-R
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/wide_d.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-D
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/wide_in.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-IN
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/named_a.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-NAMED-A
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/named_x.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-NAMED-X
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/named_y.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-NAMED-Y
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/named_rc.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-NAMED-RC
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/named_rs.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-NAMED-RS
; RUN: not --crash llc -mtriple=mos -mcpu=mos6502 %t/named_cc.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REJECT-NAMED-CC

; "a", "x", "y" name one of the 8-bit data registers and "R"/"d" name a class of
; them. None of those registers pair into a wider value, so an operand that does
; not fit in eight bits cannot be placed in one and the constraint is rejected.
; Explicit register names also arise from C register variables using "r".
; The check matters because the number of
; registers an inline-asm operand needs is reported from the value type alone,
; without the constraint, so a 16-bit operand is reported as fitting in one
; register and its high byte would be dropped on the way into an 8-bit one.

;--- ok.ll

; An 8-bit operand fits the register the constraint names.
define i8 @narrow_a() {
; CHECK-LABEL: narrow_a:
; CHECK: ;APP
; CHECK: ;NO_APP
  %v = call i8 asm "lda #42", "=a"()
  ret i8 %v
}

; "r" is the constraint that does accept a 16-bit value: it selects Imag16, a
; class whose registers hold all sixteen bits, which is what lets inline asm
; take a pointer.
define i16 @wide_r() {
; CHECK-LABEL: wide_r:
; CHECK: ;APP
; CHECK: ;NO_APP
  %v = call i16 asm "", "=r"()
  ret i16 %v
}

; The flag constraints allow extension: their registers are one bit wide and
; extending that bit to the operand's type is the point of "c" and "v".
define i8 @carry_to_byte() {
; CHECK-LABEL: carry_to_byte:
; CHECK: ;APP
; CHECK: ;NO_APP
  %v = call i8 asm "sec", "=c"()
  ret i8 %v
}

; A named byte, named pair, and untyped clobbers each satisfy their contract.
define i8 @named_byte() {
; CHECK-LABEL: named_byte:
; CHECK: ;APP
; CHECK: ;NO_APP
  %v = call i8 asm "", "={rc0},~{a},~{x},~{y},~{cc}"()
  ret i8 %v
}

define i16 @named_pair() {
; CHECK-LABEL: named_pair:
; CHECK: ;APP
; CHECK: ;NO_APP
  %v = call i16 asm "", "={rs0}"()
  ret i16 %v
}

define i8 @named_carry() {
; CHECK-LABEL: named_carry:
; CHECK: ;APP
; CHECK: ;NO_APP
  %v = call i8 asm "sec", "={c}"()
  ret i8 %v
}

;--- wide_a.ll
define i16 @wide_a() {
; REJECT-A: LLVM ERROR: unable to translate instruction: call{{.*}}wide_a
  %v = call i16 asm "", "=a"()
  ret i16 %v
}

;--- wide_x.ll
define i16 @wide_x() {
; REJECT-X: LLVM ERROR: unable to translate instruction: call{{.*}}wide_x
  %v = call i16 asm "", "=x"()
  ret i16 %v
}

;--- wide_y.ll
define i16 @wide_y() {
; REJECT-Y: LLVM ERROR: unable to translate instruction: call{{.*}}wide_y
  %v = call i16 asm "", "=y"()
  ret i16 %v
}

;--- wide_R.ll
define i16 @wide_R() {
; REJECT-R: LLVM ERROR: unable to translate instruction: call{{.*}}wide_R
  %v = call i16 asm "", "=R"()
  ret i16 %v
}

;--- wide_d.ll
define i16 @wide_d() {
; REJECT-D: LLVM ERROR: unable to translate instruction: call{{.*}}wide_d
  %v = call i16 asm "", "=d"()
  ret i16 %v
}

;--- wide_in.ll
; The input direction is rejected for the same reason as the output direction.
define void @wide_in(i16 %x) {
; REJECT-IN: LLVM ERROR: unable to translate instruction: call{{.*}}wide_in
  call void asm "", "a"(i16 %x)
  ret void
}

;--- named_a.ll
define i16 @named_a() {
; REJECT-NAMED-A: LLVM ERROR: unable to translate instruction: call{{.*}}named_a
  %v = call i16 asm "", "={a}"()
  ret i16 %v
}

;--- named_x.ll
define i16 @named_x() {
; REJECT-NAMED-X: LLVM ERROR: unable to translate instruction: call{{.*}}named_x
  %v = call i16 asm "", "={x}"()
  ret i16 %v
}

;--- named_y.ll
define i16 @named_y() {
; REJECT-NAMED-Y: LLVM ERROR: unable to translate instruction: call{{.*}}named_y
  %v = call i16 asm "", "={y}"()
  ret i16 %v
}

;--- named_rc.ll
define i16 @named_rc() {
; REJECT-NAMED-RC: LLVM ERROR: unable to translate instruction: call{{.*}}named_rc
  %v = call i16 asm "", "={rc0}"()
  ret i16 %v
}

;--- named_rs.ll
define i32 @named_rs() {
; REJECT-NAMED-RS: LLVM ERROR: unable to translate instruction: call{{.*}}named_rs
  %v = call i32 asm "", "={rs0}"()
  ret i32 %v
}

;--- named_cc.ll
define i16 @named_cc() {
; REJECT-NAMED-CC: LLVM ERROR: unable to translate instruction: call{{.*}}named_cc
  %v = call i16 asm "", "={cc}"()
  ret i16 %v
}

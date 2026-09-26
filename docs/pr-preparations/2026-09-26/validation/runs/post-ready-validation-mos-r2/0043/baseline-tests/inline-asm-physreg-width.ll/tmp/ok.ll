
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


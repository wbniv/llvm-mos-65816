; RUN: not llvm-mc -triple mos -mcpu=mos6502 %s 2>&1 | FileCheck %s

; The other half of modifier-width.s: when a modifier is wider than every
; candidate operand the mnemonic has, the instruction is refused rather than
; narrowed. Narrowing would truncate the address to fit and change what the
; instruction reads -- `lda mos24($123456)` as `a5 56` is a direct page load
; from $56, not a long load from $123456.

; A 24-bit address needs 65816 long addressing, which the 6502 does not have.
; CHECK: [[#@LINE+3]]:1: error: invalid instruction, any one of the following would fix this:
; CHECK: [[#@LINE+2]]:5: note: operand must be an 8-bit address
; CHECK: [[#@LINE+1]]:5: note: operand must be a 16-bit address
lda mos24($123456)

; CHECK: [[#@LINE+1]]:1: error: invalid instruction, any one of the following would fix this:
lda mos24($f0),x

; CHECK: [[#@LINE+1]]:1: error: invalid instruction, any one of the following would fix this:
jmp mos24($123456)

; The base of a zero page indirect mode is a zero page address, so no wider
; modifier can fill it.
; CHECK: [[#@LINE+1]]:6: error: operand must be an 8-bit address
lda (mos16($f0)),y

; CHECK: [[#@LINE+1]]:6: error: operand must be an 8-bit address
lda (mos16($f0),x)

; The immediate-context spelling obeys the same rule: a 16-bit modifier does
; not fit an 8-bit immediate.
; CHECK: [[#@LINE+1]]:1: error: invalid instruction, any one of the following would fix this:
lda #mos16(5)

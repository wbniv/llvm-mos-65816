; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs %s -o - | FileCheck %s

@table = external addrspace(2) global [131072 x i8]
@farword = external addrspace(2) global i16
@nearword = external global i16
declare void @opaque()

; Signed offsets cannot be represented by the unsigned X8 displacement.
define i8 @signed_byte_index(i8 %index) {
; CHECK-LABEL: signed_byte_index:
; CHECK-NOT: mos24(table),x
; CHECK: lda [
; CHECK: rts
  %offset = sext i8 %index to i32
  %p = getelementptr [131072 x i8], ptr addrspace(2) @table, i32 0, i32 %offset
  %value = load volatile i8, ptr addrspace(2) %p, align 1
  ret i8 %value
}

; Twice an unsigned i16 may need seventeen bits, so X16 is insufficient.
define i8 @scaled_wide_index(i16 %index) {
; CHECK-LABEL: scaled_wide_index:
; CHECK-NOT: mos24(table),x
; CHECK: lda [
; CHECK: rts
  %wide = zext i16 %index to i32
  %offset = shl i32 %wide, 1
  %p = getelementptr [131072 x i8], ptr addrspace(2) @table, i32 0, i32 %offset
  %value = load volatile i8, ptr addrspace(2) %p, align 1
  ret i8 %value
}

; Atomic word operations must remain one word access even for byte ABI values.
define i16 @far_atomic_return() {
; CHECK-LABEL: far_atomic_return:
; CHECK: rep #32
; CHECK: lda mos24(farword)
; CHECK-NOT: mos24(farword+1)
; CHECK: sep #32
; CHECK: rts
  %value = load atomic i16, ptr addrspace(2) @farword unordered, align 2
  ret i16 %value
}

define void @far_atomic_store_arg(i16 %value) {
; CHECK-LABEL: far_atomic_store_arg:
; CHECK: rep #32
; CHECK: sta mos24(farword)
; CHECK-NOT: mos24(farword+1)
; CHECK: sep #32
; CHECK: rts
  store atomic i16 %value, ptr addrspace(2) @farword unordered, align 2
  ret void
}

define void @far_atomic_store_zero() {
; CHECK-LABEL: far_atomic_store_zero:
; CHECK: rep #32
; CHECK: sta mos24(farword)
; CHECK-NOT: mos24(farword+1)
; CHECK: sep #32
; CHECK: rts
  store atomic i16 0, ptr addrspace(2) @farword unordered, align 2
  ret void
}

; The unit-decrement path must preserve the stored pre-decrement ABI value.
define i16 @near_store_decrement(i16 %value) {
; CHECK-LABEL: near_store_decrement:
; CHECK-NOT: rep #32
; CHECK: sta nearword
; CHECK: stx nearword+1
; CHECK: dec
; CHECK: rts
  store volatile i16 %value, ptr @nearword, align 1
  %result = sub i16 %value, 1
  ret i16 %result
}

; A call between the store and arithmetic requires preservation across the ABI.
define i16 @near_store_call_increment(i16 %value) {
; CHECK-LABEL: near_store_call_increment:
; CHECK: jsr opaque
; CHECK: rep #32
; CHECK: inc
; CHECK: sep #32
; CHECK: rts
  store volatile i16 %value, ptr @nearword, align 1
  call void @opaque()
  %result = add i16 %value, 1
  ret i16 %result
}

; Distinct volatile accesses retain order across the native far transfer.
define void @volatile_order() {
; CHECK-LABEL: volatile_order:
; CHECK: lda mos24(farword)
; CHECK: sta nearword
; CHECK: lda mos24(farword)
; CHECK: sta nearword
; CHECK: rts
  %a = load volatile i16, ptr addrspace(2) @farword, align 1
  store volatile i16 %a, ptr @nearword, align 1
  %b = load volatile i16, ptr addrspace(2) @farword, align 1
  store volatile i16 %b, ptr @nearword, align 1
  ret void
}

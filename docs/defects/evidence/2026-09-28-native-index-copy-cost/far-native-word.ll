; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,XY16

@farword = external addrspace(2) global i16
@nearword = external global i16
@fararray = external addrspace(2) global [256 x i16]

define void @far_global_copy() {
; CHECK-LABEL: far_global_copy:
; CHECK: rep #32
; CHECK: lda mos24(farword)
; CHECK: sta nearword
; CHECK: sep #32
  %value = load volatile i16, ptr addrspace(2) @farword
  store volatile i16 %value, ptr @nearword
  ret void
}

define void @far_global_store() {
; CHECK-LABEL: far_global_store:
; CHECK: rep #32
; CHECK: sta mos24(farword)
; CHECK: sep #32
  %value = load volatile i16, ptr @nearword
  %sum = add i16 %value, 1
  store volatile i16 %sum, ptr addrspace(2) @farword
  ret void
}

define void @far_runtime_load(ptr addrspace(2) %pointer) {
; CHECK-LABEL: far_runtime_load:
; CHECK: rep #32
; CHECK: lda [__rc{{[0-9]+}}]
; CHECK: sep #32
  %value = load volatile i16, ptr addrspace(2) %pointer
  %sum = add i16 %value, 1
  store volatile i16 %sum, ptr @nearword
  ret void
}

define void @far_runtime_store(ptr addrspace(2) %pointer) {
; CHECK-LABEL: far_runtime_store:
; CHECK: rep #32
; CHECK: sta [__rc{{[0-9]+}}]
; CHECK: sep #32
  %value = load volatile i16, ptr @nearword
  %sum = add i16 %value, 1
  store volatile i16 %sum, ptr addrspace(2) %pointer
  ret void
}

define void @far_global_word_indexed(i8 %index) {
; CHECK-LABEL: far_global_word_indexed:
; CHECK: rep #32
; CHECK: lda mos24(farword),x
; CHECK: sep #32
  %offset = zext i8 %index to i32
  %pointer = getelementptr i8, ptr addrspace(2) @farword, i32 %offset
  %value = load volatile i16, ptr addrspace(2) %pointer, align 1
  store volatile i16 %value, ptr @nearword
  ret void
}

define void @far_runtime_word_indexed(ptr addrspace(2) %base) {
; CHECK-LABEL: far_runtime_word_indexed:
; CHECK: rep #32
; CHECK: lda [__rc{{[0-9]+}}],y
; CHECK: sep #32
  %pointer = getelementptr i8, ptr addrspace(2) %base, i32 1
  %value = load volatile i16, ptr addrspace(2) %pointer, align 1
  store volatile i16 %value, ptr @nearword
  ret void
}

define void @far_scaled_word(i8 %index) {
; XY16-LABEL: far_scaled_word:
; XY16: rep #{{(16|48)}}
; XY16: lda mos24(fararray),x
; XY16: sep #{{(16|48)}}
  %offset = zext i8 %index to i32
  %pointer = getelementptr [256 x i16], ptr addrspace(2) @fararray, i32 0, i32 %offset
  %value = load volatile i16, ptr addrspace(2) %pointer
  store volatile i16 %value, ptr @nearword
  ret void
}

define void @far_scaled_word_wide(i16 %index) {
; XY16-LABEL: far_scaled_word_wide:
; XY16-NOT: mos24(fararray),x
; XY16: lda [__rc{{[0-9]+}}]
  %offset = zext i16 %index to i32
  %pointer = getelementptr [256 x i16], ptr addrspace(2) @fararray, i32 0, i32 %offset
  %value = load volatile i16, ptr addrspace(2) %pointer
  store volatile i16 %value, ptr @nearword
  ret void
}

define void @far_byte_argument(i16 %value) {
; CHECK-LABEL: far_byte_argument:
; CHECK-NOT: rep #32
; CHECK: sta mos24(farword)
; CHECK: st{{[axy]}} mos24(farword+1)
  store i16 %value, ptr addrspace(2) @farword
  ret void
}

define i16 @far_byte_return() {
; CHECK-LABEL: far_byte_return:
; CHECK-NOT: rep #32
; CHECK: lda mos24(farword)
; CHECK: lda mos24(farword+1)
  %value = load i16, ptr addrspace(2) @farword
  ret i16 %value
}

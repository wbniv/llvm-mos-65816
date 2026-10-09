; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=CHECK,XY16

@table = external addrspace(2) global [256 x i8]
@output = external addrspace(2) global [256 x i8]
@index8 = external global i8
@sink16 = external global i16

define i8 @load_byte(i8 %index) {
; CHECK-LABEL: load_byte:
; CHECK: lda mos24(table),x
  %offset = zext i8 %index to i32
  %ptr = getelementptr [256 x i8], ptr addrspace(2) @table, i32 0, i32 %offset
  %value = load i8, ptr addrspace(2) %ptr
  ret i8 %value
}

define void @store_byte(i8 %index, i8 %value) {
; CHECK-LABEL: store_byte:
; CHECK: sta mos24(output),x
  %offset = zext i8 %index to i32
  %ptr = getelementptr [256 x i8], ptr addrspace(2) @output, i32 0, i32 %offset
  store i8 %value, ptr addrspace(2) %ptr
  ret void
}

define i8 @load_byte_wide_index(i16 %index) {
; XY16-LABEL: load_byte_wide_index:
; XY16: rep #16
; XY16: lda mos24(table),x
; XY16: sep #16
  %offset = zext i16 %index to i32
  %ptr = getelementptr [256 x i8], ptr addrspace(2) @table, i32 0, i32 %offset
  %value = load i8, ptr addrspace(2) %ptr
  ret i8 %value
}

define void @load_memory_index() {
; CHECK-LABEL: load_memory_index:
; CHECK: lda mos24(table),x
  %index = load volatile i8, ptr @index8
  %offset = zext i8 %index to i32
  %ptr = getelementptr [256 x i8], ptr addrspace(2) @table, i32 0, i32 %offset
  %value = load i8, ptr addrspace(2) %ptr
  %wide = zext i8 %value to i16
  store volatile i16 %wide, ptr @sink16
  ret void
}

define void @store_memory_index(i8 %value) {
; CHECK-LABEL: store_memory_index:
; CHECK: sta mos24(output),x
  %index = load volatile i8, ptr @index8
  %offset = zext i8 %index to i32
  %ptr = getelementptr [256 x i8], ptr addrspace(2) @output, i32 0, i32 %offset
  store i8 %value, ptr addrspace(2) %ptr
  ret void
}

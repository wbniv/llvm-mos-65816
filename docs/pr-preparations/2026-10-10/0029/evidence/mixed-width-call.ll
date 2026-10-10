; RUN: llc -mtriple=mos -mcpu=mos6502 -O1 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mos6502 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=mos -mcpu=mos6502 -O3 -verify-machineinstrs < %s | FileCheck %s

; The first call argument also feeds folded arithmetic before the call. Keep
; that value spillable until the call arguments are assigned to registers.
; CHECK-LABEL: stage:
; CHECK: jsr ext
; CHECK: rts
define void @stage(ptr %p, i16 %k) {
  %first = load i16, ptr %p, align 1
  %a = add i16 %first, %k
  %p1 = getelementptr i8, ptr %p, i16 2
  %second = load i16, ptr %p1, align 1
  %b = xor i16 %second, %a
  %p2 = getelementptr i8, ptr %p, i16 4
  %byte = load i8, ptr %p2, align 1
  %blo = trunc i16 %b to i8
  %c = add i8 %byte, %blo
  %call = call i16 @ext(i16 %a, i16 13849)
  %sum = add i16 %call, %b
  store i16 %sum, ptr %p, align 1
  %wide = zext i8 %c to i16
  %difference = sub i16 %b, %wide
  store i16 %difference, ptr %p1, align 1
  %shift = lshr i16 %a, 8
  %ahi = trunc i16 %shift to i8
  %last = xor i8 %c, %ahi
  store i8 %last, ptr %p2, align 1
  ret void
}

declare i16 @ext(i16, i16)

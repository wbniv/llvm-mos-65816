; REQUIRES: asserts
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O2 -debug-only=machine-scheduler \
; RUN:   < %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=SETS
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -O3 -debug-only=machine-scheduler \
; RUN:   < %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=NOSETS

; Under +mos-a16, a 16-bit accumulator value counts toward the pressure sets of
; its low byte, A. Below -O3, it and the 8-bit A also count toward an appended
; A16 set with a limit of 2, so the heuristics see that an 8-bit value live
; across a 16-bit one competes for the same register. That set saves code size
; but costs cycles, so -O3 leaves it out.

target datalayout = "e-m:e-p:16:8-p1:8:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"

@g = global i16 0, align 1
@h = global i16 0, align 1

define void @copy_global_to_global() {
; SETS:         Max Pressure: GPR_LSB=2 GPR_LSB_with_Pc=2 Anyi1=2 Anyi1_with_Pc=2 A16=2 {{$}}
; SETS:         STAImag16 %{{[0-9]+}}:ac16
; SETS:         Pressure Diff      : GPR_LSB 2    GPR_LSB_with_Pc 2    A16 2{{$}}
; NOSETS-NOT:   A16{{[= ]}}
; NOSETS:       Max Pressure: GPR_LSB=2 GPR_LSB_with_Pc=2 Anyi1=2 Anyi1_with_Pc=2 {{$}}
; NOSETS:       STAImag16 %{{[0-9]+}}:ac16
; NOSETS:       Pressure Diff      : GPR_LSB 2    GPR_LSB_with_Pc 2{{$}}
; NOSETS-NOT:   A16{{[= ]}}
  %v = load volatile i16, ptr @g, align 1
  store volatile i16 %v, ptr @h, align 1
  ret void
}

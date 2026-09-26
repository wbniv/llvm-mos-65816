; RUN: llc -mtriple=mos -mcpu=mosw65816 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,DEFAULT
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,NATIVE
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,NATIVE

@g = global i16 0, align 1
@h = global i16 0, align 1

declare i16 @produce()

; The ABI supplies an i16 argument in A:X. Absolute byte stores can consume
; those registers directly when no native-width consumer needs the value.
define void @store_arg(i16 %value) {
; BYTE-LABEL: store_arg:
; BYTE-NEXT: ; %bb.0:
; BYTE-NEXT: sta g
; BYTE-NEXT: stx g+1
; BYTE-NEXT: rts
  store i16 %value, ptr @g, align 1
  ret void
}

define i16 @store_return(i16 %value) {
; BYTE-LABEL: store_return:
; BYTE-NEXT: ; %bb.0:
; BYTE-NEXT: sta g
; BYTE-NEXT: stx g+1
; BYTE-NEXT: rts
  store volatile i16 %value, ptr @g, align 1
  ret i16 %value
}

define void @store_twice(i16 %value) {
; BYTE-LABEL: store_twice:
; BYTE-NOT: rep
; BYTE-NOT: __rc
; BYTE-DAG: sta g
; BYTE-DAG: stx g+1
; BYTE-DAG: sta h
; BYTE-DAG: stx h+1
; BYTE-NEXT: rts
  store volatile i16 %value, ptr @g, align 1
  store volatile i16 %value, ptr @h, align 1
  ret void
}

; Call results use the same byte-register ABI as arguments.
define void @store_call() {
; BYTE-LABEL: store_call:
; BYTE-NEXT: ; %bb.0:
; BYTE-NEXT: jsr produce
; BYTE-NEXT: sta g
; BYTE-NEXT: stx g+1
; BYTE-NEXT: rts
  %value = call i16 @produce()
  store i16 %value, ptr @g, align 1
  ret void
}

; Native producers retain a native store so the value stays in the wide path.
define void @store_add(i16 %value) {
; NATIVE-LABEL: store_add:
; NATIVE: rep #32
; NATIVE: adc #mos16(42)
; NATIVE-NEXT: sta g
; NATIVE-NEXT: sep #32
; NATIVE-NEXT: rts
; DEFAULT-LABEL: store_add:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %sum = add i16 %value, 42
  store i16 %sum, ptr @g, align 1
  ret void
}

define void @store_copy() {
; NATIVE-LABEL: store_copy:
; NATIVE: rep #[[WIDTH:(16|32)]]
; NATIVE-NEXT: ld{{[axy]}} h
; NATIVE-NEXT: st{{[axy]}} g
; NATIVE-NEXT: sep #[[WIDTH]]
; NATIVE-NEXT: rts
; DEFAULT-LABEL: store_copy:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %value = load volatile i16, ptr @h, align 1
  store volatile i16 %value, ptr @g, align 1
  ret void
}

; A byte-built argument stored before a unit increment can stay in A:X.
define i16 @store_mixed(i16 %value) {
; NATIVE-LABEL: store_mixed:
; NATIVE-NOT: rep #32
; NATIVE: sta g
; NATIVE: stx g+1
; NATIVE: inc
; NATIVE: rts
; DEFAULT-LABEL: store_mixed:
; DEFAULT-NOT: rep
; DEFAULT: rts
  store i16 %value, ptr @g, align 1
  %sum = add i16 %value, 1
  ret i16 %sum
}

; A value live across a call needs preserved storage. One native reload and store
; can consume that pair without two separate byte reloads.
declare void @opaque()
define void @store_across_call(i16 %value) {
; NATIVE-LABEL: store_across_call:
; NATIVE: jsr opaque
; NATIVE-NEXT: rep #32
; NATIVE-NEXT: lda __rc20
; NATIVE-NEXT: sta g
; NATIVE-NEXT: sep #32
; NATIVE: rts
; DEFAULT-LABEL: store_across_call:
; DEFAULT-NOT: rep
; DEFAULT: rts
  call void @opaque()
  store volatile i16 %value, ptr @g, align 1
  ret void
}

; The argument can cross a call along one predecessor of the store block.
define void @store_cross_block(i16 %value, i1 %condition) {
; NATIVE-LABEL: store_cross_block:
; NATIVE: jsr opaque
; NATIVE: rep #32
; NATIVE-NEXT: lda __rc20
; NATIVE-NEXT: sta g
; NATIVE-NEXT: sep #32
; NATIVE: rts
; DEFAULT-LABEL: store_cross_block:
; DEFAULT-NOT: rep
; DEFAULT: rts
  br i1 %condition, label %call, label %store
call:
  call void @opaque()
  br label %store
store:
  store volatile i16 %value, ptr @g, align 1
  ret void
}

; Clobbering inline assembly can require the same preservation as a call.
define void @store_across_asm(i16 %value) {
; NATIVE-LABEL: store_across_asm:
; NATIVE: ;APP
; NATIVE: ;NO_APP
; NATIVE: rep #32
; NATIVE: sta g
; NATIVE: sep #32
; NATIVE: rts
; DEFAULT-LABEL: store_across_asm:
; DEFAULT-NOT: rep
; DEFAULT: rts
  call void asm sideeffect "", "~{a},~{x},~{y}"()
  store volatile i16 %value, ptr @g, align 1
  ret void
}

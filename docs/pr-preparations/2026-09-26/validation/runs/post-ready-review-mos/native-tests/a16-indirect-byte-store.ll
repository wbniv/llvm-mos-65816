; RUN: llc -mtriple=mos -mcpu=mosw65816 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,DEFAULT
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,NATIVE
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,NATIVE

@g = global i16 0, align 2
@h = global i16 0, align 1
declare void @opaque()

; The pointer already occupies an imaginary pair, while the value arrives in A:X.
; A single indirect store can use those bytes directly in the ambient M8/X8 mode.
define void @store_indirect(ptr %p, i16 %value) {
; BYTE-LABEL: store_indirect:
; BYTE-NEXT: ; %bb.0:
; BYTE-NEXT: sta (__rc2)
; BYTE-NEXT: ldy #1
; BYTE-NEXT: txa
; BYTE-NEXT: sta (__rc2),y
; BYTE-NEXT: rts
  store i16 %value, ptr %p, align 1
  ret void
}

; Volatile stores preserve both bytes and their low-to-high order.
define void @store_volatile(ptr %p, i16 %value) {
; BYTE-LABEL: store_volatile:
; BYTE-NEXT: ; %bb.0:
; BYTE-NEXT: sta (__rc2)
; BYTE-NEXT: ldy #1
; BYTE-NEXT: txa
; BYTE-NEXT: sta (__rc2),y
; BYTE-NEXT: rts
  store volatile i16 %value, ptr %p, align 1
  ret void
}

; The byte-valued return also consumes the original low byte after the stores.
define i16 @store_and_return(ptr %p, i16 %value) {
; BYTE-LABEL: store_and_return:
; BYTE-NOT: rep
; BYTE: sta (__rc2)
; BYTE: sta (__rc2),y
; BYTE: lda __rc4
; BYTE-NEXT: rts
  store volatile i16 %value, ptr %p, align 1
  ret i16 %value
}

; Sharing the value across stores changes its register and reload costs.
define void @store_twice(ptr %p, ptr %q, i16 %value) {
; NATIVE-LABEL: store_twice:
; NATIVE: rep #32
; NATIVE: sta (__rc2)
; NATIVE: sta (__rc4)
; NATIVE: sep #32
; DEFAULT-LABEL: store_twice:
; DEFAULT-NOT: rep
; DEFAULT: rts
  store volatile i16 %value, ptr %p, align 1
  store volatile i16 %value, ptr %q, align 1
  ret void
}

define void @store_absolute_and_indirect(ptr %p, i16 %value) {
; NATIVE-LABEL: store_absolute_and_indirect:
; NATIVE: rep #32
; NATIVE: sta (__rc2)
; NATIVE: sta g
; NATIVE: sep #32
; DEFAULT-LABEL: store_absolute_and_indirect:
; DEFAULT-NOT: rep
; DEFAULT: rts
  store i16 %value, ptr %p, align 1
  store volatile i16 %value, ptr @g, align 1
  ret void
}

; Indexed addressing retains its native-width store.
define void @store_offset(ptr %p, i16 %value) {
; NATIVE-LABEL: store_offset:
; NATIVE: rep #32
; NATIVE: sta (__rc2),y
; NATIVE: sep #32
; DEFAULT-LABEL: store_offset:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %q = getelementptr i16, ptr %p, i16 1
  store i16 %value, ptr %q, align 1
  ret void
}

; A native producer can feed the wide store without splitting its result.
define void @store_computed(ptr %p, i16 %value) {
; NATIVE-LABEL: store_computed:
; NATIVE: rep #32
; NATIVE: adc #mos16(42)
; NATIVE-NEXT: sta (__rc2)
; NATIVE-NEXT: sep #32
; DEFAULT-LABEL: store_computed:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %sum = add i16 %value, 42
  store i16 %sum, ptr %p, align 1
  ret void
}

; Intervening arithmetic changes both A:X residency and the current width.
define void @store_native_context(ptr %p, i16 %value) {
; NATIVE-LABEL: store_native_context:
; NATIVE: rep #32
; NATIVE: adc #mos16(42)
; NATIVE: sta (__rc2)
; NATIVE-NEXT: sep #32
; DEFAULT-LABEL: store_native_context:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %old = load volatile i16, ptr @h, align 1
  %sum = add i16 %old, 42
  store volatile i16 %sum, ptr @h, align 1
  store i16 %value, ptr %p, align 1
  ret void
}

; A call requires the argument to survive in preserved storage.
define void @store_across_call(ptr %p, i16 %value) {
; NATIVE-LABEL: store_across_call:
; NATIVE: jsr opaque
; NATIVE: rep #32
; NATIVE: sta (__rc{{[0-9]+}})
; NATIVE: sep #32
; DEFAULT-LABEL: store_across_call:
; DEFAULT-NOT: rep
; DEFAULT: rts
  call void @opaque()
  store i16 %value, ptr %p, align 1
  ret void
}

; Later arguments already reside in imaginary registers and favor a wide load.
define void @store_later_argument(ptr %p, i16 %first, i16 %value) {
; NATIVE-LABEL: store_later_argument:
; NATIVE: rep #32
; NATIVE: sta (__rc2)
; NATIVE: sep #32
; DEFAULT-LABEL: store_later_argument:
; DEFAULT-NOT: rep
; DEFAULT: rts
  store i16 %value, ptr %p, align 1
  store volatile i16 %first, ptr @g, align 1
  ret void
}

; Atomic word stores require the native single-instruction memory access. The
; function attribute enables that path even in the default-feature RUN above.
define void @store_atomic(ptr %p, i16 %value) #0 {
; BYTE-LABEL: store_atomic:
; BYTE: rep #32
; BYTE: sta (__rc2)
; BYTE-NEXT: sep #32
; BYTE-NEXT: rts
  store atomic i16 %value, ptr %p unordered, align 2
  ret void
}

; The same atomic contract applies to absolute stores and shared values.
define void @store_atomic_absolute(i16 %value) #0 {
; BYTE-LABEL: store_atomic_absolute:
; BYTE: rep #32
; BYTE: sta g
; BYTE-NEXT: sep #32
; BYTE-NEXT: rts
  store atomic i16 %value, ptr @g unordered, align 2
  ret void
}

define void @store_atomic_shared(i16 %value) #0 {
; BYTE-LABEL: store_atomic_shared:
; BYTE: rep #32
; BYTE: sta g
; BYTE: sta h
; BYTE-NEXT: sep #32
; BYTE-NEXT: rts
  store atomic i16 %value, ptr @g unordered, align 2
  store volatile i16 %value, ptr @h, align 1
  ret void
}

attributes #0 = { "target-features"="+mos-a16" }

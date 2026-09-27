; RUN: llc -mtriple=mos -mcpu=mosw65816 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,DEFAULT
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,NATIVE
; RUN: llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16,+mos-xy16 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=BYTE,NATIVE

@g = global i16 0, align 1
@byte = global i8 0
declare i16 @produce()
declare void @opaque()

; Canonical subtraction by one must preserve the stored value and return its
; decremented value, including borrow from the high byte.
define i16 @absolute_decrement(i16 %value) {
; BYTE-LABEL: absolute_decrement:
; BYTE-NOT: rep
; BYTE: sta g
; BYTE-NEXT: stx g+1
; BYTE-NEXT: dec
; BYTE: dex
; BYTE: rts
  store volatile i16 %value, ptr @g, align 1
  %result = sub i16 %value, 1
  ret i16 %result
}

; A plain pointer argument and one byte-returned increment permit byte stores.
define i16 @indirect_increment(ptr %p, i16 %value) {
; BYTE-LABEL: indirect_increment:
; BYTE-NOT: rep
; BYTE: sta (__rc2)
; BYTE: sta (__rc2),y
; BYTE: inc
; BYTE: bne
; BYTE: inc
; BYTE: rts
  store volatile i16 %value, ptr %p, align 1
  %result = add i16 %value, 1
  ret i16 %result
}

; The native store preserves the low byte for the byte decrement sequence.
define i16 @indirect_decrement(ptr %p, i16 %value) {
; NATIVE-LABEL: indirect_decrement:
; NATIVE: rep #32
; NATIVE: sta (__rc2)
; NATIVE: sep #32
; NATIVE: dec
; NATIVE: dex
; NATIVE: rts
; DEFAULT-LABEL: indirect_decrement:
; DEFAULT-NOT: rep
; DEFAULT: dec
; DEFAULT: rts
  store volatile i16 %value, ptr %p, align 1
  %result = sub i16 %value, 1
  ret i16 %result
}

; The returned A:X bytes are available after the zero-size call-frame pseudo.
define void @indirect_call_result(ptr %p) {
; BYTE-LABEL: indirect_call_result:
; BYTE-NOT: rep
; BYTE: jsr produce
; BYTE-NEXT: sta (__rc{{[0-9]+}})
; BYTE-NEXT: ldy #1
; BYTE-NEXT: txa
; BYTE-NEXT: sta (__rc{{[0-9]+}}),y
; BYTE: rts
  %value = call i16 @produce()
  store volatile i16 %value, ptr %p, align 1
  ret void
}

; A zero high byte needs one immediate byte value rather than a wide reload.
define void @indirect_byte_argument(ptr %p, i8 %value) {
; BYTE-LABEL: indirect_byte_argument:
; BYTE-NOT: rep
; BYTE: sta (__rc2)
; BYTE-NEXT: ldy #1
; BYTE-NEXT: lda #0
; BYTE-NEXT: sta (__rc2),y
; BYTE-NEXT: rts
  %wide = zext i8 %value to i16
  store volatile i16 %wide, ptr %p, align 1
  ret void
}

; The volatile byte source is read once, before the two ordered store bytes.
define void @indirect_byte_absolute(ptr %p) {
; BYTE-LABEL: indirect_byte_absolute:
; BYTE-NOT: rep
; BYTE: lda byte
; BYTE-NEXT: sta (__rc2)
; BYTE-NEXT: ldy #1
; BYTE-NEXT: lda #0
; BYTE-NEXT: sta (__rc2),y
; BYTE-NEXT: rts
  %value = load volatile i8, ptr @byte
  %wide = zext i8 %value to i16
  store volatile i16 %wide, ptr %p, align 1
  ret void
}

define void @indirect_byte_pointer(ptr %p, ptr %q) {
; BYTE-LABEL: indirect_byte_pointer:
; BYTE-NOT: rep
; BYTE: lda (__rc4)
; BYTE-NEXT: sta (__rc2)
; BYTE-NEXT: ldy #1
; BYTE-NEXT: lda #0
; BYTE-NEXT: sta (__rc2),y
; BYTE-NEXT: rts
  %value = load volatile i8, ptr %q
  %wide = zext i8 %value to i16
  store volatile i16 %wide, ptr %p, align 1
  ret void
}

; Loading the destination pointer consumes A, so the word value stays native.
define void @loaded_pointer(ptr %pp, i16 %value) {
; NATIVE-LABEL: loaded_pointer:
; NATIVE: rep #32
; NATIVE: sta (__rc{{[0-9]+}})
; NATIVE: sep #32
; NATIVE: rts
; DEFAULT-LABEL: loaded_pointer:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %p = load ptr, ptr %pp, align 1
  store volatile i16 %value, ptr %p, align 1
  ret void
}

; Values live across calls require preserved storage.
define void @byte_across_call(ptr %p, i8 %value) {
; NATIVE-LABEL: byte_across_call:
; NATIVE: jsr opaque
; NATIVE: rep #32
; NATIVE: sta (__rc{{[0-9]+}})
; NATIVE: sep #32
; NATIVE: rts
; DEFAULT-LABEL: byte_across_call:
; DEFAULT: jsr opaque
; DEFAULT: rts
  call void @opaque()
  %wide = zext i8 %value to i16
  store volatile i16 %wide, ptr %p, align 1
  ret void
}

; A native consumer of the increment result retains native arithmetic and stores.
define void @indirect_native_result(ptr %p, i16 %value) {
; NATIVE-LABEL: indirect_native_result:
; NATIVE: rep #32
; NATIVE: sta (__rc2)
; NATIVE: inc
; NATIVE: sta g
; NATIVE: sep #32
; NATIVE: rts
; DEFAULT-LABEL: indirect_native_result:
; DEFAULT-NOT: rep
; DEFAULT: rts
  store volatile i16 %value, ptr %p, align 1
  %result = add i16 %value, 1
  store volatile i16 %result, ptr @g, align 1
  ret void
}

; Independent word arithmetic between the byte argument and store keeps the
; profitable native context even when the extension is adjacent to the store.
define void @byte_native_context(ptr %p, i8 %value) {
; NATIVE-LABEL: byte_native_context:
; NATIVE: rep #32
; NATIVE: adc #mos16(42)
; NATIVE: sta g
; NATIVE: sta (__rc2)
; NATIVE: sep #32
; NATIVE: rts
; DEFAULT-LABEL: byte_native_context:
; DEFAULT-NOT: rep
; DEFAULT: rts
  %old = load volatile i16, ptr @g, align 1
  %sum = add i16 %old, 42
  store volatile i16 %sum, ptr @g, align 1
  %wide = zext i8 %value to i16
  store volatile i16 %wide, ptr %p, align 1
  ret void
}

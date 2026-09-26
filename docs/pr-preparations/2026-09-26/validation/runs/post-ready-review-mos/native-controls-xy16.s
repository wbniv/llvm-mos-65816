	.zeropage	__rc0
	.zeropage	__rc1
	.zeropage	__rc2
	.zeropage	__rc3
	.zeropage	__rc4
	.zeropage	__rc5
	.zeropage	__rc6
	.zeropage	__rc7
	.zeropage	__rc8
	.zeropage	__rc9
	.zeropage	__rc10
	.zeropage	__rc11
	.zeropage	__rc12
	.zeropage	__rc13
	.zeropage	__rc14
	.zeropage	__rc15
	.zeropage	__rc16
	.zeropage	__rc17
	.zeropage	__rc18
	.zeropage	__rc19
	.zeropage	__rc20
	.zeropage	__rc21
	.zeropage	__rc22
	.zeropage	__rc23
	.zeropage	__rc24
	.zeropage	__rc25
	.zeropage	__rc26
	.zeropage	__rc27
	.zeropage	__rc28
	.zeropage	__rc29
	.zeropage	__rc30
	.zeropage	__rc31
	.file	"review-controls.ll"
	.text
	.globl	signed_byte_index               ; -- Begin function signed_byte_index
	.type	signed_byte_index,@function
signed_byte_index:                      ; @signed_byte_index
; %bb.0:
	sta	__rc3
	tax
	bpl	.LBB0_2
; %bb.1:
	ldx	#255
	stx	__rc2
	bra	.LBB0_3
.LBB0_2:
	stz	__rc2
.LBB0_3:
	lda	#mos24segmentlo(table)
	clc
	adc	__rc3
	sta	__rc4
	lda	#mos24segmenthi(table)
	adc	__rc2
	sta	__rc5
	lda	#mos24bank(table)
	adc	__rc2
	sta	__rc6
	lda	#0
	adc	__rc2
	sta	__rc7
	lda	[__rc4]
	rts
.Lfunc_end0:
	.size	signed_byte_index, .Lfunc_end0-signed_byte_index
                                        ; -- End function
	.globl	scaled_wide_index               ; -- Begin function scaled_wide_index
	.type	scaled_wide_index,@function
scaled_wide_index:                      ; @scaled_wide_index
; %bb.0:
	stx	__rc2
	asl
	sta	__rc3
	rol	__rc2
	lda	#0
	stz	__rc4
	rol	__rc4
	rol
	sta	__rc5
	lda	#mos24segmentlo(table)
	clc
	adc	__rc3
	sta	__rc8
	lda	#mos24segmenthi(table)
	adc	__rc2
	sta	__rc9
	lda	#mos24bank(table)
	adc	__rc4
	sta	__rc10
	lda	#0
	adc	__rc5
	sta	__rc11
	lda	[__rc8]
	rts
.Lfunc_end1:
	.size	scaled_wide_index, .Lfunc_end1-scaled_wide_index
                                        ; -- End function
	.globl	far_atomic_return               ; -- Begin function far_atomic_return
	.type	far_atomic_return,@function
far_atomic_return:                      ; @far_atomic_return
; %bb.0:
	rep	#32
	lda	mos24(farword)
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	rts
.Lfunc_end2:
	.size	far_atomic_return, .Lfunc_end2-far_atomic_return
                                        ; -- End function
	.globl	far_atomic_store_arg            ; -- Begin function far_atomic_store_arg
	.type	far_atomic_store_arg,@function
far_atomic_store_arg:                   ; @far_atomic_store_arg
; %bb.0:
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sta	mos24(farword)
	sep	#32
	rts
.Lfunc_end3:
	.size	far_atomic_store_arg, .Lfunc_end3-far_atomic_store_arg
                                        ; -- End function
	.globl	far_atomic_store_zero           ; -- Begin function far_atomic_store_zero
	.type	far_atomic_store_zero,@function
far_atomic_store_zero:                  ; @far_atomic_store_zero
; %bb.0:
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	rep	#32
	lda	__rc2
	sta	mos24(farword)
	sep	#32
	rts
.Lfunc_end4:
	.size	far_atomic_store_zero, .Lfunc_end4-far_atomic_store_zero
                                        ; -- End function
	.globl	near_store_decrement            ; -- Begin function near_store_decrement
	.type	near_store_decrement,@function
near_store_decrement:                   ; @near_store_decrement
; %bb.0:
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sta	nearword
	lda	__rc2
	dec
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	rts
.Lfunc_end5:
	.size	near_store_decrement, .Lfunc_end5-near_store_decrement
                                        ; -- End function
	.globl	near_store_call_increment       ; -- Begin function near_store_call_increment
	.type	near_store_call_increment,@function
near_store_call_increment:              ; @near_store_call_increment
; %bb.0:
	ldy	__rc20
	phy
	ldy	__rc21
	phy
	sta	__rc20
	stx	__rc21
	rep	#32
	lda	__rc20
	sta	nearword
	sep	#32
	jsr	opaque
	rep	#32
	lda	__rc20
	inc
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	ply
	sty	__rc21
	ply
	sty	__rc20
	rts
.Lfunc_end6:
	.size	near_store_call_increment, .Lfunc_end6-near_store_call_increment
                                        ; -- End function
	.globl	volatile_order                  ; -- Begin function volatile_order
	.type	volatile_order,@function
volatile_order:                         ; @volatile_order
; %bb.0:
	rep	#32
	lda	mos24(farword)
	sta	nearword
	lda	mos24(farword)
	sta	nearword
	sep	#32
	rts
.Lfunc_end7:
	.size	volatile_order, .Lfunc_end7-volatile_order
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

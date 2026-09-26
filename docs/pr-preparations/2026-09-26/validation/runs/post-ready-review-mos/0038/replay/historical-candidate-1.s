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
	.file	"return-frame-address.ll"
	.text
	.globl	return_address                  ; -- Begin function return_address
	.type	return_address,@function
return_address:                         ; @return_address
; %bb.0:
	tsx
	lda	257,x
	sta	__rc2
	tsx
	lda	258,x
	sta	__rc3
	inc	__rc2
	bne	.LBB0_2
; %bb.1:
	inc	__rc3
.LBB0_2:
	rts
.Lfunc_end0:
	.size	return_address, .Lfunc_end0-return_address
                                        ; -- End function
	.globl	return_address_after_push       ; -- Begin function return_address_after_push
	.type	return_address_after_push,@function
return_address_after_push:              ; @return_address_after_push
; %bb.0:
	sta	__rc16
	lda	__rc20
	pha
	lda	__rc16
	sta	__rc20
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	jsr	sink
	lda	__rc20
	jsr	keep
	tsx
	lda	258,x
	sta	__rc2
	tsx
	lda	259,x
	sta	__rc3
	inc	__rc2
	bne	.LBB1_2
; %bb.1:
	inc	__rc3
.LBB1_2:
	pla
	sta	__rc20
	rts
.Lfunc_end1:
	.size	return_address_after_push, .Lfunc_end1-return_address_after_push
                                        ; -- End function
	.globl	return_address_level_1          ; -- Begin function return_address_level_1
	.type	return_address_level_1,@function
return_address_level_1:                 ; @return_address_level_1
; %bb.0:
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	rts
.Lfunc_end2:
	.size	return_address_level_1, .Lfunc_end2-return_address_level_1
                                        ; -- End function
	.globl	isr                             ; -- Begin function isr
	.type	isr,@function
isr:                                    ; @isr
; %bb.0:
	cld
	pha
	clc
	lda	__rc0
	adc	#253
	sta	__rc0
	lda	__rc1
	adc	#254
	sta	__rc1
	pla
	pha
	txa
	pha
	tya
	pha
	lda	__rc2
	pha
	lda	__rc3
	ldy	#2
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc16
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc17
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	__rc2
	ldy	__rc3
	stx	slot
	sty	slot+1
	ldy	#0
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc17
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc16
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	pla
	sta	__rc2
	pla
	tay
	pla
	tax
	pla
	pha
	clc
	lda	__rc0
	adc	#3
	sta	__rc0
	lda	__rc1
	adc	#1
	sta	__rc1
	pla
	rti
.Lfunc_end3:
	.size	isr, .Lfunc_end3-isr
                                        ; -- End function
	.globl	frame_address                   ; -- Begin function frame_address
	.type	frame_address,@function
frame_address:                          ; @frame_address
; %bb.0:
	clc
	ldx	__rc0
	stx	__rc2
	ldx	__rc1
	stx	__rc3
	rts
.Lfunc_end4:
	.size	frame_address, .Lfunc_end4-frame_address
                                        ; -- End function
	.globl	frame_address_with_frame        ; -- Begin function frame_address_with_frame
	.type	frame_address_with_frame,@function
frame_address_with_frame:               ; @frame_address_with_frame
; %bb.0:
	clc
	lda	__rc0
	adc	#240
	sta	__rc0
	lda	__rc1
	adc	#255
	sta	__rc1
	clc
	ldx	__rc0
	stx	__rc2
	sta	__rc3
	jsr	sink
	clc
	lda	__rc0
	adc	#16
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	clc
	lda	__rc0
	adc	#16
	sta	__rc0
	lda	__rc1
	adc	#0
	sta	__rc1
	rts
.Lfunc_end5:
	.size	frame_address_with_frame, .Lfunc_end5-frame_address_with_frame
                                        ; -- End function
	.globl	frame_address_level_1           ; -- Begin function frame_address_level_1
	.type	frame_address_level_1,@function
frame_address_level_1:                  ; @frame_address_level_1
; %bb.0:
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	rts
.Lfunc_end6:
	.size	frame_address_level_1, .Lfunc_end6-frame_address_level_1
                                        ; -- End function
	.type	slot,@object                    ; @slot
	.bss
	.globl	slot
slot:
	.short	0
	.size	slot, 2

	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that there is something in .bss, so it may need to be zeroed.
	.globl	__do_zero_bss
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

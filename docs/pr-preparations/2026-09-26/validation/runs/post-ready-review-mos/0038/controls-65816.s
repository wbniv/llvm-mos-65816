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
	.file	"additional-controls.ll"
	.text
	.globl	dynamic_frame                   ; -- Begin function dynamic_frame
	.type	dynamic_frame,@function
dynamic_frame:                          ; @dynamic_frame
; %bb.0:
	ldy	__rc30
	phy
	ldy	__rc31
	phy
	ldy	__rc0
	sty	__rc30
	ldy	__rc1
	sty	__rc31
	sta	__rc2
	stx	__rc3
	lda	__rc0
	ldy	__rc1
	sec
	sbc	__rc2
	sta	__rc2
	tya
	sbc	__rc3
	sta	__rc3
	ldx	__rc2
	stx	__rc0
	sta	__rc1
	jsr	sink
	clc
	ldx	__rc30
	stx	__rc2
	ldx	__rc31
	stx	__rc3
	ldx	__rc30
	stx	__rc0
	ldx	__rc31
	stx	__rc1
	plx
	stx	__rc31
	plx
	stx	__rc30
	rts
.Lfunc_end0:
	.size	dynamic_frame, .Lfunc_end0-dynamic_frame
                                        ; -- End function
	.globl	return_address_sign_branch      ; -- Begin function return_address_sign_branch
	.type	return_address_sign_branch,@function
return_address_sign_branch:             ; @return_address_sign_branch
; %bb.0:
	lda	1,s
	sta	__rc2
	lda	2,s
	sta	__rc3
	inc	__rc2
	bne	.LBB1_2
; %bb.1:
	inc	__rc3
.LBB1_2:
	ldx	#0
	stx	__rc4
	ldx	#0
	stx	__rc5
	ldx	__rc2
	lda	__rc3
	cpx	__rc4
	sbc	__rc5
	bvc	.LBB1_4
; %bb.3:
	eor	#128
.LBB1_4:
	tax
	bpl	.LBB1_6
; %bb.5:                                ; %then
	jmp	yes
.LBB1_6:                                ; %else
	jmp	no
.Lfunc_end1:
	.size	return_address_sign_branch, .Lfunc_end1-return_address_sign_branch
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

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
	.file	"near-index-proofs.ll"
	.text
	.globl	far_rt_blit                     ; -- Begin function far_rt_blit
	.type	far_rt_blit,@function
far_rt_blit:                            ; @far_rt_blit
; %bb.0:                                ; %entry
	sta	__rc8
	stx	__rc9
	ldx	__rc2
	stx	__rc10
	ldx	__rc3
	stx	__rc11
	stz	__rc3
	ldy	#0
.LBB0_1:                                ; %loop
                                        ; =>This Inner Loop Header: Depth=1
	lda	[__rc8],y
	sta	__rc12
	sty	__rc2
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	lda	__rc12
	sta	(__rc6)
	iny
	cpy	#64
	bne	.LBB0_1
; %bb.2:                                ; %exit
	rts
.Lfunc_end0:
	.size	far_rt_blit, .Lfunc_end0-far_rt_blit
                                        ; -- End function
	.globl	wrapping_blit                   ; -- Begin function wrapping_blit
	.type	wrapping_blit,@function
wrapping_blit:                          ; @wrapping_blit
; %bb.0:                                ; %entry
	sta	__rc8
	stx	__rc9
	ldx	__rc2
	stx	__rc10
	ldx	__rc3
	stx	__rc11
	stz	__rc3
	ldy	#0
.LBB1_1:                                ; %loop
                                        ; =>This Inner Loop Header: Depth=1
	lda	[__rc8],y
	sta	__rc12
	sty	__rc2
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	lda	__rc12
	sta	(__rc6)
	iny
	cpy	#64
	bne	.LBB1_1
; %bb.2:                                ; %exit
	rts
.Lfunc_end1:
	.size	wrapping_blit, .Lfunc_end1-wrapping_blit
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

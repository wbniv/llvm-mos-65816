; vramup M=0 (misched off), REORDERED: the lda $2b/sta $24 pointer copy sunk below the store (upper bound)
	.section	.text.vramup_m0_nmr,"ax",@progbits
vramup_m0_nmr:
	tax
	bne	L1
	jmp	L3
L1:
	tax
	ldy	#1
	lda	$25
	sta	$28
	lda	$26
	sta	$29
	lda	$27
	sta	$2a
L2:
	lda	$24
	phy
	ldy	$28
	sty	$25
	ldy	$29
	sty	$26
	ldy	$2a
	sty	$27
	ply
	dex
	clc
	adc	#2
	sta	$2b
	lda	$28
	adc	#0
	sta	$28
	lda	$29
	adc	#0
	sta	$29
	lda	$2a
	adc	#0
	sta	$2a
	rep	#32
	lda	[$24]
	sta	8472
	sep	#32
	lda	$2b
	sta	$24
	txa
	beq	L3
	jmp	L2
L3:
	rts

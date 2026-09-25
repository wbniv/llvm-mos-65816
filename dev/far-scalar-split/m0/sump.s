; sump M=0: compiler -S (+mos-a16 -Os) with the byte-split [dp]/[dp],y load replaced by rep; lda [dp]
	.section	.text.sump_m0,"ax",@progbits
sump_m0:
	tax
	bne	L1
	jmp	L3
L1:
	tax
	stz	$22
	ldy	#1
	stz	$23
L2:
	lda	$24
	phy
	ldy	$25
	sty	$29
	ply
	sta	$28
	rep	#32
	lda	[$24]
	clc
	adc	$22
	sta	$22
	sep	#32
	lda	$28
	dex
	clc
	adc	#2
	sta	$24
	lda	$29
	adc	#0
	sta	$25
	lda	$26
	adc	#0
	sta	$26
	lda	$27
	adc	#0
	sta	$27
	txa
	beq	L4
	jmp	L2
L3:
	stz	$22
	stz	$23
L4:
	ldx	$23
	lda	$22
	rts
.Lfunc_end4:

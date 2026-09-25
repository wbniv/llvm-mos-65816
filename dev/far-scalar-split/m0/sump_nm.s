; sump M=0 (misched off): compiler -S (+mos-a16 -Os -enable-misched=false), same single edit
	.section	.text.sump_m0_nm,"ax",@progbits
sump_m0_nm:
	tax
	bne	L1
	jmp	L3
L1:
	tax
	stz	$22
	ldy	#1
	stz	$23
	lda	$24
	phy
	ldy	$25
	sty	$29
	ldy	$26
	sty	$2a
	ldy	$27
	sty	$2b
	ply
L2:
	sta	$24
	phy
	ldy	$29
	sty	$25
	ldy	$2a
	sty	$26
	ldy	$2b
	sty	$27
	ply
	dex
	clc
	adc	#2
	sta	$28
	lda	$29
	adc	#0
	sta	$29
	lda	$2a
	adc	#0
	sta	$2a
	lda	$2b
	adc	#0
	sta	$2b
	rep	#32
	lda	[$24]
	clc
	adc	$22
	sta	$22
	sep	#32
	lda	$28
	cpx	#0
	beq	L4
	jmp	L2
L3:
	stz	$22
	stz	$23
L4:
	lda	$22
	ldx	$23
	rts
.Lfunc_end4:

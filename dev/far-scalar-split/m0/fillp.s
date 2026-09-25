; fillp M=0: compiler -S (+mos-a16 -Os; misched on == off) with the split store replaced by rep; lda; sta [dp]; sep
	.section	.text.fillp_m0,"ax",@progbits
fillp_m0:
	ldy	out
	sty	$22
	ldy	out+1
	tax
	bne	L1
	jmp	L3
L1:
	tax
	sty	$23
	ldy	#1
	lda	$24
	sta	$28
	lda	$25
	sta	$29
	lda	$26
	sta	$2a
	lda	$27
	sta	$2b
L2:
	lda	$28
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
	lda	$22
	sta	[$24]
	sep	#32
	txa
	bne	L2
L3:
	rts
.Lfunc_end5:

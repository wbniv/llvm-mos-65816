; vramup M=0: compiler -S (+mos-a16 -Os); byte-split load+reassembly -> rep; lda [dp]. Dead ldy #1 left in.
	.section	.text.vramup_m0,"ax",@progbits
vramup_m0:
	tax
	beq	L3
	tax
	ldy	#1
L2:
	rep	#32
	lda	[$24]
	sta	8472
	sep	#32
	lda	$24
	dex
	clc
	adc	#2
	sta	$24
	lda	$25
	adc	#0
	sta	$25
	lda	$26
	adc	#0
	sta	$26
	lda	$27
	adc	#0
	sta	$27
	txa
	bne	L2
L3:
	rts

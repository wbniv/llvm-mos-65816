; sumw: same, bf only (no adc long,X): sum kept in DP.
	.text
sumw_lxnoalu:
	rep	#$20
	stz	$20
	ldx	#0
L:
	lda	mos24(tw),x
	clc
	adc	$20
	sta	$20
	inx
	inx
	cpx	#$40
	bne	L
	lda	$20
	sta	mos16(out)
	sep	#$20
	rts

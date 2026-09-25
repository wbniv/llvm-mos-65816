; sumw: s += tw[j], j<32. Scaled 2*j <= 62 -> fits X=8-bit under +mos-a16. adc long,X (7f) fold.
	.text
sumw_lx:
	rep	#$20
	lda	#mos16(0)
	ldx	#0
L:
	clc
	adc	mos24(tw),x
	inx
	inx
	cpx	#$40
	bne	L
	sta	mos16(out)
	sep	#$20
	rts

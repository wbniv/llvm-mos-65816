; copyw: dstw[j] = tw[j], j<32. X=8-bit, lda long,X (M=0) + sta abs,X.
	.text
copyw_lx:
	rep	#$20
	ldx	#0
L:
	lda	mos24(tw),x
	sta	mos16(dstw),x
	inx
	inx
	cpx	#$40
	bne	L
	sep	#$20
	rts

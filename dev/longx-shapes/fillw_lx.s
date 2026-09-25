; fillw: ww[j] = x, j<32, far WRAM word array. sta long,X (9f), X=8-bit.
	.text
fillw_lx:
	rep	#$20
	lda	mos16(base)
	ldx	#0
L:
	sta	mos24(ww),x
	inx
	inx
	cpx	#$40
	bne	L
	sep	#$20
	rts

; ga: out = tb[i], uint8_t i, far byte table. +mos-a16, X=8-bit: fits lda long,X directly.
	.text
ga_lx:
	ldx	mos16(k8)
	lda	mos24(tb),x
	sta	$20
	stz	$21
	rep	#$20
	lda	$20
	sta	mos16(out)
	sep	#$20
	rts

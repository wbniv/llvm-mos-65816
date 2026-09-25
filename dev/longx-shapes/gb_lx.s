; gb: out = tb[i], uint16_t i. 16-bit index -> needs X16: +mos-xy16 rep/sep #$10 bracket.
	.text
gb_lx:
	rep	#$10
	ldx	mos16(k)
	lda	mos24(tb),x
	sep	#$10
	sta	$20
	stz	$21
	rep	#$20
	lda	$20
	sta	mos16(out)
	sep	#$20
	rts

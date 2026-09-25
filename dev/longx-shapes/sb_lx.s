; sb: ww[i] = v, uint16_t i, far WRAM word array. Needs X16 + i < 32768 proof.
	.text
sb_lx:
	rep	#$30
	lda	mos16(k)
	asl
	tax
	lda	mos16(v)
	sta	mos24(ww),x
	sep	#$30
	rts

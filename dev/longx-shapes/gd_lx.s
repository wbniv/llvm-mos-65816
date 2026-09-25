; gd: out = tw[i], uint16_t i. Needs X16 AND a proof 2*i < 65536 (i < 32768).
	.text
gd_lx:
	rep	#$30
	lda	mos16(k)
	asl
	tax
	lda	mos24(tw),x
	sta	mos16(out)
	sep	#$30
	rts

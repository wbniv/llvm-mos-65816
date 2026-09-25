; gc: out = tw[i], uint8_t i, far WORD table. Scaled offset 2*i <= 510 > 255 -> needs X16 (+mos-xy16).
	.text
gc_lx:
	lda	mos16(k8)
	rep	#$30
	and	#mos16($ff)
	asl
	tax
	lda	mos24(tw),x
	sta	mos16(out)
	sep	#$30
	rts

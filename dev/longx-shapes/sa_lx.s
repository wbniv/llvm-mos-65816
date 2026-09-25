; sa: wb[i] = (uint8_t)v, uint8_t i, far WRAM byte array. X=8-bit: sta long,X (9f).
	.text
sa_lx:
	ldx	mos16(k8)
	rep	#$20
	lda	mos16(v)
	sep	#$20
	sta	mos24(wb),x
	rts

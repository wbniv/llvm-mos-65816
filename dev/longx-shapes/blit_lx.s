; blit: dst[j] = tab[o+j], o runtime uint16_t, j<64. o is 16-bit -> X16 (+mos-xy16).
	.text
blit_lx:
	rep	#$10
	ldx	mos16(base)
	ldy	#mos16(0)
L:
	lda	mos24(tab),x
	sta	mos16(dst),y
	inx
	iny
	cpy	#mos16($40)
	bne	L
	sep	#$10
	rts

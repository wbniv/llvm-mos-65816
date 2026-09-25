; xc: same, no fold: 16-bit lda long + near cmp.
	.text
xc_ld16:
	sta	$20
	stx	$21
	rep	#$20
	lda	mos24(fg)
	cmp	$20
	sep	#$20
	ldx	#0
	bne	1f
	lda	#1
	rts
1:	lda	#0
	rts

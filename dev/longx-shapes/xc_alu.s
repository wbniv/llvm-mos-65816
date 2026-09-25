; xc: return x == fg. Long-form compare fold: cmp long (cf).
	.text
xc_alu:
	sta	$20
	stx	$21
	rep	#$20
	lda	$20
	cmp	mos24(fg)
	sep	#$20
	ldx	#0
	bne	1f
	lda	#1
	rts
1:	lda	#0
	rts

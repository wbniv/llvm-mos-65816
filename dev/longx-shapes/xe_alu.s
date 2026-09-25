; xe: return x ^ fg (far scalar). Long-form ALU fold: eor long (4f).
	.text
xe_alu:
	sta	$20
	stx	$21
	rep	#$20
	lda	$20
	eor	mos24(fg)
	sta	$20
	sep	#$20
	ldx	$21
	lda	$20
	rts

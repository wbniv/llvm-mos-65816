; xe: same, NO ALU fold -- one 16-bit lda long (af, M=0) + near eor. Isolates the fold from the load width.
	.text
xe_ld16:
	sta	$20
	stx	$21
	rep	#$20
	lda	mos24(fg)
	eor	$20
	sta	$20
	sep	#$20
	ldx	$21
	lda	$20
	rts

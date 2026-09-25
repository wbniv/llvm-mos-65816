; copyw via [dp],Y instead (the sibling mode), for a head-to-head: DP pointer built once.
	.text
copyw_dpy:
	rep	#$20
	lda	#mos16(tw)
	sta	$20
	sep	#$20
	lda	#mos24bank(tw)
	sta	$22
	rep	#$20
	ldy	#0
L:
	lda	[$20],y
	sta	mos16(dstw),y
	iny
	iny
	cpy	#$40
	bne	L
	sep	#$20
	rts

	.text
blit:
	rep	#$20
	lda	$1234
	clc
	adc	#$8000
	sta	$20
	sep	#$20
	lda	#$c1
	adc	#$00
	sta	$22
	ldy	#$00
L:
	lda	[$20]
	sta	$0500,y
	inc	$20
	bne	1f
	inc	$21
	bne	1f
	inc	$22
1:
	iny
	cpy	#$40
	bne	L
	rts

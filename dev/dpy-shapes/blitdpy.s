	.text
blit:
	rep	#$20
	lda	$1234           ; base (16-bit)
	clc
	adc	#$8000          ; lo16(tab)
	sta	$20             ; p.lo/p.hi  (16-bit DP store)
	sep	#$20
	lda	#$c1            ; bank(tab)
	adc	#$00
	sta	$22
	ldy	#$00
L:
	lda	[$20],y
	sta	$0500,y
	iny
	cpy	#$40
	bne	L
	rts

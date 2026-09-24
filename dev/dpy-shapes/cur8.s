	.text
	ldx	$1234
	stx	$20
	lda	#$00
	clc
	adc	$20
	sta	$21
	lda	#$80
	adc	#$00
	sta	$22
	stz	$20
	lda	#$c1
	adc	#$00
	sta	$23
	lda	#$00
	adc	#$00
	sta	$24
	lda	[$21]
	sta	$25

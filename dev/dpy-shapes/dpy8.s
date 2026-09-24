	.text
	ldy	$1234
	lda	#$00
	sta	$21
	lda	#$80
	sta	$22
	lda	#$c1
	sta	$23
	lda	[$21],y
	sta	$25

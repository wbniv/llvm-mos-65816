; tick: fc = fc + fg, M=0 far loads/store, NO ALU fold (adc long). Compare: near-analog (fold) 18 B.
	.section	.text.tick_nofold,"ax",@progbits
tick_nofold:
	rep	#32
	lda	mos24(fc)
	sta	$22
	lda	mos24(fg)
	clc
	adc	$22
	sta	mos24(fc)
	sep	#32
	rts

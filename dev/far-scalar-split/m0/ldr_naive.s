; ldr: return fg (A:X) -- what an UNGATED M=0 rule would emit (native load -> Imag16 -> bytes).
; The loss case (governing lesson 2): today's byte path is 12 B. Phase 2 must keep AllUsesUnmerge.
	.section	.text.ldr_naive,"ax",@progbits
ldr_naive:
	rep	#32
	lda	mos24(fg)
	sta	$22
	sep	#32
	ldx	$23
	lda	$22
	rts

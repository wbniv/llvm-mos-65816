	.zeropage	__rc0
	.zeropage	__rc1
	.zeropage	__rc2
	.zeropage	__rc3
	.zeropage	__rc4
	.zeropage	__rc5
	.zeropage	__rc6
	.zeropage	__rc7
	.zeropage	__rc8
	.zeropage	__rc9
	.zeropage	__rc10
	.zeropage	__rc11
	.zeropage	__rc12
	.zeropage	__rc13
	.zeropage	__rc14
	.zeropage	__rc15
	.zeropage	__rc16
	.zeropage	__rc17
	.zeropage	__rc18
	.zeropage	__rc19
	.zeropage	__rc20
	.zeropage	__rc21
	.zeropage	__rc22
	.zeropage	__rc23
	.zeropage	__rc24
	.zeropage	__rc25
	.zeropage	__rc26
	.zeropage	__rc27
	.zeropage	__rc28
	.zeropage	__rc29
	.zeropage	__rc30
	.zeropage	__rc31
	.file	"scal-to-vec3.c"
	.text
	.globl	main                            ; -- Begin function main
	.type	main,@function
main:                                   ; @main
; %bb.0:
	sta	__rc16
	clc
	lda	__rc0
	adc	#32
	sta	__rc0
	lda	__rc1
	adc	#252
	sta	__rc1
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	lda	__rc16
	pha
	lda	__rc24
	ldy	#16
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc25
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc26
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc27
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc28
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc29
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc30
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc31
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	pla
	sta	__rc6
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	tya
	sta	(__rc4),y
	sty	__rc8
	iny
	sta	(__rc4),y
	tya
	sta	__rc7
	clc
	lda	__rc0
	adc	#220
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	lda	__rc6
	ldy	__rc8
	sta	(__rc4),y
	txa
	ldy	__rc7
	sta	(__rc4),y
	lda	__rc2
	ldx	__rc3
	clc
	pha
	lda	__rc0
	adc	#218
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y
	sty	__rc4
	ldy	__rc7
	txa
	sta	(__rc2),y
	ldx	#1
	stx	__rc2
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	ldy	__rc4
	tya
	sta	(__rc20),y
	sty	__rc6
	ldy	__rc2
	sta	(__rc20),y
	ldx	#1
	stx	__rc11
	ldy	#2
	lda	#128
	sta	(__rc20),y
	tax
	stx	__rc7
	ldx	#2
	stx	__rc4
	iny
	lda	#63
	sta	(__rc20),y
	tax
	stx	__rc8
	ldx	#3
	stx	__rc5
	clc
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	sep	#32
	iny
	lda	__rc6
	sta	(__rc20),y
	inx
	ldy	__rc11
	sta	(__rc2),y
	ldy	__rc4
	sta	(__rc2),y
	sty	__rc12
	lda	#64
	ldy	__rc5
	sta	(__rc2),y
	sty	__rc4
	clc
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	ldy	#8
	lda	__rc6
	sta	(__rc20),y
	tya
	sta	__rc9
	lda	__rc6
	ldy	__rc11
	sta	(__rc2),y
	lda	#64
	ldy	__rc12
	sta	(__rc2),y
	ldy	__rc4
	sta	(__rc2),y
	sty	__rc10
	clc
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc20),y
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc7
	clc
	lda	__rc0
	adc	#144
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	ldy	__rc6
	tya
	sta	(__rc2),y
	sty	__rc12
	ldy	__rc11
	sty	__rc6
	ldy	__rc6
	sta	(__rc2),y
	lda	__rc12
	ldy	__rc7
	sta	(__rc2),y
	ldy	__rc10
	sta	(__rc2),y
	sty	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	ldy	#5
	sta	__rc10
	sta	(__rc2),y
	ldy	#5
	sty	__rc12
	iny
	lda	#240
	sta	(__rc2),y
	ldy	#6
	sty	__rc14
	iny
	lda	__rc8
	sta	(__rc2),y
	ldy	#7
	sty	__rc13
	ldy	__rc11
	lda	#64
	sta	(__rc4),y
	sty	__rc8
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	__rc10
	ldy	__rc12
	sta	(__rc4),y
	ldy	__rc14
	sta	(__rc4),y
	lda	#64
	ldy	__rc13
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc9
	sta	(__rc2),y
	sty	__rc11
	ldy	__rc6
	sta	(__rc4),y
	sty	__rc2
	ldy	__rc7
	sta	(__rc4),y
	sty	__rc3
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	stx	__rc5
	ldy	__rc10
	lda	(__rc20),y
	tax
	sty	__rc8
	clc
	ldy	__rc2
	lda	(__rc20),y
	sta	__rc9
	sty	__rc12
	ldy	__rc3
	lda	(__rc20),y
	sta	__rc6
	sty	__rc10
	ldy	__rc7
	lda	(__rc20),y
	sta	__rc7
	sty	__rc4
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc5
	lda	(__rc20),y
	sta	__rc23
	ldy	__rc12
	lda	(__rc2),y
	sta	__rc25
	sty	__rc5
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc22
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc11
	lda	(__rc20),y
	sta	__rc31
	ldy	__rc5
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc30
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#11
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#10
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc29
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#24
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	stx	__rc4
	ldx	__rc9
	stx	__rc5
	ldx	__rc8
	stx	__rc2
	ldy	#64
	sty	__rc3
	txa
	stx	__rc24
	jsr	__addsf3
	pha
	clc
	lda	__rc0
	adc	#12
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#21
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#23
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#22
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc23
	stx	__rc4
	ldx	__rc25
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc24
	stx	__rc2
	ldy	#64
	sty	__rc3
	ldy	__rc22
	sty	__rc7
	txa
	jsr	__addsf3
	sta	__rc23
	stx	__rc22
	ldx	__rc2
	stx	__rc25
	ldx	__rc3
	stx	__rc26
	ldx	__rc31
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc24
	stx	__rc2
	ldy	#64
	sty	__rc3
	ldy	__rc30
	sty	__rc7
	txa
	jsr	__addsf3
	sta	__rc27
	stx	__rc28
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	clc
	lda	__rc0
	adc	#11
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#10
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc24
	stx	__rc2
	ldy	#64
	sty	__rc3
	clc
	lda	__rc0
	adc	#24
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	txa
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#176
	sta	__rc10
	lda	__rc1
	adc	#3
	php
	sta	__rc11
	ldy	__rc24
	sty	__rc17
	clc
	lda	__rc0
	adc	#12
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc9
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#21
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc8
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#23
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc12
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#22
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc23
	sta	(__rc10),y
	lda	__rc22
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc14
	lda	__rc25
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc15
	lda	__rc26
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldx	#8
	stx	__rc8
	lda	__rc27
	ldy	__rc8
	sta	(__rc10),y
	lda	__rc28
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc30
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc31
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldx	#12
	stx	__rc13
	lda	__rc6
	ldy	__rc13
	sta	(__rc10),y
	lda	__rc7
	ldy	__rc14
	sta	(__rc4),y
	sty	__rc6
	lda	__rc2
	ldy	__rc15
	sta	(__rc4),y
	sty	__rc7
	lda	__rc3
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc4
	clc
	lda	__rc0
	adc	#96
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	ldy	__rc9
	tya
	sta	(__rc2),y
	sty	__rc11
	ldy	__rc6
	sta	(__rc2),y
	lda	__rc11
	ldy	__rc7
	sta	(__rc2),y
	sty	__rc9
	lda	#64
	ldy	__rc4
	sta	(__rc2),y
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	lda	__rc11
	ldx	#4
	stx	__rc10
	ldy	__rc10
	sta	(__rc2),y
	ldy	__rc6
	sta	(__rc4),y
	sty	__rc12
	ldy	__rc9
	sta	(__rc4),y
	ldy	__rc7
	lda	#64
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	__rc11
	ldy	__rc8
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc12
	sta	(__rc4),y
	ldy	__rc9
	sta	(__rc4),y
	sty	__rc8
	lda	#64
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc11
	ldy	__rc13
	sta	(__rc2),y
	ldy	__rc12
	sta	(__rc4),y
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc9
	lda	#64
	ldy	__rc7
	sta	(__rc4),y
	sty	__rc4
	ldy	__rc11
	lda	(__rc2),y
	sta	__rc8
	sty	__rc7
	ldy	__rc12
	lda	(__rc2),y
	tax
	sty	__rc15
	clc
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc9
	sty	__rc14
	ldy	__rc4
	lda	(__rc2),y
	sty	__rc18
	sta	__rc12
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc10
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#50
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc15
	lda	(__rc4),y
	sty	__rc19
	pha
	php
	clc
	lda	__rc0
	adc	#48
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc4),y
	sty	__rc15
	ldy	#171
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc18
	lda	(__rc4),y
	ldy	#170
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc6
	lda	(__rc2),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#111
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc6
	pha
	php
	clc
	lda	__rc0
	adc	#51
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc15
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#46
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc18
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#47
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc10
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc13
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#110
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#49
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc15
	lda	(__rc4),y
	ldy	#235
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc17
	ldy	#234
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc11
	ldy	__rc7
	lda	(__rc20),y
	sta	__rc4
	ldy	__rc6
	lda	(__rc20),y
	sty	__rc13
	sta	__rc5
	ldy	__rc15
	lda	(__rc20),y
	sty	__rc10
	sta	__rc6
	ldy	__rc11
	lda	(__rc20),y
	sta	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	ldy	#4
	lda	(__rc20),y
	sta	__rc22
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc23
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc11
	lda	(__rc2),y
	sta	__rc26
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc30
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc29
	ldy	__rc11
	lda	(__rc2),y
	sta	__rc28
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	sta	__rc21
	ldy	#1
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc20
	ldy	#3
	lda	(__rc2),y
	sta	__rc24
	ldy	__rc9
	sty	__rc2
	ldy	__rc12
	sty	__rc3
	lda	__rc8
	jsr	__addsf3
	ldy	#202
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#171
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc23
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	ldx	__rc26
	stx	__rc7
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#50
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc25
	stx	__rc26
	ldx	__rc2
	stx	__rc22
	ldx	__rc3
	stx	__rc23
	clc
	lda	__rc0
	adc	#46
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#47
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc30
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	clc
	lda	__rc0
	adc	#51
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#111
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc27
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	ldy	#235
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc31
	stx	__rc5
	ldx	__rc20
	stx	__rc6
	ldx	__rc24
	stx	__rc7
	clc
	lda	__rc0
	adc	#49
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#110
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#202
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#203
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#204
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	ldy	#205
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc25
	sta	(__rc8),y
	lda	__rc26
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc22
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc27
	sta	(__rc8),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc30
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_1
.LBB0_1:
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_2
.LBB0_2:                                ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_3
	jmp	.LBB0_10
.LBB0_3:                                ;   in Loop: Header=BB0_2 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_7
	jmp	.LBB0_4
.LBB0_4:                                ;   in Loop: Header=BB0_2 Depth=1
	ldy	__rc2
	bne	.LBB0_7
	jmp	.LBB0_5
.LBB0_5:                                ;   in Loop: Header=BB0_2 Depth=1
	cpx	#0
	bne	.LBB0_7
	jmp	.LBB0_6
.LBB0_6:                                ;   in Loop: Header=BB0_2 Depth=1
	tax
	bne	.LBB0_7
	jmp	.LBB0_8
.LBB0_7:
	jsr	abort
.LBB0_8:                                ;   in Loop: Header=BB0_2 Depth=1
	jmp	.LBB0_9
.LBB0_9:                                ;   in Loop: Header=BB0_2 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_2
.LBB0_10:
	sep	#32
	jmp	.LBB0_11
.LBB0_11:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	iny
	lda	(__rc20),y
	ldx	#1
	stx	__rc10
	sta	__rc5
	clc
	iny
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	sta	__rc24
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	iny
	lda	(__rc2),y
	sta	__rc22
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sta	__rc29
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc27
	ldy	#2
	lda	(__rc2),y
	sta	__rc30
	iny
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#37
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#28
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#38
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#39
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	__rc8
	sty	__rc6
	ldy	__rc9
	sty	__rc7
	ldy	#0
	sty	__rc2
	stx	__rc3
	stx	__rc23
	ldx	#0
	tya
	jsr	__subsf3
	pha
	clc
	lda	__rc0
	adc	#25
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#27
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc28
	clc
	lda	__rc0
	adc	#26
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc24
	stx	__rc4
	ldx	__rc26
	stx	__rc5
	ldx	__rc31
	stx	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc22
	stx	__rc7
	ldx	#0
	tya
	jsr	__subsf3
	sta	__rc31
	stx	__rc22
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc26
	ldx	__rc29
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc25
	stx	__rc7
	ldx	#0
	txa
	jsr	__subsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#37
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#28
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#38
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	clc
	lda	__rc0
	adc	#39
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	tya
	jsr	__subsf3
	sta	__rc7
	stx	__rc8
	clc
	lda	__rc0
	adc	#176
	sta	__rc10
	lda	__rc1
	adc	#3
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#25
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#27
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc14
	ldy	#2
	lda	__rc28
	sta	(__rc10),y
	sty	__rc9
	iny
	sty	__rc17
	clc
	lda	__rc0
	adc	#26
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc31
	sta	(__rc10),y
	sty	__rc13
	lda	__rc22
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc9
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc15
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldx	#8
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc12
	ldy	__rc14
	lda	__rc27
	sta	(__rc4),y
	sty	__rc18
	ldy	__rc9
	lda	__rc29
	sta	(__rc4),y
	sty	__rc14
	lda	__rc30
	ldy	__rc15
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldx	#12
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	stx	__rc9
	lda	__rc8
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc14
	sta	(__rc4),y
	sty	__rc7
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	clc
	lda	__rc0
	adc	#64
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	ldy	__rc6
	lda	#0
	sta	(__rc2),y
	sty	__rc14
	ldy	__rc18
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc7
	sta	(__rc2),y
	sty	__rc10
	tax
	lda	__rc23
	ldy	__rc15
	sta	(__rc2),y
	sty	__rc8
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc13
	txa
	sta	(__rc2),y
	sty	__rc7
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc11
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc12
	txa
	sta	(__rc2),y
	sty	__rc8
	ldy	__rc6
	sta	(__rc4),y
	sty	__rc13
	ldy	__rc10
	sta	(__rc4),y
	tax
	lda	__rc23
	ldy	__rc11
	sta	(__rc4),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc9
	txa
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc9
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	ldx	__rc14
	stx	__rc13
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc10
	ldy	__rc9
	lda	(__rc2),y
	tax
	ldy	#1
	sty	__rc9
	clc
	ldy	__rc11
	lda	(__rc2),y
	sta	__rc11
	sty	__rc19
	ldy	__rc12
	lda	(__rc2),y
	sta	__rc12
	sty	__rc22
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc7
	lda	(__rc2),y
	sty	__rc18
	pha
	php
	clc
	lda	__rc0
	adc	#55
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc4),y
	sty	__rc7
	pha
	php
	clc
	lda	__rc0
	adc	#54
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	ldy	#173
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	ldy	#172
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc22
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc8
	lda	(__rc2),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#113
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc19
	pha
	php
	clc
	lda	__rc0
	adc	#57
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc15
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#52
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc8
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc7
	pha
	php
	clc
	lda	__rc0
	adc	#53
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc6
	lda	(__rc2),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#112
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#56
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	ldy	#236
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	ldy	#237
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc20),y
	sta	__rc6
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc4
	sta	__rc5
	ldy	__rc9
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc7
	lda	(__rc20),y
	sty	__rc13
	sta	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc18
	lda	(__rc20),y
	sta	__rc23
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc24
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc26
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc29
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc30
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc21
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc20
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc22
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc11
	sty	__rc2
	ldy	__rc12
	sty	__rc3
	ldy	__rc6
	sty	__rc4
	ldy	__rc8
	sty	__rc6
	lda	__rc10
	jsr	__subsf3
	ldy	#206
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#209
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#173
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc23
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#54
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#55
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc24
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc23
	clc
	lda	__rc0
	adc	#52
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#53
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc26
	stx	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc30
	stx	__rc7
	clc
	lda	__rc0
	adc	#57
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#113
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc26
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	ldy	#236
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc20
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#56
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#112
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#206
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#207
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#209
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	ldy	#208
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc24
	sta	(__rc8),y
	lda	__rc25
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc27
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc13
	sta	(__rc4),y
	ldx	#3
	stx	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc8),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc30
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_12
.LBB0_12:
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_13
.LBB0_13:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_14
	jmp	.LBB0_21
.LBB0_14:                               ;   in Loop: Header=BB0_13 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_18
	jmp	.LBB0_15
.LBB0_15:                               ;   in Loop: Header=BB0_13 Depth=1
	ldy	__rc2
	bne	.LBB0_18
	jmp	.LBB0_16
.LBB0_16:                               ;   in Loop: Header=BB0_13 Depth=1
	cpx	#0
	bne	.LBB0_18
	jmp	.LBB0_17
.LBB0_17:                               ;   in Loop: Header=BB0_13 Depth=1
	tax
	bne	.LBB0_18
	jmp	.LBB0_19
.LBB0_18:
	jsr	abort
.LBB0_19:                               ;   in Loop: Header=BB0_13 Depth=1
	jmp	.LBB0_20
.LBB0_20:                               ;   in Loop: Header=BB0_13 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_13
.LBB0_21:
	sep	#32
	jmp	.LBB0_22
.LBB0_22:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	iny
	lda	(__rc20),y
	ldx	#1
	stx	__rc10
	sta	__rc5
	clc
	iny
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	sta	__rc24
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	iny
	lda	(__rc2),y
	sta	__rc22
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sta	__rc29
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc27
	ldy	#2
	lda	(__rc2),y
	sta	__rc30
	iny
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#40
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#32
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#41
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#42
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	__rc8
	sty	__rc6
	ldy	__rc9
	sty	__rc7
	ldy	#0
	sty	__rc2
	stx	__rc3
	stx	__rc23
	ldx	#0
	tya
	jsr	__mulsf3
	pha
	clc
	lda	__rc0
	adc	#29
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#31
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc28
	clc
	lda	__rc0
	adc	#30
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc24
	stx	__rc4
	ldx	__rc26
	stx	__rc5
	ldx	__rc31
	stx	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc22
	stx	__rc7
	ldx	#0
	tya
	jsr	__mulsf3
	sta	__rc31
	stx	__rc22
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc26
	ldx	__rc29
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc25
	stx	__rc7
	ldx	#0
	txa
	jsr	__mulsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#40
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#41
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	clc
	lda	__rc0
	adc	#42
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	tya
	jsr	__mulsf3
	sta	__rc7
	stx	__rc8
	clc
	lda	__rc0
	adc	#176
	sta	__rc10
	lda	__rc1
	adc	#3
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#29
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#31
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc14
	ldy	#2
	lda	__rc28
	sta	(__rc10),y
	sty	__rc9
	iny
	sty	__rc17
	clc
	lda	__rc0
	adc	#30
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc31
	sta	(__rc10),y
	sty	__rc13
	lda	__rc22
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc9
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc15
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldx	#8
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc12
	ldy	__rc14
	lda	__rc27
	sta	(__rc4),y
	sty	__rc18
	ldy	__rc9
	lda	__rc29
	sta	(__rc4),y
	sty	__rc14
	lda	__rc30
	ldy	__rc15
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldx	#12
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	stx	__rc9
	lda	__rc8
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc14
	sta	(__rc4),y
	sty	__rc7
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	ldy	__rc6
	lda	#0
	sta	(__rc2),y
	sty	__rc14
	ldy	__rc18
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc7
	sta	(__rc2),y
	sty	__rc10
	tax
	lda	__rc23
	ldy	__rc15
	sta	(__rc2),y
	sty	__rc8
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc13
	txa
	sta	(__rc2),y
	sty	__rc7
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc11
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc12
	txa
	sta	(__rc2),y
	sty	__rc8
	ldy	__rc6
	sta	(__rc4),y
	sty	__rc13
	ldy	__rc10
	sta	(__rc4),y
	tax
	lda	__rc23
	ldy	__rc11
	sta	(__rc4),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc9
	txa
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc9
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	ldx	__rc14
	stx	__rc13
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc10
	ldy	__rc9
	lda	(__rc2),y
	tax
	ldy	#1
	sty	__rc9
	clc
	ldy	__rc11
	lda	(__rc2),y
	sta	__rc11
	sty	__rc19
	ldy	__rc12
	lda	(__rc2),y
	sta	__rc12
	sty	__rc22
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc7
	lda	(__rc2),y
	sty	__rc18
	pha
	php
	clc
	lda	__rc0
	adc	#61
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc4),y
	sty	__rc7
	pha
	php
	clc
	lda	__rc0
	adc	#60
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	ldy	#175
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	ldy	#174
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc22
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc8
	lda	(__rc2),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#115
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc19
	pha
	php
	clc
	lda	__rc0
	adc	#63
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc15
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#58
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc8
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc7
	pha
	php
	clc
	lda	__rc0
	adc	#59
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc6
	lda	(__rc2),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#114
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	ldy	#238
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	ldy	#239
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc20),y
	sta	__rc6
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc4
	sta	__rc5
	ldy	__rc9
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc7
	lda	(__rc20),y
	sty	__rc13
	sta	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc18
	lda	(__rc20),y
	sta	__rc23
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc24
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc26
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc29
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc30
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc21
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc20
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc22
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc11
	sty	__rc2
	ldy	__rc12
	sty	__rc3
	ldy	__rc6
	sty	__rc4
	ldy	__rc8
	sty	__rc6
	lda	__rc10
	jsr	__mulsf3
	ldy	#210
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#213
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#175
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc23
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#60
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#61
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc24
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc23
	clc
	lda	__rc0
	adc	#58
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#59
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc26
	stx	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc30
	stx	__rc7
	clc
	lda	__rc0
	adc	#63
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#115
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc26
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	ldy	#238
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc20
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#62
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#114
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#210
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#211
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#213
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	ldy	#212
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc24
	sta	(__rc8),y
	lda	__rc25
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc27
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc13
	sta	(__rc4),y
	ldx	#3
	stx	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc8),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc30
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_23
.LBB0_23:
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_24
.LBB0_24:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_25
	jmp	.LBB0_32
.LBB0_25:                               ;   in Loop: Header=BB0_24 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_29
	jmp	.LBB0_26
.LBB0_26:                               ;   in Loop: Header=BB0_24 Depth=1
	ldy	__rc2
	bne	.LBB0_29
	jmp	.LBB0_27
.LBB0_27:                               ;   in Loop: Header=BB0_24 Depth=1
	cpx	#0
	bne	.LBB0_29
	jmp	.LBB0_28
.LBB0_28:                               ;   in Loop: Header=BB0_24 Depth=1
	tax
	bne	.LBB0_29
	jmp	.LBB0_30
.LBB0_29:
	jsr	abort
.LBB0_30:                               ;   in Loop: Header=BB0_24 Depth=1
	jmp	.LBB0_31
.LBB0_31:                               ;   in Loop: Header=BB0_24 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_24
.LBB0_32:
	sep	#32
	jmp	.LBB0_33
.LBB0_33:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	iny
	lda	(__rc20),y
	ldx	#1
	stx	__rc10
	sta	__rc5
	clc
	iny
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	sta	__rc24
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	iny
	lda	(__rc2),y
	sta	__rc22
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sta	__rc29
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc27
	ldy	#2
	lda	(__rc2),y
	sta	__rc30
	iny
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#43
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#36
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#44
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#45
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	__rc8
	sty	__rc6
	ldy	__rc9
	sty	__rc7
	ldy	#0
	sty	__rc2
	stx	__rc3
	stx	__rc23
	ldx	#0
	tya
	jsr	__divsf3
	pha
	clc
	lda	__rc0
	adc	#33
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#35
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc28
	clc
	lda	__rc0
	adc	#34
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc24
	stx	__rc4
	ldx	__rc26
	stx	__rc5
	ldx	__rc31
	stx	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc22
	stx	__rc7
	ldx	#0
	tya
	jsr	__divsf3
	sta	__rc31
	stx	__rc22
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc26
	ldx	__rc29
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc25
	stx	__rc7
	ldx	#0
	txa
	jsr	__divsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#43
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#36
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#44
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldx	#0
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	clc
	lda	__rc0
	adc	#45
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	tya
	jsr	__divsf3
	sta	__rc7
	stx	__rc8
	clc
	lda	__rc0
	adc	#176
	sta	__rc10
	lda	__rc1
	adc	#3
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#33
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#35
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc14
	ldy	#2
	lda	__rc28
	sta	(__rc10),y
	sty	__rc9
	iny
	sty	__rc17
	clc
	lda	__rc0
	adc	#34
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc10),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc31
	sta	(__rc10),y
	sty	__rc13
	lda	__rc22
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc9
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc15
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldx	#8
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc12
	ldy	__rc14
	lda	__rc27
	sta	(__rc4),y
	sty	__rc18
	ldy	__rc9
	lda	__rc29
	sta	(__rc4),y
	sty	__rc14
	lda	__rc30
	ldy	__rc15
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldx	#12
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	stx	__rc9
	lda	__rc8
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc14
	sta	(__rc4),y
	sty	__rc7
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	clc
	ldx	__rc0
	stx	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	ldy	__rc6
	lda	#0
	sta	(__rc2),y
	sty	__rc14
	ldy	__rc18
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc7
	sta	(__rc2),y
	sty	__rc10
	tax
	lda	__rc23
	ldy	__rc15
	sta	(__rc2),y
	sty	__rc8
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc13
	txa
	sta	(__rc2),y
	sty	__rc7
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc11
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc12
	txa
	sta	(__rc2),y
	sty	__rc8
	ldy	__rc6
	sta	(__rc4),y
	sty	__rc13
	ldy	__rc10
	sta	(__rc4),y
	tax
	lda	__rc23
	ldy	__rc11
	sta	(__rc4),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc9
	txa
	sta	(__rc2),y
	sty	__rc6
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc9
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	ldx	__rc14
	stx	__rc13
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc10
	ldy	__rc9
	lda	(__rc2),y
	tax
	ldy	#1
	sty	__rc9
	clc
	ldy	__rc11
	lda	(__rc2),y
	sta	__rc11
	sty	__rc19
	ldy	__rc12
	lda	(__rc2),y
	sta	__rc12
	sty	__rc22
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc7
	lda	(__rc2),y
	sty	__rc18
	pha
	php
	clc
	lda	__rc0
	adc	#67
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc4),y
	sty	__rc7
	pha
	php
	clc
	lda	__rc0
	adc	#66
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	ldy	#177
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	ldy	#176
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc22
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc8
	lda	(__rc2),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#117
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc19
	pha
	php
	clc
	lda	__rc0
	adc	#69
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc15
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#64
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc8
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc7
	pha
	php
	clc
	lda	__rc0
	adc	#65
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	__rc6
	lda	(__rc2),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#116
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#68
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	ldy	#240
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	ldy	#241
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc20),y
	sta	__rc6
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc4
	sta	__rc5
	ldy	__rc9
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc7
	lda	(__rc20),y
	sty	__rc13
	sta	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc18
	lda	(__rc20),y
	sta	__rc23
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc24
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc26
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc29
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc30
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc21
	ldy	__rc4
	lda	(__rc2),y
	sta	__rc20
	ldy	__rc9
	lda	(__rc2),y
	sta	__rc22
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc11
	sty	__rc2
	ldy	__rc12
	sty	__rc3
	ldy	__rc6
	sty	__rc4
	ldy	__rc8
	sty	__rc6
	lda	__rc10
	jsr	__divsf3
	ldy	#214
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#217
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#177
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc23
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#66
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#67
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc24
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc23
	clc
	lda	__rc0
	adc	#64
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#65
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc26
	stx	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc30
	stx	__rc7
	clc
	lda	__rc0
	adc	#69
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#117
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc26
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	ldy	#240
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc20
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#68
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#116
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#214
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#215
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#217
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	ldy	#216
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc24
	sta	(__rc8),y
	lda	__rc25
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc27
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc13
	sta	(__rc4),y
	ldx	#3
	stx	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc8),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc30
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_34
.LBB0_34:
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_35
.LBB0_35:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_36
	jmp	.LBB0_43
.LBB0_36:                               ;   in Loop: Header=BB0_35 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_40
	jmp	.LBB0_37
.LBB0_37:                               ;   in Loop: Header=BB0_35 Depth=1
	ldy	__rc2
	bne	.LBB0_40
	jmp	.LBB0_38
.LBB0_38:                               ;   in Loop: Header=BB0_35 Depth=1
	cpx	#0
	bne	.LBB0_40
	jmp	.LBB0_39
.LBB0_39:                               ;   in Loop: Header=BB0_35 Depth=1
	tax
	bne	.LBB0_40
	jmp	.LBB0_41
.LBB0_40:
	jsr	abort
.LBB0_41:                               ;   in Loop: Header=BB0_35 Depth=1
	jmp	.LBB0_42
.LBB0_42:                               ;   in Loop: Header=BB0_35 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_35
.LBB0_43:
	sep	#32
	jmp	.LBB0_44
.LBB0_44:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	sta	__rc6
	iny
	lda	(__rc20),y
	sta	__rc7
	ldx	#3
	stx	__rc10
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#13
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	sta	__rc22
	iny
	lda	(__rc2),y
	sta	__rc26
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#14
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	ldy	#243
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc27
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#71
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#70
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#2
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#3
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc6
	sta	__rc2
	lda	__rc7
	sta	__rc3
	sty	__rc4
	sty	__rc5
	sty	__rc6
	sty	__rc23
	stx	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__addsf3
	ldy	#131
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#242
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#130
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc30
	ldx	__rc26
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc28
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#13
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc25
	stx	__rc26
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc31
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	ldy	#243
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#14
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc27
	stx	__rc31
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#2
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#3
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#70
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#71
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#176
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#131
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#242
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	ldy	#130
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc30
	sta	(__rc8),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc25
	sta	(__rc8),y
	lda	__rc26
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc27
	sta	(__rc8),y
	lda	__rc31
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc7
	ldy	__rc11
	lda	__rc2
	sta	(__rc4),y
	sty	__rc6
	lda	__rc3
	ldy	__rc12
	sta	(__rc4),y
	sty	__rc11
	clc
	ldy	#0
	lda	(__rc20),y
	sty	__rc17
	ldy	#41
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc20),y
	ldx	__rc7
	sta	__rc8
	stx	__rc12
	ldy	__rc6
	lda	(__rc20),y
	ldx	__rc6
	sta	__rc2
	stx	__rc10
	ldy	__rc11
	lda	(__rc20),y
	sta	__rc3
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc20),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#106
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#78
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#73
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc10
	ldy	__rc11
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#72
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc6
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#122
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc6),y
	sty	__rc11
	pha
	php
	clc
	lda	__rc0
	adc	#118
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#75
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc6),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#74
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc18
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	lda	__rc0
	adc	#224
	sta	__rc12
	lda	__rc1
	adc	#2
	sta	__rc13
	ldy	__rc9
	lda	#0
	sta	(__rc12),y
	sty	__rc6
	ldx	__rc11
	stx	__rc7
	ldy	__rc7
	sta	(__rc12),y
	ldy	__rc10
	sta	(__rc12),y
	sty	__rc22
	tax
	lda	#64
	ldy	__rc18
	sta	(__rc12),y
	clc
	lda	#12
	tay
	lda	(__rc20),y
	sty	__rc9
	pha
	php
	clc
	lda	__rc0
	adc	#77
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc19
	pha
	php
	clc
	lda	__rc0
	adc	#76
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc4),y
	ldy	#244
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc18
	lda	(__rc4),y
	sty	__rc10
	ldy	#245
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc14
	txa
	sta	(__rc12),y
	ldy	__rc19
	sta	(__rc4),y
	ldy	__rc22
	sta	(__rc4),y
	sty	__rc7
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	txa
	ldy	__rc15
	sta	(__rc12),y
	ldy	__rc19
	sta	(__rc4),y
	sty	__rc11
	ldy	__rc7
	sta	(__rc4),y
	tax
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc9
	txa
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc9
	clc
	ldy	__rc6
	lda	(__rc12),y
	sta	__rc4
	ldy	__rc11
	lda	(__rc12),y
	sta	__rc5
	ldy	__rc7
	lda	(__rc12),y
	sta	__rc6
	sty	__rc14
	ldy	__rc9
	lda	(__rc12),y
	sta	__rc7
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc10
	clc
	sep	#32
	ldy	#4
	lda	(__rc12),y
	sta	__rc20
	ldy	#1
	lda	(__rc10),y
	sta	__rc23
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc25
	ldy	#3
	lda	(__rc10),y
	sta	__rc26
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	#8
	lda	(__rc12),y
	sta	__rc21
	ldy	#1
	lda	(__rc10),y
	sta	__rc22
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc27
	ldy	#3
	lda	(__rc10),y
	sta	__rc24
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc28
	ldy	#1
	lda	(__rc10),y
	sta	__rc29
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc30
	ldy	#3
	lda	(__rc10),y
	sta	__rc31
	ldx	__rc8
	ldy	#41
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	ldy	#218
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#221
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#219
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#73
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#72
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc20
	stx	__rc4
	ldx	__rc23
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	ldx	__rc26
	stx	__rc7
	clc
	lda	__rc0
	adc	#78
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#106
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc25
	stx	__rc20
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc26
	clc
	lda	__rc0
	adc	#75
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#74
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	__rc27
	stx	__rc6
	ldx	__rc24
	stx	__rc7
	clc
	lda	__rc0
	adc	#118
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#122
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc21
	stx	__rc22
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	ldy	#244
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#76
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#77
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#218
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#221
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#219
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	ldy	#220
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc25
	sta	(__rc8),y
	lda	__rc20
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc21
	sta	(__rc8),y
	lda	__rc22
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc27
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_45
.LBB0_45:
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_46
.LBB0_46:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_47
	jmp	.LBB0_54
.LBB0_47:                               ;   in Loop: Header=BB0_46 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_51
	jmp	.LBB0_48
.LBB0_48:                               ;   in Loop: Header=BB0_46 Depth=1
	ldy	__rc2
	bne	.LBB0_51
	jmp	.LBB0_49
.LBB0_49:                               ;   in Loop: Header=BB0_46 Depth=1
	cpx	#0
	bne	.LBB0_51
	jmp	.LBB0_50
.LBB0_50:                               ;   in Loop: Header=BB0_46 Depth=1
	tax
	bne	.LBB0_51
	jmp	.LBB0_52
.LBB0_51:
	jsr	abort
.LBB0_52:                               ;   in Loop: Header=BB0_46 Depth=1
	jmp	.LBB0_53
.LBB0_53:                               ;   in Loop: Header=BB0_46 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_46
.LBB0_54:
	sep	#32
	jmp	.LBB0_55
.LBB0_55:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	sta	__rc6
	iny
	lda	(__rc20),y
	sta	__rc7
	ldx	#3
	stx	__rc10
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#15
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	sta	__rc22
	iny
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#16
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	ldy	#247
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#80
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#79
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#4
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#5
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc6
	sta	__rc2
	lda	__rc7
	sta	__rc3
	sty	__rc4
	sty	__rc5
	sty	__rc6
	sty	__rc23
	stx	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__subsf3
	ldy	#133
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#246
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#132
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc30
	ldx	__rc27
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc28
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#15
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc31
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	ldy	#247
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#16
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc26
	stx	__rc31
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#4
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#5
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#79
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#80
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#176
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#133
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#246
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	ldy	#132
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc30
	sta	(__rc8),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc25
	sta	(__rc8),y
	lda	__rc27
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc8),y
	lda	__rc31
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc6
	ldy	__rc11
	lda	__rc2
	sta	(__rc4),y
	sty	__rc2
	lda	__rc3
	ldy	__rc12
	sta	(__rc4),y
	clc
	ldy	#0
	lda	(__rc20),y
	sty	__rc10
	sta	__rc8
	ldy	__rc6
	lda	(__rc20),y
	ldx	__rc6
	sta	__rc9
	stx	__rc13
	ldy	__rc2
	lda	(__rc20),y
	ldx	__rc2
	sta	__rc2
	stx	__rc11
	ldy	__rc12
	lda	(__rc20),y
	sta	__rc3
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc20),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#107
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#86
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc11
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#82
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc11
	ldy	__rc12
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#81
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc6
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#123
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc6),y
	ldx	__rc13
	pha
	php
	clc
	lda	__rc0
	adc	#119
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc11
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#83
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc6),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#84
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc19
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#2
	sta	__rc13
	ldy	__rc10
	lda	#0
	sta	(__rc12),y
	sty	__rc6
	stx	__rc7
	ldy	__rc7
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc12),y
	sty	__rc22
	tax
	stx	__rc23
	lda	#64
	ldy	__rc19
	sta	(__rc12),y
	clc
	ldx	#12
	txa
	tay
	lda	(__rc20),y
	sty	__rc18
	pha
	php
	clc
	lda	__rc0
	adc	#87
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc20
	pha
	php
	clc
	lda	__rc0
	adc	#85
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc4),y
	ldy	#248
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc10
	ldy	#249
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc14
	lda	__rc23
	sta	(__rc12),y
	ldy	__rc20
	sta	(__rc4),y
	ldy	__rc22
	sta	(__rc4),y
	sty	__rc7
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	#0
	ldy	__rc15
	sta	(__rc12),y
	ldy	__rc20
	sta	(__rc4),y
	sty	__rc11
	ldy	__rc7
	sta	(__rc4),y
	tax
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc18
	txa
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc4
	clc
	ldy	__rc6
	lda	(__rc12),y
	tax
	ldy	__rc11
	lda	(__rc12),y
	sta	__rc5
	ldy	__rc7
	lda	(__rc12),y
	sta	__rc6
	sty	__rc14
	ldy	__rc4
	lda	(__rc12),y
	sta	__rc7
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc10
	clc
	sep	#32
	ldy	#4
	lda	(__rc12),y
	sta	__rc20
	ldy	#1
	lda	(__rc10),y
	sta	__rc23
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc24
	ldy	#3
	lda	(__rc10),y
	sta	__rc26
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	#8
	lda	(__rc12),y
	sta	__rc21
	ldy	#1
	lda	(__rc10),y
	sta	__rc25
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc28
	ldy	#3
	lda	(__rc10),y
	sta	__rc27
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc22
	ldy	#1
	lda	(__rc10),y
	sta	__rc29
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc30
	ldy	#3
	lda	(__rc10),y
	sta	__rc31
	stx	__rc4
	ldx	__rc9
	lda	__rc8
	jsr	__subsf3
	ldy	#222
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#225
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#223
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#82
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#81
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc20
	stx	__rc4
	ldx	__rc23
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc26
	stx	__rc7
	clc
	lda	__rc0
	adc	#86
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#107
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc24
	stx	__rc20
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc26
	clc
	lda	__rc0
	adc	#83
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#84
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc25
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	clc
	lda	__rc0
	adc	#119
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#123
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc21
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc28
	ldy	#248
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#85
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#87
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#222
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#225
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#223
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	ldy	#224
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc24
	sta	(__rc8),y
	lda	__rc20
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc21
	sta	(__rc8),y
	lda	__rc25
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc27
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_56
.LBB0_56:
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_57
.LBB0_57:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_58
	jmp	.LBB0_65
.LBB0_58:                               ;   in Loop: Header=BB0_57 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_62
	jmp	.LBB0_59
.LBB0_59:                               ;   in Loop: Header=BB0_57 Depth=1
	ldy	__rc2
	bne	.LBB0_62
	jmp	.LBB0_60
.LBB0_60:                               ;   in Loop: Header=BB0_57 Depth=1
	cpx	#0
	bne	.LBB0_62
	jmp	.LBB0_61
.LBB0_61:                               ;   in Loop: Header=BB0_57 Depth=1
	tax
	bne	.LBB0_62
	jmp	.LBB0_63
.LBB0_62:
	jsr	abort
.LBB0_63:                               ;   in Loop: Header=BB0_57 Depth=1
	jmp	.LBB0_64
.LBB0_64:                               ;   in Loop: Header=BB0_57 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_57
.LBB0_65:
	sep	#32
	jmp	.LBB0_66
.LBB0_66:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	sta	__rc6
	iny
	lda	(__rc20),y
	sta	__rc7
	ldx	#3
	stx	__rc10
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#17
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	sta	__rc22
	iny
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#18
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	ldy	#251
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#89
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#88
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#6
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#7
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc6
	sta	__rc2
	lda	__rc7
	sta	__rc3
	sty	__rc4
	sty	__rc5
	sty	__rc6
	sty	__rc23
	stx	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsf3
	ldy	#135
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#250
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#134
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc30
	ldx	__rc27
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc28
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#17
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc31
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	ldy	#251
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#18
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc26
	stx	__rc31
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#6
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#7
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#88
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#89
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#176
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#135
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#250
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	ldy	#134
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc30
	sta	(__rc8),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc25
	sta	(__rc8),y
	lda	__rc27
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc8),y
	lda	__rc31
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc6
	ldy	__rc11
	lda	__rc2
	sta	(__rc4),y
	sty	__rc2
	lda	__rc3
	ldy	__rc12
	sta	(__rc4),y
	clc
	ldy	#0
	lda	(__rc20),y
	sty	__rc10
	sta	__rc8
	ldy	__rc6
	lda	(__rc20),y
	ldx	__rc6
	sta	__rc9
	stx	__rc13
	ldy	__rc2
	lda	(__rc20),y
	ldx	__rc2
	sta	__rc2
	stx	__rc11
	ldy	__rc12
	lda	(__rc20),y
	sta	__rc3
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc20),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#108
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#95
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc11
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#91
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc11
	ldy	__rc12
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#90
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc6
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#124
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc6),y
	ldx	__rc13
	pha
	php
	clc
	lda	__rc0
	adc	#120
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc11
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#92
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc6),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#93
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc19
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	lda	__rc0
	adc	#160
	sta	__rc12
	lda	__rc1
	adc	#2
	sta	__rc13
	ldy	__rc10
	lda	#0
	sta	(__rc12),y
	sty	__rc6
	stx	__rc7
	ldy	__rc7
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc12),y
	sty	__rc22
	tax
	stx	__rc23
	lda	#64
	ldy	__rc19
	sta	(__rc12),y
	clc
	ldx	#12
	txa
	tay
	lda	(__rc20),y
	sty	__rc18
	pha
	php
	clc
	lda	__rc0
	adc	#96
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc20
	pha
	php
	clc
	lda	__rc0
	adc	#94
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc4),y
	ldy	#252
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc10
	ldy	#253
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc14
	lda	__rc23
	sta	(__rc12),y
	ldy	__rc20
	sta	(__rc4),y
	ldy	__rc22
	sta	(__rc4),y
	sty	__rc7
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	#0
	ldy	__rc15
	sta	(__rc12),y
	ldy	__rc20
	sta	(__rc4),y
	sty	__rc11
	ldy	__rc7
	sta	(__rc4),y
	tax
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc18
	txa
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc4
	clc
	ldy	__rc6
	lda	(__rc12),y
	tax
	ldy	__rc11
	lda	(__rc12),y
	sta	__rc5
	ldy	__rc7
	lda	(__rc12),y
	sta	__rc6
	sty	__rc14
	ldy	__rc4
	lda	(__rc12),y
	sta	__rc7
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc10
	clc
	sep	#32
	ldy	#4
	lda	(__rc12),y
	sta	__rc20
	ldy	#1
	lda	(__rc10),y
	sta	__rc23
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc24
	ldy	#3
	lda	(__rc10),y
	sta	__rc26
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	#8
	lda	(__rc12),y
	sta	__rc21
	ldy	#1
	lda	(__rc10),y
	sta	__rc25
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc28
	ldy	#3
	lda	(__rc10),y
	sta	__rc27
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc22
	ldy	#1
	lda	(__rc10),y
	sta	__rc29
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc30
	ldy	#3
	lda	(__rc10),y
	sta	__rc31
	stx	__rc4
	ldx	__rc9
	lda	__rc8
	jsr	__mulsf3
	ldy	#226
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#229
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#227
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#91
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#90
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc20
	stx	__rc4
	ldx	__rc23
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc26
	stx	__rc7
	clc
	lda	__rc0
	adc	#95
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#108
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc24
	stx	__rc20
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc26
	clc
	lda	__rc0
	adc	#92
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#93
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc25
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	clc
	lda	__rc0
	adc	#120
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#124
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc21
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc28
	ldy	#252
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#94
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#96
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#226
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#229
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#227
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	ldy	#228
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc24
	sta	(__rc8),y
	lda	__rc20
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc21
	sta	(__rc8),y
	lda	__rc25
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc27
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_67
.LBB0_67:
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_68
.LBB0_68:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_69
	jmp	.LBB0_76
.LBB0_69:                               ;   in Loop: Header=BB0_68 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_73
	jmp	.LBB0_70
.LBB0_70:                               ;   in Loop: Header=BB0_68 Depth=1
	ldy	__rc2
	bne	.LBB0_73
	jmp	.LBB0_71
.LBB0_71:                               ;   in Loop: Header=BB0_68 Depth=1
	cpx	#0
	bne	.LBB0_73
	jmp	.LBB0_72
.LBB0_72:                               ;   in Loop: Header=BB0_68 Depth=1
	tax
	bne	.LBB0_73
	jmp	.LBB0_74
.LBB0_73:
	jsr	abort
.LBB0_74:                               ;   in Loop: Header=BB0_68 Depth=1
	jmp	.LBB0_75
.LBB0_75:                               ;   in Loop: Header=BB0_68 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_68
.LBB0_76:
	sep	#32
	jmp	.LBB0_77
.LBB0_77:
	ldy	#0
	clc
	lda	__rc0
	adc	#192
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	sta	__rc6
	iny
	lda	(__rc20),y
	sta	__rc7
	ldx	#3
	stx	__rc10
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc2
	clc
	sep	#32
	iny
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#19
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	sta	__rc22
	iny
	lda	(__rc2),y
	sta	__rc27
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc25
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	pha
	php
	clc
	lda	__rc0
	adc	#20
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	ldy	#255
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc31
	ldy	__rc10
	lda	(__rc2),y
	sta	__rc26
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	#12
	lda	(__rc20),y
	pha
	clc
	lda	__rc0
	adc	#98
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#97
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#8
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#9
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc6
	sta	__rc2
	lda	__rc7
	sta	__rc3
	sty	__rc4
	sty	__rc5
	sty	__rc6
	sty	__rc23
	stx	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__divsf3
	ldy	#137
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#254
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#136
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc30
	ldx	__rc27
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc28
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#19
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc31
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	ldy	#255
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#20
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc26
	stx	__rc31
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#8
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#9
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#97
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#98
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#176
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#137
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#254
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	ldy	#136
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc30
	sta	(__rc8),y
	sty	__rc12
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc25
	sta	(__rc8),y
	lda	__rc27
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc24
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc8),y
	lda	__rc31
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc12
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc6
	ldy	__rc11
	lda	__rc2
	sta	(__rc4),y
	sty	__rc2
	lda	__rc3
	ldy	__rc12
	sta	(__rc4),y
	clc
	ldy	#0
	lda	(__rc20),y
	sty	__rc10
	sta	__rc8
	ldy	__rc6
	lda	(__rc20),y
	ldx	__rc6
	sta	__rc9
	stx	__rc13
	ldy	__rc2
	lda	(__rc20),y
	ldx	__rc2
	sta	__rc2
	stx	__rc11
	ldy	__rc12
	lda	(__rc20),y
	sta	__rc3
	rep	#32
	lda	__rc20
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc20),y
	sty	__rc14
	pha
	php
	clc
	lda	__rc0
	adc	#109
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#104
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc11
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#100
	sta	__rc6
	lda	__rc1
	adc	#1
	plp
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc11
	ldy	__rc12
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#99
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc6
	clc
	sep	#32
	ldy	#8
	lda	(__rc20),y
	sty	__rc15
	pha
	php
	clc
	lda	__rc0
	adc	#125
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc6),y
	ldx	__rc13
	pha
	php
	clc
	lda	__rc0
	adc	#121
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc11
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#101
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc6),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#102
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc19
	rep	#32
	lda	__rc20
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	lda	__rc0
	adc	#128
	sta	__rc12
	lda	__rc1
	adc	#2
	sta	__rc13
	ldy	__rc10
	lda	#0
	sta	(__rc12),y
	sty	__rc6
	stx	__rc7
	ldy	__rc7
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc12),y
	sty	__rc22
	tax
	stx	__rc23
	lda	#64
	ldy	__rc19
	sta	(__rc12),y
	clc
	ldx	#12
	txa
	tay
	lda	(__rc20),y
	sty	__rc18
	pha
	php
	clc
	lda	__rc0
	adc	#105
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc7
	lda	(__rc4),y
	sty	__rc20
	pha
	php
	clc
	lda	__rc0
	adc	#103
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc4),y
	pha
	php
	clc
	ldx	__rc0
	stx	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc10
	pha
	php
	clc
	lda	__rc0
	adc	#1
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc14
	lda	__rc23
	sta	(__rc12),y
	ldy	__rc20
	sta	(__rc4),y
	ldy	__rc22
	sta	(__rc4),y
	sty	__rc7
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	#0
	ldy	__rc15
	sta	(__rc12),y
	ldy	__rc20
	sta	(__rc4),y
	sty	__rc11
	ldy	__rc7
	sta	(__rc4),y
	tax
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	__rc18
	txa
	sta	(__rc12),y
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	lda	#64
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc4
	clc
	ldy	__rc6
	lda	(__rc12),y
	tax
	ldy	__rc11
	lda	(__rc12),y
	sta	__rc5
	ldy	__rc7
	lda	(__rc12),y
	sta	__rc6
	sty	__rc14
	ldy	__rc4
	lda	(__rc12),y
	sta	__rc7
	rep	#32
	lda	__rc12
	adc	#mos16(4)
	sta	__rc10
	clc
	sep	#32
	ldy	#4
	lda	(__rc12),y
	sta	__rc20
	ldy	#1
	lda	(__rc10),y
	sta	__rc23
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc24
	ldy	#3
	lda	(__rc10),y
	sta	__rc26
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	#8
	lda	(__rc12),y
	sta	__rc21
	ldy	#1
	lda	(__rc10),y
	sta	__rc25
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc28
	ldy	#3
	lda	(__rc10),y
	sta	__rc27
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc22
	ldy	#1
	lda	(__rc10),y
	sta	__rc29
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc30
	ldy	#3
	lda	(__rc10),y
	sta	__rc31
	stx	__rc4
	ldx	__rc9
	lda	__rc8
	jsr	__divsf3
	ldy	#230
	sta	(__rc0),y                       ; 1-byte Folded Spill
	txa
	ldy	#233
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc2
	ldy	#231
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc3
	iny
	sta	(__rc0),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#100
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#99
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc20
	stx	__rc4
	ldx	__rc23
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc26
	stx	__rc7
	clc
	lda	__rc0
	adc	#104
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#109
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc24
	stx	__rc20
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc26
	clc
	lda	__rc0
	adc	#101
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#102
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc25
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	clc
	lda	__rc0
	adc	#121
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#125
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc21
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc28
	clc
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#1
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc22
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	clc
	lda	__rc0
	adc	#103
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#105
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#160
	sta	__rc8
	lda	__rc1
	adc	#3
	sta	__rc9
	ldy	#0
	sty	__rc17
	ldy	#230
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	ldy	#233
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	ldy	#231
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	ldy	#232
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc13
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc24
	sta	(__rc8),y
	lda	__rc20
	ldy	__rc10
	sta	(__rc4),y
	sty	__rc11
	lda	__rc23
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc26
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc10
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc21
	sta	(__rc8),y
	lda	__rc25
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc27
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc6
	sta	(__rc8),y
	lda	__rc7
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc10
	sta	(__rc4),y
	jmp	.LBB0_78
.LBB0_78:
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_79
.LBB0_79:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32772
	bcc	.LBB0_80
	jmp	.LBB0_87
.LBB0_80:                               ;   in Loop: Header=BB0_79 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#4
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	iny
	lda	(__rc6),y
	ldx	#2
	stx	__rc28
	sta	__rc25
	iny
	lda	(__rc6),y
	inx
	stx	__rc29
	sta	__rc26
	ldy	__rc27
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	ldx	#1
	stx	__rc20
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc4
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc5
	ldy	__rc28
	lda	(__rc6),y
	tax
	ldy	__rc29
	lda	(__rc6),y
	ldy	__rc25
	sty	__rc2
	ldy	__rc26
	sty	__rc3
	stx	__rc6
	sta	__rc7
	ldx	__rc23
	lda	__rc22
	jsr	__nesf2
	ldy	__rc3
	bne	.LBB0_84
	jmp	.LBB0_81
.LBB0_81:                               ;   in Loop: Header=BB0_79 Depth=1
	ldy	__rc2
	bne	.LBB0_84
	jmp	.LBB0_82
.LBB0_82:                               ;   in Loop: Header=BB0_79 Depth=1
	cpx	#0
	bne	.LBB0_84
	jmp	.LBB0_83
.LBB0_83:                               ;   in Loop: Header=BB0_79 Depth=1
	tax
	bne	.LBB0_84
	jmp	.LBB0_85
.LBB0_84:
	jsr	abort
.LBB0_85:                               ;   in Loop: Header=BB0_79 Depth=1
	jmp	.LBB0_86
.LBB0_86:                               ;   in Loop: Header=BB0_79 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_79
.LBB0_87:
	sep	#32
	jmp	.LBB0_88
.LBB0_88:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc6
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	iny
	lda	(__rc20),y
	sta	__rc14
	iny
	lda	(__rc20),y
	sta	__rc15
	ldx	#7
	stx	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#182
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#1
	lda	(__rc2),y
	ldy	#179
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	ldy	#180
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#181
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#178
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	ldy	#183
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	#0
	sty	__rc2
	ldy	#0
	sty	__rc3
	ldy	#0
	sty	__rc4
	ldy	#0
	sty	__rc5
	ldy	#0
	sty	__rc6
	stx	__rc7
	ldx	#0
	tya
	jsr	__adddf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	ldx	__rc4
	stx	__rc25
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc23
	ldx	__rc7
	stx	__rc24
	ldy	#182
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	ldy	#179
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc11
	ldy	#178
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc12
	ldx	__rc27
	stx	__rc13
	ldx	__rc28
	stx	__rc14
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	#0
	stx	__rc4
	ldx	#0
	stx	__rc5
	ldx	#0
	stx	__rc6
	ldx	#64
	stx	__rc7
	ldy	#183
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	txa
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc18
	ldy	#2
	lda	__rc30
	sta	(__rc10),y
	sty	__rc27
	iny
	lda	__rc31
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc25
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	inx
	stx	__rc14
	ldy	__rc14
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc10
	lda	__rc2
	ldy	__rc27
	sta	(__rc12),y
	ldx	#2
	stx	__rc11
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	lda	__rc4
	ldy	__rc25
	sta	(__rc12),y
	sty	__rc18
	lda	__rc5
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc4
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc12
	clc
	lda	__rc0
	adc	#96
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	lda	#0
	ldy	__rc15
	sta	(__rc8),y
	sty	__rc2
	ldy	__rc10
	sta	(__rc8),y
	sty	__rc3
	ldy	__rc11
	sta	(__rc8),y
	sty	__rc6
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	stx	__rc7
	ldy	__rc18
	sta	(__rc8),y
	sty	__rc13
	ldy	__rc5
	sta	(__rc8),y
	sty	__rc11
	ldy	__rc4
	sta	(__rc8),y
	ldx	#0
	sty	__rc10
	lda	#64
	ldy	__rc12
	sta	(__rc8),y
	sty	__rc18
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc14
	txa
	sta	(__rc8),y
	sty	__rc12
	ldy	__rc3
	sta	(__rc4),y
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc15
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	#64
	ldy	__rc18
	sta	(__rc4),y
	sty	__rc25
	ldy	__rc2
	lda	(__rc8),y
	ldy	#37
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#33
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	clc
	ldy	__rc6
	lda	(__rc8),y
	tax
	sty	__rc14
	ldy	__rc7
	lda	(__rc8),y
	sta	__rc18
	sty	__rc19
	ldy	__rc15
	lda	(__rc8),y
	sta	__rc4
	sty	__rc24
	ldy	__rc11
	lda	(__rc8),y
	sta	__rc5
	sty	__rc23
	ldy	__rc10
	lda	(__rc8),y
	sta	__rc6
	sty	__rc22
	ldy	__rc25
	lda	(__rc8),y
	sta	__rc7
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	__rc12
	lda	(__rc8),y
	ldy	#141
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	ldy	#140
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	ldy	#138
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	ldy	#46
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#49
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	ldy	#48
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	ldy	#47
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	ldy	#139
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc13
	lda	(__rc20),y
	sty	__rc28
	sta	__rc9
	ldy	__rc26
	lda	(__rc20),y
	sty	__rc2
	sta	__rc26
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc29
	sta	__rc19
	ldy	__rc24
	lda	(__rc20),y
	sty	__rc31
	sta	__rc12
	ldy	__rc23
	lda	(__rc20),y
	sty	__rc30
	sta	__rc13
	ldy	__rc22
	lda	(__rc20),y
	sty	__rc24
	sta	__rc14
	ldy	__rc25
	lda	(__rc20),y
	sty	__rc3
	sta	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc22
	sep	#32
	ldy	__rc27
	lda	(__rc20),y
	ldy	#44
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	ldy	#45
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	ldy	#43
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc29
	lda	(__rc22),y
	sta	__rc27
	ldy	__rc31
	lda	(__rc22),y
	sta	__rc29
	ldy	__rc30
	lda	(__rc22),y
	sta	__rc30
	ldy	__rc24
	lda	(__rc22),y
	sta	__rc25
	ldy	__rc3
	lda	(__rc22),y
	sta	__rc31
	stx	__rc2
	ldx	__rc18
	stx	__rc3
	ldx	__rc26
	stx	__rc10
	ldx	__rc19
	stx	__rc11
	ldy	#33
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#37
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc22
	stx	__rc20
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc21
	ldx	__rc5
	stx	__rc23
	ldx	__rc6
	stx	__rc26
	lda	__rc7
	ldy	#42
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#138
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#46
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#49
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldy	#139
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldy	#44
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	ldy	#43
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	ldx	__rc27
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc30
	stx	__rc13
	ldx	__rc25
	stx	__rc14
	ldx	__rc31
	stx	__rc15
	ldy	#140
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc22
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc20
	sta	(__rc12),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc28
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc21
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc12),y
	sty	__rc21
	inx
	txa
	tay
	sty	__rc17
	ldy	#42
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc22
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc21
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc22
	sta	(__rc4),y
	jmp	.LBB0_89
.LBB0_89:
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_90
.LBB0_90:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_91
	jmp	.LBB0_98
.LBB0_91:                               ;   in Loop: Header=BB0_90 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#31
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#31
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_95
	jmp	.LBB0_92
.LBB0_92:                               ;   in Loop: Header=BB0_90 Depth=1
	ldy	__rc2
	bne	.LBB0_95
	jmp	.LBB0_93
.LBB0_93:                               ;   in Loop: Header=BB0_90 Depth=1
	cpx	#0
	bne	.LBB0_95
	jmp	.LBB0_94
.LBB0_94:                               ;   in Loop: Header=BB0_90 Depth=1
	tax
	bne	.LBB0_95
	jmp	.LBB0_96
.LBB0_95:
	jsr	abort
.LBB0_96:                               ;   in Loop: Header=BB0_90 Depth=1
	jmp	.LBB0_97
.LBB0_97:                               ;   in Loop: Header=BB0_90 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_90
.LBB0_98:
	sep	#32
	jmp	.LBB0_99
.LBB0_99:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc6
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	iny
	lda	(__rc20),y
	sta	__rc14
	iny
	lda	(__rc20),y
	sta	__rc15
	ldx	#7
	stx	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#188
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#1
	lda	(__rc2),y
	ldy	#185
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	ldy	#186
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#187
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#184
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	ldy	#189
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	#0
	sty	__rc2
	ldy	#0
	sty	__rc3
	ldy	#0
	sty	__rc4
	ldy	#0
	sty	__rc5
	ldy	#0
	sty	__rc6
	stx	__rc7
	ldx	#0
	tya
	jsr	__subdf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	ldx	__rc4
	stx	__rc25
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc23
	ldx	__rc7
	stx	__rc24
	ldy	#188
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	ldy	#185
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc11
	ldy	#184
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc12
	ldx	__rc27
	stx	__rc13
	ldx	__rc28
	stx	__rc14
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	#0
	stx	__rc4
	ldx	#0
	stx	__rc5
	ldx	#0
	stx	__rc6
	ldx	#64
	stx	__rc7
	ldy	#189
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	txa
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc18
	ldy	#2
	lda	__rc30
	sta	(__rc10),y
	sty	__rc27
	iny
	lda	__rc31
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc25
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	inx
	stx	__rc14
	ldy	__rc14
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc10
	lda	__rc2
	ldy	__rc27
	sta	(__rc12),y
	ldx	#2
	stx	__rc11
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	lda	__rc4
	ldy	__rc25
	sta	(__rc12),y
	sty	__rc18
	lda	__rc5
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc4
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc12
	clc
	lda	__rc0
	adc	#64
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	lda	#0
	ldy	__rc15
	sta	(__rc8),y
	sty	__rc2
	ldy	__rc10
	sta	(__rc8),y
	sty	__rc3
	ldy	__rc11
	sta	(__rc8),y
	sty	__rc6
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	stx	__rc7
	ldy	__rc18
	sta	(__rc8),y
	sty	__rc13
	ldy	__rc5
	sta	(__rc8),y
	sty	__rc11
	ldy	__rc4
	sta	(__rc8),y
	ldx	#0
	sty	__rc10
	lda	#64
	ldy	__rc12
	sta	(__rc8),y
	sty	__rc18
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc14
	txa
	sta	(__rc8),y
	sty	__rc12
	ldy	__rc3
	sta	(__rc4),y
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc15
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	#64
	ldy	__rc18
	sta	(__rc4),y
	sty	__rc25
	ldy	__rc2
	lda	(__rc8),y
	ldy	#38
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#34
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	clc
	ldy	__rc6
	lda	(__rc8),y
	tax
	sty	__rc14
	ldy	__rc7
	lda	(__rc8),y
	sta	__rc18
	sty	__rc19
	ldy	__rc15
	lda	(__rc8),y
	sta	__rc4
	sty	__rc24
	ldy	__rc11
	lda	(__rc8),y
	sta	__rc5
	sty	__rc23
	ldy	__rc10
	lda	(__rc8),y
	sta	__rc6
	sty	__rc22
	ldy	__rc25
	lda	(__rc8),y
	sta	__rc7
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	__rc12
	lda	(__rc8),y
	ldy	#145
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	ldy	#144
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	ldy	#142
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	ldy	#54
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#57
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	ldy	#56
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	ldy	#55
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	ldy	#143
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc13
	lda	(__rc20),y
	sty	__rc28
	sta	__rc9
	ldy	__rc26
	lda	(__rc20),y
	sty	__rc2
	sta	__rc26
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc29
	sta	__rc19
	ldy	__rc24
	lda	(__rc20),y
	sty	__rc31
	sta	__rc12
	ldy	__rc23
	lda	(__rc20),y
	sty	__rc30
	sta	__rc13
	ldy	__rc22
	lda	(__rc20),y
	sty	__rc24
	sta	__rc14
	ldy	__rc25
	lda	(__rc20),y
	sty	__rc3
	sta	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc22
	sep	#32
	ldy	__rc27
	lda	(__rc20),y
	ldy	#52
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	ldy	#53
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	ldy	#51
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc29
	lda	(__rc22),y
	sta	__rc27
	ldy	__rc31
	lda	(__rc22),y
	sta	__rc29
	ldy	__rc30
	lda	(__rc22),y
	sta	__rc30
	ldy	__rc24
	lda	(__rc22),y
	sta	__rc25
	ldy	__rc3
	lda	(__rc22),y
	sta	__rc31
	stx	__rc2
	ldx	__rc18
	stx	__rc3
	ldx	__rc26
	stx	__rc10
	ldx	__rc19
	stx	__rc11
	ldy	#34
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#38
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc22
	stx	__rc20
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc21
	ldx	__rc5
	stx	__rc23
	ldx	__rc6
	stx	__rc26
	lda	__rc7
	ldy	#50
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#142
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#54
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#57
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldy	#143
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldy	#52
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	ldy	#51
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	ldx	__rc27
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc30
	stx	__rc13
	ldx	__rc25
	stx	__rc14
	ldx	__rc31
	stx	__rc15
	ldy	#144
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc22
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc20
	sta	(__rc12),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc28
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc21
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc12),y
	sty	__rc21
	inx
	txa
	tay
	sty	__rc17
	ldy	#50
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc22
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc21
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc22
	sta	(__rc4),y
	jmp	.LBB0_100
.LBB0_100:
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_101
.LBB0_101:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_102
	jmp	.LBB0_109
.LBB0_102:                              ;   in Loop: Header=BB0_101 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#29
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#29
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_106
	jmp	.LBB0_103
.LBB0_103:                              ;   in Loop: Header=BB0_101 Depth=1
	ldy	__rc2
	bne	.LBB0_106
	jmp	.LBB0_104
.LBB0_104:                              ;   in Loop: Header=BB0_101 Depth=1
	cpx	#0
	bne	.LBB0_106
	jmp	.LBB0_105
.LBB0_105:                              ;   in Loop: Header=BB0_101 Depth=1
	tax
	bne	.LBB0_106
	jmp	.LBB0_107
.LBB0_106:
	jsr	abort
.LBB0_107:                              ;   in Loop: Header=BB0_101 Depth=1
	jmp	.LBB0_108
.LBB0_108:                              ;   in Loop: Header=BB0_101 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_101
.LBB0_109:
	sep	#32
	jmp	.LBB0_110
.LBB0_110:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc6
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	iny
	lda	(__rc20),y
	sta	__rc14
	iny
	lda	(__rc20),y
	sta	__rc15
	ldx	#7
	stx	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#194
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#1
	lda	(__rc2),y
	ldy	#191
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	ldy	#192
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#193
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#190
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	ldy	#195
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	#0
	sty	__rc2
	ldy	#0
	sty	__rc3
	ldy	#0
	sty	__rc4
	ldy	#0
	sty	__rc5
	ldy	#0
	sty	__rc6
	stx	__rc7
	ldx	#0
	tya
	jsr	__muldf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	ldx	__rc4
	stx	__rc25
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc23
	ldx	__rc7
	stx	__rc24
	ldy	#194
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	ldy	#191
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc11
	ldy	#190
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc12
	ldx	__rc27
	stx	__rc13
	ldx	__rc28
	stx	__rc14
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	#0
	stx	__rc4
	ldx	#0
	stx	__rc5
	ldx	#0
	stx	__rc6
	ldx	#64
	stx	__rc7
	ldy	#195
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	txa
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc18
	ldy	#2
	lda	__rc30
	sta	(__rc10),y
	sty	__rc27
	iny
	lda	__rc31
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc25
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	inx
	stx	__rc14
	ldy	__rc14
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc10
	lda	__rc2
	ldy	__rc27
	sta	(__rc12),y
	ldx	#2
	stx	__rc11
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	lda	__rc4
	ldy	__rc25
	sta	(__rc12),y
	sty	__rc18
	lda	__rc5
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc4
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc12
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	lda	#0
	ldy	__rc15
	sta	(__rc8),y
	sty	__rc2
	ldy	__rc10
	sta	(__rc8),y
	sty	__rc3
	ldy	__rc11
	sta	(__rc8),y
	sty	__rc6
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	stx	__rc7
	ldy	__rc18
	sta	(__rc8),y
	sty	__rc13
	ldy	__rc5
	sta	(__rc8),y
	sty	__rc11
	ldy	__rc4
	sta	(__rc8),y
	ldx	#0
	sty	__rc10
	lda	#64
	ldy	__rc12
	sta	(__rc8),y
	sty	__rc18
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc14
	txa
	sta	(__rc8),y
	sty	__rc12
	ldy	__rc3
	sta	(__rc4),y
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc15
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	#64
	ldy	__rc18
	sta	(__rc4),y
	sty	__rc25
	ldy	__rc2
	lda	(__rc8),y
	ldy	#39
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#35
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	clc
	ldy	__rc6
	lda	(__rc8),y
	tax
	sty	__rc14
	ldy	__rc7
	lda	(__rc8),y
	sta	__rc18
	sty	__rc19
	ldy	__rc15
	lda	(__rc8),y
	sta	__rc4
	sty	__rc24
	ldy	__rc11
	lda	(__rc8),y
	sta	__rc5
	sty	__rc23
	ldy	__rc10
	lda	(__rc8),y
	sta	__rc6
	sty	__rc22
	ldy	__rc25
	lda	(__rc8),y
	sta	__rc7
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	__rc12
	lda	(__rc8),y
	ldy	#149
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	ldy	#148
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	ldy	#146
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	ldy	#62
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#65
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	ldy	#64
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	ldy	#63
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	ldy	#147
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc13
	lda	(__rc20),y
	sty	__rc28
	sta	__rc9
	ldy	__rc26
	lda	(__rc20),y
	sty	__rc2
	sta	__rc26
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc29
	sta	__rc19
	ldy	__rc24
	lda	(__rc20),y
	sty	__rc31
	sta	__rc12
	ldy	__rc23
	lda	(__rc20),y
	sty	__rc30
	sta	__rc13
	ldy	__rc22
	lda	(__rc20),y
	sty	__rc24
	sta	__rc14
	ldy	__rc25
	lda	(__rc20),y
	sty	__rc3
	sta	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc22
	sep	#32
	ldy	__rc27
	lda	(__rc20),y
	ldy	#60
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	ldy	#61
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	ldy	#59
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc29
	lda	(__rc22),y
	sta	__rc27
	ldy	__rc31
	lda	(__rc22),y
	sta	__rc29
	ldy	__rc30
	lda	(__rc22),y
	sta	__rc30
	ldy	__rc24
	lda	(__rc22),y
	sta	__rc25
	ldy	__rc3
	lda	(__rc22),y
	sta	__rc31
	stx	__rc2
	ldx	__rc18
	stx	__rc3
	ldx	__rc26
	stx	__rc10
	ldx	__rc19
	stx	__rc11
	ldy	#35
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#39
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc22
	stx	__rc20
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc21
	ldx	__rc5
	stx	__rc23
	ldx	__rc6
	stx	__rc26
	lda	__rc7
	ldy	#58
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#146
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#62
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#65
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldy	#147
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldy	#60
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	ldy	#59
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	ldx	__rc27
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc30
	stx	__rc13
	ldx	__rc25
	stx	__rc14
	ldx	__rc31
	stx	__rc15
	ldy	#148
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc22
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc20
	sta	(__rc12),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc28
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc21
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc12),y
	sty	__rc21
	inx
	txa
	tay
	sty	__rc17
	ldy	#58
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc22
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc21
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc22
	sta	(__rc4),y
	jmp	.LBB0_111
.LBB0_111:
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_112
.LBB0_112:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_113
	jmp	.LBB0_120
.LBB0_113:                              ;   in Loop: Header=BB0_112 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc20
	lda	__rc1
	adc	#2
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#27
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#27
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_117
	jmp	.LBB0_114
.LBB0_114:                              ;   in Loop: Header=BB0_112 Depth=1
	ldy	__rc2
	bne	.LBB0_117
	jmp	.LBB0_115
.LBB0_115:                              ;   in Loop: Header=BB0_112 Depth=1
	cpx	#0
	bne	.LBB0_117
	jmp	.LBB0_116
.LBB0_116:                              ;   in Loop: Header=BB0_112 Depth=1
	tax
	bne	.LBB0_117
	jmp	.LBB0_118
.LBB0_117:
	jsr	abort
.LBB0_118:                              ;   in Loop: Header=BB0_112 Depth=1
	jmp	.LBB0_119
.LBB0_119:                              ;   in Loop: Header=BB0_112 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_112
.LBB0_120:
	sep	#32
	jmp	.LBB0_121
.LBB0_121:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	clc
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc6
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	iny
	lda	(__rc20),y
	sta	__rc14
	iny
	lda	(__rc20),y
	sta	__rc15
	ldx	#7
	stx	__rc7
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#200
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#1
	lda	(__rc2),y
	ldy	#197
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	ldy	#198
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#199
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#196
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	ldy	#201
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldx	#64
	ldy	#0
	sty	__rc2
	ldy	#0
	sty	__rc3
	ldy	#0
	sty	__rc4
	ldy	#0
	sty	__rc5
	ldy	#0
	sty	__rc6
	stx	__rc7
	ldx	#0
	tya
	jsr	__divdf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	ldx	__rc4
	stx	__rc25
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc23
	ldx	__rc7
	stx	__rc24
	ldy	#200
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	ldy	#197
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc11
	ldy	#196
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc12
	ldx	__rc27
	stx	__rc13
	ldx	__rc28
	stx	__rc14
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	#0
	stx	__rc4
	ldx	#0
	stx	__rc5
	ldx	#0
	stx	__rc6
	ldx	#64
	stx	__rc7
	ldy	#201
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	txa
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc18
	ldy	#2
	lda	__rc30
	sta	(__rc10),y
	sty	__rc27
	iny
	lda	__rc31
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc25
	sta	(__rc10),y
	sty	__rc25
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	inx
	stx	__rc14
	ldy	__rc14
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc10
	lda	__rc2
	ldy	__rc27
	sta	(__rc12),y
	ldx	#2
	stx	__rc11
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	lda	__rc4
	ldy	__rc25
	sta	(__rc12),y
	sty	__rc18
	lda	__rc5
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc4
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc12
	clc
	ldy	__rc0
	sty	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	lda	#0
	ldy	__rc15
	sta	(__rc8),y
	sty	__rc2
	ldy	__rc10
	sta	(__rc8),y
	sty	__rc3
	ldy	__rc11
	sta	(__rc8),y
	sty	__rc6
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	stx	__rc7
	ldy	__rc18
	sta	(__rc8),y
	sty	__rc13
	ldy	__rc5
	sta	(__rc8),y
	sty	__rc11
	ldy	__rc4
	sta	(__rc8),y
	ldx	#0
	sty	__rc10
	lda	#64
	ldy	__rc12
	sta	(__rc8),y
	sty	__rc18
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	__rc14
	txa
	sta	(__rc8),y
	sty	__rc12
	ldy	__rc3
	sta	(__rc4),y
	ldy	__rc6
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	ldy	__rc13
	sta	(__rc4),y
	sty	__rc15
	ldy	__rc11
	sta	(__rc4),y
	ldy	__rc10
	sta	(__rc4),y
	lda	#64
	ldy	__rc18
	sta	(__rc4),y
	sty	__rc25
	ldy	__rc2
	lda	(__rc8),y
	ldy	#40
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#36
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	clc
	ldy	__rc6
	lda	(__rc8),y
	tax
	sty	__rc14
	ldy	__rc7
	lda	(__rc8),y
	sta	__rc18
	sty	__rc19
	ldy	__rc15
	lda	(__rc8),y
	sta	__rc4
	sty	__rc24
	ldy	__rc11
	lda	(__rc8),y
	sta	__rc5
	sty	__rc23
	ldy	__rc10
	lda	(__rc8),y
	sta	__rc6
	sty	__rc22
	ldy	__rc25
	lda	(__rc8),y
	sta	__rc7
	rep	#32
	lda	__rc8
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	ldy	__rc12
	lda	(__rc8),y
	ldy	#153
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	ldy	#152
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	ldy	#150
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	ldy	#70
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#73
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	ldy	#72
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	ldy	#71
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	ldy	#151
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc20),y
	sta	__rc8
	ldy	__rc13
	lda	(__rc20),y
	sty	__rc28
	sta	__rc9
	ldy	__rc26
	lda	(__rc20),y
	sty	__rc2
	sta	__rc26
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc29
	sta	__rc19
	ldy	__rc24
	lda	(__rc20),y
	sty	__rc31
	sta	__rc12
	ldy	__rc23
	lda	(__rc20),y
	sty	__rc30
	sta	__rc13
	ldy	__rc22
	lda	(__rc20),y
	sty	__rc24
	sta	__rc14
	ldy	__rc25
	lda	(__rc20),y
	sty	__rc3
	sta	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc22
	sep	#32
	ldy	__rc27
	lda	(__rc20),y
	ldy	#68
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	ldy	#69
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	ldy	#67
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc29
	lda	(__rc22),y
	sta	__rc27
	ldy	__rc31
	lda	(__rc22),y
	sta	__rc29
	ldy	__rc30
	lda	(__rc22),y
	sta	__rc30
	ldy	__rc24
	lda	(__rc22),y
	sta	__rc25
	ldy	__rc3
	lda	(__rc22),y
	sta	__rc31
	stx	__rc2
	ldx	__rc18
	stx	__rc3
	ldx	__rc26
	stx	__rc10
	ldx	__rc19
	stx	__rc11
	ldy	#36
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#40
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc22
	stx	__rc20
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc21
	ldx	__rc5
	stx	__rc23
	ldx	__rc6
	stx	__rc26
	lda	__rc7
	ldy	#66
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#150
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#70
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#73
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	ldy	#151
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldy	#68
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc8
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc9
	ldy	#67
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc10
	ldx	__rc27
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc30
	stx	__rc13
	ldx	__rc25
	stx	__rc14
	ldx	__rc31
	stx	__rc15
	ldy	#152
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc22
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc20
	sta	(__rc12),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	lda	__rc28
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc21
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc23
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc12),y
	sty	__rc21
	inx
	txa
	tay
	sty	__rc17
	ldy	#66
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc22
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	lda	__rc2
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc21
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc22
	sta	(__rc4),y
	jmp	.LBB0_122
.LBB0_122:
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_123
.LBB0_123:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_124
	jmp	.LBB0_131
.LBB0_124:                              ;   in Loop: Header=BB0_123 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc20
	lda	__rc1
	adc	#1
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#25
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#25
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_128
	jmp	.LBB0_125
.LBB0_125:                              ;   in Loop: Header=BB0_123 Depth=1
	ldy	__rc2
	bne	.LBB0_128
	jmp	.LBB0_126
.LBB0_126:                              ;   in Loop: Header=BB0_123 Depth=1
	cpx	#0
	bne	.LBB0_128
	jmp	.LBB0_127
.LBB0_127:                              ;   in Loop: Header=BB0_123 Depth=1
	tax
	bne	.LBB0_128
	jmp	.LBB0_129
.LBB0_128:
	jsr	abort
.LBB0_129:                              ;   in Loop: Header=BB0_123 Depth=1
	jmp	.LBB0_130
.LBB0_130:                              ;   in Loop: Header=BB0_123 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_123
.LBB0_131:
	sep	#32
	jmp	.LBB0_132
.LBB0_132:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc18
	iny
	lda	(__rc20),y
	sta	__rc19
	ldx	#1
	stx	__rc4
	clc
	iny
	lda	(__rc20),y
	inx
	stx	__rc14
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	iny
	lda	(__rc20),y
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	ldx	#7
	stx	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#79
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	ldy	#78
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	ldy	#75
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#77
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#76
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	ldy	#74
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc8
	sta	__rc2
	lda	__rc9
	sta	__rc3
	lda	__rc10
	sta	__rc4
	lda	__rc11
	sta	__rc5
	lda	__rc12
	sta	__rc6
	lda	__rc13
	sta	__rc7
	sty	__rc8
	sty	__rc9
	sty	__rc10
	sty	__rc11
	sty	__rc12
	sty	__rc13
	sty	__rc14
	stx	__rc15
	ldx	__rc19
	lda	__rc18
	jsr	__adddf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc30
	ldx	__rc4
	stx	__rc24
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc31
	ldx	__rc7
	stx	__rc27
	ldy	#75
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#77
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	ldy	#74
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	stx	__rc8
	stx	__rc9
	stx	__rc10
	stx	__rc11
	stx	__rc12
	stx	__rc13
	stx	__rc14
	ldx	#64
	stx	__rc15
	ldy	#78
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc15
	ldy	#2
	lda	__rc23
	sta	(__rc10),y
	sty	__rc25
	iny
	lda	__rc30
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc31
	sta	(__rc10),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc27
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc15
	sta	(__rc12),y
	lda	__rc2
	ldy	__rc25
	sta	(__rc12),y
	ldx	#2
	stx	__rc2
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	stx	__rc3
	lda	__rc4
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc4
	lda	__rc5
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc8
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc7
	clc
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc18
	sty	__rc6
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc19
	ldy	__rc2
	lda	(__rc20),y
	sta	__rc2
	sty	__rc14
	ldy	__rc3
	lda	(__rc20),y
	sta	__rc3
	sty	__rc13
	ldy	__rc4
	lda	(__rc20),y
	sta	__rc4
	sty	__rc25
	ldy	__rc5
	lda	(__rc20),y
	sta	__rc5
	sty	__rc24
	ldy	__rc8
	lda	(__rc20),y
	sta	__rc8
	sty	__rc9
	ldy	__rc7
	lda	(__rc20),y
	sta	__rc7
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	lda	__rc0
	adc	#224
	sta	__rc22
	lda	__rc1
	adc	#1
	sta	__rc23
	lda	#0
	ldy	__rc6
	sta	(__rc22),y
	ldy	__rc15
	sta	(__rc22),y
	sty	__rc27
	ldy	__rc14
	sta	(__rc22),y
	sty	__rc26
	ldy	__rc13
	sta	(__rc22),y
	ldy	__rc25
	sta	(__rc22),y
	ldy	__rc24
	sta	(__rc22),y
	ldy	__rc9
	sta	(__rc22),y
	tax
	lda	#64
	ldy	__rc12
	sta	(__rc22),y
	clc
	ldy	#8
	lda	(__rc20),y
	sty	__rc20
	ldy	#157
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	ldy	#156
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	ldy	#84
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	ldy	#85
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	ldy	#155
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#154
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	ldy	#87
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	ldy	#86
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	txa
	ldy	__rc20
	sta	(__rc22),y
	ldy	__rc27
	sta	(__rc10),y
	ldy	__rc26
	sta	(__rc10),y
	ldy	__rc13
	sta	(__rc10),y
	ldy	__rc25
	sta	(__rc10),y
	ldy	__rc24
	sta	(__rc10),y
	ldy	__rc9
	sta	(__rc10),y
	lda	#64
	ldy	__rc12
	sta	(__rc10),y
	clc
	ldy	__rc6
	lda	(__rc22),y
	tax
	ldy	#1
	lda	(__rc22),y
	sta	__rc9
	iny
	lda	(__rc22),y
	sta	__rc10
	iny
	lda	(__rc22),y
	sta	__rc11
	iny
	lda	(__rc22),y
	sta	__rc12
	iny
	lda	(__rc22),y
	sta	__rc13
	iny
	lda	(__rc22),y
	sta	__rc14
	iny
	lda	(__rc22),y
	sta	__rc15
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc30
	sep	#32
	iny
	lda	(__rc22),y
	sta	__rc25
	ldy	#1
	lda	(__rc30),y
	sta	__rc26
	iny
	lda	(__rc30),y
	sta	__rc27
	iny
	lda	(__rc30),y
	sta	__rc28
	iny
	lda	(__rc30),y
	sta	__rc29
	iny
	lda	(__rc30),y
	sta	__rc21
	iny
	lda	(__rc30),y
	sta	__rc20
	iny
	lda	(__rc30),y
	sta	__rc22
	ldy	__rc8
	sty	__rc6
	stx	__rc8
	ldx	__rc19
	lda	__rc18
	jsr	__adddf3
	sta	__rc23
	stx	__rc24
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	lda	__rc4
	ldy	#83
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc5
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc6
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc7
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#84
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#155
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	ldy	#87
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	__rc25
	stx	__rc8
	ldx	__rc26
	stx	__rc9
	ldx	__rc27
	stx	__rc10
	ldx	__rc28
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc21
	stx	__rc13
	ldx	__rc20
	stx	__rc14
	ldx	__rc22
	stx	__rc15
	ldy	#156
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc23
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc14
	ldy	#2
	lda	__rc30
	sta	(__rc12),y
	ldx	#3
	txa
	tay
	lda	__rc31
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	sty	__rc17
	ldy	#83
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	ldy	#82
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	ldy	#81
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	ldy	#80
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc21
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	ldy	#2
	lda	__rc2
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc21
	sta	(__rc4),y
	jmp	.LBB0_133
.LBB0_133:
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_134
.LBB0_134:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_135
	jmp	.LBB0_142
.LBB0_135:                              ;   in Loop: Header=BB0_134 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc20
	lda	__rc1
	adc	#1
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#23
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#23
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_139
	jmp	.LBB0_136
.LBB0_136:                              ;   in Loop: Header=BB0_134 Depth=1
	ldy	__rc2
	bne	.LBB0_139
	jmp	.LBB0_137
.LBB0_137:                              ;   in Loop: Header=BB0_134 Depth=1
	cpx	#0
	bne	.LBB0_139
	jmp	.LBB0_138
.LBB0_138:                              ;   in Loop: Header=BB0_134 Depth=1
	tax
	bne	.LBB0_139
	jmp	.LBB0_140
.LBB0_139:
	jsr	abort
.LBB0_140:                              ;   in Loop: Header=BB0_134 Depth=1
	jmp	.LBB0_141
.LBB0_141:                              ;   in Loop: Header=BB0_134 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_134
.LBB0_142:
	sep	#32
	jmp	.LBB0_143
.LBB0_143:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc18
	iny
	lda	(__rc20),y
	sta	__rc19
	ldx	#1
	stx	__rc4
	clc
	iny
	lda	(__rc20),y
	inx
	stx	__rc14
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	iny
	lda	(__rc20),y
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	ldx	#7
	stx	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#93
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	ldy	#92
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	ldy	#89
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#91
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#90
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	ldy	#88
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc8
	sta	__rc2
	lda	__rc9
	sta	__rc3
	lda	__rc10
	sta	__rc4
	lda	__rc11
	sta	__rc5
	lda	__rc12
	sta	__rc6
	lda	__rc13
	sta	__rc7
	sty	__rc8
	sty	__rc9
	sty	__rc10
	sty	__rc11
	sty	__rc12
	sty	__rc13
	sty	__rc14
	stx	__rc15
	ldx	__rc19
	lda	__rc18
	jsr	__subdf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc30
	ldx	__rc4
	stx	__rc24
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc31
	ldx	__rc7
	stx	__rc27
	ldy	#89
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#91
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	ldy	#88
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	stx	__rc8
	stx	__rc9
	stx	__rc10
	stx	__rc11
	stx	__rc12
	stx	__rc13
	stx	__rc14
	ldx	#64
	stx	__rc15
	ldy	#92
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc15
	ldy	#2
	lda	__rc23
	sta	(__rc10),y
	sty	__rc25
	iny
	lda	__rc30
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc31
	sta	(__rc10),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc27
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc15
	sta	(__rc12),y
	lda	__rc2
	ldy	__rc25
	sta	(__rc12),y
	ldx	#2
	stx	__rc2
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	stx	__rc3
	lda	__rc4
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc4
	lda	__rc5
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc8
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc7
	clc
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc18
	sty	__rc6
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc19
	ldy	__rc2
	lda	(__rc20),y
	sta	__rc2
	sty	__rc14
	ldy	__rc3
	lda	(__rc20),y
	sta	__rc3
	sty	__rc13
	ldy	__rc4
	lda	(__rc20),y
	sta	__rc4
	sty	__rc25
	ldy	__rc5
	lda	(__rc20),y
	sta	__rc5
	sty	__rc24
	ldy	__rc8
	lda	(__rc20),y
	sta	__rc8
	sty	__rc9
	ldy	__rc7
	lda	(__rc20),y
	sta	__rc7
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	lda	__rc0
	adc	#192
	sta	__rc22
	lda	__rc1
	adc	#1
	sta	__rc23
	lda	#0
	ldy	__rc6
	sta	(__rc22),y
	ldy	__rc15
	sta	(__rc22),y
	sty	__rc27
	ldy	__rc14
	sta	(__rc22),y
	sty	__rc26
	ldy	__rc13
	sta	(__rc22),y
	ldy	__rc25
	sta	(__rc22),y
	ldy	__rc24
	sta	(__rc22),y
	ldy	__rc9
	sta	(__rc22),y
	tax
	lda	#64
	ldy	__rc12
	sta	(__rc22),y
	clc
	ldy	#8
	lda	(__rc20),y
	sty	__rc20
	ldy	#161
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	ldy	#160
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	ldy	#98
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	ldy	#99
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	ldy	#159
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#158
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	ldy	#101
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	ldy	#100
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	txa
	ldy	__rc20
	sta	(__rc22),y
	ldy	__rc27
	sta	(__rc10),y
	ldy	__rc26
	sta	(__rc10),y
	ldy	__rc13
	sta	(__rc10),y
	ldy	__rc25
	sta	(__rc10),y
	ldy	__rc24
	sta	(__rc10),y
	ldy	__rc9
	sta	(__rc10),y
	lda	#64
	ldy	__rc12
	sta	(__rc10),y
	clc
	ldy	__rc6
	lda	(__rc22),y
	tax
	ldy	#1
	lda	(__rc22),y
	sta	__rc9
	iny
	lda	(__rc22),y
	sta	__rc10
	iny
	lda	(__rc22),y
	sta	__rc11
	iny
	lda	(__rc22),y
	sta	__rc12
	iny
	lda	(__rc22),y
	sta	__rc13
	iny
	lda	(__rc22),y
	sta	__rc14
	iny
	lda	(__rc22),y
	sta	__rc15
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc30
	sep	#32
	iny
	lda	(__rc22),y
	sta	__rc25
	ldy	#1
	lda	(__rc30),y
	sta	__rc26
	iny
	lda	(__rc30),y
	sta	__rc27
	iny
	lda	(__rc30),y
	sta	__rc28
	iny
	lda	(__rc30),y
	sta	__rc29
	iny
	lda	(__rc30),y
	sta	__rc21
	iny
	lda	(__rc30),y
	sta	__rc20
	iny
	lda	(__rc30),y
	sta	__rc22
	ldy	__rc8
	sty	__rc6
	stx	__rc8
	ldx	__rc19
	lda	__rc18
	jsr	__subdf3
	sta	__rc23
	stx	__rc24
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	lda	__rc4
	ldy	#97
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc5
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc6
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc7
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#98
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#159
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	ldy	#101
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	__rc25
	stx	__rc8
	ldx	__rc26
	stx	__rc9
	ldx	__rc27
	stx	__rc10
	ldx	__rc28
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc21
	stx	__rc13
	ldx	__rc20
	stx	__rc14
	ldx	__rc22
	stx	__rc15
	ldy	#160
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc23
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc14
	ldy	#2
	lda	__rc30
	sta	(__rc12),y
	ldx	#3
	txa
	tay
	lda	__rc31
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	sty	__rc17
	ldy	#97
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	ldy	#96
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	ldy	#95
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	ldy	#94
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc21
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	ldy	#2
	lda	__rc2
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc21
	sta	(__rc4),y
	jmp	.LBB0_144
.LBB0_144:
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_145
.LBB0_145:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_146
	jmp	.LBB0_153
.LBB0_146:                              ;   in Loop: Header=BB0_145 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc20
	lda	__rc1
	adc	#1
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#21
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#21
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_150
	jmp	.LBB0_147
.LBB0_147:                              ;   in Loop: Header=BB0_145 Depth=1
	ldy	__rc2
	bne	.LBB0_150
	jmp	.LBB0_148
.LBB0_148:                              ;   in Loop: Header=BB0_145 Depth=1
	cpx	#0
	bne	.LBB0_150
	jmp	.LBB0_149
.LBB0_149:                              ;   in Loop: Header=BB0_145 Depth=1
	tax
	bne	.LBB0_150
	jmp	.LBB0_151
.LBB0_150:
	jsr	abort
.LBB0_151:                              ;   in Loop: Header=BB0_145 Depth=1
	jmp	.LBB0_152
.LBB0_152:                              ;   in Loop: Header=BB0_145 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_145
.LBB0_153:
	sep	#32
	jmp	.LBB0_154
.LBB0_154:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc18
	iny
	lda	(__rc20),y
	sta	__rc19
	ldx	#1
	stx	__rc4
	clc
	iny
	lda	(__rc20),y
	inx
	stx	__rc14
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	iny
	lda	(__rc20),y
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	ldx	#7
	stx	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#107
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	ldy	#106
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	ldy	#103
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#105
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#104
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	ldy	#102
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc8
	sta	__rc2
	lda	__rc9
	sta	__rc3
	lda	__rc10
	sta	__rc4
	lda	__rc11
	sta	__rc5
	lda	__rc12
	sta	__rc6
	lda	__rc13
	sta	__rc7
	sty	__rc8
	sty	__rc9
	sty	__rc10
	sty	__rc11
	sty	__rc12
	sty	__rc13
	sty	__rc14
	stx	__rc15
	ldx	__rc19
	lda	__rc18
	jsr	__muldf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc30
	ldx	__rc4
	stx	__rc24
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc31
	ldx	__rc7
	stx	__rc27
	ldy	#103
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#105
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	ldy	#102
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	stx	__rc8
	stx	__rc9
	stx	__rc10
	stx	__rc11
	stx	__rc12
	stx	__rc13
	stx	__rc14
	ldx	#64
	stx	__rc15
	ldy	#106
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc15
	ldy	#2
	lda	__rc23
	sta	(__rc10),y
	sty	__rc25
	iny
	lda	__rc30
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc31
	sta	(__rc10),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc27
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc15
	sta	(__rc12),y
	lda	__rc2
	ldy	__rc25
	sta	(__rc12),y
	ldx	#2
	stx	__rc2
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	stx	__rc3
	lda	__rc4
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc4
	lda	__rc5
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc8
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc7
	clc
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc18
	sty	__rc6
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc19
	ldy	__rc2
	lda	(__rc20),y
	sta	__rc2
	sty	__rc14
	ldy	__rc3
	lda	(__rc20),y
	sta	__rc3
	sty	__rc13
	ldy	__rc4
	lda	(__rc20),y
	sta	__rc4
	sty	__rc25
	ldy	__rc5
	lda	(__rc20),y
	sta	__rc5
	sty	__rc24
	ldy	__rc8
	lda	(__rc20),y
	sta	__rc8
	sty	__rc9
	ldy	__rc7
	lda	(__rc20),y
	sta	__rc7
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	lda	__rc0
	adc	#160
	sta	__rc22
	lda	__rc1
	adc	#1
	sta	__rc23
	lda	#0
	ldy	__rc6
	sta	(__rc22),y
	ldy	__rc15
	sta	(__rc22),y
	sty	__rc27
	ldy	__rc14
	sta	(__rc22),y
	sty	__rc26
	ldy	__rc13
	sta	(__rc22),y
	ldy	__rc25
	sta	(__rc22),y
	ldy	__rc24
	sta	(__rc22),y
	ldy	__rc9
	sta	(__rc22),y
	tax
	lda	#64
	ldy	__rc12
	sta	(__rc22),y
	clc
	ldy	#8
	lda	(__rc20),y
	sty	__rc20
	ldy	#165
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	ldy	#164
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	ldy	#112
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	ldy	#113
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	ldy	#163
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#162
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	ldy	#115
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	ldy	#114
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	txa
	ldy	__rc20
	sta	(__rc22),y
	ldy	__rc27
	sta	(__rc10),y
	ldy	__rc26
	sta	(__rc10),y
	ldy	__rc13
	sta	(__rc10),y
	ldy	__rc25
	sta	(__rc10),y
	ldy	__rc24
	sta	(__rc10),y
	ldy	__rc9
	sta	(__rc10),y
	lda	#64
	ldy	__rc12
	sta	(__rc10),y
	clc
	ldy	__rc6
	lda	(__rc22),y
	tax
	ldy	#1
	lda	(__rc22),y
	sta	__rc9
	iny
	lda	(__rc22),y
	sta	__rc10
	iny
	lda	(__rc22),y
	sta	__rc11
	iny
	lda	(__rc22),y
	sta	__rc12
	iny
	lda	(__rc22),y
	sta	__rc13
	iny
	lda	(__rc22),y
	sta	__rc14
	iny
	lda	(__rc22),y
	sta	__rc15
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc30
	sep	#32
	iny
	lda	(__rc22),y
	sta	__rc25
	ldy	#1
	lda	(__rc30),y
	sta	__rc26
	iny
	lda	(__rc30),y
	sta	__rc27
	iny
	lda	(__rc30),y
	sta	__rc28
	iny
	lda	(__rc30),y
	sta	__rc29
	iny
	lda	(__rc30),y
	sta	__rc21
	iny
	lda	(__rc30),y
	sta	__rc20
	iny
	lda	(__rc30),y
	sta	__rc22
	ldy	__rc8
	sty	__rc6
	stx	__rc8
	ldx	__rc19
	lda	__rc18
	jsr	__muldf3
	sta	__rc23
	stx	__rc24
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	lda	__rc4
	ldy	#111
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc5
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc6
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc7
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#112
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#163
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	ldy	#115
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	__rc25
	stx	__rc8
	ldx	__rc26
	stx	__rc9
	ldx	__rc27
	stx	__rc10
	ldx	__rc28
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc21
	stx	__rc13
	ldx	__rc20
	stx	__rc14
	ldx	__rc22
	stx	__rc15
	ldy	#164
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc23
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc14
	ldy	#2
	lda	__rc30
	sta	(__rc12),y
	ldx	#3
	txa
	tay
	lda	__rc31
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	sty	__rc17
	ldy	#111
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	ldy	#110
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	ldy	#109
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	ldy	#108
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc21
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	ldy	#2
	lda	__rc2
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc21
	sta	(__rc4),y
	jmp	.LBB0_155
.LBB0_155:
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_156
.LBB0_156:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_157
	jmp	.LBB0_164
.LBB0_157:                              ;   in Loop: Header=BB0_156 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc20
	lda	__rc1
	adc	#1
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#19
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#19
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_161
	jmp	.LBB0_158
.LBB0_158:                              ;   in Loop: Header=BB0_156 Depth=1
	ldy	__rc2
	bne	.LBB0_161
	jmp	.LBB0_159
.LBB0_159:                              ;   in Loop: Header=BB0_156 Depth=1
	cpx	#0
	bne	.LBB0_161
	jmp	.LBB0_160
.LBB0_160:                              ;   in Loop: Header=BB0_156 Depth=1
	tax
	bne	.LBB0_161
	jmp	.LBB0_162
.LBB0_161:
	jsr	abort
.LBB0_162:                              ;   in Loop: Header=BB0_156 Depth=1
	jmp	.LBB0_163
.LBB0_163:                              ;   in Loop: Header=BB0_156 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_156
.LBB0_164:
	sep	#32
	jmp	.LBB0_165
.LBB0_165:
	ldy	#0
	clc
	lda	__rc0
	adc	#144
	sta	__rc20
	lda	__rc1
	adc	#3
	sta	__rc21
	lda	(__rc20),y
	sta	__rc18
	iny
	lda	(__rc20),y
	sta	__rc19
	ldx	#1
	stx	__rc4
	clc
	iny
	lda	(__rc20),y
	inx
	stx	__rc14
	sta	__rc8
	iny
	lda	(__rc20),y
	sta	__rc9
	iny
	lda	(__rc20),y
	sta	__rc10
	iny
	lda	(__rc20),y
	sta	__rc11
	iny
	lda	(__rc20),y
	sta	__rc12
	iny
	lda	(__rc20),y
	sta	__rc13
	ldx	#7
	stx	__rc15
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc20),y
	ldy	#121
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	ldy	#120
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	ldy	#117
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	ldy	#119
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	ldy	#118
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	ldy	#116
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#0
	ldx	#64
	lda	__rc8
	sta	__rc2
	lda	__rc9
	sta	__rc3
	lda	__rc10
	sta	__rc4
	lda	__rc11
	sta	__rc5
	lda	__rc12
	sta	__rc6
	lda	__rc13
	sta	__rc7
	sty	__rc8
	sty	__rc9
	sty	__rc10
	sty	__rc11
	sty	__rc12
	sty	__rc13
	sty	__rc14
	stx	__rc15
	ldx	__rc19
	lda	__rc18
	jsr	__divdf3
	sta	__rc29
	stx	__rc22
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc30
	ldx	__rc4
	stx	__rc24
	ldx	__rc5
	stx	__rc26
	ldx	__rc6
	stx	__rc31
	ldx	__rc7
	stx	__rc27
	ldy	#117
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldy	#119
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	ldy	#116
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	stx	__rc8
	stx	__rc9
	stx	__rc10
	stx	__rc11
	stx	__rc12
	stx	__rc13
	stx	__rc14
	ldx	#64
	stx	__rc15
	ldy	#120
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#128
	sta	__rc10
	lda	__rc1
	adc	#3
	sta	__rc11
	ldx	#0
	txa
	tay
	lda	__rc29
	sta	(__rc10),y
	sty	__rc14
	inx
	txa
	tay
	lda	__rc22
	sta	(__rc10),y
	sty	__rc15
	ldy	#2
	lda	__rc23
	sta	(__rc10),y
	sty	__rc25
	iny
	lda	__rc30
	sta	(__rc10),y
	sty	__rc28
	ldx	#4
	txa
	tay
	lda	__rc24
	sta	(__rc10),y
	sty	__rc22
	inx
	txa
	tay
	lda	__rc26
	sta	(__rc10),y
	sty	__rc19
	inx
	txa
	tay
	lda	__rc31
	sta	(__rc10),y
	sty	__rc18
	inx
	txa
	tay
	lda	__rc27
	sta	(__rc10),y
	sty	__rc23
	clc
	rep	#32
	lda	__rc10
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc10),y
	lda	__rc9
	ldy	__rc15
	sta	(__rc12),y
	lda	__rc2
	ldy	__rc25
	sta	(__rc12),y
	ldx	#2
	stx	__rc2
	lda	__rc3
	ldy	__rc28
	sta	(__rc12),y
	inx
	stx	__rc3
	lda	__rc4
	ldy	__rc22
	sta	(__rc12),y
	sty	__rc4
	lda	__rc5
	ldy	__rc19
	sta	(__rc12),y
	sty	__rc5
	lda	__rc6
	ldy	__rc18
	sta	(__rc12),y
	sty	__rc8
	lda	__rc7
	ldy	__rc23
	sta	(__rc12),y
	sty	__rc7
	clc
	ldy	__rc14
	lda	(__rc20),y
	sta	__rc18
	sty	__rc6
	ldy	__rc15
	lda	(__rc20),y
	sta	__rc19
	ldy	__rc2
	lda	(__rc20),y
	sta	__rc2
	sty	__rc14
	ldy	__rc3
	lda	(__rc20),y
	sta	__rc3
	sty	__rc13
	ldy	__rc4
	lda	(__rc20),y
	sta	__rc4
	sty	__rc25
	ldy	__rc5
	lda	(__rc20),y
	sta	__rc5
	sty	__rc24
	ldy	__rc8
	lda	(__rc20),y
	sta	__rc8
	sty	__rc9
	ldy	__rc7
	lda	(__rc20),y
	sta	__rc7
	sty	__rc12
	rep	#32
	lda	__rc20
	adc	#mos16(8)
	sta	__rc10
	clc
	sep	#32
	lda	__rc0
	adc	#128
	sta	__rc22
	lda	__rc1
	adc	#1
	sta	__rc23
	lda	#0
	ldy	__rc6
	sta	(__rc22),y
	ldy	__rc15
	sta	(__rc22),y
	sty	__rc27
	ldy	__rc14
	sta	(__rc22),y
	sty	__rc26
	ldy	__rc13
	sta	(__rc22),y
	ldy	__rc25
	sta	(__rc22),y
	ldy	__rc24
	sta	(__rc22),y
	ldy	__rc9
	sta	(__rc22),y
	tax
	lda	#64
	ldy	__rc12
	sta	(__rc22),y
	clc
	ldy	#8
	lda	(__rc20),y
	sty	__rc20
	ldy	#169
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	ldy	#168
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	ldy	#126
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	ldy	#127
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	ldy	#167
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	ldy	#166
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	ldy	#129
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	ldy	#128
	sta	(__rc0),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	txa
	ldy	__rc20
	sta	(__rc22),y
	ldy	__rc27
	sta	(__rc10),y
	ldy	__rc26
	sta	(__rc10),y
	ldy	__rc13
	sta	(__rc10),y
	ldy	__rc25
	sta	(__rc10),y
	ldy	__rc24
	sta	(__rc10),y
	ldy	__rc9
	sta	(__rc10),y
	lda	#64
	ldy	__rc12
	sta	(__rc10),y
	clc
	ldy	__rc6
	lda	(__rc22),y
	tax
	ldy	#1
	lda	(__rc22),y
	sta	__rc9
	iny
	lda	(__rc22),y
	sta	__rc10
	iny
	lda	(__rc22),y
	sta	__rc11
	iny
	lda	(__rc22),y
	sta	__rc12
	iny
	lda	(__rc22),y
	sta	__rc13
	iny
	lda	(__rc22),y
	sta	__rc14
	iny
	lda	(__rc22),y
	sta	__rc15
	rep	#32
	lda	__rc22
	adc	#mos16(8)
	sta	__rc30
	sep	#32
	iny
	lda	(__rc22),y
	sta	__rc25
	ldy	#1
	lda	(__rc30),y
	sta	__rc26
	iny
	lda	(__rc30),y
	sta	__rc27
	iny
	lda	(__rc30),y
	sta	__rc28
	iny
	lda	(__rc30),y
	sta	__rc29
	iny
	lda	(__rc30),y
	sta	__rc21
	iny
	lda	(__rc30),y
	sta	__rc20
	iny
	lda	(__rc30),y
	sta	__rc22
	ldy	__rc8
	sty	__rc6
	stx	__rc8
	ldx	__rc19
	lda	__rc18
	jsr	__divdf3
	sta	__rc23
	stx	__rc24
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc31
	lda	__rc4
	ldy	#125
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc5
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc6
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	lda	__rc7
	dey
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	#126
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldy	#167
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc4
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc5
	ldy	#129
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc6
	dey
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	__rc25
	stx	__rc8
	ldx	__rc26
	stx	__rc9
	ldx	__rc27
	stx	__rc10
	ldx	__rc28
	stx	__rc11
	ldx	__rc29
	stx	__rc12
	ldx	__rc21
	stx	__rc13
	ldx	__rc20
	stx	__rc14
	ldx	__rc22
	stx	__rc15
	ldy	#168
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#112
	sta	__rc12
	lda	__rc1
	adc	#3
	sta	__rc13
	ldy	#0
	lda	__rc23
	sta	(__rc12),y
	ldx	#1
	txa
	tay
	lda	__rc24
	sta	(__rc12),y
	sty	__rc14
	ldy	#2
	lda	__rc30
	sta	(__rc12),y
	ldx	#3
	txa
	tay
	lda	__rc31
	sta	(__rc12),y
	sty	__rc15
	inx
	txa
	tay
	sty	__rc17
	ldy	#125
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	ldy	#124
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	ldy	#123
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	ldy	#122
	lda	(__rc0),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc21
	clc
	rep	#32
	lda	__rc12
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc8
	sta	(__rc12),y
	lda	__rc9
	ldy	__rc14
	sta	(__rc4),y
	ldy	#2
	lda	__rc2
	sta	(__rc4),y
	lda	__rc3
	ldy	__rc15
	sta	(__rc4),y
	lda	__rc10
	ldy	__rc19
	sta	(__rc4),y
	lda	__rc11
	ldy	__rc18
	sta	(__rc4),y
	lda	__rc6
	ldy	__rc20
	sta	(__rc4),y
	lda	__rc7
	ldy	__rc21
	sta	(__rc4),y
	jmp	.LBB0_166
.LBB0_166:
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_167
.LBB0_167:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	tax
	iny
	lda	(__rc2),y
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#32768
	cmp	#32770
	bcc	.LBB0_168
	jmp	.LBB0_175
.LBB0_168:                              ;   in Loop: Header=BB0_167 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc20
	lda	__rc1
	adc	#1
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	inx
	stx	__rc23
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sta	__rc22
	sep	#16
	ldy	__rc23
	lda	(__rc6),y
	sty	__rc2
	sta	__rc23
	ldy	#2
	lda	(__rc6),y
	sta	__rc26
	ldx	#2
	stx	__rc24
	iny
	lda	(__rc6),y
	sta	__rc27
	inx
	stx	__rc25
	iny
	lda	(__rc6),y
	sta	__rc28
	iny
	lda	(__rc6),y
	sta	__rc29
	iny
	lda	(__rc6),y
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	__rc31
	ldy	#0
	lda	(__rc20),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc20),y
	sty	__rc20
	ldx	#8
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#3
	sta	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc2
	sta	__rc6
	sep	#32
	rep	#16
	ldy	__rc2
	clc
	lda	__rc0
	adc	#17
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	tya
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#48
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc10
	ldy	__rc25
	lda	(__rc6),y
	sta	__rc11
	ldy	#4
	lda	(__rc6),y
	sta	__rc12
	iny
	lda	(__rc6),y
	sta	__rc13
	iny
	lda	(__rc6),y
	sta	__rc14
	iny
	lda	(__rc6),y
	sta	__rc15
	clc
	lda	__rc0
	adc	#17
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	rep	#16
	tay
	sep	#32
	lda	(__rc4),y
	sep	#16
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc29
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc31
	stx	__rc7
	sta	__rc8
	ldx	__rc23
	lda	__rc22
	jsr	__nedf2
	ldy	__rc3
	bne	.LBB0_172
	jmp	.LBB0_169
.LBB0_169:                              ;   in Loop: Header=BB0_167 Depth=1
	ldy	__rc2
	bne	.LBB0_172
	jmp	.LBB0_170
.LBB0_170:                              ;   in Loop: Header=BB0_167 Depth=1
	cpx	#0
	bne	.LBB0_172
	jmp	.LBB0_171
.LBB0_171:                              ;   in Loop: Header=BB0_167 Depth=1
	tax
	bne	.LBB0_172
	jmp	.LBB0_173
.LBB0_172:
	jsr	abort
.LBB0_173:                              ;   in Loop: Header=BB0_167 Depth=1
	jmp	.LBB0_174
.LBB0_174:                              ;   in Loop: Header=BB0_167 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	(__rc2),y
	sta	__rc4
	ldx	#0
	stx	__rc6
	iny
	lda	(__rc2),y
	inx
	stx	__rc7
	sta	__rc5
	rep	#32
	lda	__rc4
	inc
	sta	__rc4
	sep	#32
	lda	__rc4
	ldy	__rc6
	sta	(__rc2),y
	ldy	__rc7
	lda	__rc5
	sta	(__rc2),y
	jmp	.LBB0_167
.LBB0_175:
	sep	#32
	jmp	.LBB0_176
.LBB0_176:
	ldx	#0
	txa
	sta	__rc16
	ldy	#9
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc31
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc30
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc29
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc28
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc27
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc26
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc25
	iny
	lda	(__rc0),y                       ; 1-byte Folded Reload
	sta	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	clc
	lda	__rc0
	adc	#224
	sta	__rc0
	lda	__rc1
	adc	#3
	sta	__rc1
	lda	__rc16
	rts
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
                                        ; -- End function
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

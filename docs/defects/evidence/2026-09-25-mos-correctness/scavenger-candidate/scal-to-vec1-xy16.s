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
	.file	"scal-to-vec1.c"
	.text
	.globl	main                            ; -- Begin function main
	.type	main,@function
main:                                   ; @main
; %bb.0:
	sta	__rc16
	clc
	lda	__rc0
	adc	#176
	sta	__rc0
	lda	__rc1
	adc	#250
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
	stx	__rc7
	ldy	#0
	clc
	lda	__rc0
	adc	#78
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	tya
	sta	(__rc4),y
	ldx	#0
	iny
	txa
	sta	(__rc4),y
	ldy	#1
	sty	__rc8
	clc
	lda	__rc0
	adc	#76
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	lda	__rc6
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	sty	__rc6
	lda	__rc7
	ldy	__rc8
	sta	(__rc4),y
	lda	__rc2
	ldx	__rc3
	clc
	pha
	lda	__rc0
	adc	#74
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	pla
	ldy	__rc6
	sta	(__rc2),y
	sty	__rc4
	ldy	__rc8
	txa
	sta	(__rc2),y
	sty	__rc5
	rep	#32
	lda	one
	sta	__rc2
	sep	#32
	lda	__rc2
	ldx	__rc3
	stx	__rc6
	clc
	pha
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	pla
	ldy	__rc4
	sta	(__rc2),y
	ldx	__rc4
	ldy	__rc5
	lda	__rc6
	sta	(__rc2),y
	rep	#32
	lda	__rc2
	clc
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	tya
	sty	__rc6
	ldy	#2
	sta	(__rc2),y
	sty	__rc7
	txa
	ldy	__rc6
	sta	(__rc4),y
	lda	#1
	sta	__rc9
	rep	#32
	lda	__rc2
	clc
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	__rc7
	sty	__rc6
	lda	__rc6
	ldy	#4
	sta	(__rc2),y
	ldy	#4
	sty	__rc8
	txa
	stx	__rc7
	stx	__rc11
	ldy	__rc9
	sta	(__rc4),y
	sty	__rc7
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#151
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#6
	ldx	#3
	txa
	stx	__rc9
	sta	(__rc2),y
	ldx	#6
	stx	__rc30
	clc
	php
	clc
	lda	__rc0
	adc	#151
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	lda	__rc11
	ldy	__rc7
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#17
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc8
	ldy	#8
	sta	(__rc2),y
	ldx	#8
	stx	__rc31
	clc
	php
	clc
	lda	__rc0
	adc	#17
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	__rc11
	ldy	__rc7
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#153
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	ldx	#5
	txa
	stx	__rc10
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#153
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	lda	__rc11
	ldy	__rc7
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#19
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	__rc30
	sta	(__rc2),y
	ldx	#12
	stx	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#19
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldx	__rc11
	stx	__rc13
	lda	__rc13
	ldy	__rc7
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#155
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	ldx	#7
	txa
	stx	__rc11
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#155
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	lda	__rc13
	ldy	__rc7
	sta	(__rc4),y
	clc
	lda	__rc0
	adc	#16
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	ldy	__rc13
	tya
	sta	(__rc4),y
	ldy	__rc7
	sta	(__rc4),y
	sty	__rc15
	lda	#128
	ldy	__rc6
	sta	(__rc4),y
	sty	__rc19
	tax
	stx	__rc18
	lda	#63
	ldy	__rc9
	sta	(__rc4),y
	sty	__rc21
	tax
	stx	__rc9
	clc
	rep	#32
	lda	__rc4
	adc	#mos16(4)
	sta	__rc6
	sep	#32
	lda	__rc13
	ldy	__rc8
	sta	(__rc4),y
	sty	__rc14
	ldx	__rc13
	txa
	ldy	__rc15
	sta	(__rc6),y
	ldy	__rc19
	sta	(__rc6),y
	sty	__rc29
	lda	#64
	ldy	__rc21
	sta	(__rc6),y
	sty	__rc19
	clc
	rep	#32
	lda	__rc4
	adc	#mos16(8)
	sta	__rc6
	sep	#32
	txa
	stx	__rc8
	ldy	__rc31
	sta	(__rc4),y
	lda	__rc8
	ldy	__rc15
	sta	(__rc6),y
	lda	#64
	ldy	__rc29
	sta	(__rc6),y
	ldy	__rc19
	sta	(__rc6),y
	tax
	stx	__rc13
	clc
	rep	#32
	lda	__rc4
	adc	#mos16(12)
	sta	__rc6
	sep	#32
	lda	__rc8
	ldy	__rc12
	sta	(__rc4),y
	ldy	__rc15
	sta	(__rc6),y
	sty	__rc12
	lda	__rc18
	ldy	__rc29
	sta	(__rc6),y
	clc
	lda	__rc0
	adc	#224
	sta	__rc4
	lda	__rc1
	adc	#4
	sta	__rc5
	ldy	__rc8
	tya
	sta	(__rc4),y
	ldy	__rc12
	sta	(__rc4),y
	lda	__rc8
	ldy	__rc29
	sta	(__rc4),y
	ldy	__rc19
	sta	(__rc4),y
	ldy	__rc14
	sta	(__rc4),y
	pha
	tya
	tax
	pla
	ldy	__rc10
	sta	(__rc4),y
	lda	#240
	ldy	__rc30
	sta	(__rc4),y
	ldy	__rc11
	lda	__rc9
	sta	(__rc4),y
	ldy	#3
	lda	__rc13
	sta	(__rc6),y
	clc
	rep	#32
	lda	__rc4
	adc	#mos16(8)
	sta	__rc6
	sep	#32
	lda	__rc8
	sta	(__rc6),y
	ldy	__rc10
	sta	(__rc6),y
	ldy	__rc11
	lda	__rc13
	sta	(__rc6),y
	lda	__rc8
	ldy	__rc31
	sta	(__rc4),y
	ldy	__rc12
	sta	(__rc6),y
	ldy	__rc29
	sta	(__rc6),y
	pha
	txa
	tay
	pla
	sta	(__rc6),y
	ldy	__rc30
	sta	(__rc6),y
	ldy	__rc8
	lda	(__rc2),y
	sta	__rc4
	ldy	__rc12
	lda	(__rc2),y
	sta	__rc5
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#21
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	pla
	rep	#32
	sta	(__rc6)                         ; 2-byte Folded Spill
	sep	#32
	ldy	__rc29
	lda	(__rc2),y
	sta	__rc6
	clc
	php
	clc
	lda	__rc0
	adc	#21
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(2)
	sta	__rc8
	sep	#32
	ldy	__rc12
	lda	(__rc8),y
	sta	__rc7
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#23
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	pla
	rep	#32
	sta	(__rc8)                         ; 2-byte Folded Spill
	sep	#32
	txa
	tay
	lda	(__rc2),y
	sta	__rc8
	clc
	php
	clc
	lda	__rc0
	adc	#23
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(4)
	sta	__rc10
	sep	#32
	ldy	__rc12
	lda	(__rc10),y
	sty	__rc20
	sta	__rc9
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#25
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	ldy	__rc30
	lda	(__rc2),y
	sta	__rc10
	clc
	php
	clc
	lda	__rc0
	adc	#25
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	__rc20
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#27
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	__rc31
	lda	(__rc2),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#27
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc20
	lda	(__rc14),y
	sta	__rc13
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#29
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	pla
	rep	#32
	sta	(__rc14)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc2),y
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#29
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc14
	sep	#32
	ldy	__rc20
	lda	(__rc14),y
	sta	__rc19
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#31
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	pla
	rep	#32
	sta	(__rc14)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc2),y
	sta	__rc24
	clc
	php
	clc
	lda	__rc0
	adc	#31
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc14
	sep	#32
	ldy	__rc20
	lda	(__rc14),y
	sta	__rc25
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#33
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	pla
	rep	#32
	sta	(__rc14)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc2),y
	sta	__rc22
	clc
	php
	clc
	lda	__rc0
	adc	#33
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	ldy	__rc20
	lda	(__rc2),y
	sty	__rc28
	sta	__rc23
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(2)
	sta	__rc26
	lda	__rc6
	clc
	adc	#mos16(2)
	sta	__rc20
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc14
	lda	__rc10
	clc
	adc	#mos16(2)
	sta	__rc10
	lda	__rc12
	clc
	adc	#mos16(2)
	sta	__rc8
	lda	__rc18
	clc
	adc	#mos16(2)
	sta	__rc4
	lda	__rc24
	clc
	adc	#mos16(2)
	clc
	sep	#32
	pha
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	pla
	rep	#32
	sta	__rc6
	lda	__rc22
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#253
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	#0
	sta	(__rc2),y
	lda	__rc27
	ldy	__rc28
	sta	(__rc2),y
	sty	__rc18
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc20
	ldy	__rc29
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc18
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc14
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	lda	__rc15
	ldy	__rc18
	sta	(__rc12),y
	clc
	php
	clc
	lda	__rc0
	adc	#253
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(2)
	sta	__rc12
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#35
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	pla
	rep	#32
	sta	(__rc14)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	__rc30
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#35
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc14
	sep	#32
	lda	__rc11
	ldy	__rc18
	sta	(__rc14),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#37
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc8
	ldy	__rc31
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#37
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	lda	__rc9
	ldy	__rc18
	sta	(__rc10),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#39
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	pla
	rep	#32
	sta	(__rc8)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	#10
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#39
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc8
	sep	#32
	lda	__rc5
	ldy	__rc18
	sta	(__rc8),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#41
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	#12
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#41
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc7
	ldy	__rc18
	sta	(__rc4),y
	sty	__rc4
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#43
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	pla
	rep	#32
	sta	(__rc6)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc12
	ldy	#14
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#43
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc13
	ldy	__rc4
	sta	(__rc2),y
	ldx	#2
	stx	__rc30
	ldx	#0
	stx	__rc31
	jmp	.LBB0_1
.LBB0_1:
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#4
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
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_3
	jmp	.LBB0_7
.LBB0_3:                                ;   in Loop: Header=BB0_2 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc21
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	clc
	adc	#mos16(2)
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_4
	jmp	.LBB0_5
.LBB0_4:
	sep	#32
	jsr	abort
.LBB0_5:                                ;   in Loop: Header=BB0_2 Depth=1
	sep	#32
	jmp	.LBB0_6
.LBB0_6:                                ;   in Loop: Header=BB0_2 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#4
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
.LBB0_7:
	sep	#32
	jmp	.LBB0_8
.LBB0_8:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	lda	(__rc4),y
	sta	__rc2
	iny
	lda	(__rc4),y
	ldx	#1
	stx	__rc8
	sta	__rc3
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(2)
	sta	__rc6
	sep	#32
	iny
	lda	(__rc4),y
	tax
	ldy	__rc8
	lda	(__rc6),y
	sty	__rc10
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(4)
	sta	__rc8
	sep	#32
	ldy	#4
	lda	(__rc4),y
	tax
	ldy	__rc10
	lda	(__rc8),y
	sty	__rc18
	stx	__rc8
	sta	__rc9
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc4),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#157
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc4),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#157
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#159
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc4),y
	ldx	#10
	stx	__rc21
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#159
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc23
	sta	__rc15
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#161
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc4),y
	sta	__rc22
	clc
	php
	clc
	lda	__rc0
	adc	#161
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc18
	sep	#32
	ldy	__rc23
	lda	(__rc18),y
	sty	__rc18
	sta	__rc23
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#163
	sta	__rc24
	lda	__rc1
	adc	#0
	plp
	sta	__rc25
	pla
	rep	#32
	sta	(__rc24)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc4),y
	ldx	#14
	sta	__rc28
	clc
	php
	clc
	lda	__rc0
	adc	#163
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	__rc18
	lda	(__rc4),y
	sty	__rc20
	sta	__rc29
	rep	#32
	lda	__rc30
	sec
	sbc	__rc2
	sta	__rc26
	lda	__rc30
	sec
	sbc	__rc6
	sta	__rc24
	lda	__rc30
	sec
	sbc	__rc8
	sta	__rc18
	lda	__rc30
	sec
	sbc	__rc10
	sta	__rc10
	lda	__rc30
	sec
	sbc	__rc12
	sta	__rc8
	lda	__rc30
	sec
	sbc	__rc14
	sta	__rc6
	lda	__rc30
	sec
	sbc	__rc22
	sta	__rc4
	lda	__rc30
	sec
	sbc	__rc28
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#1
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	clc
	sep	#32
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	__rc26
	ldy	#0
	sta	(__rc2),y
	lda	__rc27
	ldy	__rc20
	sta	(__rc2),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc24
	ldy	#2
	sta	(__rc2),y
	lda	__rc25
	ldy	__rc20
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc18
	ldy	#4
	sta	(__rc2),y
	lda	__rc19
	ldy	__rc20
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#1
	sta	__rc12
	lda	__rc1
	adc	#1
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	sta	__rc12
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#45
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	pla
	rep	#32
	sta	(__rc14)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#6
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#45
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc14
	sep	#32
	lda	__rc11
	ldy	__rc20
	sta	(__rc14),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#47
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc8
	ldy	#8
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#47
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	lda	__rc9
	ldy	__rc20
	sta	(__rc10),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#49
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	pla
	rep	#32
	sta	(__rc8)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc21
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#49
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc8
	sep	#32
	lda	__rc7
	ldy	__rc20
	sta	(__rc8),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#51
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	pla
	rep	#32
	sta	(__rc6)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	#12
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#51
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc6
	sep	#32
	lda	__rc5
	ldy	__rc20
	sta	(__rc6),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#53
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc12
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#53
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc13
	ldy	__rc20
	sta	(__rc2),y
	jmp	.LBB0_9
.LBB0_9:
	ldy	#0
	clc
	lda	__rc0
	adc	#188
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_10
.LBB0_10:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#188
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_11
	jmp	.LBB0_15
.LBB0_11:                               ;   in Loop: Header=BB0_10 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#188
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc21
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc30
	sec
	sbc	__rc2
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_12
	jmp	.LBB0_13
.LBB0_12:
	sep	#32
	jsr	abort
.LBB0_13:                               ;   in Loop: Header=BB0_10 Depth=1
	sep	#32
	jmp	.LBB0_14
.LBB0_14:                               ;   in Loop: Header=BB0_10 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#188
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_10
.LBB0_15:
	sep	#32
	clc
	lda	__rc0
	adc	#156
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
                                        ; kill: def $rs15 killed $rs15
	lda	__rc30
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	lda	__rc31
	iny
	sta	(__rc2),y                       ; 1-byte Folded Spill
	jmp	.LBB0_16
.LBB0_16:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc6
	lda	__rc1
	adc	#5
	sta	__rc7
	lda	(__rc6),y
	sta	__rc2
	iny
	lda	(__rc6),y
	ldx	#1
	sta	__rc3
	clc
	rep	#32
	lda	__rc6
	adc	#mos16(2)
	sta	__rc4
	clc
	sep	#32
	iny
	lda	(__rc6),y
	sta	__rc23
	txa
	tay
	lda	(__rc4),y
	sty	__rc10
	sta	__rc21
	rep	#32
	lda	__rc6
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#112
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc8
	sta	__rc27
	rep	#32
	lda	__rc6
	adc	#mos16(6)
	sta	__rc4
	clc
	sep	#32
	ldy	#6
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc29
	rep	#32
	lda	__rc6
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	#8
	lda	(__rc6),y
	sta	__rc30
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc31
	rep	#32
	lda	__rc6
	adc	#mos16(10)
	sta	__rc4
	clc
	sep	#32
	ldy	#10
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc22
	rep	#32
	lda	__rc6
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	#12
	lda	(__rc6),y
	sta	__rc24
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc26
	rep	#32
	lda	__rc6
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	(__rc6),y
	pha
	clc
	lda	__rc0
	adc	#113
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	pha
	clc
	lda	__rc0
	adc	#97
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	dex
	lda	#2
	jsr	__mulhi3
	pha
	clc
	lda	__rc0
	adc	#118
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#119
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc23
	stx	__rc2
	ldx	__rc21
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc21
	stx	__rc23
	clc
	lda	__rc0
	adc	#112
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc27
	stx	__rc20
	ldx	__rc28
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc28
	stx	__rc29
	ldx	__rc30
	stx	__rc2
	ldx	__rc31
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc30
	stx	__rc31
	ldx	__rc25
	stx	__rc2
	ldx	__rc22
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc22
	stx	__rc25
	ldx	__rc24
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc24
	stx	__rc26
	clc
	lda	__rc0
	adc	#113
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#97
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	#0
	lda	#2
	jsr	__mulhi3
	sta	__rc6
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#118
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#119
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	ldy	#2
	lda	__rc21
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc27
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	ldy	#6
	lda	__rc28
	sta	(__rc2),y
	lda	__rc29
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc30
	sta	(__rc2),y
	lda	__rc31
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc22
	sta	(__rc2),y
	lda	__rc25
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc24
	sta	(__rc2),y
	lda	__rc26
	ldy	__rc7
	sta	(__rc4),y
	ldy	#1
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc6
	sta	(__rc2),y
	txa
	ldy	__rc7
	sta	(__rc4),y
	jmp	.LBB0_17
.LBB0_17:
	ldy	#0
	clc
	lda	__rc0
	adc	#186
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#156
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	jmp	.LBB0_18
.LBB0_18:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#186
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_19
	jmp	.LBB0_23
.LBB0_19:                               ;   in Loop: Header=BB0_18 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#186
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc21
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	lda	#2
	ldx	#0
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_20
	jmp	.LBB0_21
.LBB0_20:
	sep	#32
	jsr	abort
.LBB0_21:                               ;   in Loop: Header=BB0_18 Depth=1
	sep	#32
	jmp	.LBB0_22
.LBB0_22:                               ;   in Loop: Header=BB0_18 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#186
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_18
.LBB0_23:
	sep	#32
	jmp	.LBB0_24
.LBB0_24:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc6
	lda	__rc1
	adc	#5
	sta	__rc7
	lda	(__rc6),y
	sta	__rc2
	iny
	lda	(__rc6),y
	ldx	#1
	sta	__rc3
	clc
	rep	#32
	lda	__rc6
	adc	#mos16(2)
	sta	__rc4
	clc
	sep	#32
	iny
	lda	(__rc6),y
	sta	__rc23
	txa
	tay
	lda	(__rc4),y
	sty	__rc10
	sta	__rc21
	rep	#32
	lda	__rc6
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#114
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc8
	sta	__rc27
	rep	#32
	lda	__rc6
	adc	#mos16(6)
	sta	__rc4
	clc
	sep	#32
	ldy	#6
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc29
	rep	#32
	lda	__rc6
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	#8
	lda	(__rc6),y
	sta	__rc30
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc31
	rep	#32
	lda	__rc6
	adc	#mos16(10)
	sta	__rc4
	clc
	sep	#32
	ldy	#10
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc22
	rep	#32
	lda	__rc6
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	#12
	lda	(__rc6),y
	sta	__rc24
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc26
	rep	#32
	lda	__rc6
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	(__rc6),y
	pha
	clc
	lda	__rc0
	adc	#115
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	pha
	clc
	lda	__rc0
	adc	#98
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	dex
	lda	#2
	jsr	__divhi3
	pha
	clc
	lda	__rc0
	adc	#120
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#121
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc23
	stx	__rc2
	ldx	__rc21
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc21
	stx	__rc23
	clc
	lda	__rc0
	adc	#114
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc27
	stx	__rc20
	ldx	__rc28
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc28
	stx	__rc29
	ldx	__rc30
	stx	__rc2
	ldx	__rc31
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc30
	stx	__rc31
	ldx	__rc25
	stx	__rc2
	ldx	__rc22
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc22
	stx	__rc25
	ldx	__rc24
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc24
	stx	__rc26
	clc
	lda	__rc0
	adc	#115
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#98
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	#0
	lda	#2
	jsr	__divhi3
	sta	__rc6
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#120
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#121
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	ldy	#2
	lda	__rc21
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc27
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	ldy	#6
	lda	__rc28
	sta	(__rc2),y
	lda	__rc29
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc30
	sta	(__rc2),y
	lda	__rc31
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc22
	sta	(__rc2),y
	lda	__rc25
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc24
	sta	(__rc2),y
	lda	__rc26
	ldy	__rc7
	sta	(__rc4),y
	ldy	#1
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc6
	sta	(__rc2),y
	txa
	ldy	__rc7
	sta	(__rc4),y
	jmp	.LBB0_25
.LBB0_25:
	ldy	#0
	clc
	lda	__rc0
	adc	#184
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#156
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	jmp	.LBB0_26
.LBB0_26:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#184
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_27
	jmp	.LBB0_31
.LBB0_27:                               ;   in Loop: Header=BB0_26 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#184
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc21
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	lda	#2
	ldx	#0
	jsr	__divhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_28
	jmp	.LBB0_29
.LBB0_28:
	sep	#32
	jsr	abort
.LBB0_29:                               ;   in Loop: Header=BB0_26 Depth=1
	sep	#32
	jmp	.LBB0_30
.LBB0_30:                               ;   in Loop: Header=BB0_26 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#184
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_26
.LBB0_31:
	sep	#32
	jmp	.LBB0_32
.LBB0_32:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc6
	lda	__rc1
	adc	#5
	sta	__rc7
	lda	(__rc6),y
	sta	__rc2
	iny
	lda	(__rc6),y
	ldx	#1
	sta	__rc3
	clc
	rep	#32
	lda	__rc6
	adc	#mos16(2)
	sta	__rc4
	clc
	sep	#32
	iny
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#127
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	txa
	tay
	lda	(__rc4),y
	sty	__rc10
	sta	__rc21
	rep	#32
	lda	__rc6
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc6),y
	pha
	php
	clc
	lda	__rc0
	adc	#116
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc8
	sta	__rc27
	rep	#32
	lda	__rc6
	adc	#mos16(6)
	sta	__rc4
	clc
	sep	#32
	ldy	#6
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc29
	rep	#32
	lda	__rc6
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	#8
	lda	(__rc6),y
	sta	__rc23
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc25
	rep	#32
	lda	__rc6
	adc	#mos16(10)
	sta	__rc4
	clc
	sep	#32
	ldy	#10
	lda	(__rc6),y
	sta	__rc31
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc22
	rep	#32
	lda	__rc6
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	#12
	lda	(__rc6),y
	sta	__rc24
	ldy	__rc8
	lda	(__rc4),y
	sta	__rc26
	rep	#32
	lda	__rc6
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	(__rc6),y
	pha
	clc
	lda	__rc0
	adc	#117
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	pha
	clc
	lda	__rc0
	adc	#99
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	dex
	lda	#2
	jsr	__modhi3
	pha
	clc
	lda	__rc0
	adc	#122
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#127
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldx	__rc21
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc21
	stx	__rc30
	clc
	lda	__rc0
	adc	#116
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc27
	stx	__rc20
	ldx	__rc28
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc28
	stx	__rc29
	ldx	__rc23
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc23
	stx	__rc25
	ldx	__rc31
	stx	__rc2
	ldx	__rc22
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc22
	stx	__rc31
	ldx	__rc24
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc24
	stx	__rc26
	clc
	lda	__rc0
	adc	#117
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#99
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	#0
	lda	#2
	jsr	__modhi3
	sta	__rc6
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#122
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#126
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	ldy	#2
	lda	__rc21
	sta	(__rc2),y
	lda	__rc30
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc27
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	ldy	#6
	lda	__rc28
	sta	(__rc2),y
	lda	__rc29
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc23
	sta	(__rc2),y
	lda	__rc25
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc22
	sta	(__rc2),y
	lda	__rc31
	ldy	__rc7
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc24
	sta	(__rc2),y
	lda	__rc26
	ldy	__rc7
	sta	(__rc4),y
	ldy	#1
	sty	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc6
	sta	(__rc2),y
	txa
	ldy	__rc7
	sta	(__rc4),y
	jmp	.LBB0_33
.LBB0_33:
	ldy	#0
	clc
	lda	__rc0
	adc	#182
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_34
.LBB0_34:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#182
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_35
	jmp	.LBB0_39
.LBB0_35:                               ;   in Loop: Header=BB0_34 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#182
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc21
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	lda	#2
	ldx	#0
	jsr	__modhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_36
	jmp	.LBB0_37
.LBB0_36:
	sep	#32
	jsr	abort
.LBB0_37:                               ;   in Loop: Header=BB0_34 Depth=1
	sep	#32
	jmp	.LBB0_38
.LBB0_38:                               ;   in Loop: Header=BB0_34 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#182
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_34
.LBB0_39:
	sep	#32
	jmp	.LBB0_40
.LBB0_40:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	lda	(__rc8),y
	sta	__rc2
	ldx	#0
	stx	__rc30
	iny
	lda	(__rc8),y
	inx
	stx	__rc6
	sta	__rc3
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	iny
	lda	(__rc8),y
	tax
	ldy	__rc6
	lda	(__rc4),y
	sty	__rc10
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(4)
	sta	__rc6
	sep	#32
	ldy	#4
	lda	(__rc8),y
	tax
	ldy	__rc10
	lda	(__rc6),y
	sty	__rc18
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc8),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#165
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc8),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#165
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#167
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc8),y
	ldy	#10
	sty	__rc31
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#167
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc19
	sta	__rc15
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#169
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	pla
	rep	#32
	sta	(__rc20)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc8),y
	ldx	#12
	stx	__rc29
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#169
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	rep	#32
	lda	(__rc20)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc20
	sep	#32
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc20
	sta	__rc19
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#171
	sta	__rc22
	lda	__rc1
	adc	#0
	plp
	sta	__rc23
	pla
	rep	#32
	sta	(__rc22)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc8),y
	ldx	#14
	stx	__rc28
	sta	__rc22
	clc
	php
	clc
	lda	__rc0
	adc	#171
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc8
	sep	#32
	ldy	__rc20
	lda	(__rc8),y
	pha
	tya
	tax
	pla
	sta	__rc23
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	rep	#32
	lda	__rc2
	eor	#mos16(2)
	sta	__rc26
	lda	__rc4
	eor	#mos16(2)
	sta	__rc24
	lda	__rc6
	eor	#mos16(2)
	sta	__rc6
	lda	__rc10
	eor	#mos16(2)
	sta	__rc20
	lda	__rc12
	eor	#mos16(2)
	sta	__rc10
	lda	__rc14
	eor	#mos16(2)
	sta	__rc4
	lda	__rc18
	eor	#mos16(2)
	sta	__rc2
	lda	__rc22
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#241
	sta	__rc12
	lda	__rc1
	adc	#0
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	__rc30
	sta	(__rc8),y
	lda	__rc27
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc24
	ldy	#2
	sta	(__rc8),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc6
	ldy	#4
	sta	(__rc8),y
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#241
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	eor	#mos16(2)
	sta	__rc6
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#55
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc20
	ldy	#6
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#55
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	lda	__rc21
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#57
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#8
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#57
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#59
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	__rc31
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#59
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc10
	sep	#32
	lda	__rc5
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#61
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc2
	ldy	__rc29
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#61
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc3
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#63
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc28
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#63
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_41
.LBB0_41:
	ldy	#0
	clc
	lda	__rc0
	adc	#180
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#156
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	iny
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	jmp	.LBB0_42
.LBB0_42:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#180
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_43
	jmp	.LBB0_47
.LBB0_43:                               ;   in Loop: Header=BB0_42 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#180
	sta	__rc20
	lda	__rc1
	adc	#4
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc25
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
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#mos16(2)
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_44
	jmp	.LBB0_45
.LBB0_44:
	sep	#32
	jsr	abort
.LBB0_45:                               ;   in Loop: Header=BB0_42 Depth=1
	sep	#32
	jmp	.LBB0_46
.LBB0_46:                               ;   in Loop: Header=BB0_42 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#180
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_42
.LBB0_47:
	sep	#32
	jmp	.LBB0_48
.LBB0_48:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	lda	(__rc8),y
	sta	__rc2
	ldx	#0
	stx	__rc30
	iny
	lda	(__rc8),y
	inx
	stx	__rc6
	sta	__rc3
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	iny
	lda	(__rc8),y
	tax
	ldy	__rc6
	lda	(__rc4),y
	sty	__rc10
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(4)
	sta	__rc6
	sep	#32
	ldy	#4
	lda	(__rc8),y
	tax
	ldy	__rc10
	lda	(__rc6),y
	sty	__rc18
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc8),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#173
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc8),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#173
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#175
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc8),y
	ldy	#10
	sty	__rc31
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#175
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc19
	sta	__rc15
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#177
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	pla
	rep	#32
	sta	(__rc20)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc8),y
	ldx	#12
	stx	__rc29
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#177
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	rep	#32
	lda	(__rc20)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc20
	sep	#32
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc21
	sta	__rc19
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#179
	sta	__rc22
	lda	__rc1
	adc	#0
	plp
	sta	__rc23
	pla
	rep	#32
	sta	(__rc22)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc8),y
	ldx	#14
	stx	__rc28
	sta	__rc20
	clc
	php
	clc
	lda	__rc0
	adc	#179
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc8
	sep	#32
	ldy	__rc21
	lda	(__rc8),y
	pha
	tya
	tax
	pla
	sta	__rc21
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	rep	#32
	lda	__rc2
	and	#mos16(2)
	sta	__rc26
	lda	__rc4
	and	#mos16(2)
	sta	__rc24
	lda	__rc6
	and	#mos16(2)
	sta	__rc6
	lda	__rc10
	and	#mos16(2)
	sta	__rc22
	lda	__rc12
	and	#mos16(2)
	sta	__rc10
	lda	__rc14
	and	#mos16(2)
	sta	__rc4
	lda	__rc18
	and	#mos16(2)
	sta	__rc2
	lda	__rc20
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#243
	sta	__rc12
	lda	__rc1
	adc	#0
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	__rc30
	sta	(__rc8),y
	lda	__rc27
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc24
	ldy	#2
	sta	(__rc8),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc6
	ldy	#4
	sta	(__rc8),y
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#243
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	and	#mos16(2)
	sta	__rc6
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#65
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc22
	ldy	#6
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#65
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	lda	__rc23
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#67
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#8
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#67
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#69
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	__rc31
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#69
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc10
	sep	#32
	lda	__rc5
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#71
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc2
	ldy	__rc29
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#71
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc3
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#73
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc28
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#73
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_49
.LBB0_49:
	ldy	#0
	clc
	lda	__rc0
	adc	#178
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_50
.LBB0_50:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#178
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_51
	jmp	.LBB0_55
.LBB0_51:                               ;   in Loop: Header=BB0_50 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#178
	sta	__rc22
	lda	__rc1
	adc	#4
	sta	__rc23
	lda	(__rc22),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc22),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc24
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc25
	ldy	__rc21
	lda	(__rc22),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc22),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	and	#mos16(2)
	sta	__rc2
	lda	__rc24
	cmp	__rc2
	bne	.LBB0_52
	jmp	.LBB0_53
.LBB0_52:
	sep	#32
	jsr	abort
.LBB0_53:                               ;   in Loop: Header=BB0_50 Depth=1
	sep	#32
	jmp	.LBB0_54
.LBB0_54:                               ;   in Loop: Header=BB0_50 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#178
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_50
.LBB0_55:
	sep	#32
	jmp	.LBB0_56
.LBB0_56:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	lda	(__rc8),y
	sta	__rc22
	ldx	#0
	stx	__rc30
	iny
	lda	(__rc8),y
	inx
	stx	__rc4
	sta	__rc23
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc2
	sep	#32
	iny
	lda	(__rc8),y
	sta	__rc7
	inx
	stx	__rc29
	ldy	__rc4
	lda	(__rc2),y
	sty	__rc6
	ldx	__rc7
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(4)
	sta	__rc2
	sep	#32
	ldy	#4
	lda	(__rc8),y
	sta	__rc10
	ldx	#4
	stx	__rc28
	ldy	__rc6
	lda	(__rc2),y
	sty	__rc13
	ldx	__rc10
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(6)
	sta	__rc2
	sep	#32
	ldy	#6
	lda	(__rc8),y
	sta	__rc10
	ldy	__rc13
	lda	(__rc2),y
	sta	__rc11
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#181
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc8),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#181
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	ldy	__rc13
	lda	(__rc2),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#183
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc8),y
	ldy	#10
	sty	__rc31
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#183
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc2
	sep	#32
	ldy	__rc15
	lda	(__rc2),y
	sty	__rc19
	sta	__rc15
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#185
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc8),y
	ldy	#12
	sty	__rc21
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#185
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	ldy	__rc19
	lda	(__rc2),y
	sty	__rc3
	sta	__rc19
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#187
	sta	__rc24
	lda	__rc1
	adc	#0
	plp
	sta	__rc25
	pla
	rep	#32
	sta	(__rc24)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc8),y
	ldx	#14
	stx	__rc20
	sta	__rc2
	clc
	php
	clc
	lda	__rc0
	adc	#187
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc8
	sep	#32
	ldy	__rc3
	lda	(__rc8),y
	pha
	tya
	tax
	pla
	sta	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	rep	#32
	lda	__rc22
	ora	#mos16(2)
	sta	__rc26
	lda	__rc4
	ora	#mos16(2)
	sta	__rc24
	lda	__rc6
	ora	#mos16(2)
	sta	__rc6
	lda	__rc10
	ora	#mos16(2)
	sta	__rc22
	lda	__rc12
	ora	#mos16(2)
	sta	__rc12
	lda	__rc14
	ora	#mos16(2)
	sta	__rc4
	lda	__rc18
	ora	#mos16(2)
	sta	__rc10
	lda	__rc2
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#245
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	__rc30
	sta	(__rc8),y
	lda	__rc27
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(2)
	sta	__rc2
	sep	#32
	lda	__rc24
	ldy	__rc29
	sta	(__rc8),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc2
	sep	#32
	lda	__rc6
	ldy	__rc28
	sta	(__rc8),y
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#245
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	ora	#mos16(2)
	sta	__rc6
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#75
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc22
	ldy	#6
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#75
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc2
	sep	#32
	lda	__rc23
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#77
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc12
	ldy	#8
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#77
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc2
	sep	#32
	lda	__rc13
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#79
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	__rc31
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#79
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc2
	sep	#32
	lda	__rc5
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#81
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	__rc21
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#81
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc2
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#83
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc20
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#83
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_57
.LBB0_57:
	ldy	#0
	clc
	lda	__rc0
	adc	#176
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_58
.LBB0_58:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#176
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_59
	jmp	.LBB0_63
.LBB0_59:                               ;   in Loop: Header=BB0_58 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#176
	sta	__rc22
	lda	__rc1
	adc	#4
	sta	__rc23
	lda	(__rc22),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc22),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc24
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc25
	ldy	__rc21
	lda	(__rc22),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc22),y
	ldx	#1
	stx	__rc21
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc21
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	ora	#mos16(2)
	sta	__rc2
	lda	__rc24
	cmp	__rc2
	bne	.LBB0_60
	jmp	.LBB0_61
.LBB0_60:
	sep	#32
	jsr	abort
.LBB0_61:                               ;   in Loop: Header=BB0_58 Depth=1
	sep	#32
	jmp	.LBB0_62
.LBB0_62:                               ;   in Loop: Header=BB0_58 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#176
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_58
.LBB0_63:
	sep	#32
	jmp	.LBB0_64
.LBB0_64:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	(__rc2),y
	tax
	ldy	#2
	lda	(__rc2),y
	sta	__rc23
	ldy	#4
	lda	(__rc2),y
	sta	__rc24
	ldy	#6
	lda	(__rc2),y
	sta	__rc22
	ldy	#8
	lda	(__rc2),y
	sta	__rc21
	ldy	#10
	lda	(__rc2),y
	sta	__rc20
	ldy	#12
	lda	(__rc2),y
	sta	__rc28
	ldy	#14
	lda	(__rc2),y
	sta	__rc30
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	pha
	clc
	lda	__rc0
	adc	#81
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#82
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc23
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc31
	clc
	lda	__rc0
	adc	#73
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc24
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc29
	stx	__rc24
	ldx	__rc22
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc26
	stx	__rc23
	ldx	__rc21
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc25
	stx	__rc22
	ldx	__rc20
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc27
	stx	__rc21
	ldx	__rc28
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc28
	stx	__rc20
	ldx	__rc30
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashlhi3
	sta	__rc8
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#81
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#82
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	lda	__rc31
	ldy	#2
	sta	(__rc2),y
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#73
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc4),y
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	lda	__rc29
	ldy	#4
	sta	(__rc2),y
	lda	__rc24
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	lda	__rc26
	ldy	#6
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc25
	sta	(__rc2),y
	lda	__rc22
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc27
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc28
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc6
	sta	(__rc4),y
	ldy	#1
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc8
	sta	(__rc2),y
	txa
	ldy	__rc6
	sta	(__rc4),y
	jmp	.LBB0_65
.LBB0_65:
	ldy	#0
	clc
	lda	__rc0
	adc	#174
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_66
.LBB0_66:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#174
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_67
	jmp	.LBB0_71
.LBB0_67:                               ;   in Loop: Header=BB0_66 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#174
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldx	__rc21
	stx	__rc3
	ldy	__rc3
	lda	(__rc24),y
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sep	#16
	ldx	#0
	sta	__rc2
	lda	#2
	jsr	__ashlhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_68
	jmp	.LBB0_69
.LBB0_68:
	sep	#32
	jsr	abort
.LBB0_69:                               ;   in Loop: Header=BB0_66 Depth=1
	sep	#32
	jmp	.LBB0_70
.LBB0_70:                               ;   in Loop: Header=BB0_66 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#174
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_66
.LBB0_71:
	sep	#32
	jmp	.LBB0_72
.LBB0_72:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	(__rc2),y
	tax
	ldy	#2
	lda	(__rc2),y
	sta	__rc23
	ldy	#4
	lda	(__rc2),y
	sta	__rc24
	ldy	#6
	lda	(__rc2),y
	sta	__rc22
	ldy	#8
	lda	(__rc2),y
	sta	__rc21
	ldy	#10
	lda	(__rc2),y
	sta	__rc20
	ldy	#12
	lda	(__rc2),y
	sta	__rc28
	ldy	#14
	lda	(__rc2),y
	sta	__rc30
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	pha
	clc
	lda	__rc0
	adc	#83
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#84
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc23
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc31
	clc
	lda	__rc0
	adc	#74
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc24
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc29
	stx	__rc24
	ldx	__rc22
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc26
	stx	__rc23
	ldx	__rc21
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc25
	stx	__rc22
	ldx	__rc20
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc27
	stx	__rc21
	ldx	__rc28
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc28
	stx	__rc20
	ldx	__rc30
	stx	__rc2
	ldx	#0
	lda	#2
	jsr	__ashrhi3
	sta	__rc8
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#83
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#84
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	lda	__rc31
	ldy	#2
	sta	(__rc2),y
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#74
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc4),y
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	lda	__rc29
	ldy	#4
	sta	(__rc2),y
	lda	__rc24
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	lda	__rc26
	ldy	#6
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc25
	sta	(__rc2),y
	lda	__rc22
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc27
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc6
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc28
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc6
	sta	(__rc4),y
	ldy	#1
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc8
	sta	(__rc2),y
	txa
	ldy	__rc6
	sta	(__rc4),y
	jmp	.LBB0_73
.LBB0_73:
	ldy	#0
	clc
	lda	__rc0
	adc	#172
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_74
.LBB0_74:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#172
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_75
	jmp	.LBB0_79
.LBB0_75:                               ;   in Loop: Header=BB0_74 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#172
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldx	__rc21
	stx	__rc3
	ldy	__rc3
	lda	(__rc24),y
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	__rc20
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	rep	#16
	ldy	__rc2
	lda	(__rc4),y
	sep	#16
	ldx	#0
	sta	__rc2
	lda	#2
	jsr	__ashrhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_76
	jmp	.LBB0_77
.LBB0_76:
	sep	#32
	jsr	abort
.LBB0_77:                               ;   in Loop: Header=BB0_74 Depth=1
	sep	#32
	jmp	.LBB0_78
.LBB0_78:                               ;   in Loop: Header=BB0_74 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#172
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_74
.LBB0_79:
	sep	#32
	jmp	.LBB0_80
.LBB0_80:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	lda	(__rc4),y
	sta	__rc2
	ldx	#0
	stx	__rc29
	iny
	lda	(__rc4),y
	inx
	stx	__rc8
	sta	__rc3
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(2)
	sta	__rc6
	sep	#32
	iny
	lda	(__rc4),y
	sta	__rc9
	inx
	stx	__rc28
	ldy	__rc8
	lda	(__rc6),y
	sty	__rc10
	ldx	__rc9
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(4)
	sta	__rc8
	sep	#32
	ldy	#4
	lda	(__rc4),y
	sta	__rc11
	ldx	#4
	stx	__rc30
	ldy	__rc10
	lda	(__rc8),y
	sty	__rc18
	ldx	__rc11
	stx	__rc8
	sta	__rc9
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc4),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#189
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc4),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#189
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#191
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc4),y
	ldy	#10
	sty	__rc27
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#191
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc21
	sta	__rc15
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#193
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc4),y
	ldy	#12
	sty	__rc31
	sta	__rc20
	clc
	php
	clc
	lda	__rc0
	adc	#193
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc18
	sep	#32
	ldy	__rc21
	lda	(__rc18),y
	sty	__rc22
	sta	__rc21
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#195
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc4),y
	ldx	#14
	stx	__rc26
	sta	__rc4
	clc
	php
	clc
	lda	__rc0
	adc	#195
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc18
	sep	#32
	ldy	__rc22
	lda	(__rc18),y
	pha
	tya
	tax
	pla
	sta	__rc5
	rep	#32
	lda	__rc2
	clc
	adc	#mos16(2)
	sta	__rc24
	lda	__rc6
	clc
	adc	#mos16(2)
	sta	__rc22
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc18
	lda	__rc10
	clc
	adc	#mos16(2)
	sta	__rc10
	lda	__rc12
	clc
	adc	#mos16(2)
	sta	__rc8
	lda	__rc14
	clc
	adc	#mos16(2)
	sta	__rc14
	lda	__rc20
	clc
	adc	#mos16(2)
	clc
	sep	#32
	pha
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	pla
	rep	#32
	sta	__rc6
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#255
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc24
	ldy	__rc29
	sta	(__rc2),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	lda	__rc22
	ldy	__rc28
	sta	(__rc2),y
	lda	__rc23
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	lda	__rc18
	ldy	__rc30
	sta	(__rc2),y
	lda	__rc19
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	clc
	php
	clc
	lda	__rc0
	adc	#255
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(2)
	sta	__rc12
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#85
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#6
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#85
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#87
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc8
	ldy	#8
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#87
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	lda	__rc9
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#89
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc14
	ldy	__rc27
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#89
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	lda	__rc15
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#91
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc31
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#91
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#93
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc12
	ldy	__rc26
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#93
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc13
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_81
.LBB0_81:
	ldy	#0
	clc
	lda	__rc0
	adc	#170
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#156
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	dey
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc20
	iny
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc21
	jmp	.LBB0_82
.LBB0_82:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#170
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_83
	jmp	.LBB0_87
.LBB0_83:                               ;   in Loop: Header=BB0_82 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#170
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc26
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc27
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc24
	ldx	__rc26
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	clc
	adc	#mos16(2)
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_84
	jmp	.LBB0_85
.LBB0_84:
	sep	#32
	jsr	abort
.LBB0_85:                               ;   in Loop: Header=BB0_82 Depth=1
	sep	#32
	jmp	.LBB0_86
.LBB0_86:                               ;   in Loop: Header=BB0_82 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#170
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_82
.LBB0_87:
	sep	#32
	jmp	.LBB0_88
.LBB0_88:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
	sta	__rc5
	lda	(__rc4),y
	sta	__rc2
	iny
	lda	(__rc4),y
	ldx	#1
	stx	__rc8
	sta	__rc3
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(2)
	sta	__rc6
	sep	#32
	iny
	lda	(__rc4),y
	tax
	ldy	__rc8
	lda	(__rc6),y
	sty	__rc10
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(4)
	sta	__rc8
	sep	#32
	ldy	#4
	lda	(__rc4),y
	sta	__rc11
	ldx	#4
	stx	__rc30
	ldy	__rc10
	lda	(__rc8),y
	sty	__rc18
	ldx	__rc11
	stx	__rc8
	sta	__rc9
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc4),y
	ldx	#6
	stx	__rc31
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#197
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc4),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#197
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#199
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc4),y
	ldx	#10
	stx	__rc29
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#199
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc23
	sta	__rc15
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#201
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc4),y
	ldx	#12
	stx	__rc28
	sta	__rc22
	clc
	php
	clc
	lda	__rc0
	adc	#201
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc18
	sep	#32
	ldy	__rc23
	lda	(__rc18),y
	sty	__rc18
	sta	__rc23
	rep	#32
	lda	__rc4
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#203
	sta	__rc24
	lda	__rc1
	adc	#0
	plp
	sta	__rc25
	pla
	rep	#32
	sta	(__rc24)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc4),y
	ldx	#14
	sta	__rc26
	clc
	php
	clc
	lda	__rc0
	adc	#203
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	__rc18
	lda	(__rc4),y
	sty	__rc4
	sta	__rc27
	rep	#32
	lda	__rc2
	sec
	sbc	__rc20
	sta	__rc24
	lda	__rc6
	sec
	sbc	__rc20
	sep	#32
	ldy	__rc20
	sty	__rc2
	ldy	__rc21
	sty	__rc3
	rep	#32
	sta	__rc20
	lda	__rc8
	sec
	sbc	__rc2
	sta	__rc18
	lda	__rc10
	sec
	sbc	__rc2
	sta	__rc10
	lda	__rc12
	sec
	sbc	__rc2
	sta	__rc8
	lda	__rc14
	sec
	sbc	__rc2
	sta	__rc6
	lda	__rc22
	sec
	sbc	__rc2
	sta	__rc22
	lda	__rc26
	sec
	sep	#32
	ldy	__rc2
	sty	__rc14
	ldy	__rc3
	sty	__rc15
	rep	#32
	sbc	__rc2
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#3
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	clc
	sep	#32
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	__rc24
	ldy	#0
	sta	(__rc2),y
	lda	__rc25
	ldy	__rc4
	sta	(__rc2),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc20
	ldy	#2
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc4
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc18
	ldy	__rc30
	sta	(__rc2),y
	lda	__rc19
	ldy	__rc4
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#3
	sta	__rc12
	lda	__rc1
	adc	#1
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	sta	__rc12
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#95
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	__rc31
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#95
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc18
	sep	#32
	lda	__rc11
	ldy	__rc4
	sta	(__rc18),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#97
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc8
	ldy	#8
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#97
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc10
	sep	#32
	lda	__rc9
	ldy	__rc4
	sta	(__rc10),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#99
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	pla
	rep	#32
	sta	(__rc8)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc29
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#99
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc8
	sep	#32
	lda	__rc7
	ldy	__rc4
	sta	(__rc8),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#101
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	pla
	rep	#32
	sta	(__rc6)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc22
	ldy	__rc28
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#101
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc6
	sep	#32
	lda	__rc23
	ldy	__rc4
	sta	(__rc6),y
	rep	#32
	lda	__rc2
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#103
	sta	__rc6
	lda	__rc1
	adc	#0
	plp
	sta	__rc7
	pla
	rep	#32
	sta	(__rc6)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc12
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	clc
	php
	clc
	lda	__rc0
	adc	#103
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc13
	ldy	__rc4
	sta	(__rc2),y
	jmp	.LBB0_89
.LBB0_89:
	ldy	#0
	clc
	lda	__rc0
	adc	#168
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	ldx	__rc14
	stx	__rc20
	ldx	__rc15
	stx	__rc21
	jmp	.LBB0_90
.LBB0_90:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#168
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_91
	jmp	.LBB0_95
.LBB0_91:                               ;   in Loop: Header=BB0_90 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#168
	sta	__rc24
	lda	__rc1
	adc	#4
	sta	__rc25
	lda	(__rc24),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc24),y
	ldx	#2
	stx	__rc2
	stx	__rc26
	ldx	__rc3
	stx	__rc27
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc27
	lda	(__rc24),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc24),y
	ldx	#1
	stx	__rc24
	ldx	__rc26
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc24
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	sec
	sbc	__rc20
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_92
	jmp	.LBB0_93
.LBB0_92:
	sep	#32
	jsr	abort
.LBB0_93:                               ;   in Loop: Header=BB0_90 Depth=1
	sep	#32
	jmp	.LBB0_94
.LBB0_94:                               ;   in Loop: Header=BB0_90 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#168
	sta	__rc2
	lda	__rc1
	adc	#4
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
.LBB0_95:
	sep	#32
	jmp	.LBB0_96
.LBB0_96:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	(__rc2),y
	sta	__rc6
	iny
	lda	(__rc2),y
	ldx	#1
	sta	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	clc
	sep	#32
	iny
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#135
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	txa
	tay
	lda	(__rc4),y
	sty	__rc10
	sta	__rc30
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#131
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#111
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc10
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	clc
	sep	#32
	ldy	#6
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#128
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#100
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	#8
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#123
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sta	__rc26
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	clc
	sep	#32
	ldy	#10
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#101
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sta	__rc28
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	#12
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#88
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#85
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#134
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	clc
	lda	__rc0
	adc	#108
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	inx
	ldy	#0
	stx	__rc2
	stx	__rc27
	sty	__rc3
	sty	__rc29
	ldx	__rc7
	lda	__rc6
	jsr	__mulhi3
	pha
	clc
	lda	__rc0
	adc	#91
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#92
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc30
	clc
	lda	__rc0
	adc	#135
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	pha
	clc
	lda	__rc0
	adc	#75
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#76
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#111
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#131
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	sta	__rc31
	stx	__rc30
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#100
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#128
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	sta	__rc25
	stx	__rc23
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc26
	clc
	lda	__rc0
	adc	#123
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	sta	__rc26
	stx	__rc22
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc28
	clc
	lda	__rc0
	adc	#101
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	sta	__rc28
	stx	__rc21
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#85
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#88
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	sta	__rc24
	stx	__rc20
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#108
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#134
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__mulhi3
	sta	__rc8
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#91
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#92
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc9
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#75
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#76
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc31
	sta	(__rc2),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	ldy	#6
	lda	__rc25
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc2),y
	lda	__rc22
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc28
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc24
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc9
	sta	(__rc4),y
	ldy	#1
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc8
	sta	(__rc2),y
	txa
	ldy	__rc6
	sta	(__rc4),y
	jmp	.LBB0_97
.LBB0_97:
	ldy	#0
	clc
	lda	__rc0
	adc	#166
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_98
.LBB0_98:                               ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#166
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_99
	jmp	.LBB0_103
.LBB0_99:                               ;   in Loop: Header=BB0_98 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#166
	sta	__rc22
	lda	__rc1
	adc	#4
	sta	__rc23
	lda	(__rc22),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc22),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc20
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc21
	ldy	__rc25
	lda	(__rc22),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc22),y
	ldx	#1
	stx	__rc22
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc22
	lda	(__rc6),y
	ldx	#2
	ldy	#0
	stx	__rc2
	sty	__rc3
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc20
	cmp	__rc2
	bne	.LBB0_100
	jmp	.LBB0_101
.LBB0_100:
	sep	#32
	jsr	abort
.LBB0_101:                              ;   in Loop: Header=BB0_98 Depth=1
	sep	#32
	jmp	.LBB0_102
.LBB0_102:                              ;   in Loop: Header=BB0_98 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#166
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_98
.LBB0_103:
	sep	#32
	jmp	.LBB0_104
.LBB0_104:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	(__rc2),y
	sta	__rc6
	iny
	lda	(__rc2),y
	ldx	#1
	sta	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	clc
	sep	#32
	iny
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#137
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	txa
	tay
	lda	(__rc4),y
	sty	__rc10
	sta	__rc30
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#132
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#110
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc10
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	clc
	sep	#32
	ldy	#6
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#129
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#102
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	#8
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#124
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sta	__rc26
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	clc
	sep	#32
	ldy	#10
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#103
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sta	__rc28
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	#12
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#89
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#86
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#136
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	clc
	lda	__rc0
	adc	#107
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	inx
	ldy	#0
	stx	__rc2
	stx	__rc27
	sty	__rc3
	sty	__rc29
	ldx	__rc7
	lda	__rc6
	jsr	__divhi3
	pha
	clc
	lda	__rc0
	adc	#93
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc30
	clc
	lda	__rc0
	adc	#137
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	pha
	clc
	lda	__rc0
	adc	#77
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#78
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#110
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#132
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	sta	__rc31
	stx	__rc30
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#102
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#129
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	sta	__rc25
	stx	__rc23
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc26
	clc
	lda	__rc0
	adc	#124
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	sta	__rc26
	stx	__rc22
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc28
	clc
	lda	__rc0
	adc	#103
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	sta	__rc28
	stx	__rc21
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#86
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#89
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	sta	__rc24
	stx	__rc20
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#107
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#136
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__divhi3
	sta	__rc8
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#93
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#94
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc9
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#77
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#78
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc31
	sta	(__rc2),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	ldy	#6
	lda	__rc25
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc2),y
	lda	__rc22
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc28
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc24
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc9
	sta	(__rc4),y
	ldy	#1
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc8
	sta	(__rc2),y
	txa
	ldy	__rc6
	sta	(__rc4),y
	jmp	.LBB0_105
.LBB0_105:
	ldy	#0
	clc
	lda	__rc0
	adc	#164
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_106
.LBB0_106:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#164
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_107
	jmp	.LBB0_111
.LBB0_107:                              ;   in Loop: Header=BB0_106 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#164
	sta	__rc22
	lda	__rc1
	adc	#4
	sta	__rc23
	lda	(__rc22),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc22),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc20
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc21
	ldy	__rc25
	lda	(__rc22),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc22),y
	ldx	#1
	stx	__rc22
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc22
	lda	(__rc6),y
	ldx	#2
	ldy	#0
	stx	__rc2
	sty	__rc3
	tax
	lda	__rc4
	jsr	__divhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc20
	cmp	__rc2
	bne	.LBB0_108
	jmp	.LBB0_109
.LBB0_108:
	sep	#32
	jsr	abort
.LBB0_109:                              ;   in Loop: Header=BB0_106 Depth=1
	sep	#32
	jmp	.LBB0_110
.LBB0_110:                              ;   in Loop: Header=BB0_106 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#164
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_106
.LBB0_111:
	sep	#32
	jmp	.LBB0_112
.LBB0_112:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	lda	(__rc2),y
	sta	__rc6
	iny
	lda	(__rc2),y
	ldx	#1
	sta	__rc7
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	clc
	sep	#32
	iny
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#139
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	txa
	tay
	lda	(__rc4),y
	sty	__rc10
	sta	__rc30
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	clc
	sep	#32
	ldy	#4
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#133
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#109
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc10
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	clc
	sep	#32
	ldy	#6
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#130
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#104
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	clc
	sep	#32
	ldy	#8
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#125
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sta	__rc26
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	clc
	sep	#32
	ldy	#10
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#105
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	sta	__rc28
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	clc
	sep	#32
	ldy	#12
	lda	(__rc2),y
	pha
	php
	clc
	lda	__rc0
	adc	#90
	sta	__rc8
	lda	__rc1
	adc	#2
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#87
	sta	__rc4
	lda	__rc1
	adc	#2
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#138
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc4),y
	pha
	clc
	lda	__rc0
	adc	#106
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	inx
	ldy	#0
	stx	__rc2
	stx	__rc27
	sty	__rc3
	sty	__rc29
	ldx	__rc7
	lda	__rc6
	jsr	__modhi3
	pha
	clc
	lda	__rc0
	adc	#95
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#96
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc30
	clc
	lda	__rc0
	adc	#139
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	pha
	clc
	lda	__rc0
	adc	#79
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#80
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	txa
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#109
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#133
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	sta	__rc31
	stx	__rc30
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#104
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#130
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	sta	__rc25
	stx	__rc23
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc26
	clc
	lda	__rc0
	adc	#125
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	sta	__rc26
	stx	__rc22
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc28
	clc
	lda	__rc0
	adc	#105
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	sta	__rc28
	stx	__rc21
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#87
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#90
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	sta	__rc24
	stx	__rc20
	ldx	__rc27
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	clc
	lda	__rc0
	adc	#106
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#138
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	jsr	__modhi3
	sta	__rc8
	clc
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#5
	sta	__rc3
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#95
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	ldy	#1
	sty	__rc17
	clc
	lda	__rc0
	adc	#96
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	dey
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	sty	__rc9
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#79
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#80
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(4)
	sta	__rc4
	sep	#32
	ldy	#4
	lda	__rc31
	sta	(__rc2),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(6)
	sta	__rc4
	sep	#32
	ldy	#6
	lda	__rc25
	sta	(__rc2),y
	lda	__rc23
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(8)
	sta	__rc4
	sep	#32
	ldy	#8
	lda	__rc26
	sta	(__rc2),y
	lda	__rc22
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(10)
	sta	__rc4
	sep	#32
	ldy	#10
	lda	__rc28
	sta	(__rc2),y
	lda	__rc21
	ldy	__rc9
	sta	(__rc4),y
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	ldy	#12
	lda	__rc24
	sta	(__rc2),y
	lda	__rc20
	ldy	__rc9
	sta	(__rc4),y
	ldy	#1
	sty	__rc6
	clc
	rep	#32
	lda	__rc2
	adc	#mos16(14)
	sta	__rc4
	sep	#32
	ldy	#14
	lda	__rc8
	sta	(__rc2),y
	txa
	ldy	__rc6
	sta	(__rc4),y
	jmp	.LBB0_113
.LBB0_113:
	ldy	#0
	clc
	lda	__rc0
	adc	#162
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_114
.LBB0_114:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#162
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_115
	jmp	.LBB0_119
.LBB0_115:                              ;   in Loop: Header=BB0_114 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#162
	sta	__rc22
	lda	__rc1
	adc	#4
	sta	__rc23
	lda	(__rc22),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc22),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc20
	sep	#16
	ldy	#1
	lda	(__rc6),y
	sty	__rc2
	sta	__rc21
	ldy	__rc25
	lda	(__rc22),y
	sty	__rc3
	sta	__rc4
	ldy	__rc2
	lda	(__rc22),y
	ldx	#1
	stx	__rc22
	ldx	__rc24
	stx	__rc2
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc22
	lda	(__rc6),y
	ldx	#2
	ldy	#0
	stx	__rc2
	sty	__rc3
	tax
	lda	__rc4
	jsr	__modhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc20
	cmp	__rc2
	bne	.LBB0_116
	jmp	.LBB0_117
.LBB0_116:
	sep	#32
	jsr	abort
.LBB0_117:                              ;   in Loop: Header=BB0_114 Depth=1
	sep	#32
	jmp	.LBB0_118
.LBB0_118:                              ;   in Loop: Header=BB0_114 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#162
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_114
.LBB0_119:
	sep	#32
	jmp	.LBB0_120
.LBB0_120:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	lda	(__rc8),y
	sta	__rc2
	ldx	#0
	stx	__rc30
	iny
	lda	(__rc8),y
	inx
	stx	__rc6
	sta	__rc3
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	iny
	lda	(__rc8),y
	tax
	ldy	__rc6
	lda	(__rc4),y
	sty	__rc10
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(4)
	sta	__rc6
	sep	#32
	ldy	#4
	lda	(__rc8),y
	tax
	ldy	__rc10
	lda	(__rc6),y
	sty	__rc18
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc8),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#205
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc8),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#205
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#207
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc8),y
	ldy	#10
	sty	__rc31
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#207
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc19
	sta	__rc15
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#209
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	pla
	rep	#32
	sta	(__rc20)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc8),y
	ldx	#12
	stx	__rc29
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#209
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	rep	#32
	lda	(__rc20)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc20
	sep	#32
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc21
	sta	__rc19
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#211
	sta	__rc22
	lda	__rc1
	adc	#0
	plp
	sta	__rc23
	pla
	rep	#32
	sta	(__rc22)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc8),y
	ldx	#14
	stx	__rc28
	sta	__rc20
	clc
	php
	clc
	lda	__rc0
	adc	#211
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc8
	sep	#32
	ldy	__rc21
	lda	(__rc8),y
	pha
	tya
	tax
	pla
	sta	__rc21
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	rep	#32
	lda	__rc2
	eor	#mos16(2)
	sta	__rc26
	lda	__rc4
	eor	#mos16(2)
	sta	__rc24
	lda	__rc6
	eor	#mos16(2)
	sta	__rc6
	lda	__rc10
	eor	#mos16(2)
	sta	__rc22
	lda	__rc12
	eor	#mos16(2)
	sta	__rc10
	lda	__rc14
	eor	#mos16(2)
	sta	__rc4
	lda	__rc18
	eor	#mos16(2)
	sta	__rc2
	lda	__rc20
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#247
	sta	__rc12
	lda	__rc1
	adc	#0
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	__rc30
	sta	(__rc8),y
	lda	__rc27
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc24
	ldy	#2
	sta	(__rc8),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc6
	ldy	#4
	sta	(__rc8),y
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#247
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	eor	#mos16(2)
	sta	__rc6
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#105
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc22
	ldy	#6
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#105
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	lda	__rc23
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#107
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#8
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#107
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#109
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	__rc31
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#109
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc10
	sep	#32
	lda	__rc5
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#111
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc2
	ldy	__rc29
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#111
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc3
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#113
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc28
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#113
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_121
.LBB0_121:
	ldy	#0
	clc
	lda	__rc0
	adc	#160
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_122
.LBB0_122:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#160
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_123
	jmp	.LBB0_127
.LBB0_123:                              ;   in Loop: Header=BB0_122 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#160
	sta	__rc20
	lda	__rc1
	adc	#4
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc25
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
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	eor	#mos16(2)
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_124
	jmp	.LBB0_125
.LBB0_124:
	sep	#32
	jsr	abort
.LBB0_125:                              ;   in Loop: Header=BB0_122 Depth=1
	sep	#32
	jmp	.LBB0_126
.LBB0_126:                              ;   in Loop: Header=BB0_122 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#160
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_122
.LBB0_127:
	sep	#32
	jmp	.LBB0_128
.LBB0_128:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	lda	(__rc8),y
	sta	__rc2
	ldx	#0
	stx	__rc30
	iny
	lda	(__rc8),y
	inx
	stx	__rc6
	sta	__rc3
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	iny
	lda	(__rc8),y
	tax
	ldy	__rc6
	lda	(__rc4),y
	sty	__rc10
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(4)
	sta	__rc6
	sep	#32
	ldy	#4
	lda	(__rc8),y
	tax
	ldy	__rc10
	lda	(__rc6),y
	sty	__rc18
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc8),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#213
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc8),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#213
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#215
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc8),y
	ldy	#10
	sty	__rc31
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#215
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc19
	sta	__rc15
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#217
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	pla
	rep	#32
	sta	(__rc20)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc8),y
	ldx	#12
	stx	__rc29
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#217
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	rep	#32
	lda	(__rc20)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc20
	sep	#32
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc21
	sta	__rc19
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#219
	sta	__rc22
	lda	__rc1
	adc	#0
	plp
	sta	__rc23
	pla
	rep	#32
	sta	(__rc22)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc8),y
	ldx	#14
	stx	__rc28
	sta	__rc20
	clc
	php
	clc
	lda	__rc0
	adc	#219
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc8
	sep	#32
	ldy	__rc21
	lda	(__rc8),y
	pha
	tya
	tax
	pla
	sta	__rc21
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	rep	#32
	lda	__rc2
	and	#mos16(2)
	sta	__rc26
	lda	__rc4
	and	#mos16(2)
	sta	__rc24
	lda	__rc6
	and	#mos16(2)
	sta	__rc6
	lda	__rc10
	and	#mos16(2)
	sta	__rc22
	lda	__rc12
	and	#mos16(2)
	sta	__rc10
	lda	__rc14
	and	#mos16(2)
	sta	__rc4
	lda	__rc18
	and	#mos16(2)
	sta	__rc2
	lda	__rc20
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#249
	sta	__rc12
	lda	__rc1
	adc	#0
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	__rc30
	sta	(__rc8),y
	lda	__rc27
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc24
	ldy	#2
	sta	(__rc8),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc6
	ldy	#4
	sta	(__rc8),y
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#249
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	and	#mos16(2)
	sta	__rc6
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#115
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc22
	ldy	#6
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#115
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	lda	__rc23
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#117
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#8
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#117
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#119
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	__rc31
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#119
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc10
	sep	#32
	lda	__rc5
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#121
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc2
	ldy	__rc29
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#121
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc3
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#123
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc28
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#123
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_129
.LBB0_129:
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_130
.LBB0_130:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_131
	jmp	.LBB0_135
.LBB0_131:                              ;   in Loop: Header=BB0_130 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc20
	lda	__rc1
	adc	#4
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc25
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
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	and	#mos16(2)
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_132
	jmp	.LBB0_133
.LBB0_132:
	sep	#32
	jsr	abort
.LBB0_133:                              ;   in Loop: Header=BB0_130 Depth=1
	sep	#32
	jmp	.LBB0_134
.LBB0_134:                              ;   in Loop: Header=BB0_130 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_130
.LBB0_135:
	sep	#32
	jmp	.LBB0_136
.LBB0_136:
	ldy	#0
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	lda	(__rc8),y
	sta	__rc2
	ldx	#0
	stx	__rc30
	iny
	lda	(__rc8),y
	inx
	stx	__rc6
	sta	__rc3
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(2)
	sta	__rc4
	sep	#32
	iny
	lda	(__rc8),y
	tax
	ldy	__rc6
	lda	(__rc4),y
	sty	__rc10
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(4)
	sta	__rc6
	sep	#32
	ldy	#4
	lda	(__rc8),y
	tax
	ldy	__rc10
	lda	(__rc6),y
	sty	__rc18
	stx	__rc6
	sta	__rc7
	rep	#32
	lda	__rc8
	clc
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	ldy	#6
	lda	(__rc8),y
	sta	__rc10
	ldy	__rc18
	lda	(__rc12),y
	sta	__rc11
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#221
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#8
	lda	(__rc8),y
	sta	__rc12
	clc
	php
	clc
	lda	__rc0
	adc	#221
	sta	__rc14
	lda	__rc1
	adc	#0
	plp
	sta	__rc15
	rep	#32
	lda	(__rc14)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc14
	sep	#32
	ldy	__rc18
	lda	(__rc14),y
	sty	__rc15
	sta	__rc13
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#223
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	pla
	rep	#32
	sta	(__rc18)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#10
	lda	(__rc8),y
	ldy	#10
	sty	__rc31
	sta	__rc14
	clc
	php
	clc
	lda	__rc0
	adc	#223
	sta	__rc18
	lda	__rc1
	adc	#0
	plp
	sta	__rc19
	rep	#32
	lda	(__rc18)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc18
	sep	#32
	ldy	__rc15
	lda	(__rc18),y
	sty	__rc19
	sta	__rc15
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#225
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	pla
	rep	#32
	sta	(__rc20)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#12
	lda	(__rc8),y
	ldx	#12
	stx	__rc29
	sta	__rc18
	clc
	php
	clc
	lda	__rc0
	adc	#225
	sta	__rc20
	lda	__rc1
	adc	#0
	plp
	sta	__rc21
	rep	#32
	lda	(__rc20)                        ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc20
	sep	#32
	ldy	__rc19
	lda	(__rc20),y
	sty	__rc21
	sta	__rc19
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#227
	sta	__rc22
	lda	__rc1
	adc	#0
	plp
	sta	__rc23
	pla
	rep	#32
	sta	(__rc22)                        ; 2-byte Folded Spill
	sep	#32
	ldy	#14
	lda	(__rc8),y
	ldx	#14
	stx	__rc28
	sta	__rc20
	clc
	php
	clc
	lda	__rc0
	adc	#227
	sta	__rc8
	lda	__rc1
	adc	#0
	plp
	sta	__rc9
	rep	#32
	lda	(__rc8)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc8
	sep	#32
	ldy	__rc21
	lda	(__rc8),y
	pha
	tya
	tax
	pla
	sta	__rc21
	clc
	lda	__rc0
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#5
	sta	__rc9
	rep	#32
	lda	__rc2
	ora	#mos16(2)
	sta	__rc26
	lda	__rc4
	ora	#mos16(2)
	sta	__rc24
	lda	__rc6
	ora	#mos16(2)
	sta	__rc6
	lda	__rc10
	ora	#mos16(2)
	sta	__rc22
	lda	__rc12
	ora	#mos16(2)
	sta	__rc10
	lda	__rc14
	ora	#mos16(2)
	sta	__rc4
	lda	__rc18
	ora	#mos16(2)
	sta	__rc2
	lda	__rc20
	sep	#32
	pha
	clc
	lda	__rc0
	adc	#251
	sta	__rc12
	lda	__rc1
	adc	#0
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc26
	ldy	__rc30
	sta	(__rc8),y
	lda	__rc27
	pha
	txa
	tay
	pla
	sta	(__rc8),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(2)
	sta	__rc12
	sep	#32
	lda	__rc24
	ldy	#2
	sta	(__rc8),y
	lda	__rc25
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	rep	#32
	lda	__rc8
	adc	#mos16(4)
	sta	__rc12
	sep	#32
	lda	__rc6
	ldy	#4
	sta	(__rc8),y
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	clc
	lda	__rc0
	adc	#251
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	(__rc6)                         ; 2-byte Folded Reload
	ora	#mos16(2)
	sta	__rc6
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#125
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc22
	ldy	#6
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#125
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(6)
	sta	__rc12
	sep	#32
	lda	__rc23
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#127
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	pla
	rep	#32
	sta	(__rc12)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc10
	ldy	#8
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#127
	sta	__rc12
	lda	__rc1
	adc	#0
	plp
	sta	__rc13
	rep	#32
	lda	(__rc12)                        ; 2-byte Folded Reload
	adc	#mos16(8)
	sta	__rc12
	sep	#32
	lda	__rc11
	pha
	txa
	tay
	pla
	sta	(__rc12),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#129
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	pla
	rep	#32
	sta	(__rc10)                        ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	ldy	__rc31
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#129
	sta	__rc10
	lda	__rc1
	adc	#0
	plp
	sta	__rc11
	rep	#32
	lda	(__rc10)                        ; 2-byte Folded Reload
	adc	#mos16(10)
	sta	__rc10
	sep	#32
	lda	__rc5
	pha
	txa
	tay
	pla
	sta	(__rc10),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#131
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	pla
	rep	#32
	sta	(__rc4)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc2
	ldy	__rc29
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#131
	sta	__rc4
	lda	__rc1
	adc	#0
	plp
	sta	__rc5
	rep	#32
	lda	(__rc4)                         ; 2-byte Folded Reload
	adc	#mos16(12)
	sta	__rc4
	sep	#32
	lda	__rc3
	pha
	txa
	tay
	pla
	sta	(__rc4),y
	rep	#32
	lda	__rc8
	sep	#32
	pha
	php
	clc
	lda	__rc0
	adc	#133
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	pla
	rep	#32
	sta	(__rc2)                         ; 2-byte Folded Spill
	sep	#32
	lda	__rc6
	ldy	__rc28
	sta	(__rc8),y
	clc
	php
	clc
	lda	__rc0
	adc	#133
	sta	__rc2
	lda	__rc1
	adc	#0
	plp
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	adc	#mos16(14)
	sta	__rc2
	sep	#32
	lda	__rc7
	pha
	txa
	tay
	pla
	sta	(__rc2),y
	jmp	.LBB0_137
.LBB0_137:
	ldy	#0
	clc
	lda	__rc0
	adc	#156
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_138
.LBB0_138:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#156
	sta	__rc2
	lda	__rc1
	adc	#4
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
	cmp	#32776
	bcc	.LBB0_139
	jmp	.LBB0_143
.LBB0_139:                              ;   in Loop: Header=BB0_138 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#156
	sta	__rc20
	lda	__rc1
	adc	#4
	sta	__rc21
	lda	(__rc20),y
	sta	__rc4
	ldx	#0
	stx	__rc3
	iny
	lda	(__rc20),y
	ldx	#2
	stx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc25
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#32
	sta	__rc4
	lda	__rc1
	adc	#5
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
	ldy	__rc25
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
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#5
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
	sta	__rc2
	sep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc3
	rep	#32
	lda	__rc2
	ora	#mos16(2)
	sta	__rc2
	lda	__rc22
	cmp	__rc2
	bne	.LBB0_140
	jmp	.LBB0_141
.LBB0_140:
	sep	#32
	jsr	abort
.LBB0_141:                              ;   in Loop: Header=BB0_138 Depth=1
	sep	#32
	jmp	.LBB0_142
.LBB0_142:                              ;   in Loop: Header=BB0_138 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#156
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_138
.LBB0_143:
	sep	#32
	jmp	.LBB0_144
.LBB0_144:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#253
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
	adc	#240
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
	adc	#254
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
	adc	#255
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
	jsr	__addsf3
	pha
	clc
	lda	__rc0
	adc	#237
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#239
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
	adc	#238
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
	jsr	__addsf3
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
	jsr	__addsf3
	sta	__rc25
	stx	__rc27
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#253
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#240
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#254
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
	adc	#255
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	ldx	#0
	tya
	jsr	__addsf3
	sta	__rc7
	stx	__rc8
	clc
	ldx	__rc0
	stx	__rc10
	lda	__rc1
	adc	#5
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#237
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
	adc	#239
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
	adc	#238
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
	adc	#128
	sta	__rc2
	lda	__rc1
	adc	#4
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
	adc	#12
	sta	__rc14
	lda	__rc1
	adc	#2
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
	adc	#11
	sta	__rc14
	lda	__rc1
	adc	#2
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#134
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#133
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
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
	adc	#141
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#14
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#9
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#10
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#140
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#13
	sta	__rc2
	lda	__rc1
	adc	#2
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#197
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#198
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	jsr	__addsf3
	pha
	clc
	lda	__rc0
	adc	#165
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#166
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#168
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#167
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#134
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#133
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#11
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#12
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc24
	stx	__rc25
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc23
	clc
	lda	__rc0
	adc	#9
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#10
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#14
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#141
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc26
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#197
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#198
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#13
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#140
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#165
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#166
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#168
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	clc
	lda	__rc0
	adc	#167
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_145
.LBB0_145:
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_146
.LBB0_146:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#4
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
	bcc	.LBB0_147
	jmp	.LBB0_154
.LBB0_147:                              ;   in Loop: Header=BB0_146 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc20
	lda	__rc1
	adc	#4
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_151
	jmp	.LBB0_148
.LBB0_148:                              ;   in Loop: Header=BB0_146 Depth=1
	ldy	__rc2
	bne	.LBB0_151
	jmp	.LBB0_149
.LBB0_149:                              ;   in Loop: Header=BB0_146 Depth=1
	cpx	#0
	bne	.LBB0_151
	jmp	.LBB0_150
.LBB0_150:                              ;   in Loop: Header=BB0_146 Depth=1
	tax
	bne	.LBB0_151
	jmp	.LBB0_152
.LBB0_151:
	jsr	abort
.LBB0_152:                              ;   in Loop: Header=BB0_146 Depth=1
	jmp	.LBB0_153
.LBB0_153:                              ;   in Loop: Header=BB0_146 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_146
.LBB0_154:
	sep	#32
	jmp	.LBB0_155
.LBB0_155:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	ldx	__rc0
	stx	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#244
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
	adc	#1
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#2
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#241
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#243
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
	adc	#242
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
	ldx	__rc0
	stx	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#244
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#1
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#2
	sta	__rc8
	lda	__rc1
	adc	#2
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
	ldx	__rc0
	stx	__rc10
	lda	__rc1
	adc	#5
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#241
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
	adc	#243
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
	adc	#242
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
	adc	#96
	sta	__rc2
	lda	__rc1
	adc	#4
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
	adc	#18
	sta	__rc14
	lda	__rc1
	adc	#2
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
	adc	#17
	sta	__rc14
	lda	__rc1
	adc	#2
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#136
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#135
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
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
	adc	#143
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#20
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#15
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#16
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#142
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#19
	sta	__rc2
	lda	__rc1
	adc	#2
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#199
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#200
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#169
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#170
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#172
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#171
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#136
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#135
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#17
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#18
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#15
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#16
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#20
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#143
	sta	__rc8
	lda	__rc1
	adc	#2
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
	clc
	lda	__rc0
	adc	#199
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#200
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#19
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#142
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#169
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#170
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#172
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	clc
	lda	__rc0
	adc	#171
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_156
.LBB0_156:
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_157
.LBB0_157:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#4
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
	bcc	.LBB0_158
	jmp	.LBB0_165
.LBB0_158:                              ;   in Loop: Header=BB0_157 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc20
	lda	__rc1
	adc	#4
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_162
	jmp	.LBB0_159
.LBB0_159:                              ;   in Loop: Header=BB0_157 Depth=1
	ldy	__rc2
	bne	.LBB0_162
	jmp	.LBB0_160
.LBB0_160:                              ;   in Loop: Header=BB0_157 Depth=1
	cpx	#0
	bne	.LBB0_162
	jmp	.LBB0_161
.LBB0_161:                              ;   in Loop: Header=BB0_157 Depth=1
	tax
	bne	.LBB0_162
	jmp	.LBB0_163
.LBB0_162:
	jsr	abort
.LBB0_163:                              ;   in Loop: Header=BB0_157 Depth=1
	jmp	.LBB0_164
.LBB0_164:                              ;   in Loop: Header=BB0_157 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#94
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_157
.LBB0_165:
	sep	#32
	jmp	.LBB0_166
.LBB0_166:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#3
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#248
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
	adc	#4
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#5
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#245
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#247
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
	adc	#246
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
	adc	#3
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#248
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#4
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#5
	sta	__rc8
	lda	__rc1
	adc	#2
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
	ldx	__rc0
	stx	__rc10
	lda	__rc1
	adc	#5
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#245
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
	adc	#247
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
	adc	#246
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
	adc	#4
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
	adc	#24
	sta	__rc14
	lda	__rc1
	adc	#2
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
	adc	#23
	sta	__rc14
	lda	__rc1
	adc	#2
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#138
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#137
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
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
	adc	#145
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#26
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#21
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#22
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#144
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#25
	sta	__rc2
	lda	__rc1
	adc	#2
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#201
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#202
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#173
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#174
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#175
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#138
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#137
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#23
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#24
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#21
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#22
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#26
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#145
	sta	__rc8
	lda	__rc1
	adc	#2
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
	clc
	lda	__rc0
	adc	#201
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#202
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#25
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#144
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#173
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#174
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#176
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	clc
	lda	__rc0
	adc	#175
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_167
.LBB0_167:
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_168
.LBB0_168:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#4
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
	bcc	.LBB0_169
	jmp	.LBB0_176
.LBB0_169:                              ;   in Loop: Header=BB0_168 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc20
	lda	__rc1
	adc	#4
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_173
	jmp	.LBB0_170
.LBB0_170:                              ;   in Loop: Header=BB0_168 Depth=1
	ldy	__rc2
	bne	.LBB0_173
	jmp	.LBB0_171
.LBB0_171:                              ;   in Loop: Header=BB0_168 Depth=1
	cpx	#0
	bne	.LBB0_173
	jmp	.LBB0_172
.LBB0_172:                              ;   in Loop: Header=BB0_168 Depth=1
	tax
	bne	.LBB0_173
	jmp	.LBB0_174
.LBB0_173:
	jsr	abort
.LBB0_174:                              ;   in Loop: Header=BB0_168 Depth=1
	jmp	.LBB0_175
.LBB0_175:                              ;   in Loop: Header=BB0_168 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#62
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_168
.LBB0_176:
	sep	#32
	jmp	.LBB0_177
.LBB0_177:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#6
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#252
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
	adc	#7
	sta	__rc6
	lda	__rc1
	adc	#2
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#8
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#249
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#251
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
	adc	#250
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
	adc	#6
	sta	__rc2
	lda	__rc1
	adc	#2
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#252
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#7
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#8
	sta	__rc8
	lda	__rc1
	adc	#2
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
	ldx	__rc0
	stx	__rc10
	lda	__rc1
	adc	#5
	php
	sta	__rc11
	ldx	#0
	stx	__rc6
	ldy	__rc6
	sty	__rc17
	clc
	lda	__rc0
	adc	#249
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
	adc	#251
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
	adc	#250
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
	adc	#4
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
	adc	#30
	sta	__rc14
	lda	__rc1
	adc	#2
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
	adc	#29
	sta	__rc14
	lda	__rc1
	adc	#2
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc19
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#140
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc15
	ldy	__rc22
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#139
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
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
	adc	#147
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#27
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#28
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#146
	sta	__rc2
	lda	__rc1
	adc	#2
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
	adc	#31
	sta	__rc2
	lda	__rc1
	adc	#2
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc4),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#203
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc9
	ldy	__rc7
	lda	(__rc4),y
	pha
	php
	clc
	lda	__rc0
	adc	#204
	sta	__rc2
	lda	__rc1
	adc	#1
	plp
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#177
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#178
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#180
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#179
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#140
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#139
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#29
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#30
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#27
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#28
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#32
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#147
	sta	__rc8
	lda	__rc1
	adc	#2
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
	clc
	lda	__rc0
	adc	#203
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#204
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	adc	#31
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#146
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#177
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#178
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#180
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldy	#3
	sty	__rc17
	clc
	lda	__rc0
	adc	#179
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_178
.LBB0_178:
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#4
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_179
.LBB0_179:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#4
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
	bcc	.LBB0_180
	jmp	.LBB0_187
.LBB0_180:                              ;   in Loop: Header=BB0_179 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc20
	lda	__rc1
	adc	#4
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_184
	jmp	.LBB0_181
.LBB0_181:                              ;   in Loop: Header=BB0_179 Depth=1
	ldy	__rc2
	bne	.LBB0_184
	jmp	.LBB0_182
.LBB0_182:                              ;   in Loop: Header=BB0_179 Depth=1
	cpx	#0
	bne	.LBB0_184
	jmp	.LBB0_183
.LBB0_183:                              ;   in Loop: Header=BB0_179 Depth=1
	tax
	bne	.LBB0_184
	jmp	.LBB0_185
.LBB0_184:
	jsr	abort
.LBB0_185:                              ;   in Loop: Header=BB0_179 Depth=1
	jmp	.LBB0_186
.LBB0_186:                              ;   in Loop: Header=BB0_179 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#30
	sta	__rc2
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_179
.LBB0_187:
	sep	#32
	jmp	.LBB0_188
.LBB0_188:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#229
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
	adc	#230
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
	pha
	php
	clc
	lda	__rc0
	adc	#206
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc28
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
	adc	#34
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#33
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#221
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
	adc	#222
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
	pha
	clc
	lda	__rc0
	adc	#94
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#205
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#93
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc31
	ldx	__rc26
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc29
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#229
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
	ldx	__rc28
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc29
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#206
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#230
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
	clc
	lda	__rc0
	adc	#221
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#222
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
	adc	#33
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#34
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	ldx	__rc0
	stx	__rc8
	lda	__rc1
	adc	#5
	php
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#94
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#205
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#93
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc31
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
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc30
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
	ldy	#240
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
	adc	#69
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#40
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#36
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#35
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#152
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#148
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#38
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#37
	sta	__rc4
	lda	__rc1
	adc	#2
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
	ldx	__rc0
	stx	__rc12
	lda	__rc1
	adc	#4
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
	adc	#41
	sta	__rc10
	lda	__rc1
	adc	#2
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
	adc	#39
	sta	__rc10
	lda	__rc1
	adc	#2
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
	lda	__rc0
	adc	#207
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
	sty	__rc10
	pha
	php
	clc
	lda	__rc0
	adc	#208
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
	sta	__rc27
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc29
	ldy	#3
	lda	(__rc10),y
	sta	__rc28
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc30
	ldy	#1
	lda	(__rc10),y
	sta	__rc31
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc22
	ldy	#3
	lda	(__rc10),y
	sta	__rc25
	ldx	__rc8
	ldy	#240
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	pha
	clc
	lda	__rc0
	adc	#181
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#184
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#182
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#183
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#36
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#35
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#40
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#69
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc24
	stx	__rc20
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc26
	clc
	lda	__rc0
	adc	#38
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#37
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	clc
	lda	__rc0
	adc	#148
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#152
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc21
	stx	__rc27
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#207
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc30
	stx	__rc4
	ldx	__rc31
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#39
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#41
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#181
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#184
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#182
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#183
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	lda	__rc27
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc29
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
	jmp	.LBB0_189
.LBB0_189:
	ldy	#0
	clc
	lda	__rc0
	adc	#254
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_190
.LBB0_190:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#254
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
	bcc	.LBB0_191
	jmp	.LBB0_198
.LBB0_191:                              ;   in Loop: Header=BB0_190 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#254
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_195
	jmp	.LBB0_192
.LBB0_192:                              ;   in Loop: Header=BB0_190 Depth=1
	ldy	__rc2
	bne	.LBB0_195
	jmp	.LBB0_193
.LBB0_193:                              ;   in Loop: Header=BB0_190 Depth=1
	cpx	#0
	bne	.LBB0_195
	jmp	.LBB0_194
.LBB0_194:                              ;   in Loop: Header=BB0_190 Depth=1
	tax
	bne	.LBB0_195
	jmp	.LBB0_196
.LBB0_195:
	jsr	abort
.LBB0_196:                              ;   in Loop: Header=BB0_190 Depth=1
	jmp	.LBB0_197
.LBB0_197:                              ;   in Loop: Header=BB0_190 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#254
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
	jmp	.LBB0_190
.LBB0_198:
	sep	#32
	jmp	.LBB0_199
.LBB0_199:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#231
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
	adc	#232
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
	pha
	php
	clc
	lda	__rc0
	adc	#210
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc28
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
	adc	#43
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#42
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#223
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
	adc	#224
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
	pha
	clc
	lda	__rc0
	adc	#96
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#209
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#95
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc31
	ldx	__rc26
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc29
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#231
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc25
	stx	__rc26
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc28
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc29
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#210
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#232
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc27
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#223
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#224
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
	adc	#42
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#43
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	stx	__rc7
	clc
	ldx	__rc0
	stx	__rc8
	lda	__rc1
	adc	#5
	php
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#96
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#209
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#95
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc31
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
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc30
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
	ldy	#239
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
	adc	#70
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#49
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#45
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#44
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#153
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#149
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#47
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#46
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#3
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
	adc	#50
	sta	__rc10
	lda	__rc1
	adc	#2
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
	adc	#48
	sta	__rc10
	lda	__rc1
	adc	#2
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
	lda	__rc0
	adc	#211
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
	sty	__rc10
	pha
	php
	clc
	lda	__rc0
	adc	#212
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
	sta	__rc27
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc29
	ldy	#3
	lda	(__rc10),y
	sta	__rc28
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc30
	ldy	#1
	lda	(__rc10),y
	sta	__rc31
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc22
	ldy	#3
	lda	(__rc10),y
	sta	__rc25
	ldx	__rc8
	ldy	#239
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	pha
	clc
	lda	__rc0
	adc	#185
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#188
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#186
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#187
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#45
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#44
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#49
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#70
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#47
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#46
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	clc
	lda	__rc0
	adc	#149
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#153
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc21
	stx	__rc27
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#211
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#212
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc30
	stx	__rc4
	ldx	__rc31
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#48
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#50
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#185
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#188
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#186
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#187
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	lda	__rc27
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc29
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
	jmp	.LBB0_200
.LBB0_200:
	ldy	#0
	clc
	lda	__rc0
	adc	#222
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_201
.LBB0_201:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#222
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
	bcc	.LBB0_202
	jmp	.LBB0_209
.LBB0_202:                              ;   in Loop: Header=BB0_201 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#222
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_206
	jmp	.LBB0_203
.LBB0_203:                              ;   in Loop: Header=BB0_201 Depth=1
	ldy	__rc2
	bne	.LBB0_206
	jmp	.LBB0_204
.LBB0_204:                              ;   in Loop: Header=BB0_201 Depth=1
	cpx	#0
	bne	.LBB0_206
	jmp	.LBB0_205
.LBB0_205:                              ;   in Loop: Header=BB0_201 Depth=1
	tax
	bne	.LBB0_206
	jmp	.LBB0_207
.LBB0_206:
	jsr	abort
.LBB0_207:                              ;   in Loop: Header=BB0_201 Depth=1
	jmp	.LBB0_208
.LBB0_208:                              ;   in Loop: Header=BB0_201 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#222
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
	jmp	.LBB0_201
.LBB0_209:
	sep	#32
	jmp	.LBB0_210
.LBB0_210:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#233
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
	adc	#234
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
	pha
	php
	clc
	lda	__rc0
	adc	#214
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc28
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
	adc	#52
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#51
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#225
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
	adc	#226
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
	clc
	lda	__rc0
	adc	#213
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#97
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc31
	ldx	__rc26
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc29
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#233
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc25
	stx	__rc26
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc28
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc29
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#214
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#234
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc27
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#225
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#226
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
	adc	#51
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#52
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	stx	__rc7
	clc
	ldx	__rc0
	stx	__rc8
	lda	__rc1
	adc	#5
	php
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#98
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#213
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#97
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc31
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
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc30
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
	ldy	#238
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
	adc	#71
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#58
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#54
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#53
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#154
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#150
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#56
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#55
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#3
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
	adc	#59
	sta	__rc10
	lda	__rc1
	adc	#2
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
	adc	#57
	sta	__rc10
	lda	__rc1
	adc	#2
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
	lda	__rc0
	adc	#215
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
	sty	__rc10
	pha
	php
	clc
	lda	__rc0
	adc	#216
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
	sta	__rc27
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc29
	ldy	#3
	lda	(__rc10),y
	sta	__rc28
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc30
	ldy	#1
	lda	(__rc10),y
	sta	__rc31
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc22
	ldy	#3
	lda	(__rc10),y
	sta	__rc25
	ldx	__rc8
	ldy	#238
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	pha
	clc
	lda	__rc0
	adc	#189
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#190
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#191
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#54
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#53
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#58
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#71
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#56
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#55
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	clc
	lda	__rc0
	adc	#150
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#154
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc21
	stx	__rc27
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#215
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#216
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc30
	stx	__rc4
	ldx	__rc31
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#57
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#59
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#189
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#190
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#191
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	lda	__rc27
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc29
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
	jmp	.LBB0_211
.LBB0_211:
	ldy	#0
	clc
	lda	__rc0
	adc	#190
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_212
.LBB0_212:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
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
	bcc	.LBB0_213
	jmp	.LBB0_220
.LBB0_213:                              ;   in Loop: Header=BB0_212 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#190
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_217
	jmp	.LBB0_214
.LBB0_214:                              ;   in Loop: Header=BB0_212 Depth=1
	ldy	__rc2
	bne	.LBB0_217
	jmp	.LBB0_215
.LBB0_215:                              ;   in Loop: Header=BB0_212 Depth=1
	cpx	#0
	bne	.LBB0_217
	jmp	.LBB0_216
.LBB0_216:                              ;   in Loop: Header=BB0_212 Depth=1
	tax
	bne	.LBB0_217
	jmp	.LBB0_218
.LBB0_217:
	jsr	abort
.LBB0_218:                              ;   in Loop: Header=BB0_212 Depth=1
	jmp	.LBB0_219
.LBB0_219:                              ;   in Loop: Header=BB0_212 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#190
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
	jmp	.LBB0_212
.LBB0_220:
	sep	#32
	jmp	.LBB0_221
.LBB0_221:
	ldy	#0
	clc
	lda	__rc0
	adc	#16
	sta	__rc20
	lda	__rc1
	adc	#5
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
	adc	#235
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
	adc	#236
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
	pha
	php
	clc
	lda	__rc0
	adc	#218
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	sta	__rc28
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
	adc	#61
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	iny
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#60
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#2
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#227
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
	adc	#228
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
	pha
	clc
	lda	__rc0
	adc	#100
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#217
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#99
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldx	__rc3
	stx	__rc31
	ldx	__rc26
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc23
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc29
	ldx	#64
	stx	__rc7
	ldx	__rc22
	clc
	lda	__rc0
	adc	#235
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc25
	stx	__rc26
	ldx	__rc2
	stx	__rc24
	ldx	__rc3
	stx	__rc23
	ldx	__rc28
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc29
	stx	__rc4
	stx	__rc5
	stx	__rc6
	stx	__rc22
	ldx	#64
	stx	__rc7
	clc
	lda	__rc0
	adc	#218
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#236
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc27
	stx	__rc28
	ldx	__rc2
	stx	__rc29
	ldx	__rc3
	stx	__rc30
	clc
	lda	__rc0
	adc	#227
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#228
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
	adc	#60
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#61
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	stx	__rc7
	clc
	ldx	__rc0
	stx	__rc8
	lda	__rc1
	adc	#5
	php
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#100
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#217
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#99
	sta	__rc4
	lda	__rc1
	adc	#1
	plp
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc11
	inx
	txa
	tay
	lda	__rc31
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
	lda	__rc28
	ldy	__rc10
	sta	(__rc4),y
	lda	__rc29
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc30
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
	ldy	#237
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
	adc	#72
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#67
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#63
	sta	__rc6
	lda	__rc1
	adc	#2
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
	adc	#62
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#155
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#151
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#65
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#64
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#160
	sta	__rc12
	lda	__rc1
	adc	#3
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
	adc	#68
	sta	__rc10
	lda	__rc1
	adc	#2
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
	adc	#66
	sta	__rc10
	lda	__rc1
	adc	#2
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
	lda	__rc0
	adc	#219
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
	sty	__rc10
	pha
	php
	clc
	lda	__rc0
	adc	#220
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
	sta	__rc27
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc29
	ldy	#3
	lda	(__rc10),y
	sta	__rc28
	rep	#32
	lda	__rc12
	adc	#mos16(12)
	sta	__rc10
	sep	#32
	ldy	#12
	lda	(__rc12),y
	sta	__rc30
	ldy	#1
	lda	(__rc10),y
	sta	__rc31
	ldy	__rc14
	lda	(__rc10),y
	sta	__rc22
	ldy	#3
	lda	(__rc10),y
	sta	__rc25
	ldx	__rc8
	ldy	#237
	lda	(__rc0),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	pha
	clc
	lda	__rc0
	adc	#193
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#196
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	txa
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#194
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc2
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#195
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	lda	__rc3
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#63
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#62
	sta	__rc4
	lda	__rc1
	adc	#2
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
	adc	#67
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#72
	sta	__rc8
	lda	__rc1
	adc	#2
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
	adc	#65
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#64
	sta	__rc4
	lda	__rc1
	adc	#2
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc21
	stx	__rc4
	ldx	__rc27
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	clc
	lda	__rc0
	adc	#151
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#155
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc21
	stx	__rc27
	ldx	__rc2
	stx	__rc28
	ldx	__rc3
	stx	__rc29
	clc
	lda	__rc0
	adc	#219
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#220
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	ldx	__rc30
	stx	__rc4
	ldx	__rc31
	stx	__rc5
	ldx	__rc22
	stx	__rc6
	ldx	__rc25
	stx	__rc7
	clc
	lda	__rc0
	adc	#66
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#68
	sta	__rc8
	lda	__rc1
	adc	#2
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	stx	__rc7
	clc
	lda	__rc0
	adc	#240
	sta	__rc8
	lda	__rc1
	adc	#4
	sta	__rc9
	ldy	#0
	sty	__rc17
	clc
	lda	__rc0
	adc	#193
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	ldx	#1
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#196
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc10
	ldy	#2
	sty	__rc17
	clc
	lda	__rc0
	adc	#194
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc8),y
	sty	__rc12
	ldx	#3
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#195
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	lda	__rc27
	ldy	__rc11
	sta	(__rc4),y
	lda	__rc28
	ldy	__rc12
	sta	(__rc4),y
	dex
	stx	__rc12
	lda	__rc29
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
	jmp	.LBB0_222
.LBB0_222:
	ldy	#0
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_223
.LBB0_223:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
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
	bcc	.LBB0_224
	jmp	.LBB0_231
.LBB0_224:                              ;   in Loop: Header=BB0_223 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#158
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
	ldx	__rc0
	stx	__rc4
	lda	__rc1
	adc	#5
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
	adc	#240
	sta	__rc4
	lda	__rc1
	adc	#4
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
	bne	.LBB0_228
	jmp	.LBB0_225
.LBB0_225:                              ;   in Loop: Header=BB0_223 Depth=1
	ldy	__rc2
	bne	.LBB0_228
	jmp	.LBB0_226
.LBB0_226:                              ;   in Loop: Header=BB0_223 Depth=1
	cpx	#0
	bne	.LBB0_228
	jmp	.LBB0_227
.LBB0_227:                              ;   in Loop: Header=BB0_223 Depth=1
	tax
	bne	.LBB0_228
	jmp	.LBB0_229
.LBB0_228:
	jsr	abort
.LBB0_229:                              ;   in Loop: Header=BB0_223 Depth=1
	jmp	.LBB0_230
.LBB0_230:                              ;   in Loop: Header=BB0_223 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#158
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
	jmp	.LBB0_223
.LBB0_231:
	sep	#32
	jmp	.LBB0_232
.LBB0_232:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#145
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
	adc	#142
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#143
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#144
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#141
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#146
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#145
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#142
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#143
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc10
	clc
	lda	__rc0
	adc	#144
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc11
	clc
	lda	__rc0
	adc	#141
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#146
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	tya
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#128
	sta	__rc8
	lda	__rc1
	adc	#3
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
	ldy	#233
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#229
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
	pha
	php
	clc
	lda	__rc0
	adc	#104
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#103
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#101
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#9
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#12
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#11
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#10
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#102
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#7
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#8
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#6
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	ldy	#229
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#233
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
	clc
	lda	__rc0
	adc	#5
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	adc	#9
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#12
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#11
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#10
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#102
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	clc
	lda	__rc0
	adc	#7
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#8
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#6
	sta	__rc12
	lda	__rc1
	adc	#1
	sta	__rc13
	ldy	#0
	lda	(__rc12),y                      ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#103
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#104
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	clc
	lda	__rc0
	adc	#5
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_233
.LBB0_233:
	ldy	#0
	clc
	lda	__rc0
	adc	#126
	sta	__rc2
	lda	__rc1
	adc	#3
	sta	__rc3
	tya
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	jmp	.LBB0_234
.LBB0_234:                              ; =>This Inner Loop Header: Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
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
	cmp	#32770
	bcc	.LBB0_235
	jmp	.LBB0_242
.LBB0_235:                              ;   in Loop: Header=BB0_234 Depth=1
	sep	#32
	ldy	#0
	clc
	lda	__rc0
	adc	#126
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#149
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
	adc	#149
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
	bne	.LBB0_239
	jmp	.LBB0_236
.LBB0_236:                              ;   in Loop: Header=BB0_234 Depth=1
	ldy	__rc2
	bne	.LBB0_239
	jmp	.LBB0_237
.LBB0_237:                              ;   in Loop: Header=BB0_234 Depth=1
	cpx	#0
	bne	.LBB0_239
	jmp	.LBB0_238
.LBB0_238:                              ;   in Loop: Header=BB0_234 Depth=1
	tax
	bne	.LBB0_239
	jmp	.LBB0_240
.LBB0_239:
	jsr	abort
.LBB0_240:                              ;   in Loop: Header=BB0_234 Depth=1
	jmp	.LBB0_241
.LBB0_241:                              ;   in Loop: Header=BB0_234 Depth=1
	ldy	#0
	clc
	lda	__rc0
	adc	#126
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
	jmp	.LBB0_234
.LBB0_242:
	sep	#32
	jmp	.LBB0_243
.LBB0_243:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#151
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
	adc	#148
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#149
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#150
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#147
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#152
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#151
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#148
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#149
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc10
	clc
	lda	__rc0
	adc	#150
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc11
	clc
	lda	__rc0
	adc	#147
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#152
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	tya
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#3
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
	ldy	#234
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#230
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
	pha
	php
	clc
	lda	__rc0
	adc	#108
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#107
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#105
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#17
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#20
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#19
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#18
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#106
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#15
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#16
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#14
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	ldy	#230
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#234
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
	clc
	lda	__rc0
	adc	#13
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#105
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#17
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#20
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#19
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#18
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#106
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	clc
	lda	__rc0
	adc	#15
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#16
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#14
	sta	__rc12
	lda	__rc1
	adc	#1
	sta	__rc13
	ldy	#0
	lda	(__rc12),y                      ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#107
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#108
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	clc
	lda	__rc0
	adc	#13
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_244
.LBB0_244:
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
	jmp	.LBB0_245
.LBB0_245:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_246
	jmp	.LBB0_253
.LBB0_246:                              ;   in Loop: Header=BB0_245 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#147
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
	adc	#147
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
	bne	.LBB0_250
	jmp	.LBB0_247
.LBB0_247:                              ;   in Loop: Header=BB0_245 Depth=1
	ldy	__rc2
	bne	.LBB0_250
	jmp	.LBB0_248
.LBB0_248:                              ;   in Loop: Header=BB0_245 Depth=1
	cpx	#0
	bne	.LBB0_250
	jmp	.LBB0_249
.LBB0_249:                              ;   in Loop: Header=BB0_245 Depth=1
	tax
	bne	.LBB0_250
	jmp	.LBB0_251
.LBB0_250:
	jsr	abort
.LBB0_251:                              ;   in Loop: Header=BB0_245 Depth=1
	jmp	.LBB0_252
.LBB0_252:                              ;   in Loop: Header=BB0_245 Depth=1
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
	jmp	.LBB0_245
.LBB0_253:
	sep	#32
	jmp	.LBB0_254
.LBB0_254:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#157
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
	adc	#154
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#155
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#156
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#153
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#158
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#157
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#154
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#155
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc10
	clc
	lda	__rc0
	adc	#156
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc11
	clc
	lda	__rc0
	adc	#153
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#158
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	tya
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#3
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
	ldy	#235
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#231
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
	pha
	php
	clc
	lda	__rc0
	adc	#112
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#111
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#109
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#25
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#28
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#27
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#26
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#110
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#23
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#24
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#22
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	ldy	#231
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#235
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
	clc
	lda	__rc0
	adc	#21
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#109
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#25
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#28
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#27
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#26
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#110
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	clc
	lda	__rc0
	adc	#23
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#24
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#22
	sta	__rc12
	lda	__rc1
	adc	#1
	sta	__rc13
	ldy	#0
	lda	(__rc12),y                      ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#111
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#112
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_255
.LBB0_255:
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
	jmp	.LBB0_256
.LBB0_256:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_257
	jmp	.LBB0_264
.LBB0_257:                              ;   in Loop: Header=BB0_256 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#145
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
	adc	#145
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
	bne	.LBB0_261
	jmp	.LBB0_258
.LBB0_258:                              ;   in Loop: Header=BB0_256 Depth=1
	ldy	__rc2
	bne	.LBB0_261
	jmp	.LBB0_259
.LBB0_259:                              ;   in Loop: Header=BB0_256 Depth=1
	cpx	#0
	bne	.LBB0_261
	jmp	.LBB0_260
.LBB0_260:                              ;   in Loop: Header=BB0_256 Depth=1
	tax
	bne	.LBB0_261
	jmp	.LBB0_262
.LBB0_261:
	jsr	abort
.LBB0_262:                              ;   in Loop: Header=BB0_256 Depth=1
	jmp	.LBB0_263
.LBB0_263:                              ;   in Loop: Header=BB0_256 Depth=1
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
	jmp	.LBB0_256
.LBB0_264:
	sep	#32
	jmp	.LBB0_265
.LBB0_265:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#163
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
	adc	#160
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	dey
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc6
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#161
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#162
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#159
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc27
	iny
	lda	(__rc2),y
	sta	__rc28
	ldy	__rc7
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#164
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#163
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#160
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#161
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc10
	clc
	lda	__rc0
	adc	#162
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
	sta	__rc11
	clc
	lda	__rc0
	adc	#159
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	ldy	#0
	lda	(__rc2),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#164
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	sta	__rc15
	ldx	#0
	tya
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#3
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
	ldy	#236
	sta	(__rc0),y                       ; 1-byte Folded Spill
	ldy	__rc3
	lda	(__rc8),y
	sty	__rc17
	ldy	#232
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
	pha
	php
	clc
	lda	__rc0
	adc	#116
	sta	__rc8
	lda	__rc1
	adc	#1
	plp
	sta	__rc9
	pla
	ldy	#0
	sta	(__rc8),y                       ; 1-byte Folded Spill
	ldy	__rc12
	sty	__rc27
	ldy	__rc13
	lda	(__rc10),y
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
	ldy	__rc14
	lda	(__rc10),y
	sty	__rc17
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
	ldy	__rc17
	sty	__rc26
	ldy	__rc19
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#33
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#36
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#35
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#34
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#114
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	pha
	clc
	lda	__rc0
	adc	#31
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc28
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#32
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc22),y
	pha
	clc
	lda	__rc0
	adc	#30
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	ldy	#232
	lda	(__rc0),y                       ; 1-byte Folded Reload
	tax
	ldy	#236
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
	clc
	lda	__rc0
	adc	#29
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#113
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#33
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#36
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#35
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#34
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#114
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc7
	clc
	lda	__rc0
	adc	#31
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc8
	clc
	lda	__rc0
	adc	#32
	sta	__rc10
	lda	__rc1
	adc	#1
	sta	__rc11
	ldy	#0
	lda	(__rc10),y                      ; 1-byte Folded Reload
	sta	__rc9
	clc
	lda	__rc0
	adc	#30
	sta	__rc12
	lda	__rc1
	adc	#1
	sta	__rc13
	ldy	#0
	lda	(__rc12),y                      ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#115
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#116
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	jmp	.LBB0_266
.LBB0_266:
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
	jmp	.LBB0_267
.LBB0_267:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_268
	jmp	.LBB0_275
.LBB0_268:                              ;   in Loop: Header=BB0_267 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#143
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
	adc	#143
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
	bne	.LBB0_272
	jmp	.LBB0_269
.LBB0_269:                              ;   in Loop: Header=BB0_267 Depth=1
	ldy	__rc2
	bne	.LBB0_272
	jmp	.LBB0_270
.LBB0_270:                              ;   in Loop: Header=BB0_267 Depth=1
	cpx	#0
	bne	.LBB0_272
	jmp	.LBB0_271
.LBB0_271:                              ;   in Loop: Header=BB0_267 Depth=1
	tax
	bne	.LBB0_272
	jmp	.LBB0_273
.LBB0_272:
	jsr	abort
.LBB0_273:                              ;   in Loop: Header=BB0_267 Depth=1
	jmp	.LBB0_274
.LBB0_274:                              ;   in Loop: Header=BB0_267 Depth=1
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
	jmp	.LBB0_267
.LBB0_275:
	sep	#32
	jmp	.LBB0_276
.LBB0_276:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#42
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#41
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#38
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#40
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#39
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#37
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#38
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#40
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#39
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	clc
	lda	__rc0
	adc	#37
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#41
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#42
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	ldx	__rc0
	stx	__rc22
	lda	__rc1
	adc	#3
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
	pha
	php
	clc
	lda	__rc0
	adc	#120
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#119
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#47
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#48
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#118
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#117
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#50
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#49
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#46
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc4
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#45
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc5
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#44
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc6
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#43
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#47
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#48
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#118
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#117
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#50
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#49
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#119
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#120
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	clc
	lda	__rc0
	adc	#46
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#45
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#44
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#43
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_277
.LBB0_277:
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
	jmp	.LBB0_278
.LBB0_278:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_279
	jmp	.LBB0_286
.LBB0_279:                              ;   in Loop: Header=BB0_278 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#141
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
	adc	#141
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
	bne	.LBB0_283
	jmp	.LBB0_280
.LBB0_280:                              ;   in Loop: Header=BB0_278 Depth=1
	ldy	__rc2
	bne	.LBB0_283
	jmp	.LBB0_281
.LBB0_281:                              ;   in Loop: Header=BB0_278 Depth=1
	cpx	#0
	bne	.LBB0_283
	jmp	.LBB0_282
.LBB0_282:                              ;   in Loop: Header=BB0_278 Depth=1
	tax
	bne	.LBB0_283
	jmp	.LBB0_284
.LBB0_283:
	jsr	abort
.LBB0_284:                              ;   in Loop: Header=BB0_278 Depth=1
	jmp	.LBB0_285
.LBB0_285:                              ;   in Loop: Header=BB0_278 Depth=1
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
	jmp	.LBB0_278
.LBB0_286:
	sep	#32
	jmp	.LBB0_287
.LBB0_287:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#56
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#55
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#52
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#54
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#53
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#51
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	adc	#54
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#53
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	clc
	lda	__rc0
	adc	#51
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#55
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#56
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#2
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
	pha
	php
	clc
	lda	__rc0
	adc	#124
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#123
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
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
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#62
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#122
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#121
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#64
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#63
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#60
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc4
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#59
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc5
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#58
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc6
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#57
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#61
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#62
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#122
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#121
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#64
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#63
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#123
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#124
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	clc
	lda	__rc0
	adc	#60
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#59
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#58
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#57
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_288
.LBB0_288:
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
	jmp	.LBB0_289
.LBB0_289:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_290
	jmp	.LBB0_297
.LBB0_290:                              ;   in Loop: Header=BB0_289 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#139
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
	adc	#139
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
	bne	.LBB0_294
	jmp	.LBB0_291
.LBB0_291:                              ;   in Loop: Header=BB0_289 Depth=1
	ldy	__rc2
	bne	.LBB0_294
	jmp	.LBB0_292
.LBB0_292:                              ;   in Loop: Header=BB0_289 Depth=1
	cpx	#0
	bne	.LBB0_294
	jmp	.LBB0_293
.LBB0_293:                              ;   in Loop: Header=BB0_289 Depth=1
	tax
	bne	.LBB0_294
	jmp	.LBB0_295
.LBB0_294:
	jsr	abort
.LBB0_295:                              ;   in Loop: Header=BB0_289 Depth=1
	jmp	.LBB0_296
.LBB0_296:                              ;   in Loop: Header=BB0_289 Depth=1
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
	jmp	.LBB0_289
.LBB0_297:
	sep	#32
	jmp	.LBB0_298
.LBB0_298:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#70
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#69
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#66
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#68
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#67
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#65
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#66
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#68
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#67
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	clc
	lda	__rc0
	adc	#65
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#69
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#70
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#2
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
	pha
	php
	clc
	lda	__rc0
	adc	#128
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#127
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#75
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#76
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#126
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#125
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#78
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
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
	clc
	lda	__rc0
	adc	#74
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc4
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#73
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc5
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#72
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc6
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#71
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	adc	#76
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#126
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#125
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#78
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#77
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#127
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#128
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	clc
	lda	__rc0
	adc	#74
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#73
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#72
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#71
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_299
.LBB0_299:
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
	jmp	.LBB0_300
.LBB0_300:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_301
	jmp	.LBB0_308
.LBB0_301:                              ;   in Loop: Header=BB0_300 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#137
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
	adc	#137
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
	bne	.LBB0_305
	jmp	.LBB0_302
.LBB0_302:                              ;   in Loop: Header=BB0_300 Depth=1
	ldy	__rc2
	bne	.LBB0_305
	jmp	.LBB0_303
.LBB0_303:                              ;   in Loop: Header=BB0_300 Depth=1
	cpx	#0
	bne	.LBB0_305
	jmp	.LBB0_304
.LBB0_304:                              ;   in Loop: Header=BB0_300 Depth=1
	tax
	bne	.LBB0_305
	jmp	.LBB0_306
.LBB0_305:
	jsr	abort
.LBB0_306:                              ;   in Loop: Header=BB0_300 Depth=1
	jmp	.LBB0_307
.LBB0_307:                              ;   in Loop: Header=BB0_300 Depth=1
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
	jmp	.LBB0_300
.LBB0_308:
	sep	#32
	jmp	.LBB0_309
.LBB0_309:
	ldy	#0
	clc
	lda	__rc0
	adc	#224
	sta	__rc20
	lda	__rc1
	adc	#4
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
	pha
	clc
	lda	__rc0
	adc	#84
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	pla
	ldy	#0
	sta	(__rc6),y                       ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#83
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	__rc14
	lda	(__rc2),y
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
	ldy	#3
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#82
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#81
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	pla
	ldy	#0
	sta	(__rc4),y                       ; 1-byte Folded Spill
	ldy	#5
	lda	(__rc2),y
	sta	__rc28
	iny
	lda	(__rc2),y
	sta	__rc25
	ldy	__rc15
	lda	(__rc2),y
	pha
	clc
	lda	__rc0
	adc	#79
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	pla
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#80
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc2
	clc
	lda	__rc0
	adc	#82
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	sta	__rc3
	clc
	lda	__rc0
	adc	#81
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	ldx	__rc28
	stx	__rc5
	ldx	__rc25
	stx	__rc6
	clc
	lda	__rc0
	adc	#79
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#83
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#84
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	clc
	lda	__rc0
	adc	#208
	sta	__rc10
	lda	__rc1
	adc	#4
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
	adc	#2
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
	pha
	php
	clc
	lda	__rc0
	adc	#132
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc27
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#131
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc26
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#89
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc13
	lda	(__rc10),y
	sty	__rc17
	pha
	php
	clc
	lda	__rc0
	adc	#90
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc17
	sty	__rc13
	ldy	__rc25
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#130
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc24
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#129
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#92
	sta	__rc14
	lda	__rc1
	adc	#1
	plp
	sta	__rc15
	pla
	ldy	#0
	sta	(__rc14),y                      ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc10),y
	pha
	php
	clc
	lda	__rc0
	adc	#91
	sta	__rc10
	lda	__rc1
	adc	#1
	plp
	sta	__rc11
	pla
	ldy	#0
	sta	(__rc10),y                      ; 1-byte Folded Spill
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
	clc
	lda	__rc0
	adc	#88
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc4
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#87
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc5
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#86
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc6
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#85
	sta	__rc2
	lda	__rc1
	adc	#1
	sta	__rc3
	lda	__rc7
	ldy	#0
	sta	(__rc2),y                       ; 1-byte Folded Spill
	clc
	lda	__rc0
	adc	#89
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
	clc
	lda	__rc0
	adc	#130
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc4
	clc
	lda	__rc0
	adc	#129
	sta	__rc6
	lda	__rc1
	adc	#1
	sta	__rc7
	ldy	#0
	lda	(__rc6),y                       ; 1-byte Folded Reload
	sta	__rc5
	clc
	lda	__rc0
	adc	#92
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
	sta	__rc6
	clc
	lda	__rc0
	adc	#91
	sta	__rc8
	lda	__rc1
	adc	#1
	sta	__rc9
	ldy	#0
	lda	(__rc8),y                       ; 1-byte Folded Reload
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
	clc
	lda	__rc0
	adc	#131
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	tax
	clc
	lda	__rc0
	adc	#132
	sta	__rc18
	lda	__rc1
	adc	#1
	sta	__rc19
	ldy	#0
	lda	(__rc18),y                      ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	stx	__rc9
	ldx	__rc4
	stx	__rc10
	ldx	__rc5
	stx	__rc11
	clc
	lda	__rc0
	adc	#192
	sta	__rc12
	lda	__rc1
	adc	#4
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
	clc
	lda	__rc0
	adc	#88
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc19
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#87
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc18
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#86
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
	ldy	__rc17
	sta	(__rc12),y
	sty	__rc20
	inx
	txa
	tay
	sty	__rc17
	clc
	lda	__rc0
	adc	#85
	sta	__rc4
	lda	__rc1
	adc	#1
	sta	__rc5
	ldy	#0
	lda	(__rc4),y                       ; 1-byte Folded Reload
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
	jmp	.LBB0_310
.LBB0_310:
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
	jmp	.LBB0_311
.LBB0_311:                              ; =>This Inner Loop Header: Depth=1
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
	cmp	#32770
	bcc	.LBB0_312
	jmp	.LBB0_319
.LBB0_312:                              ;   in Loop: Header=BB0_311 Depth=1
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
	adc	#208
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#192
	sta	__rc4
	lda	__rc1
	adc	#4
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
	adc	#135
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
	adc	#135
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
	bne	.LBB0_316
	jmp	.LBB0_313
.LBB0_313:                              ;   in Loop: Header=BB0_311 Depth=1
	ldy	__rc2
	bne	.LBB0_316
	jmp	.LBB0_314
.LBB0_314:                              ;   in Loop: Header=BB0_311 Depth=1
	cpx	#0
	bne	.LBB0_316
	jmp	.LBB0_315
.LBB0_315:                              ;   in Loop: Header=BB0_311 Depth=1
	tax
	bne	.LBB0_316
	jmp	.LBB0_317
.LBB0_316:
	jsr	abort
.LBB0_317:                              ;   in Loop: Header=BB0_311 Depth=1
	jmp	.LBB0_318
.LBB0_318:                              ;   in Loop: Header=BB0_311 Depth=1
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
	jmp	.LBB0_311
.LBB0_319:
	sep	#32
	jmp	.LBB0_320
.LBB0_320:
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
	adc	#80
	sta	__rc0
	lda	__rc1
	adc	#5
	sta	__rc1
	lda	__rc16
	rts
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
                                        ; -- End function
	.type	one,@object                     ; @one
	.data
	.globl	one
one:
	.short	1                               ; 0x1
	.size	one, 2

	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that there is something in .data, so it may need to be copied from LMA to VMA.
	.globl	__do_copy_data
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

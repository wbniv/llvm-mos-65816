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
	.file	"float-vector.ll"
	.text
	.globl	add_v4sf                        ; -- Begin function add_v4sf
	.type	add_v4sf,@function
add_v4sf:                               ; @add_v4sf
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Ladd_v4sf_sstk+18              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Ladd_v4sf_sstk+19              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Ladd_v4sf_sstk+20              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Ladd_v4sf_sstk+21              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Ladd_v4sf_sstk+22              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Ladd_v4sf_sstk+23              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Ladd_v4sf_sstk+24              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Ladd_v4sf_sstk+25              ; 1-byte Folded Spill
	lda	__rc4
	clc
	adc	#4
	sta	__rc8
	lda	__rc5
	adc	#0
	sta	__rc9
	clc
	lda	__rc4
	adc	#8
	sta	__rc10
	lda	__rc5
	adc	#0
	sta	__rc11
	clc
	lda	__rc4
	adc	#12
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#4
	sta	__rc14
	lda	__rc7
	adc	#0
	sta	__rc15
	clc
	lda	__rc6
	adc	#8
	sta	__rc18
	lda	__rc7
	adc	#0
	sta	__rc19
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	clc
	lda	__rc6
	adc	#12
	sta	__rc2
	lda	(__rc4),y
	sta	__rc24
	iny
	lda	__rc7
	adc	#0
	sta	__rc3
	lda	(__rc4),y
	ldx	#1
	stx	__rc22
	tax
	iny
	lda	(__rc4),y
	sty	__rc25
	sta	.Ladd_v4sf_sstk+13              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sty	__rc26
	sta	.Ladd_v4sf_sstk+15              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sta	.Ladd_v4sf_sstk+5               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc8),y
	sta	__rc23
	ldy	__rc25
	lda	(__rc8),y
	ldy	#2
	sty	__rc25
	sta	__rc31
	ldy	__rc26
	lda	(__rc8),y
	ldy	#3
	sty	__rc8
	sta	__rc29
	ldy	#8
	lda	(__rc4),y
	sta	.Ladd_v4sf_sstk+4               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	sta	.Ladd_v4sf_sstk+9               ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	sty	__rc9
	sta	.Ladd_v4sf_sstk+11              ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc10),y
	sta	.Ladd_v4sf_sstk+12              ; 1-byte Folded Spill
	ldy	#12
	lda	(__rc4),y
	sta	.Ladd_v4sf_sstk                 ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc12),y
	sty	__rc4
	sta	.Ladd_v4sf_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sty	__rc5
	sta	.Ladd_v4sf_sstk+3               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sty	__rc12
	sta	.Ladd_v4sf_sstk+2               ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc6),y
	sta	__rc11
	ldy	__rc4
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc9
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc12
	lda	(__rc6),y
	sta	__rc10
	ldy	#4
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc4
	lda	(__rc14),y
	sta	__rc22
	ldy	__rc5
	lda	(__rc14),y
	sta	.Ladd_v4sf_sstk+6               ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc14),y
	sta	.Ladd_v4sf_sstk+7               ; 1-byte Folded Spill
	ldy	#8
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc4
	lda	(__rc18),y
	sta	__rc30
	ldy	__rc5
	lda	(__rc18),y
	sta	__rc26
	ldy	__rc12
	lda	(__rc18),y
	sta	__rc27
	ldy	#12
	lda	(__rc6),y
	sta	.Ladd_v4sf_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	sta	.Ladd_v4sf_sstk+10              ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc2),y
	sta	.Ladd_v4sf_sstk+14              ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc2),y
	sta	.Ladd_v4sf_sstk+16              ; 1-byte Folded Spill
	ldy	.Ladd_v4sf_sstk+13              ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Ladd_v4sf_sstk+15              ; 1-byte Folded Reload
	sty	__rc3
	ldy	__rc11
	sty	__rc4
	ldy	__rc8
	sty	__rc5
	ldy	__rc9
	sty	__rc6
	ldy	__rc10
	sty	__rc7
	lda	__rc24
	jsr	__addsf3
	sta	__rc24
	stx	.Ladd_v4sf_sstk+17              ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Ladd_v4sf_sstk+15              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ladd_v4sf_sstk+13              ; 1-byte Folded Spill
	ldx	__rc31
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc25
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	.Ladd_v4sf_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Ladd_v4sf_sstk+7               ; 1-byte Folded Reload
	stx	__rc7
	ldx	__rc23
	lda	.Ladd_v4sf_sstk+5               ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc22
	stx	.Ladd_v4sf_sstk+7               ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Ladd_v4sf_sstk+5               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ladd_v4sf_sstk+6               ; 1-byte Folded Spill
	ldx	.Ladd_v4sf_sstk+11              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ladd_v4sf_sstk+12              ; 1-byte Folded Reload
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc30
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	ldx	.Ladd_v4sf_sstk+9               ; 1-byte Folded Reload
	lda	.Ladd_v4sf_sstk+4               ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc25
	stx	__rc23
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	.Ladd_v4sf_sstk+3               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ladd_v4sf_sstk+2               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Ladd_v4sf_sstk+8               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Ladd_v4sf_sstk+10              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Ladd_v4sf_sstk+14              ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Ladd_v4sf_sstk+16              ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Ladd_v4sf_sstk+1               ; 1-byte Folded Reload
	lda	.Ladd_v4sf_sstk                 ; 1-byte Folded Reload
	jsr	__addsf3
	sta	__rc6
	ldy	#0
	lda	__rc24
	sta	(__rc20),y
	iny
	lda	.Ladd_v4sf_sstk+17              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc5
	iny
	lda	.Ladd_v4sf_sstk+15              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc9
	iny
	lda	.Ladd_v4sf_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc8
	iny
	lda	__rc22
	sta	(__rc20),y
	ldy	#8
	lda	__rc25
	sta	(__rc20),y
	ldy	#12
	lda	__rc6
	sta	(__rc20),y
	clc
	lda	__rc20
	adc	#4
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	.Ladd_v4sf_sstk+7               ; 1-byte Folded Reload
	ldy	__rc5
	sta	(__rc6),y
	lda	.Ladd_v4sf_sstk+5               ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc6),y
	lda	.Ladd_v4sf_sstk+6               ; 1-byte Folded Reload
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#8
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	__rc23
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc28
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#12
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	txa
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc2
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc3
	ldy	__rc8
	sta	(__rc6),y
	ldx	.Ladd_v4sf_sstk+25              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Ladd_v4sf_sstk+24              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Ladd_v4sf_sstk+23              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Ladd_v4sf_sstk+22              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Ladd_v4sf_sstk+21              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Ladd_v4sf_sstk+20              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Ladd_v4sf_sstk+19              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Ladd_v4sf_sstk+18              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end0:
	.size	add_v4sf, .Lfunc_end0-add_v4sf
                                        ; -- End function
	.globl	sub_v4sf                        ; -- Begin function sub_v4sf
	.type	sub_v4sf,@function
sub_v4sf:                               ; @sub_v4sf
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Lsub_v4sf_sstk+18              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lsub_v4sf_sstk+19              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lsub_v4sf_sstk+20              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lsub_v4sf_sstk+21              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lsub_v4sf_sstk+22              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lsub_v4sf_sstk+23              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lsub_v4sf_sstk+24              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lsub_v4sf_sstk+25              ; 1-byte Folded Spill
	lda	__rc4
	clc
	adc	#4
	sta	__rc8
	lda	__rc5
	adc	#0
	sta	__rc9
	clc
	lda	__rc4
	adc	#8
	sta	__rc10
	lda	__rc5
	adc	#0
	sta	__rc11
	clc
	lda	__rc4
	adc	#12
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#4
	sta	__rc14
	lda	__rc7
	adc	#0
	sta	__rc15
	clc
	lda	__rc6
	adc	#8
	sta	__rc18
	lda	__rc7
	adc	#0
	sta	__rc19
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	clc
	lda	__rc6
	adc	#12
	sta	__rc2
	lda	(__rc4),y
	sta	__rc24
	iny
	lda	__rc7
	adc	#0
	sta	__rc3
	lda	(__rc4),y
	ldx	#1
	stx	__rc22
	tax
	iny
	lda	(__rc4),y
	sty	__rc25
	sta	.Lsub_v4sf_sstk+13              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sty	__rc26
	sta	.Lsub_v4sf_sstk+15              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sta	.Lsub_v4sf_sstk+5               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc8),y
	sta	__rc23
	ldy	__rc25
	lda	(__rc8),y
	ldy	#2
	sty	__rc25
	sta	__rc31
	ldy	__rc26
	lda	(__rc8),y
	ldy	#3
	sty	__rc8
	sta	__rc29
	ldy	#8
	lda	(__rc4),y
	sta	.Lsub_v4sf_sstk+4               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	sta	.Lsub_v4sf_sstk+9               ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	sty	__rc9
	sta	.Lsub_v4sf_sstk+11              ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc10),y
	sta	.Lsub_v4sf_sstk+12              ; 1-byte Folded Spill
	ldy	#12
	lda	(__rc4),y
	sta	.Lsub_v4sf_sstk                 ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc12),y
	sty	__rc4
	sta	.Lsub_v4sf_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sty	__rc5
	sta	.Lsub_v4sf_sstk+3               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sty	__rc12
	sta	.Lsub_v4sf_sstk+2               ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc6),y
	sta	__rc11
	ldy	__rc4
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc9
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc12
	lda	(__rc6),y
	sta	__rc10
	ldy	#4
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc4
	lda	(__rc14),y
	sta	__rc22
	ldy	__rc5
	lda	(__rc14),y
	sta	.Lsub_v4sf_sstk+6               ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc14),y
	sta	.Lsub_v4sf_sstk+7               ; 1-byte Folded Spill
	ldy	#8
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc4
	lda	(__rc18),y
	sta	__rc30
	ldy	__rc5
	lda	(__rc18),y
	sta	__rc26
	ldy	__rc12
	lda	(__rc18),y
	sta	__rc27
	ldy	#12
	lda	(__rc6),y
	sta	.Lsub_v4sf_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	sta	.Lsub_v4sf_sstk+10              ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc2),y
	sta	.Lsub_v4sf_sstk+14              ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc2),y
	sta	.Lsub_v4sf_sstk+16              ; 1-byte Folded Spill
	ldy	.Lsub_v4sf_sstk+13              ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Lsub_v4sf_sstk+15              ; 1-byte Folded Reload
	sty	__rc3
	ldy	__rc11
	sty	__rc4
	ldy	__rc8
	sty	__rc5
	ldy	__rc9
	sty	__rc6
	ldy	__rc10
	sty	__rc7
	lda	__rc24
	jsr	__subsf3
	sta	__rc24
	stx	.Lsub_v4sf_sstk+17              ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lsub_v4sf_sstk+15              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lsub_v4sf_sstk+13              ; 1-byte Folded Spill
	ldx	__rc31
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc25
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	.Lsub_v4sf_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lsub_v4sf_sstk+7               ; 1-byte Folded Reload
	stx	__rc7
	ldx	__rc23
	lda	.Lsub_v4sf_sstk+5               ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc22
	stx	.Lsub_v4sf_sstk+7               ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lsub_v4sf_sstk+5               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lsub_v4sf_sstk+6               ; 1-byte Folded Spill
	ldx	.Lsub_v4sf_sstk+11              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lsub_v4sf_sstk+12              ; 1-byte Folded Reload
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc30
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	ldx	.Lsub_v4sf_sstk+9               ; 1-byte Folded Reload
	lda	.Lsub_v4sf_sstk+4               ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc25
	stx	__rc23
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	.Lsub_v4sf_sstk+3               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lsub_v4sf_sstk+2               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Lsub_v4sf_sstk+8               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lsub_v4sf_sstk+10              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lsub_v4sf_sstk+14              ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lsub_v4sf_sstk+16              ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Lsub_v4sf_sstk+1               ; 1-byte Folded Reload
	lda	.Lsub_v4sf_sstk                 ; 1-byte Folded Reload
	jsr	__subsf3
	sta	__rc6
	ldy	#0
	lda	__rc24
	sta	(__rc20),y
	iny
	lda	.Lsub_v4sf_sstk+17              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc5
	iny
	lda	.Lsub_v4sf_sstk+15              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc9
	iny
	lda	.Lsub_v4sf_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc8
	iny
	lda	__rc22
	sta	(__rc20),y
	ldy	#8
	lda	__rc25
	sta	(__rc20),y
	ldy	#12
	lda	__rc6
	sta	(__rc20),y
	clc
	lda	__rc20
	adc	#4
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	.Lsub_v4sf_sstk+7               ; 1-byte Folded Reload
	ldy	__rc5
	sta	(__rc6),y
	lda	.Lsub_v4sf_sstk+5               ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc6),y
	lda	.Lsub_v4sf_sstk+6               ; 1-byte Folded Reload
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#8
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	__rc23
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc28
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#12
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	txa
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc2
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc3
	ldy	__rc8
	sta	(__rc6),y
	ldx	.Lsub_v4sf_sstk+25              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lsub_v4sf_sstk+24              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lsub_v4sf_sstk+23              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lsub_v4sf_sstk+22              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lsub_v4sf_sstk+21              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lsub_v4sf_sstk+20              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lsub_v4sf_sstk+19              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lsub_v4sf_sstk+18              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end1:
	.size	sub_v4sf, .Lfunc_end1-sub_v4sf
                                        ; -- End function
	.globl	mul_v4sf                        ; -- Begin function mul_v4sf
	.type	mul_v4sf,@function
mul_v4sf:                               ; @mul_v4sf
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Lmul_v4sf_sstk+18              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lmul_v4sf_sstk+19              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lmul_v4sf_sstk+20              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lmul_v4sf_sstk+21              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lmul_v4sf_sstk+22              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lmul_v4sf_sstk+23              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lmul_v4sf_sstk+24              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lmul_v4sf_sstk+25              ; 1-byte Folded Spill
	lda	__rc4
	clc
	adc	#4
	sta	__rc8
	lda	__rc5
	adc	#0
	sta	__rc9
	clc
	lda	__rc4
	adc	#8
	sta	__rc10
	lda	__rc5
	adc	#0
	sta	__rc11
	clc
	lda	__rc4
	adc	#12
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#4
	sta	__rc14
	lda	__rc7
	adc	#0
	sta	__rc15
	clc
	lda	__rc6
	adc	#8
	sta	__rc18
	lda	__rc7
	adc	#0
	sta	__rc19
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	clc
	lda	__rc6
	adc	#12
	sta	__rc2
	lda	(__rc4),y
	sta	__rc24
	iny
	lda	__rc7
	adc	#0
	sta	__rc3
	lda	(__rc4),y
	ldx	#1
	stx	__rc22
	tax
	iny
	lda	(__rc4),y
	sty	__rc25
	sta	.Lmul_v4sf_sstk+13              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sty	__rc26
	sta	.Lmul_v4sf_sstk+15              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sta	.Lmul_v4sf_sstk+5               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc8),y
	sta	__rc23
	ldy	__rc25
	lda	(__rc8),y
	ldy	#2
	sty	__rc25
	sta	__rc31
	ldy	__rc26
	lda	(__rc8),y
	ldy	#3
	sty	__rc8
	sta	__rc29
	ldy	#8
	lda	(__rc4),y
	sta	.Lmul_v4sf_sstk+4               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	sta	.Lmul_v4sf_sstk+9               ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	sty	__rc9
	sta	.Lmul_v4sf_sstk+11              ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc10),y
	sta	.Lmul_v4sf_sstk+12              ; 1-byte Folded Spill
	ldy	#12
	lda	(__rc4),y
	sta	.Lmul_v4sf_sstk                 ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc12),y
	sty	__rc4
	sta	.Lmul_v4sf_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sty	__rc5
	sta	.Lmul_v4sf_sstk+3               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sty	__rc12
	sta	.Lmul_v4sf_sstk+2               ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc6),y
	sta	__rc11
	ldy	__rc4
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc9
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc12
	lda	(__rc6),y
	sta	__rc10
	ldy	#4
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc4
	lda	(__rc14),y
	sta	__rc22
	ldy	__rc5
	lda	(__rc14),y
	sta	.Lmul_v4sf_sstk+6               ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc14),y
	sta	.Lmul_v4sf_sstk+7               ; 1-byte Folded Spill
	ldy	#8
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc4
	lda	(__rc18),y
	sta	__rc30
	ldy	__rc5
	lda	(__rc18),y
	sta	__rc26
	ldy	__rc12
	lda	(__rc18),y
	sta	__rc27
	ldy	#12
	lda	(__rc6),y
	sta	.Lmul_v4sf_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	sta	.Lmul_v4sf_sstk+10              ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc2),y
	sta	.Lmul_v4sf_sstk+14              ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc2),y
	sta	.Lmul_v4sf_sstk+16              ; 1-byte Folded Spill
	ldy	.Lmul_v4sf_sstk+13              ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Lmul_v4sf_sstk+15              ; 1-byte Folded Reload
	sty	__rc3
	ldy	__rc11
	sty	__rc4
	ldy	__rc8
	sty	__rc5
	ldy	__rc9
	sty	__rc6
	ldy	__rc10
	sty	__rc7
	lda	__rc24
	jsr	__mulsf3
	sta	__rc24
	stx	.Lmul_v4sf_sstk+17              ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lmul_v4sf_sstk+15              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lmul_v4sf_sstk+13              ; 1-byte Folded Spill
	ldx	__rc31
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc25
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	.Lmul_v4sf_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lmul_v4sf_sstk+7               ; 1-byte Folded Reload
	stx	__rc7
	ldx	__rc23
	lda	.Lmul_v4sf_sstk+5               ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc22
	stx	.Lmul_v4sf_sstk+7               ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lmul_v4sf_sstk+5               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lmul_v4sf_sstk+6               ; 1-byte Folded Spill
	ldx	.Lmul_v4sf_sstk+11              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lmul_v4sf_sstk+12              ; 1-byte Folded Reload
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc30
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	ldx	.Lmul_v4sf_sstk+9               ; 1-byte Folded Reload
	lda	.Lmul_v4sf_sstk+4               ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc25
	stx	__rc23
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	.Lmul_v4sf_sstk+3               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lmul_v4sf_sstk+2               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Lmul_v4sf_sstk+8               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lmul_v4sf_sstk+10              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lmul_v4sf_sstk+14              ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lmul_v4sf_sstk+16              ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Lmul_v4sf_sstk+1               ; 1-byte Folded Reload
	lda	.Lmul_v4sf_sstk                 ; 1-byte Folded Reload
	jsr	__mulsf3
	sta	__rc6
	ldy	#0
	lda	__rc24
	sta	(__rc20),y
	iny
	lda	.Lmul_v4sf_sstk+17              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc5
	iny
	lda	.Lmul_v4sf_sstk+15              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc9
	iny
	lda	.Lmul_v4sf_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc8
	iny
	lda	__rc22
	sta	(__rc20),y
	ldy	#8
	lda	__rc25
	sta	(__rc20),y
	ldy	#12
	lda	__rc6
	sta	(__rc20),y
	clc
	lda	__rc20
	adc	#4
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	.Lmul_v4sf_sstk+7               ; 1-byte Folded Reload
	ldy	__rc5
	sta	(__rc6),y
	lda	.Lmul_v4sf_sstk+5               ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc6),y
	lda	.Lmul_v4sf_sstk+6               ; 1-byte Folded Reload
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#8
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	__rc23
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc28
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#12
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	txa
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc2
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc3
	ldy	__rc8
	sta	(__rc6),y
	ldx	.Lmul_v4sf_sstk+25              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lmul_v4sf_sstk+24              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lmul_v4sf_sstk+23              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lmul_v4sf_sstk+22              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lmul_v4sf_sstk+21              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lmul_v4sf_sstk+20              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lmul_v4sf_sstk+19              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lmul_v4sf_sstk+18              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end2:
	.size	mul_v4sf, .Lfunc_end2-mul_v4sf
                                        ; -- End function
	.globl	div_v4sf                        ; -- Begin function div_v4sf
	.type	div_v4sf,@function
div_v4sf:                               ; @div_v4sf
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Ldiv_v4sf_sstk+18              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Ldiv_v4sf_sstk+19              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Ldiv_v4sf_sstk+20              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Ldiv_v4sf_sstk+21              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Ldiv_v4sf_sstk+22              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Ldiv_v4sf_sstk+23              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Ldiv_v4sf_sstk+24              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Ldiv_v4sf_sstk+25              ; 1-byte Folded Spill
	lda	__rc4
	clc
	adc	#4
	sta	__rc8
	lda	__rc5
	adc	#0
	sta	__rc9
	clc
	lda	__rc4
	adc	#8
	sta	__rc10
	lda	__rc5
	adc	#0
	sta	__rc11
	clc
	lda	__rc4
	adc	#12
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#4
	sta	__rc14
	lda	__rc7
	adc	#0
	sta	__rc15
	clc
	lda	__rc6
	adc	#8
	sta	__rc18
	lda	__rc7
	adc	#0
	sta	__rc19
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	clc
	lda	__rc6
	adc	#12
	sta	__rc2
	lda	(__rc4),y
	sta	__rc24
	iny
	lda	__rc7
	adc	#0
	sta	__rc3
	lda	(__rc4),y
	ldx	#1
	stx	__rc22
	tax
	iny
	lda	(__rc4),y
	sty	__rc25
	sta	.Ldiv_v4sf_sstk+13              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sty	__rc26
	sta	.Ldiv_v4sf_sstk+15              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sta	.Ldiv_v4sf_sstk+5               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc8),y
	sta	__rc23
	ldy	__rc25
	lda	(__rc8),y
	ldy	#2
	sty	__rc25
	sta	__rc31
	ldy	__rc26
	lda	(__rc8),y
	ldy	#3
	sty	__rc8
	sta	__rc29
	ldy	#8
	lda	(__rc4),y
	sta	.Ldiv_v4sf_sstk+4               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	sta	.Ldiv_v4sf_sstk+9               ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	sty	__rc9
	sta	.Ldiv_v4sf_sstk+11              ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc10),y
	sta	.Ldiv_v4sf_sstk+12              ; 1-byte Folded Spill
	ldy	#12
	lda	(__rc4),y
	sta	.Ldiv_v4sf_sstk                 ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc12),y
	sty	__rc4
	sta	.Ldiv_v4sf_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sty	__rc5
	sta	.Ldiv_v4sf_sstk+3               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sty	__rc12
	sta	.Ldiv_v4sf_sstk+2               ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc6),y
	sta	__rc11
	ldy	__rc4
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc9
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc12
	lda	(__rc6),y
	sta	__rc10
	ldy	#4
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc4
	lda	(__rc14),y
	sta	__rc22
	ldy	__rc5
	lda	(__rc14),y
	sta	.Ldiv_v4sf_sstk+6               ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc14),y
	sta	.Ldiv_v4sf_sstk+7               ; 1-byte Folded Spill
	ldy	#8
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc4
	lda	(__rc18),y
	sta	__rc30
	ldy	__rc5
	lda	(__rc18),y
	sta	__rc26
	ldy	__rc12
	lda	(__rc18),y
	sta	__rc27
	ldy	#12
	lda	(__rc6),y
	sta	.Ldiv_v4sf_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	sta	.Ldiv_v4sf_sstk+10              ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc2),y
	sta	.Ldiv_v4sf_sstk+14              ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc2),y
	sta	.Ldiv_v4sf_sstk+16              ; 1-byte Folded Spill
	ldy	.Ldiv_v4sf_sstk+13              ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Ldiv_v4sf_sstk+15              ; 1-byte Folded Reload
	sty	__rc3
	ldy	__rc11
	sty	__rc4
	ldy	__rc8
	sty	__rc5
	ldy	__rc9
	sty	__rc6
	ldy	__rc10
	sty	__rc7
	lda	__rc24
	jsr	__divsf3
	sta	__rc24
	stx	.Ldiv_v4sf_sstk+17              ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Ldiv_v4sf_sstk+15              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ldiv_v4sf_sstk+13              ; 1-byte Folded Spill
	ldx	__rc31
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc25
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	.Ldiv_v4sf_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Ldiv_v4sf_sstk+7               ; 1-byte Folded Reload
	stx	__rc7
	ldx	__rc23
	lda	.Ldiv_v4sf_sstk+5               ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc22
	stx	.Ldiv_v4sf_sstk+7               ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Ldiv_v4sf_sstk+5               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ldiv_v4sf_sstk+6               ; 1-byte Folded Spill
	ldx	.Ldiv_v4sf_sstk+11              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldiv_v4sf_sstk+12              ; 1-byte Folded Reload
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc30
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	ldx	.Ldiv_v4sf_sstk+9               ; 1-byte Folded Reload
	lda	.Ldiv_v4sf_sstk+4               ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc25
	stx	__rc23
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	.Ldiv_v4sf_sstk+3               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldiv_v4sf_sstk+2               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Ldiv_v4sf_sstk+8               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Ldiv_v4sf_sstk+10              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Ldiv_v4sf_sstk+14              ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Ldiv_v4sf_sstk+16              ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Ldiv_v4sf_sstk+1               ; 1-byte Folded Reload
	lda	.Ldiv_v4sf_sstk                 ; 1-byte Folded Reload
	jsr	__divsf3
	sta	__rc6
	ldy	#0
	lda	__rc24
	sta	(__rc20),y
	iny
	lda	.Ldiv_v4sf_sstk+17              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc5
	iny
	lda	.Ldiv_v4sf_sstk+15              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc9
	iny
	lda	.Ldiv_v4sf_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc8
	iny
	lda	__rc22
	sta	(__rc20),y
	ldy	#8
	lda	__rc25
	sta	(__rc20),y
	ldy	#12
	lda	__rc6
	sta	(__rc20),y
	clc
	lda	__rc20
	adc	#4
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	.Ldiv_v4sf_sstk+7               ; 1-byte Folded Reload
	ldy	__rc5
	sta	(__rc6),y
	lda	.Ldiv_v4sf_sstk+5               ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc6),y
	lda	.Ldiv_v4sf_sstk+6               ; 1-byte Folded Reload
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#8
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	__rc23
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc28
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#12
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	txa
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc2
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc3
	ldy	__rc8
	sta	(__rc6),y
	ldx	.Ldiv_v4sf_sstk+25              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Ldiv_v4sf_sstk+24              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Ldiv_v4sf_sstk+23              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Ldiv_v4sf_sstk+22              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Ldiv_v4sf_sstk+21              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Ldiv_v4sf_sstk+20              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Ldiv_v4sf_sstk+19              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Ldiv_v4sf_sstk+18              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end3:
	.size	div_v4sf, .Lfunc_end3-div_v4sf
                                        ; -- End function
	.globl	rem_v4sf                        ; -- Begin function rem_v4sf
	.type	rem_v4sf,@function
rem_v4sf:                               ; @rem_v4sf
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Lrem_v4sf_sstk+18              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lrem_v4sf_sstk+19              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lrem_v4sf_sstk+20              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lrem_v4sf_sstk+21              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lrem_v4sf_sstk+22              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lrem_v4sf_sstk+23              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lrem_v4sf_sstk+24              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lrem_v4sf_sstk+25              ; 1-byte Folded Spill
	lda	__rc4
	clc
	adc	#4
	sta	__rc8
	lda	__rc5
	adc	#0
	sta	__rc9
	clc
	lda	__rc4
	adc	#8
	sta	__rc10
	lda	__rc5
	adc	#0
	sta	__rc11
	clc
	lda	__rc4
	adc	#12
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#4
	sta	__rc14
	lda	__rc7
	adc	#0
	sta	__rc15
	clc
	lda	__rc6
	adc	#8
	sta	__rc18
	lda	__rc7
	adc	#0
	sta	__rc19
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	clc
	lda	__rc6
	adc	#12
	sta	__rc2
	lda	(__rc4),y
	sta	__rc24
	iny
	lda	__rc7
	adc	#0
	sta	__rc3
	lda	(__rc4),y
	ldx	#1
	stx	__rc22
	tax
	iny
	lda	(__rc4),y
	sty	__rc25
	sta	.Lrem_v4sf_sstk+13              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sty	__rc26
	sta	.Lrem_v4sf_sstk+15              ; 1-byte Folded Spill
	iny
	lda	(__rc4),y
	sta	.Lrem_v4sf_sstk+5               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc8),y
	sta	__rc23
	ldy	__rc25
	lda	(__rc8),y
	ldy	#2
	sty	__rc25
	sta	__rc31
	ldy	__rc26
	lda	(__rc8),y
	ldy	#3
	sty	__rc8
	sta	__rc29
	ldy	#8
	lda	(__rc4),y
	sta	.Lrem_v4sf_sstk+4               ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc10),y
	sta	.Lrem_v4sf_sstk+9               ; 1-byte Folded Spill
	ldy	__rc25
	lda	(__rc10),y
	sty	__rc9
	sta	.Lrem_v4sf_sstk+11              ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc10),y
	sta	.Lrem_v4sf_sstk+12              ; 1-byte Folded Spill
	ldy	#12
	lda	(__rc4),y
	sta	.Lrem_v4sf_sstk                 ; 1-byte Folded Spill
	ldy	__rc22
	lda	(__rc12),y
	sty	__rc4
	sta	.Lrem_v4sf_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sty	__rc5
	sta	.Lrem_v4sf_sstk+3               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sty	__rc12
	sta	.Lrem_v4sf_sstk+2               ; 1-byte Folded Spill
	ldy	#0
	lda	(__rc6),y
	sta	__rc11
	ldy	__rc4
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc9
	lda	(__rc6),y
	sta	__rc9
	ldy	__rc12
	lda	(__rc6),y
	sta	__rc10
	ldy	#4
	lda	(__rc6),y
	sta	__rc25
	ldy	__rc4
	lda	(__rc14),y
	sta	__rc22
	ldy	__rc5
	lda	(__rc14),y
	sta	.Lrem_v4sf_sstk+6               ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc14),y
	sta	.Lrem_v4sf_sstk+7               ; 1-byte Folded Spill
	ldy	#8
	lda	(__rc6),y
	sta	__rc28
	ldy	__rc4
	lda	(__rc18),y
	sta	__rc30
	ldy	__rc5
	lda	(__rc18),y
	sta	__rc26
	ldy	__rc12
	lda	(__rc18),y
	sta	__rc27
	ldy	#12
	lda	(__rc6),y
	sta	.Lrem_v4sf_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc2),y
	sta	.Lrem_v4sf_sstk+10              ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc2),y
	sta	.Lrem_v4sf_sstk+14              ; 1-byte Folded Spill
	ldy	__rc12
	lda	(__rc2),y
	sta	.Lrem_v4sf_sstk+16              ; 1-byte Folded Spill
	ldy	.Lrem_v4sf_sstk+13              ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Lrem_v4sf_sstk+15              ; 1-byte Folded Reload
	sty	__rc3
	ldy	__rc11
	sty	__rc4
	ldy	__rc8
	sty	__rc5
	ldy	__rc9
	sty	__rc6
	ldy	__rc10
	sty	__rc7
	lda	__rc24
	jsr	fmodf
	sta	__rc24
	stx	.Lrem_v4sf_sstk+17              ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lrem_v4sf_sstk+15              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lrem_v4sf_sstk+13              ; 1-byte Folded Spill
	ldx	__rc31
	stx	__rc2
	ldx	__rc29
	stx	__rc3
	ldx	__rc25
	stx	__rc4
	ldx	__rc22
	stx	__rc5
	ldx	.Lrem_v4sf_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lrem_v4sf_sstk+7               ; 1-byte Folded Reload
	stx	__rc7
	ldx	__rc23
	lda	.Lrem_v4sf_sstk+5               ; 1-byte Folded Reload
	jsr	fmodf
	sta	__rc22
	stx	.Lrem_v4sf_sstk+7               ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lrem_v4sf_sstk+5               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lrem_v4sf_sstk+6               ; 1-byte Folded Spill
	ldx	.Lrem_v4sf_sstk+11              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lrem_v4sf_sstk+12              ; 1-byte Folded Reload
	stx	__rc3
	ldx	__rc28
	stx	__rc4
	ldx	__rc30
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc27
	stx	__rc7
	ldx	.Lrem_v4sf_sstk+9               ; 1-byte Folded Reload
	lda	.Lrem_v4sf_sstk+4               ; 1-byte Folded Reload
	jsr	fmodf
	sta	__rc25
	stx	__rc23
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	.Lrem_v4sf_sstk+3               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lrem_v4sf_sstk+2               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Lrem_v4sf_sstk+8               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lrem_v4sf_sstk+10              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lrem_v4sf_sstk+14              ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lrem_v4sf_sstk+16              ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Lrem_v4sf_sstk+1               ; 1-byte Folded Reload
	lda	.Lrem_v4sf_sstk                 ; 1-byte Folded Reload
	jsr	fmodf
	sta	__rc6
	ldy	#0
	lda	__rc24
	sta	(__rc20),y
	iny
	lda	.Lrem_v4sf_sstk+17              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc5
	iny
	lda	.Lrem_v4sf_sstk+15              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc9
	iny
	lda	.Lrem_v4sf_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	sty	__rc8
	iny
	lda	__rc22
	sta	(__rc20),y
	ldy	#8
	lda	__rc25
	sta	(__rc20),y
	ldy	#12
	lda	__rc6
	sta	(__rc20),y
	clc
	lda	__rc20
	adc	#4
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	.Lrem_v4sf_sstk+7               ; 1-byte Folded Reload
	ldy	__rc5
	sta	(__rc6),y
	lda	.Lrem_v4sf_sstk+5               ; 1-byte Folded Reload
	ldy	__rc9
	sta	(__rc6),y
	lda	.Lrem_v4sf_sstk+6               ; 1-byte Folded Reload
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#8
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	lda	__rc23
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc30
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc28
	ldy	__rc8
	sta	(__rc6),y
	clc
	lda	__rc20
	adc	#12
	sta	__rc6
	lda	__rc21
	adc	#0
	sta	__rc7
	txa
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc2
	ldy	__rc9
	sta	(__rc6),y
	lda	__rc3
	ldy	__rc8
	sta	(__rc6),y
	ldx	.Lrem_v4sf_sstk+25              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lrem_v4sf_sstk+24              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lrem_v4sf_sstk+23              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lrem_v4sf_sstk+22              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lrem_v4sf_sstk+21              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lrem_v4sf_sstk+20              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lrem_v4sf_sstk+19              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lrem_v4sf_sstk+18              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end4:
	.size	rem_v4sf, .Lfunc_end4-rem_v4sf
                                        ; -- End function
	.globl	add_v2df                        ; -- Begin function add_v2df
	.type	add_v2df,@function
add_v2df:                               ; @add_v2df
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Ladd_v2df_sstk+14              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Ladd_v2df_sstk+15              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Ladd_v2df_sstk+16              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Ladd_v2df_sstk+17              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Ladd_v2df_sstk+18              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Ladd_v2df_sstk+19              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Ladd_v2df_sstk+20              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Ladd_v2df_sstk+21              ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	lda	(__rc4),y
	sta	.Ladd_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	#0
	stx	__rc10
	iny
	lda	__rc4
	clc
	adc	#8
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#8
	sta	__rc24
	lda	__rc7
	adc	#0
	sta	__rc25
	lda	(__rc4),y
	sta	__rc19
	inx
	stx	__rc2
	iny
	lda	(__rc4),y
	inx
	stx	__rc9
	tax
	iny
	lda	(__rc4),y
	sty	__rc8
	sta	__rc3
	iny
	lda	(__rc4),y
	sta	__rc11
	iny
	lda	(__rc4),y
	sta	__rc14
	iny
	lda	(__rc4),y
	sta	__rc15
	iny
	lda	(__rc4),y
	sty	__rc23
	sta	__rc22
	iny
	lda	(__rc4),y
	sta	.Ladd_v2df_sstk                 ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+7               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+3               ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+4               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+5               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+6               ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc12),y
	sta	.Ladd_v2df_sstk+2               ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc2
	lda	(__rc6),y
	sta	__rc9
	ldy	#2
	lda	(__rc6),y
	sty	__rc5
	sta	__rc10
	iny
	lda	(__rc6),y
	sty	__rc4
	sta	__rc27
	iny
	lda	(__rc6),y
	sty	__rc26
	sta	__rc12
	iny
	lda	(__rc6),y
	sty	__rc29
	sta	__rc13
	iny
	lda	(__rc6),y
	sty	__rc23
	sta	__rc28
	iny
	lda	(__rc6),y
	sty	__rc18
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	.Ladd_v2df_sstk+10              ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc24),y
	sta	.Ladd_v2df_sstk+9               ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc24),y
	sta	.Ladd_v2df_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc24),y
	sta	__rc31
	ldy	__rc26
	lda	(__rc24),y
	sta	__rc26
	ldy	__rc29
	lda	(__rc24),y
	sta	__rc29
	ldy	__rc23
	lda	(__rc24),y
	sta	__rc23
	ldy	__rc18
	lda	(__rc24),y
	sta	__rc24
	stx	__rc2
	ldx	__rc11
	stx	__rc4
	ldx	__rc14
	stx	__rc5
	ldx	__rc15
	stx	__rc6
	ldx	__rc22
	stx	__rc7
	ldx	__rc27
	stx	__rc11
	ldx	__rc28
	stx	__rc14
	ldx	__rc30
	stx	__rc15
	ldx	__rc19
	lda	.Ladd_v2df_sstk+11              ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc25
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc27
	ldx	__rc5
	stx	.Ladd_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	__rc6
	stx	.Ladd_v2df_sstk+12              ; 1-byte Folded Spill
	ldx	__rc7
	stx	.Ladd_v2df_sstk+13              ; 1-byte Folded Spill
	ldx	.Ladd_v2df_sstk+7               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ladd_v2df_sstk+3               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Ladd_v2df_sstk+4               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Ladd_v2df_sstk+5               ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Ladd_v2df_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Ladd_v2df_sstk+2               ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Ladd_v2df_sstk+10              ; 1-byte Folded Reload
	stx	__rc8
	ldx	.Ladd_v2df_sstk+9               ; 1-byte Folded Reload
	stx	__rc9
	ldx	.Ladd_v2df_sstk+8               ; 1-byte Folded Reload
	stx	__rc10
	ldx	__rc31
	stx	__rc11
	ldx	__rc26
	stx	__rc12
	ldx	__rc29
	stx	__rc13
	ldx	__rc23
	stx	__rc14
	ldx	__rc24
	stx	__rc15
	ldx	.Ladd_v2df_sstk+1               ; 1-byte Folded Reload
	lda	.Ladd_v2df_sstk                 ; 1-byte Folded Reload
	jsr	__adddf3
	sta	__rc8
	ldy	#0
	lda	__rc25
	sta	(__rc20),y
	iny
	lda	__rc22
	sta	(__rc20),y
	sty	__rc10
	iny
	lda	__rc30
	sta	(__rc20),y
	iny
	lda	__rc28
	sta	(__rc20),y
	iny
	lda	__rc27
	sta	(__rc20),y
	iny
	lda	.Ladd_v2df_sstk+11              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Ladd_v2df_sstk+12              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Ladd_v2df_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	__rc8
	sta	(__rc20),y
	lda	__rc20
	clc
	adc	#8
	sta	__rc8
	lda	__rc21
	adc	#0
	sta	__rc9
	txa
	ldy	__rc10
	sta	(__rc8),y
	ldy	#2
	lda	__rc2
	sta	(__rc8),y
	iny
	lda	__rc3
	sta	(__rc8),y
	iny
	lda	__rc4
	sta	(__rc8),y
	iny
	lda	__rc5
	sta	(__rc8),y
	iny
	lda	__rc6
	sta	(__rc8),y
	iny
	lda	__rc7
	sta	(__rc8),y
	ldx	.Ladd_v2df_sstk+21              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Ladd_v2df_sstk+20              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Ladd_v2df_sstk+19              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Ladd_v2df_sstk+18              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Ladd_v2df_sstk+17              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Ladd_v2df_sstk+16              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Ladd_v2df_sstk+15              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Ladd_v2df_sstk+14              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end5:
	.size	add_v2df, .Lfunc_end5-add_v2df
                                        ; -- End function
	.globl	sub_v2df                        ; -- Begin function sub_v2df
	.type	sub_v2df,@function
sub_v2df:                               ; @sub_v2df
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Lsub_v2df_sstk+14              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lsub_v2df_sstk+15              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lsub_v2df_sstk+16              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lsub_v2df_sstk+17              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lsub_v2df_sstk+18              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lsub_v2df_sstk+19              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lsub_v2df_sstk+20              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lsub_v2df_sstk+21              ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	lda	(__rc4),y
	sta	.Lsub_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	#0
	stx	__rc10
	iny
	lda	__rc4
	clc
	adc	#8
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#8
	sta	__rc24
	lda	__rc7
	adc	#0
	sta	__rc25
	lda	(__rc4),y
	sta	__rc19
	inx
	stx	__rc2
	iny
	lda	(__rc4),y
	inx
	stx	__rc9
	tax
	iny
	lda	(__rc4),y
	sty	__rc8
	sta	__rc3
	iny
	lda	(__rc4),y
	sta	__rc11
	iny
	lda	(__rc4),y
	sta	__rc14
	iny
	lda	(__rc4),y
	sta	__rc15
	iny
	lda	(__rc4),y
	sty	__rc23
	sta	__rc22
	iny
	lda	(__rc4),y
	sta	.Lsub_v2df_sstk                 ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+7               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+3               ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+4               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+5               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+6               ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc12),y
	sta	.Lsub_v2df_sstk+2               ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc2
	lda	(__rc6),y
	sta	__rc9
	ldy	#2
	lda	(__rc6),y
	sty	__rc5
	sta	__rc10
	iny
	lda	(__rc6),y
	sty	__rc4
	sta	__rc27
	iny
	lda	(__rc6),y
	sty	__rc26
	sta	__rc12
	iny
	lda	(__rc6),y
	sty	__rc29
	sta	__rc13
	iny
	lda	(__rc6),y
	sty	__rc23
	sta	__rc28
	iny
	lda	(__rc6),y
	sty	__rc18
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	.Lsub_v2df_sstk+10              ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc24),y
	sta	.Lsub_v2df_sstk+9               ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc24),y
	sta	.Lsub_v2df_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc24),y
	sta	__rc31
	ldy	__rc26
	lda	(__rc24),y
	sta	__rc26
	ldy	__rc29
	lda	(__rc24),y
	sta	__rc29
	ldy	__rc23
	lda	(__rc24),y
	sta	__rc23
	ldy	__rc18
	lda	(__rc24),y
	sta	__rc24
	stx	__rc2
	ldx	__rc11
	stx	__rc4
	ldx	__rc14
	stx	__rc5
	ldx	__rc15
	stx	__rc6
	ldx	__rc22
	stx	__rc7
	ldx	__rc27
	stx	__rc11
	ldx	__rc28
	stx	__rc14
	ldx	__rc30
	stx	__rc15
	ldx	__rc19
	lda	.Lsub_v2df_sstk+11              ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc25
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc27
	ldx	__rc5
	stx	.Lsub_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	__rc6
	stx	.Lsub_v2df_sstk+12              ; 1-byte Folded Spill
	ldx	__rc7
	stx	.Lsub_v2df_sstk+13              ; 1-byte Folded Spill
	ldx	.Lsub_v2df_sstk+7               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lsub_v2df_sstk+3               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Lsub_v2df_sstk+4               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lsub_v2df_sstk+5               ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lsub_v2df_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lsub_v2df_sstk+2               ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Lsub_v2df_sstk+10              ; 1-byte Folded Reload
	stx	__rc8
	ldx	.Lsub_v2df_sstk+9               ; 1-byte Folded Reload
	stx	__rc9
	ldx	.Lsub_v2df_sstk+8               ; 1-byte Folded Reload
	stx	__rc10
	ldx	__rc31
	stx	__rc11
	ldx	__rc26
	stx	__rc12
	ldx	__rc29
	stx	__rc13
	ldx	__rc23
	stx	__rc14
	ldx	__rc24
	stx	__rc15
	ldx	.Lsub_v2df_sstk+1               ; 1-byte Folded Reload
	lda	.Lsub_v2df_sstk                 ; 1-byte Folded Reload
	jsr	__subdf3
	sta	__rc8
	ldy	#0
	lda	__rc25
	sta	(__rc20),y
	iny
	lda	__rc22
	sta	(__rc20),y
	sty	__rc10
	iny
	lda	__rc30
	sta	(__rc20),y
	iny
	lda	__rc28
	sta	(__rc20),y
	iny
	lda	__rc27
	sta	(__rc20),y
	iny
	lda	.Lsub_v2df_sstk+11              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Lsub_v2df_sstk+12              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Lsub_v2df_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	__rc8
	sta	(__rc20),y
	lda	__rc20
	clc
	adc	#8
	sta	__rc8
	lda	__rc21
	adc	#0
	sta	__rc9
	txa
	ldy	__rc10
	sta	(__rc8),y
	ldy	#2
	lda	__rc2
	sta	(__rc8),y
	iny
	lda	__rc3
	sta	(__rc8),y
	iny
	lda	__rc4
	sta	(__rc8),y
	iny
	lda	__rc5
	sta	(__rc8),y
	iny
	lda	__rc6
	sta	(__rc8),y
	iny
	lda	__rc7
	sta	(__rc8),y
	ldx	.Lsub_v2df_sstk+21              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lsub_v2df_sstk+20              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lsub_v2df_sstk+19              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lsub_v2df_sstk+18              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lsub_v2df_sstk+17              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lsub_v2df_sstk+16              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lsub_v2df_sstk+15              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lsub_v2df_sstk+14              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end6:
	.size	sub_v2df, .Lfunc_end6-sub_v2df
                                        ; -- End function
	.globl	mul_v2df                        ; -- Begin function mul_v2df
	.type	mul_v2df,@function
mul_v2df:                               ; @mul_v2df
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Lmul_v2df_sstk+14              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lmul_v2df_sstk+15              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lmul_v2df_sstk+16              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lmul_v2df_sstk+17              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lmul_v2df_sstk+18              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lmul_v2df_sstk+19              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lmul_v2df_sstk+20              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lmul_v2df_sstk+21              ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	lda	(__rc4),y
	sta	.Lmul_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	#0
	stx	__rc10
	iny
	lda	__rc4
	clc
	adc	#8
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#8
	sta	__rc24
	lda	__rc7
	adc	#0
	sta	__rc25
	lda	(__rc4),y
	sta	__rc19
	inx
	stx	__rc2
	iny
	lda	(__rc4),y
	inx
	stx	__rc9
	tax
	iny
	lda	(__rc4),y
	sty	__rc8
	sta	__rc3
	iny
	lda	(__rc4),y
	sta	__rc11
	iny
	lda	(__rc4),y
	sta	__rc14
	iny
	lda	(__rc4),y
	sta	__rc15
	iny
	lda	(__rc4),y
	sty	__rc23
	sta	__rc22
	iny
	lda	(__rc4),y
	sta	.Lmul_v2df_sstk                 ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+7               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+3               ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+4               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+5               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+6               ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc12),y
	sta	.Lmul_v2df_sstk+2               ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc2
	lda	(__rc6),y
	sta	__rc9
	ldy	#2
	lda	(__rc6),y
	sty	__rc5
	sta	__rc10
	iny
	lda	(__rc6),y
	sty	__rc4
	sta	__rc27
	iny
	lda	(__rc6),y
	sty	__rc26
	sta	__rc12
	iny
	lda	(__rc6),y
	sty	__rc29
	sta	__rc13
	iny
	lda	(__rc6),y
	sty	__rc23
	sta	__rc28
	iny
	lda	(__rc6),y
	sty	__rc18
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	.Lmul_v2df_sstk+10              ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc24),y
	sta	.Lmul_v2df_sstk+9               ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc24),y
	sta	.Lmul_v2df_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc24),y
	sta	__rc31
	ldy	__rc26
	lda	(__rc24),y
	sta	__rc26
	ldy	__rc29
	lda	(__rc24),y
	sta	__rc29
	ldy	__rc23
	lda	(__rc24),y
	sta	__rc23
	ldy	__rc18
	lda	(__rc24),y
	sta	__rc24
	stx	__rc2
	ldx	__rc11
	stx	__rc4
	ldx	__rc14
	stx	__rc5
	ldx	__rc15
	stx	__rc6
	ldx	__rc22
	stx	__rc7
	ldx	__rc27
	stx	__rc11
	ldx	__rc28
	stx	__rc14
	ldx	__rc30
	stx	__rc15
	ldx	__rc19
	lda	.Lmul_v2df_sstk+11              ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc25
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc27
	ldx	__rc5
	stx	.Lmul_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	__rc6
	stx	.Lmul_v2df_sstk+12              ; 1-byte Folded Spill
	ldx	__rc7
	stx	.Lmul_v2df_sstk+13              ; 1-byte Folded Spill
	ldx	.Lmul_v2df_sstk+7               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lmul_v2df_sstk+3               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Lmul_v2df_sstk+4               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lmul_v2df_sstk+5               ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lmul_v2df_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lmul_v2df_sstk+2               ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Lmul_v2df_sstk+10              ; 1-byte Folded Reload
	stx	__rc8
	ldx	.Lmul_v2df_sstk+9               ; 1-byte Folded Reload
	stx	__rc9
	ldx	.Lmul_v2df_sstk+8               ; 1-byte Folded Reload
	stx	__rc10
	ldx	__rc31
	stx	__rc11
	ldx	__rc26
	stx	__rc12
	ldx	__rc29
	stx	__rc13
	ldx	__rc23
	stx	__rc14
	ldx	__rc24
	stx	__rc15
	ldx	.Lmul_v2df_sstk+1               ; 1-byte Folded Reload
	lda	.Lmul_v2df_sstk                 ; 1-byte Folded Reload
	jsr	__muldf3
	sta	__rc8
	ldy	#0
	lda	__rc25
	sta	(__rc20),y
	iny
	lda	__rc22
	sta	(__rc20),y
	sty	__rc10
	iny
	lda	__rc30
	sta	(__rc20),y
	iny
	lda	__rc28
	sta	(__rc20),y
	iny
	lda	__rc27
	sta	(__rc20),y
	iny
	lda	.Lmul_v2df_sstk+11              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Lmul_v2df_sstk+12              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Lmul_v2df_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	__rc8
	sta	(__rc20),y
	lda	__rc20
	clc
	adc	#8
	sta	__rc8
	lda	__rc21
	adc	#0
	sta	__rc9
	txa
	ldy	__rc10
	sta	(__rc8),y
	ldy	#2
	lda	__rc2
	sta	(__rc8),y
	iny
	lda	__rc3
	sta	(__rc8),y
	iny
	lda	__rc4
	sta	(__rc8),y
	iny
	lda	__rc5
	sta	(__rc8),y
	iny
	lda	__rc6
	sta	(__rc8),y
	iny
	lda	__rc7
	sta	(__rc8),y
	ldx	.Lmul_v2df_sstk+21              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lmul_v2df_sstk+20              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lmul_v2df_sstk+19              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lmul_v2df_sstk+18              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lmul_v2df_sstk+17              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lmul_v2df_sstk+16              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lmul_v2df_sstk+15              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lmul_v2df_sstk+14              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end7:
	.size	mul_v2df, .Lfunc_end7-mul_v2df
                                        ; -- End function
	.globl	div_v2df                        ; -- Begin function div_v2df
	.type	div_v2df,@function
div_v2df:                               ; @div_v2df
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Ldiv_v2df_sstk+14              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Ldiv_v2df_sstk+15              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Ldiv_v2df_sstk+16              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Ldiv_v2df_sstk+17              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Ldiv_v2df_sstk+18              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Ldiv_v2df_sstk+19              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Ldiv_v2df_sstk+20              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Ldiv_v2df_sstk+21              ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	lda	(__rc4),y
	sta	.Ldiv_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	#0
	stx	__rc10
	iny
	lda	__rc4
	clc
	adc	#8
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#8
	sta	__rc24
	lda	__rc7
	adc	#0
	sta	__rc25
	lda	(__rc4),y
	sta	__rc19
	inx
	stx	__rc2
	iny
	lda	(__rc4),y
	inx
	stx	__rc9
	tax
	iny
	lda	(__rc4),y
	sty	__rc8
	sta	__rc3
	iny
	lda	(__rc4),y
	sta	__rc11
	iny
	lda	(__rc4),y
	sta	__rc14
	iny
	lda	(__rc4),y
	sta	__rc15
	iny
	lda	(__rc4),y
	sty	__rc23
	sta	__rc22
	iny
	lda	(__rc4),y
	sta	.Ldiv_v2df_sstk                 ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+7               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+3               ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+4               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+5               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+6               ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc12),y
	sta	.Ldiv_v2df_sstk+2               ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc2
	lda	(__rc6),y
	sta	__rc9
	ldy	#2
	lda	(__rc6),y
	sty	__rc5
	sta	__rc10
	iny
	lda	(__rc6),y
	sty	__rc4
	sta	__rc27
	iny
	lda	(__rc6),y
	sty	__rc26
	sta	__rc12
	iny
	lda	(__rc6),y
	sty	__rc29
	sta	__rc13
	iny
	lda	(__rc6),y
	sty	__rc23
	sta	__rc28
	iny
	lda	(__rc6),y
	sty	__rc18
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	.Ldiv_v2df_sstk+10              ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc24),y
	sta	.Ldiv_v2df_sstk+9               ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc24),y
	sta	.Ldiv_v2df_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc24),y
	sta	__rc31
	ldy	__rc26
	lda	(__rc24),y
	sta	__rc26
	ldy	__rc29
	lda	(__rc24),y
	sta	__rc29
	ldy	__rc23
	lda	(__rc24),y
	sta	__rc23
	ldy	__rc18
	lda	(__rc24),y
	sta	__rc24
	stx	__rc2
	ldx	__rc11
	stx	__rc4
	ldx	__rc14
	stx	__rc5
	ldx	__rc15
	stx	__rc6
	ldx	__rc22
	stx	__rc7
	ldx	__rc27
	stx	__rc11
	ldx	__rc28
	stx	__rc14
	ldx	__rc30
	stx	__rc15
	ldx	__rc19
	lda	.Ldiv_v2df_sstk+11              ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc25
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc27
	ldx	__rc5
	stx	.Ldiv_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	__rc6
	stx	.Ldiv_v2df_sstk+12              ; 1-byte Folded Spill
	ldx	__rc7
	stx	.Ldiv_v2df_sstk+13              ; 1-byte Folded Spill
	ldx	.Ldiv_v2df_sstk+7               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldiv_v2df_sstk+3               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Ldiv_v2df_sstk+4               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Ldiv_v2df_sstk+5               ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Ldiv_v2df_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Ldiv_v2df_sstk+2               ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Ldiv_v2df_sstk+10              ; 1-byte Folded Reload
	stx	__rc8
	ldx	.Ldiv_v2df_sstk+9               ; 1-byte Folded Reload
	stx	__rc9
	ldx	.Ldiv_v2df_sstk+8               ; 1-byte Folded Reload
	stx	__rc10
	ldx	__rc31
	stx	__rc11
	ldx	__rc26
	stx	__rc12
	ldx	__rc29
	stx	__rc13
	ldx	__rc23
	stx	__rc14
	ldx	__rc24
	stx	__rc15
	ldx	.Ldiv_v2df_sstk+1               ; 1-byte Folded Reload
	lda	.Ldiv_v2df_sstk                 ; 1-byte Folded Reload
	jsr	__divdf3
	sta	__rc8
	ldy	#0
	lda	__rc25
	sta	(__rc20),y
	iny
	lda	__rc22
	sta	(__rc20),y
	sty	__rc10
	iny
	lda	__rc30
	sta	(__rc20),y
	iny
	lda	__rc28
	sta	(__rc20),y
	iny
	lda	__rc27
	sta	(__rc20),y
	iny
	lda	.Ldiv_v2df_sstk+11              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Ldiv_v2df_sstk+12              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Ldiv_v2df_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	__rc8
	sta	(__rc20),y
	lda	__rc20
	clc
	adc	#8
	sta	__rc8
	lda	__rc21
	adc	#0
	sta	__rc9
	txa
	ldy	__rc10
	sta	(__rc8),y
	ldy	#2
	lda	__rc2
	sta	(__rc8),y
	iny
	lda	__rc3
	sta	(__rc8),y
	iny
	lda	__rc4
	sta	(__rc8),y
	iny
	lda	__rc5
	sta	(__rc8),y
	iny
	lda	__rc6
	sta	(__rc8),y
	iny
	lda	__rc7
	sta	(__rc8),y
	ldx	.Ldiv_v2df_sstk+21              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Ldiv_v2df_sstk+20              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Ldiv_v2df_sstk+19              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Ldiv_v2df_sstk+18              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Ldiv_v2df_sstk+17              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Ldiv_v2df_sstk+16              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Ldiv_v2df_sstk+15              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Ldiv_v2df_sstk+14              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end8:
	.size	div_v2df, .Lfunc_end8-div_v2df
                                        ; -- End function
	.globl	rem_v2df                        ; -- Begin function rem_v2df
	.type	rem_v2df,@function
rem_v2df:                               ; @rem_v2df
; %bb.0:
	lda	__rc20
	pha
	lda	__rc21
	pha
	lda	__rc22
	pha
	lda	__rc23
	pha
	ldx	__rc24
	stx	.Lrem_v2df_sstk+14              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lrem_v2df_sstk+15              ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lrem_v2df_sstk+16              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lrem_v2df_sstk+17              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lrem_v2df_sstk+18              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lrem_v2df_sstk+19              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lrem_v2df_sstk+20              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lrem_v2df_sstk+21              ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	ldy	#0
	lda	(__rc4),y
	sta	.Lrem_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	#0
	stx	__rc10
	iny
	lda	__rc4
	clc
	adc	#8
	sta	__rc12
	lda	__rc5
	adc	#0
	sta	__rc13
	lda	__rc6
	clc
	adc	#8
	sta	__rc24
	lda	__rc7
	adc	#0
	sta	__rc25
	lda	(__rc4),y
	sta	__rc19
	inx
	stx	__rc2
	iny
	lda	(__rc4),y
	inx
	stx	__rc9
	tax
	iny
	lda	(__rc4),y
	sty	__rc8
	sta	__rc3
	iny
	lda	(__rc4),y
	sta	__rc11
	iny
	lda	(__rc4),y
	sta	__rc14
	iny
	lda	(__rc4),y
	sta	__rc15
	iny
	lda	(__rc4),y
	sty	__rc23
	sta	__rc22
	iny
	lda	(__rc4),y
	sta	.Lrem_v2df_sstk                 ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+1               ; 1-byte Folded Spill
	ldy	__rc9
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+7               ; 1-byte Folded Spill
	ldy	__rc8
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+3               ; 1-byte Folded Spill
	ldy	#4
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+4               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+5               ; 1-byte Folded Spill
	iny
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+6               ; 1-byte Folded Spill
	ldy	__rc23
	lda	(__rc12),y
	sta	.Lrem_v2df_sstk+2               ; 1-byte Folded Spill
	ldy	__rc10
	lda	(__rc6),y
	sta	__rc8
	ldy	__rc2
	lda	(__rc6),y
	sta	__rc9
	ldy	#2
	lda	(__rc6),y
	sty	__rc5
	sta	__rc10
	iny
	lda	(__rc6),y
	sty	__rc4
	sta	__rc27
	iny
	lda	(__rc6),y
	sty	__rc26
	sta	__rc12
	iny
	lda	(__rc6),y
	sty	__rc29
	sta	__rc13
	iny
	lda	(__rc6),y
	sty	__rc23
	sta	__rc28
	iny
	lda	(__rc6),y
	sty	__rc18
	sta	__rc30
	iny
	lda	(__rc6),y
	sta	.Lrem_v2df_sstk+10              ; 1-byte Folded Spill
	ldy	__rc2
	lda	(__rc24),y
	sta	.Lrem_v2df_sstk+9               ; 1-byte Folded Spill
	ldy	__rc5
	lda	(__rc24),y
	sta	.Lrem_v2df_sstk+8               ; 1-byte Folded Spill
	ldy	__rc4
	lda	(__rc24),y
	sta	__rc31
	ldy	__rc26
	lda	(__rc24),y
	sta	__rc26
	ldy	__rc29
	lda	(__rc24),y
	sta	__rc29
	ldy	__rc23
	lda	(__rc24),y
	sta	__rc23
	ldy	__rc18
	lda	(__rc24),y
	sta	__rc24
	stx	__rc2
	ldx	__rc11
	stx	__rc4
	ldx	__rc14
	stx	__rc5
	ldx	__rc15
	stx	__rc6
	ldx	__rc22
	stx	__rc7
	ldx	__rc27
	stx	__rc11
	ldx	__rc28
	stx	__rc14
	ldx	__rc30
	stx	__rc15
	ldx	__rc19
	lda	.Lrem_v2df_sstk+11              ; 1-byte Folded Reload
	jsr	fmod
	sta	__rc25
	stx	__rc22
	ldx	__rc2
	stx	__rc30
	ldx	__rc3
	stx	__rc28
	ldx	__rc4
	stx	__rc27
	ldx	__rc5
	stx	.Lrem_v2df_sstk+11              ; 1-byte Folded Spill
	ldx	__rc6
	stx	.Lrem_v2df_sstk+12              ; 1-byte Folded Spill
	ldx	__rc7
	stx	.Lrem_v2df_sstk+13              ; 1-byte Folded Spill
	ldx	.Lrem_v2df_sstk+7               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lrem_v2df_sstk+3               ; 1-byte Folded Reload
	stx	__rc3
	ldx	.Lrem_v2df_sstk+4               ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lrem_v2df_sstk+5               ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lrem_v2df_sstk+6               ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lrem_v2df_sstk+2               ; 1-byte Folded Reload
	stx	__rc7
	ldx	.Lrem_v2df_sstk+10              ; 1-byte Folded Reload
	stx	__rc8
	ldx	.Lrem_v2df_sstk+9               ; 1-byte Folded Reload
	stx	__rc9
	ldx	.Lrem_v2df_sstk+8               ; 1-byte Folded Reload
	stx	__rc10
	ldx	__rc31
	stx	__rc11
	ldx	__rc26
	stx	__rc12
	ldx	__rc29
	stx	__rc13
	ldx	__rc23
	stx	__rc14
	ldx	__rc24
	stx	__rc15
	ldx	.Lrem_v2df_sstk+1               ; 1-byte Folded Reload
	lda	.Lrem_v2df_sstk                 ; 1-byte Folded Reload
	jsr	fmod
	sta	__rc8
	ldy	#0
	lda	__rc25
	sta	(__rc20),y
	iny
	lda	__rc22
	sta	(__rc20),y
	sty	__rc10
	iny
	lda	__rc30
	sta	(__rc20),y
	iny
	lda	__rc28
	sta	(__rc20),y
	iny
	lda	__rc27
	sta	(__rc20),y
	iny
	lda	.Lrem_v2df_sstk+11              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Lrem_v2df_sstk+12              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	.Lrem_v2df_sstk+13              ; 1-byte Folded Reload
	sta	(__rc20),y
	iny
	lda	__rc8
	sta	(__rc20),y
	lda	__rc20
	clc
	adc	#8
	sta	__rc8
	lda	__rc21
	adc	#0
	sta	__rc9
	txa
	ldy	__rc10
	sta	(__rc8),y
	ldy	#2
	lda	__rc2
	sta	(__rc8),y
	iny
	lda	__rc3
	sta	(__rc8),y
	iny
	lda	__rc4
	sta	(__rc8),y
	iny
	lda	__rc5
	sta	(__rc8),y
	iny
	lda	__rc6
	sta	(__rc8),y
	iny
	lda	__rc7
	sta	(__rc8),y
	ldx	.Lrem_v2df_sstk+21              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lrem_v2df_sstk+20              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lrem_v2df_sstk+19              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lrem_v2df_sstk+18              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lrem_v2df_sstk+17              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lrem_v2df_sstk+16              ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lrem_v2df_sstk+15              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lrem_v2df_sstk+14              ; 1-byte Folded Reload
	stx	__rc24
	pla
	sta	__rc23
	pla
	sta	__rc22
	pla
	sta	__rc21
	pla
	sta	__rc20
	rts
.Lfunc_end9:
	.size	rem_v2df, .Lfunc_end9-rem_v2df
                                        ; -- End function
	.type	.Lstatic_stack,@object          ; @static_stack
	.section	.noinit,"aw",@nobits
	.p2align	4, 0x0
.Lstatic_stack:
	.zero	26
	.size	.Lstatic_stack, 26

.Ladd_v4sf_sstk = .Lstatic_stack
	.size	.Ladd_v4sf_sstk, 26
.Lsub_v4sf_sstk = .Lstatic_stack
	.size	.Lsub_v4sf_sstk, 26
.Lmul_v4sf_sstk = .Lstatic_stack
	.size	.Lmul_v4sf_sstk, 26
.Ldiv_v4sf_sstk = .Lstatic_stack
	.size	.Ldiv_v4sf_sstk, 26
.Lrem_v4sf_sstk = .Lstatic_stack
	.size	.Lrem_v4sf_sstk, 26
.Ladd_v2df_sstk = .Lstatic_stack
	.size	.Ladd_v2df_sstk, 22
.Lsub_v2df_sstk = .Lstatic_stack
	.size	.Lsub_v2df_sstk, 22
.Lmul_v2df_sstk = .Lstatic_stack
	.size	.Lmul_v2df_sstk, 22
.Ldiv_v2df_sstk = .Lstatic_stack
	.size	.Ldiv_v2df_sstk, 22
.Lrem_v2df_sstk = .Lstatic_stack
	.size	.Lrem_v2df_sstk, 22
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

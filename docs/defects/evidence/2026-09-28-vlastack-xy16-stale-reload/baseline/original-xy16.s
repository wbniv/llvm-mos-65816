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
	.file	"vlastack_sim.c"
	.section	.text.main,"ax",@progbits
	.globl	main                            ; -- Begin function main
	.type	main,@function
main:                                   ; @main
; %bb.0:
	jsr	vs_build
	jsr	vs_decode
	rep	#32
	lda	vs_totalruns
	eor	#19755
	sta	__rc4
	sep	#32
	lda	__rc5
	cmp	#128
	rol	__rc4
	rol
	ldy	#85
	ldx	#98
	sty	__rc2
	sty	__rc20
	stx	__rc28
	stx	__rc3
	tax
	lda	__rc4
	jsr	__mulhi3
	ldy	__rc20
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	clc
	adc	#13849
	sta	__rc2
	sep	#32
	ldx	#mos16lo(vs_img)
	stx	__rc22
	ldx	#mos16hi(vs_img)
	stx	__rc23
	stz	__rc21
	stz	__rc24
	stz	__rc26
.LBB0_1:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB0_2 Depth 2
	stz	__rc27
	ldx	#mos16lo(vs_nruns)
	stx	__rc4
	ldx	#mos16hi(vs_nruns)
	stx	__rc5
	rep	#32
	lda	__rc4
	sep	#32
	ldx	#0
	stx	__rc29
	clc
	rep	#32
	adc	__rc26
	sta	__rc4
	sep	#32
	lda	(__rc4)
	sta	__rc20
	rep	#32
	lda	__rc2
	eor	__rc20
	sta	__rc4
	sep	#32
	lda	__rc5
	cmp	#128
	rol	__rc4
	rol
	sty	__rc2
	ldx	__rc28
	stx	__rc3
	tax
	lda	__rc4
	sty	__rc27
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc29
	cpx	#1
	rep	#32
	adc	#13849
	sta	__rc2
	sep	#32
	stz	__rc25
	ldx	#mos16lo(vs_pfxsum)
	stx	__rc4
	ldx	#mos16hi(vs_pfxsum)
	stx	__rc5
	rep	#32
	lda	__rc4
	sep	#32
	ldx	__rc29
	cpx	#1
	rep	#32
	adc	__rc24
	sta	__rc4
	lda	(__rc4)
	sta	__rc4
	lda	__rc2
	eor	__rc4
	sta	__rc4
	sep	#32
	lda	__rc5
	cmp	#128
	rol	__rc4
	rol
	ldx	__rc27
	stx	__rc2
	ldx	__rc28
	stx	__rc3
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc29
	cpx	#1
	rep	#32
	adc	#13849
	sta	__rc2
	sep	#32
	stz	__rc20
.LBB0_2:                                ;   Parent Loop BB0_1 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	rep	#32
	lda	__rc22
	sep	#32
	ldx	#0
	stx	__rc25
	clc
	rep	#32
	adc	__rc20
	sta	__rc4
	sep	#32
	lda	(__rc4)
	sta	__rc4
	stz	__rc5
	rep	#32
	lda	__rc2
	eor	__rc4
	sta	__rc4
	sep	#32
	lda	__rc5
	cmp	#128
	rol	__rc4
	rol
	inc	__rc20
	ldx	__rc27
	stx	__rc2
	ldx	__rc28
	stx	__rc3
	tax
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc25
	cpx	#1
	rep	#32
	adc	#13849
	sta	__rc2
	sep	#32
	ldx	__rc20
	cpx	#64
	beq	.LBB0_3
; %bb.6:                                ;   in Loop: Header=BB0_2 Depth=2
	jmp	.LBB0_2
.LBB0_3:                                ;   in Loop: Header=BB0_1 Depth=1
	ldx	#98
	stx	__rc28
	ldx	__rc26
	inx
	rep	#32
	lda	__rc22
	clc
	adc	#mos16(64)
	sta	__rc22
	sep	#32
	inc	__rc24
	inc	__rc24
	stx	__rc26
	ldy	__rc27
	cpx	#24
	beq	.LBB0_4
; %bb.8:                                ;   in Loop: Header=BB0_1 Depth=1
	jmp	.LBB0_1
.LBB0_4:
	rep	#32
	lda	__rc2
	sta	corpus_result
	sep	#32
.LBB0_5:                                ; =>This Inner Loop Header: Depth=1
	;APP
	wai
	;NO_APP
	bra	.LBB0_5
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
                                        ; -- End function
	.section	.text.vs_build,"ax",@progbits
	.type	vs_build,@function              ; -- Begin function vs_build
vs_build:                               ; @vs_build
; %bb.0:
	ldx	__rc20
	phx
	ldx	__rc21
	phx
	ldx	__rc22
	phx
	ldx	__rc23
	phx
	ldx	__rc24
	stx	.Lvs_build_sstk+10              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lvs_build_sstk+11              ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lvs_build_sstk+12              ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lvs_build_sstk+13              ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lvs_build_sstk+14              ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lvs_build_sstk+15              ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lvs_build_sstk+16              ; 1-byte Folded Spill
	stz	__rc29
	ldx	#47
	ldy	#27
	lda	#85
	sta	__rc24
	lda	#98
	sta	__rc25
	lda	#0
	stz	__rc22
	sty	__rc4
	stx	__rc5
	stz	__rc8
	stz	__rc9
	tax
	stz	__rc2
	stz	__rc3
; %bb.15:
	jmp	.LBB1_13
.LBB1_1:                                ;   in Loop: Header=BB1_9 Depth=2
	sep	#32
	ldx	__rc6
	stx	__rc20
	ldx	__rc7
	stx	__rc21
	ldy	__rc2
.LBB1_2:                                ;   in Loop: Header=BB1_9 Depth=2
	ldx	__rc23
	stx	__rc28
	ldx	.Lvs_build_sstk                 ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lvs_build_sstk+1               ; 1-byte Folded Reload
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	#0
	clc
	rep	#32
	adc	__rc28
	sta	__rc2
	sep	#32
	tya
	sta	(__rc2)
	rep	#32
	lda	__rc30
	clc
	adc	__rc28
	sta	__rc2
	sep	#32
	lda	__rc4
	lsr
	lsr
	lsr
	lsr
	lsr
	and	#3
	tax
	lda	__rc22
	and	#12
	sta	__rc6
	txa
	ora	__rc6
	sta	(__rc2)
	rep	#32
	lda	__rc20
	cmp	#mos16(64)
	sep	#32
	ldx	#1
	bcs	.LBB1_4
; %bb.3:                                ;   in Loop: Header=BB1_9 Depth=2
	ldx	#0
.LBB1_4:                                ;   in Loop: Header=BB1_9 Depth=2
	stx	__rc2
	ldx	#0
	ldy	__rc8
	cpy	#15
	bcs	.LBB1_6
; %bb.5:                                ;   in Loop: Header=BB1_9 Depth=2
	ldx	#1
.LBB1_6:                                ;   in Loop: Header=BB1_9 Depth=2
	lda	__rc2
	beq	.LBB1_8
; %bb.7:                                ;   in Loop: Header=BB1_9 Depth=2
	ldx	#0
.LBB1_8:                                ;   in Loop: Header=BB1_9 Depth=2
	iny
	inc	__rc23
	inc	__rc23
	clc
	lda	__rc22
	adc	#4
	sta	__rc22
	sty	__rc27
	txa
	bne	.LBB1_9
; %bb.21:                               ;   in Loop: Header=BB1_13 Depth=1
	jmp	.LBB1_12
.LBB1_9:                                ;   Parent Loop BB1_13 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	ldx	__rc24
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	__rc5
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	clc
	adc	#13849
	sta	__rc4
	sep	#32
	ldx	__rc27
	stx	__rc8
	cpx	#15
	beq	.LBB1_11
; %bb.10:                               ;   in Loop: Header=BB1_9 Depth=2
	ldx	__rc5
	stx	__rc28
	rep	#32
	lda	__rc28
	lsr
	and	#mos16(7)
	sep	#32
	ldx	#0
	clc
	rep	#32
	adc	#mos16(2)
	sta	__rc2
	clc
	adc	__rc20
	sta	__rc6
	cmp	#mos16(65)
	bcs	.LBB1_11
; %bb.23:                               ;   in Loop: Header=BB1_9 Depth=2
	jmp	.LBB1_1
.LBB1_11:                               ;   in Loop: Header=BB1_9 Depth=2
	sep	#32
	ldx	#64
	txa
	sec
	sbc	__rc20
	tay
	stz	__rc21
	stx	__rc20
; %bb.17:                               ;   in Loop: Header=BB1_9 Depth=2
	jmp	.LBB1_2
.LBB1_12:                               ;   in Loop: Header=BB1_13 Depth=1
	ldx	__rc23
	stx	__rc28
	ldx	.Lvs_build_sstk+4               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lvs_build_sstk+5               ; 1-byte Folded Reload
	stx	__rc3
	lda	__rc2
	sta	__rc6
	stx	__rc7
	rep	#32
	lda	__rc2
	sep	#32
	ldx	#0
	stx	__rc8
	clc
	rep	#32
	adc	__rc28
	inc
	sta	__rc2
	sep	#32
	ldx	__rc2
	stx	.Lvs_build_sstk                 ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_build_sstk+1               ; 1-byte Folded Spill
	rep	#16
	ldx	__rc6
	tya
	sta	vs_rle,x
	sep	#16
	sty	__rc28
	ldx	.Lvs_build_sstk+2               ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lvs_build_sstk+3               ; 1-byte Folded Reload
	stx	__rc3
	ldy	__rc2
	sty	__rc6
	stx	__rc7
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc8
	cpx	#1
	rep	#32
	adc	__rc28
	sta	__rc2
	sep	#32
	ldx	.Lvs_build_sstk+9               ; 1-byte Folded Reload
	inx
	ldy	.Lvs_build_sstk+6               ; 1-byte Folded Reload
	sty	__rc8
	ldy	.Lvs_build_sstk+7               ; 1-byte Folded Reload
	ldy	__rc8
	sty	__rc22
	inc	__rc22
	inc	__rc22
	clc
	lda	.Lvs_build_sstk+8               ; 1-byte Folded Reload
	adc	#4
	ldy	.Lvs_build_sstk                 ; 1-byte Folded Reload
	sty	__rc8
	ldy	.Lvs_build_sstk+1               ; 1-byte Folded Reload
	ldy	.Lvs_build_sstk                 ; 1-byte Folded Reload
	ldy	.Lvs_build_sstk+1               ; 1-byte Folded Reload
	sty	__rc9
	cpx	#24
	bne	.LBB1_13
; %bb.25:
	jmp	.LBB1_14
.LBB1_13:                               ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB1_9 Depth 2
	stx	.Lvs_build_sstk+9               ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lvs_build_sstk+2               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_build_sstk+3               ; 1-byte Folded Spill
	stz	__rc23
	ldx	#mos16lo(vs_rowoff)
	stx	__rc2
	ldx	#mos16hi(vs_rowoff)
	stx	__rc3
	tay
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc22
	stx	__rc2
                                        ; kill: def $rs1 killed $rs1
	ldx	__rc2
	stx	.Lvs_build_sstk+6               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_build_sstk+7               ; 1-byte Folded Spill
	ldx	#0
	stx	__rc6
	clc
	rep	#32
	adc	__rc22
	sta	__rc2
	lda	__rc8
	sta	(__rc2)
	sep	#32
	ldx	#mos16lo(vs_rle+1)
	stx	__rc2
	ldx	#mos16hi(vs_rle+1)
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc6
	cpx	#1
	rep	#32
	adc	__rc8
	sta	__rc2
	sep	#32
	ldx	__rc2
	stx	.Lvs_build_sstk                 ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_build_sstk+1               ; 1-byte Folded Spill
	ldx	#mos16lo(vs_rle+2)
	stx	__rc2
	ldx	#mos16hi(vs_rle+2)
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc8
	stx	__rc2
	ldx	__rc9
	stx	__rc3
	ldx	__rc2
	stx	.Lvs_build_sstk+4               ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_build_sstk+5               ; 1-byte Folded Spill
	ldx	__rc6
	cpx	#1
	rep	#32
	adc	__rc8
	sta	__rc30
	sep	#32
	sty	.Lvs_build_sstk+8               ; 1-byte Folded Spill
	sty	__rc22
	stz	__rc20
	stz	__rc21
	stz	__rc27
; %bb.19:                               ;   in Loop: Header=BB1_13 Depth=1
	jmp	.LBB1_9
.LBB1_14:
	stz	__rc3
	ldx	__rc27
	stx	__rc2
	rep	#32
	lda	__rc6
	clc
	adc	__rc2
	sta	vs_totalruns
	sep	#32
	ldx	.Lvs_build_sstk+16              ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lvs_build_sstk+15              ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lvs_build_sstk+14              ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lvs_build_sstk+13              ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lvs_build_sstk+12              ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lvs_build_sstk+11              ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lvs_build_sstk+10              ; 1-byte Folded Reload
	stx	__rc24
	plx
	stx	__rc23
	plx
	stx	__rc22
	plx
	stx	__rc21
	plx
	stx	__rc20
	rts
.Lfunc_end1:
	.size	vs_build, .Lfunc_end1-vs_build
                                        ; -- End function
	.section	.text.vs_decode,"ax",@progbits
	.type	vs_decode,@function             ; -- Begin function vs_decode
vs_decode:                              ; @vs_decode
; %bb.0:
	ldx	__rc20
	phx
	ldx	__rc21
	phx
	ldx	__rc22
	phx
	ldx	__rc23
	phx
	ldx	__rc24
	stx	.Lvs_decode_sstk+11             ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lvs_decode_sstk+12             ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lvs_decode_sstk+13             ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lvs_decode_sstk+14             ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lvs_decode_sstk+15             ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lvs_decode_sstk+16             ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lvs_decode_sstk+17             ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lvs_decode_sstk+18             ; 1-byte Folded Spill
	ldx	__rc0
	stx	__rc30
	ldx	__rc1
	stx	__rc31
	stz	__rc23
	ldx	#64
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	__rc2
	stx	.Lvs_decode_sstk+9              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_decode_sstk+10             ; 1-byte Folded Spill
	stz	__rc20
	stz	__rc24
; %bb.23:
	jmp	.LBB2_16
.LBB2_1:                                ;   in Loop: Header=BB2_7 Depth=2
	sep	#32
	ldx	#1
	rep	#32
.LBB2_2:                                ;   in Loop: Header=BB2_7 Depth=2
	clc
	lda	.Lvs_decode_sstk                ; 2-byte Folded Reload
	adc	#mos16(2)
	sep	#32
	txy
	bne	.LBB2_4
; %bb.3:                                ;   in Loop: Header=BB2_7 Depth=2
	ldx	#64
	stz	__rc21
	stx	__rc20
.LBB2_4:                                ;   in Loop: Header=BB2_7 Depth=2
	rep	#32
	sta	__rc10
	lda	__rc4
	cmp	__rc20
	bcc	.LBB2_5
; %bb.29:                               ;   in Loop: Header=BB2_7 Depth=2
	jmp	.LBB2_6
.LBB2_5:                                ;   in Loop: Header=BB2_7 Depth=2
	sep	#32
	lda	(__rc10)
	tay
	rep	#32
	lda	__rc8
	clc
	adc	__rc4
	sta	__rc2
	lda	__rc20
	sec
	sbc	__rc4
	sta	__rc6
	sep	#32
	ldx	__rc7
	stx	__rc4
	ldx	__rc6
	tya
	ldy	__rc8
	sty	__rc26
	ldy	__rc9
	sty	__rc27
	ldy	__rc28
	sty	.Lvs_decode_sstk                ; 1-byte Folded Spill
	ldy	__rc29
	sty	.Lvs_decode_sstk+1              ; 1-byte Folded Spill
	ldy	__rc10
	sty	__rc28
	ldy	__rc11
	sty	__rc29
	jsr	__memset
	ldx	__rc28
	stx	__rc10
	ldx	__rc29
	stx	__rc11
	ldx	.Lvs_decode_sstk                ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lvs_decode_sstk+1              ; 1-byte Folded Reload
	stx	__rc29
	ldx	__rc26
	stx	__rc8
	ldx	__rc27
	stx	__rc9
	ldx	__rc20
	stx	__rc4
	ldx	__rc21
	stx	__rc5
	rep	#32
.LBB2_6:                                ;   in Loop: Header=BB2_7 Depth=2
	lda	__rc24
	clc
	sep	#32
	ldx	#0
	rep	#32
	adc	#mos16(2)
	sta	__rc24
	sep	#32
	dec	__rc22
	beq	.LBB2_9
.LBB2_7:                                ;   Parent Loop BB2_16 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	rep	#32
	lda	__rc10
	sta	.Lvs_decode_sstk                ; 2-byte Folded Spill
	lda	(__rc24)
	sta	__rc20
	cmp	#mos16(64)
	bcs	.LBB2_8
; %bb.31:                               ;   in Loop: Header=BB2_7 Depth=2
	jmp	.LBB2_1
.LBB2_8:                                ;   in Loop: Header=BB2_7 Depth=2
	sep	#32
	ldx	#0
	rep	#32
; %bb.25:                               ;   in Loop: Header=BB2_7 Depth=2
	jmp	.LBB2_2
.LBB2_9:                                ;   in Loop: Header=BB2_16 Depth=1
	stx	__rc26
	rep	#32
	lda	__rc4
	cmp	#mos16(64)
	bcs	.LBB2_11
; %bb.10:                               ;   in Loop: Header=BB2_16 Depth=1
	lda	__rc8
	clc
	sep	#32
	stx	__rc26
	rep	#32
	adc	__rc4
	sta	__rc2
	sep	#32
	ldx	.Lvs_decode_sstk+9              ; 1-byte Folded Reload
	stx	__rc6
	ldx	.Lvs_decode_sstk+10             ; 1-byte Folded Reload
	stx	__rc7
	rep	#32
	lda	__rc6
	sec
	sbc	__rc4
	sta	__rc6
	sep	#32
	ldx	__rc7
	stx	__rc4
	ldx	__rc6
	lda	#0
	jsr	__memset
.LBB2_11:                               ;   in Loop: Header=BB2_16 Depth=1
	sep	#32
	ldx	#158
	ldy	#55
	sty	__rc2
	stx	__rc3
	ldx	#85
	stx	__rc20
	ldx	#98
	stx	__rc21
	ldx	.Lvs_decode_sstk+6              ; 1-byte Folded Reload
	stx	__rc24
	ldx	.Lvs_decode_sstk+7              ; 1-byte Folded Reload
	ldx	.Lvs_decode_sstk+2              ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lvs_decode_sstk+3              ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc4
	stx	.Lvs_decode_sstk+2              ; 1-byte Folded Spill
	ldx	__rc5
	stx	.Lvs_decode_sstk+3              ; 1-byte Folded Spill
	ldx	.Lvs_decode_sstk+8              ; 1-byte Folded Reload
	stx	__rc22
.LBB2_12:                               ;   Parent Loop BB2_16 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	rep	#32
	lda	(__rc28)
	eor	__rc2
	sta	__rc4
	sep	#32
	ldx	__rc20
	stx	__rc2
	ldx	__rc21
	stx	__rc3
	ldx	__rc5
	lda	__rc4
	jsr	__mulhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc26
	cpx	#1
	rep	#32
	adc	#13849
	sta	__rc2
	lda	__rc28
	sep	#32
	ldx	__rc26
	cpx	#1
	rep	#32
	adc	#mos16(2)
	sta	__rc28
	sep	#32
	dec	__rc22
	bne	.LBB2_12
; %bb.13:                               ;   in Loop: Header=BB2_16 Depth=1
	ldx	.Lvs_decode_sstk+4              ; 1-byte Folded Reload
	stx	__rc20
	ldx	.Lvs_decode_sstk+5              ; 1-byte Folded Reload
	stx	__rc21
	ldx	.Lvs_decode_sstk+2              ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lvs_decode_sstk+3              ; 1-byte Folded Reload
	stx	__rc5
	ldy	__rc4
	sty	__rc26
	stx	__rc27
	bra	.LBB2_15
.LBB2_14:                               ;   in Loop: Header=BB2_16 Depth=1
	ldx	__rc8
	stx	__rc2
	ldx	__rc9
	stx	__rc3
	stz	__rc4
	ldx	#64
	lda	#0
	jsr	__memset
	ldx	#158
	ldy	#55
	sty	__rc2
	stx	__rc3
.LBB2_15:                               ;   in Loop: Header=BB2_16 Depth=1
	ldx	#mos16lo(vs_pfxsum)
	stx	__rc4
	ldx	#mos16hi(vs_pfxsum)
	stx	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc20
	sta	__rc4
	lda	__rc2
	sta	(__rc4)
	sep	#32
	ldx	__rc26
	stx	__rc0
	ldx	__rc27
	stx	__rc1
	ldx	__rc24
	inx
	ldy	__rc20
	iny
	iny
	sty	__rc20
	stx	__rc24
	cpx	#24
	bne	.LBB2_16
; %bb.33:
	jmp	.LBB2_22
.LBB2_16:                               ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB2_20 Depth 2
                                        ;     Child Loop BB2_7 Depth 2
                                        ;     Child Loop BB2_12 Depth 2
	stz	__rc25
	rep	#32
	lda	__rc24
	asl
	asl
	asl
	asl
	asl
	asl
	sta	__rc2
	sep	#32
	ldx	#mos16lo(vs_img)
	stx	__rc4
	ldx	#mos16hi(vs_img)
	stx	__rc5
	rep	#32
	lda	__rc4
	sep	#32
	ldx	#0
	stx	__rc6
	clc
	rep	#32
	adc	__rc2
	sta	__rc8
	sep	#32
	stz	__rc21
	ldx	#mos16lo(vs_rowoff)
	stx	__rc2
	ldx	#mos16hi(vs_rowoff)
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	__rc6
	cpx	#1
	rep	#32
	adc	__rc20
	sta	__rc2
	lda	(__rc2)
	sta	__rc2
	sep	#32
	ldx	#mos16lo(vs_rle)
	stx	__rc4
	ldx	#mos16hi(vs_rle)
	stx	__rc5
	rep	#32
	lda	__rc4
	sep	#32
	ldx	__rc6
	cpx	#1
	rep	#32
	adc	__rc2
	sta	.Lvs_decode_sstk                ; 2-byte Folded Spill
	sep	#32
	rep	#16
	ldx	__rc2
	sep	#16
	ldy	#mos16lo(vs_nruns)
	sty	__rc2
	ldy	#mos16hi(vs_nruns)
	sty	__rc3
	rep	#16
	ldx	__rc2
	lda	vs_rle,x
	sep	#16
	tax
	rep	#32
	lda	__rc2
	sep	#32
	ldy	#0
	ldy	__rc6
	cpy	#1
	rep	#32
	adc	__rc24
	sta	__rc2
	sep	#32
	txa
	stx	__rc22
	sta	(__rc2)
	rep	#32
	lda	__rc22
	asl
	sta	__rc2
	lda	__rc0
	sec
	sbc	__rc2
	sta	__rc28
	sep	#32
	ldy	__rc0
	sty	__rc26
	ldy	__rc1
	sty	__rc27
	ldy	__rc28
	sty	__rc0
	ldy	__rc29
	sty	__rc1
	txa
	bne	.LBB2_17
; %bb.35:                               ;   in Loop: Header=BB2_16 Depth=1
	jmp	.LBB2_14
.LBB2_17:                               ;   in Loop: Header=BB2_16 Depth=1
	stx	__rc5
	ldx	__rc26
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	__rc2
	stx	.Lvs_decode_sstk+2              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lvs_decode_sstk+3              ; 1-byte Folded Spill
                                        ; kill: def $rs12 killed $rs12
	ldx	__rc24
	stx	.Lvs_decode_sstk+6              ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lvs_decode_sstk+7              ; 1-byte Folded Spill
	ldx	__rc20
	stx	.Lvs_decode_sstk+4              ; 1-byte Folded Spill
	ldx	#0
	stx	.Lvs_decode_sstk+5              ; 1-byte Folded Spill
	rep	#32
	lda	.Lvs_decode_sstk                ; 2-byte Folded Reload
	sta	__rc10
	sep	#32
	ldx	__rc10
	stx	__rc2
	ldx	__rc11
	stx	__rc3
	inc	__rc2
	bne	.LBB2_19
; %bb.18:                               ;   in Loop: Header=BB2_16 Depth=1
	inc	__rc3
.LBB2_19:                               ;   in Loop: Header=BB2_16 Depth=1
	stz	__rc4
	ldx	__rc5
	stx	.Lvs_decode_sstk+8              ; 1-byte Folded Spill
	ldy	__rc28
	sty	__rc6
	ldy	__rc29
	sty	__rc7
	stz	__rc5
.LBB2_20:                               ;   Parent Loop BB2_16 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	lda	(__rc2)
	sta	__rc22
	rep	#32
	lda	__rc4
	clc
	adc	__rc22
	sta	__rc4
	sta	(__rc6)
	lda	__rc2
	clc
	adc	#mos16(2)
	sta	__rc2
	lda	__rc6
	clc
	adc	#mos16(2)
	sta	__rc6
	sep	#32
	dex
	bne	.LBB2_20
; %bb.21:                               ;   in Loop: Header=BB2_16 Depth=1
	stz	__rc4
	ldx	.Lvs_decode_sstk+8              ; 1-byte Folded Reload
	stx	__rc22
	ldx	__rc28
	stx	__rc24
	ldx	__rc29
	stx	__rc25
	stz	__rc5
; %bb.27:                               ;   in Loop: Header=BB2_16 Depth=1
	jmp	.LBB2_7
.LBB2_22:
	ldx	__rc30
	stx	__rc0
	ldx	__rc31
	stx	__rc1
	ldx	.Lvs_decode_sstk+18             ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lvs_decode_sstk+17             ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lvs_decode_sstk+16             ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lvs_decode_sstk+15             ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lvs_decode_sstk+14             ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lvs_decode_sstk+13             ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lvs_decode_sstk+12             ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lvs_decode_sstk+11             ; 1-byte Folded Reload
	stx	__rc24
	plx
	stx	__rc23
	plx
	stx	__rc22
	plx
	stx	__rc21
	plx
	stx	__rc20
	rts
.Lfunc_end2:
	.size	vs_decode, .Lfunc_end2-vs_decode
                                        ; -- End function
	.type	corpus_result,@object           ; @corpus_result
	.section	.bss.corpus_result,"aw",@nobits
	.globl	corpus_result
corpus_result:
	.short	0                               ; 0x0
	.size	corpus_result, 2

	.type	vs_totalruns,@object            ; @vs_totalruns
	.section	.bss.vs_totalruns,"aw",@nobits
vs_totalruns:
	.short	0                               ; 0x0
	.size	vs_totalruns, 2

	.type	vs_nruns,@object                ; @vs_nruns
	.section	.bss.vs_nruns,"aw",@nobits
vs_nruns:
	.zero	24
	.size	vs_nruns, 24

	.type	vs_pfxsum,@object               ; @vs_pfxsum
	.section	.bss.vs_pfxsum,"aw",@nobits
vs_pfxsum:
	.zero	48
	.size	vs_pfxsum, 48

	.type	vs_img,@object                  ; @vs_img
	.section	.bss.vs_img,"aw",@nobits
vs_img:
	.zero	1536
	.size	vs_img, 1536

	.type	vs_rowoff,@object               ; @vs_rowoff
	.section	.bss.vs_rowoff,"aw",@nobits
vs_rowoff:
	.zero	48
	.size	vs_rowoff, 48

	.type	vs_rle,@object                  ; @vs_rle
	.section	.bss.vs_rle,"aw",@nobits
vs_rle:
	.zero	792
	.size	vs_rle, 792

	.type	.Lstatic_stack,@object          ; @static_stack
	.section	.noinit..Lstatic_stack,"aw",@nobits
.Lstatic_stack:
	.zero	19
	.size	.Lstatic_stack, 19

.Lvs_build_sstk = .Lstatic_stack
	.size	.Lvs_build_sstk, 17
.Lvs_decode_sstk = .Lstatic_stack
	.size	.Lvs_decode_sstk, 19
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym corpus_result
	.addrsig_sym .Lstatic_stack
	;Declaring this symbol tells the CRT that there is something in .bss, so it may need to be zeroed.
	.globl	__do_zero_bss
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

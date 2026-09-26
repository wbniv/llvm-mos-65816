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
	.file	"rcundef.c"
	.text
	.globl	newton_step                     ; -- Begin function newton_step
	.type	newton_step,@function
newton_step:                            ; @newton_step
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
	stx	.Lnewton_step_sstk+27           ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lnewton_step_sstk+28           ; 1-byte Folded Spill
	ldx	__rc26
	stx	.Lnewton_step_sstk+29           ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lnewton_step_sstk+30           ; 1-byte Folded Spill
	ldx	__rc28
	stx	.Lnewton_step_sstk+31           ; 1-byte Folded Spill
	ldx	__rc29
	stx	.Lnewton_step_sstk+32           ; 1-byte Folded Spill
	ldx	__rc30
	stx	.Lnewton_step_sstk+33           ; 1-byte Folded Spill
	ldx	__rc31
	stx	.Lnewton_step_sstk+34           ; 1-byte Folded Spill
	ldy	#1
	lda	(__rc2),y
	sta	.Lnewton_step_sstk              ; 1-byte Folded Spill
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	bpl	.LBB0_2
; %bb.1:
	ldx	#255
	bra	.LBB0_3
.LBB0_2:
	ldx	#0
.LBB0_3:
	stx	.Lnewton_step_sstk+4            ; 1-byte Folded Spill
	lda	(__rc2)
	sta	.Lnewton_step_sstk+3            ; 1-byte Folded Spill
	lda	(__rc4)
	sta	.Lnewton_step_sstk+2            ; 1-byte Folded Spill
	lda	(__rc4),y
	sta	.Lnewton_step_sstk+1            ; 1-byte Folded Spill
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	bpl	.LBB0_5
; %bb.4:
	ldx	__rc2
	stx	.Lnewton_step_sstk+8            ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+9            ; 1-byte Folded Spill
	ldx	__rc4
	stx	.Lnewton_step_sstk+6            ; 1-byte Folded Spill
	ldx	__rc5
	stx	.Lnewton_step_sstk+7            ; 1-byte Folded Spill
	ldx	#255
	stx	__rc24
	bra	.LBB0_6
.LBB0_5:
	ldx	__rc2
	stx	.Lnewton_step_sstk+8            ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+9            ; 1-byte Folded Spill
	ldx	__rc4
	stx	.Lnewton_step_sstk+6            ; 1-byte Folded Spill
	ldx	__rc5
	stx	.Lnewton_step_sstk+7            ; 1-byte Folded Spill
	stz	__rc24
.LBB0_6:
	clc
	ldx	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	stx	__rc3
	stx	__rc2
	lda	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	sta	__rc9
	adc	__rc2
	sta	__rc4
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc10
	stx	__rc2
	ldy	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	tya
	adc	__rc2
	sta	__rc5
	lda	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	sta	__rc8
	sta	__rc2
	lda	__rc24
	adc	__rc2
	sta	__rc6
	lda	__rc24
	adc	__rc2
	sta	__rc7
	sec
	lda	__rc3
	sbc	__rc9
	tax
	sty	__rc2
	lda	__rc10
	sbc	__rc2
	sta	__rc2
	lda	__rc8
	sbc	__rc24
	sta	__rc3
	ldy	#0
	sty	.Lnewton_step_sstk+11           ; 1-byte Folded Spill
	tya
	jsr	__mulsi3
	ldx	__rc2
	stx	__rc31
	ldx	__rc3
	stx	__rc26
	bpl	.LBB0_8
; %bb.7:
	ldx	#255
	stx	.Lnewton_step_sstk+11           ; 1-byte Folded Spill
.LBB0_8:
	lda	__rc3
	asl
	ldx	#1
	bcs	.LBB0_10
; %bb.9:
	ldx	#0
.LBB0_10:
	stx	.Lnewton_step_sstk+16           ; 1-byte Folded Spill
	lda	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	asl
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc2
	rol	__rc2
	ldx	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	stx	__rc3
	rol	__rc3
	ldx	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc24
	stx	__rc7
	tax
	ldy	#0
	sty	.Lnewton_step_sstk+12           ; 1-byte Folded Spill
	tya
	jsr	__mulsi3
	ldx	__rc2
	stx	__rc27
	ldx	__rc3
	stx	__rc28
	bpl	.LBB0_12
; %bb.11:
	ldx	#255
	stx	.Lnewton_step_sstk+12           ; 1-byte Folded Spill
.LBB0_12:
	lda	__rc3
	asl
	ldx	#1
	bcs	.LBB0_14
; %bb.13:
	ldx	#0
.LBB0_14:
	stx	.Lnewton_step_sstk+17           ; 1-byte Folded Spill
	lda	__rc31
	asl
	ldx	__rc26
	stx	__rc2
	rol	__rc2
	ldx	#0
	stx	__rc3
	clc
	adc	__rc31
	sta	__rc30
	lda	__rc2
	adc	__rc26
	tax
	lda	__rc27
	asl
	ldy	__rc28
	sty	__rc4
	rol	__rc4
	ldy	__rc3
	cpy	#1
	adc	__rc27
	sta	__rc2
	lda	__rc4
	adc	__rc28
	sta	__rc3
	txa
	cpx	#128
	ror
	ldx	#1
	bcs	.LBB0_16
; %bb.15:
	ldx	#0
.LBB0_16:
	stx	__rc4
	sta	__rc25
	tax
	bpl	.LBB0_18
; %bb.17:
	ldx	#255
	bra	.LBB0_19
.LBB0_18:
	ldx	#0
.LBB0_19:
	ldy	__rc4
	cpy	#1
	ror	__rc30
	lda	__rc3
	cmp	#128
	ror
	tay
	lda	__rc2
	ror
	sta	.Lnewton_step_sstk+10           ; 1-byte Folded Spill
	sty	.Lnewton_step_sstk+5            ; 1-byte Folded Spill
	tya
	bpl	.LBB0_21
; %bb.20:
	ldy	#255
	sty	__rc20
	bra	.LBB0_22
.LBB0_21:
	stz	__rc20
.LBB0_22:
	stx	__rc2
	stx	__rc3
	ldy	__rc30
	sty	__rc4
	ldy	__rc25
	sty	__rc5
	stx	__rc6
	stx	__rc7
	ldx	__rc25
	lda	__rc30
	jsr	__mulsi3
	sta	__rc21
	stx	__rc29
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc22
	ldy	__rc20
	sty	__rc2
	sty	__rc3
	ldx	.Lnewton_step_sstk+10           ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+5            ; 1-byte Folded Reload
	stx	__rc20
	stx	__rc5
	sty	__rc6
	sty	__rc7
	lda	__rc4
	jsr	__mulsi3
	sta	__rc4
	txy
	clc
	lda	__rc21
	adc	__rc4
	tax
	tya
	adc	__rc29
	sta	__rc4
	lda	__rc23
	adc	__rc2
	sta	__rc2
	lda	__rc22
	adc	__rc3
	tay
	txa
	stx	.Lnewton_step_sstk+13           ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc3
	ldx	__rc2
	stx	.Lnewton_step_sstk+14           ; 1-byte Folded Spill
	sty	.Lnewton_step_sstk+15           ; 1-byte Folded Spill
	tyx
	bne	.LBB0_26
; %bb.23:
	ldx	__rc3
	bne	.LBB0_26
; %bb.24:
	ldx	__rc4
	bne	.LBB0_26
; %bb.25:
	tax
	bne	.LBB0_26
; %bb.52:
	jmp	.LBB0_51
.LBB0_26:
	ldx	__rc4
	stx	.Lnewton_step_sstk+19           ; 1-byte Folded Spill
	ldx	#255
	stx	.Lnewton_step_sstk+18           ; 1-byte Folded Spill
	txy
	lda	__rc20
	bmi	.LBB0_28
; %bb.27:
	ldy	#0
.LBB0_28:
	sty	.Lnewton_step_sstk+20           ; 1-byte Folded Spill
	lda	.Lnewton_step_sstk+11           ; 1-byte Folded Reload
	ldx	.Lnewton_step_sstk+16           ; 1-byte Folded Reload
	cpx	#1
	rol
	ldx	.Lnewton_step_sstk+12           ; 1-byte Folded Reload
	stx	__rc21
	ldx	.Lnewton_step_sstk+17           ; 1-byte Folded Reload
	cpx	#1
	rol	__rc21
	ldx	#255
	ldy	__rc25
	bmi	.LBB0_30
; %bb.29:
	ldx	#0
.LBB0_30:
	stx	.Lnewton_step_sstk+11           ; 1-byte Folded Spill
	sta	__rc2
	sta	__rc20
	sta	__rc3
	ldx	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc24
	stx	__rc7
	ldx	__rc26
	lda	__rc31
	jsr	__mulsi3
	sta	__rc23
	stx	__rc29
	ldx	__rc2
	stx	__rc22
	ldx	__rc21
	stx	__rc2
	stx	__rc3
	ldx	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	stx	__rc6
	stx	__rc7
	ldx	__rc28
	lda	__rc27
	jsr	__mulsi3
	sta	__rc3
	clc
	lda	__rc23
	adc	__rc3
	txa
	adc	__rc29
	sta	__rc23
	lda	__rc22
	adc	__rc2
	ldx	#255
	sta	__rc2
	tay
	bmi	.LBB0_32
; %bb.31:
	ldx	#0
.LBB0_32:
	asl
	txa
	rol
	cmp	#128
	sta	__rc29
	ror
	sta	.Lnewton_step_sstk+16           ; 1-byte Folded Spill
	ror	__rc29
	ror	__rc2
	ldx	__rc2
	stx	.Lnewton_step_sstk+12           ; 1-byte Folded Spill
	ror	__rc23
	ldx	__rc20
	stx	__rc2
	stx	__rc3
	ldx	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	stx	__rc6
	stx	__rc7
	ldx	__rc26
	lda	__rc31
	jsr	__mulsi3
	sta	__rc26
	stx	__rc20
	ldx	__rc2
	stx	__rc22
	ldx	__rc21
	stx	__rc2
	stx	__rc3
	ldx	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc24
	stx	__rc6
	ldx	__rc24
	stx	__rc7
	ldx	__rc28
	lda	__rc27
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	ldx	__rc26
	cpx	__rc3
	lda	__rc20
	sbc	__rc4
	tay
	lda	__rc22
	sbc	__rc2
	tax
	clc
	tya
	adc	#0
	sta	__rc8
	txa
	adc	#255
	cmp	#128
	ror
	tay
	ror	__rc8
	tax
	bmi	.LBB0_34
; %bb.33:
	ldx	#0
	stx	.Lnewton_step_sstk+18           ; 1-byte Folded Spill
.LBB0_34:
	ldx	.Lnewton_step_sstk+18           ; 1-byte Folded Reload
	stx	__rc31
	stx	__rc2
	stx	__rc3
	lda	__rc30
	sta	.Lnewton_step_sstk+25           ; 1-byte Folded Spill
	sta	__rc4
	lda	__rc25
	sta	.Lnewton_step_sstk+26           ; 1-byte Folded Spill
	sta	__rc5
	ldx	.Lnewton_step_sstk+11           ; 1-byte Folded Reload
	stx	__rc30
	stx	__rc6
	stx	__rc7
	tyx
	sty	.Lnewton_step_sstk+4            ; 1-byte Folded Spill
	ldy	__rc8
	sty	.Lnewton_step_sstk+17           ; 1-byte Folded Spill
	lda	__rc8
	jsr	__mulsi3
	sta	__rc21
	stx	__rc26
	ldx	__rc2
	stx	__rc27
	ldx	__rc29
	stx	__rc24
	ldx	__rc29
	stx	__rc2
	ldx	.Lnewton_step_sstk+16           ; 1-byte Folded Reload
	stx	__rc25
	stx	__rc3
	ldx	.Lnewton_step_sstk+10           ; 1-byte Folded Reload
	stx	__rc22
	stx	__rc4
	ldx	.Lnewton_step_sstk+5            ; 1-byte Folded Reload
	stx	.Lnewton_step_sstk+5            ; 1-byte Folded Spill
	stx	__rc5
	ldx	.Lnewton_step_sstk+20           ; 1-byte Folded Reload
	stx	__rc28
	stx	__rc6
	stx	__rc7
	ldx	.Lnewton_step_sstk+12           ; 1-byte Folded Reload
	stx	__rc29
	ldy	__rc23
	sty	__rc20
	lda	__rc23
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	clc
	lda	__rc21
	adc	__rc3
	tay
	lda	__rc26
	adc	__rc4
	tax
	lda	__rc27
	adc	__rc2
	stx	__rc2
	sta	__rc3
	ldx	.Lnewton_step_sstk+13           ; 1-byte Folded Reload
	stx	__rc21
	stx	__rc4
	ldx	.Lnewton_step_sstk+19           ; 1-byte Folded Reload
	stx	__rc27
	stx	__rc5
	ldx	.Lnewton_step_sstk+14           ; 1-byte Folded Reload
	stx	__rc23
	stx	__rc6
	ldx	.Lnewton_step_sstk+15           ; 1-byte Folded Reload
	stx	__rc26
	stx	__rc7
	tyx
	lda	#0
	jsr	__divsi3
	sta	.Lnewton_step_sstk+24           ; 1-byte Folded Spill
	stx	.Lnewton_step_sstk+23           ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lnewton_step_sstk+22           ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+21           ; 1-byte Folded Spill
	ldx	__rc24
	stx	__rc2
	ldx	.Lnewton_step_sstk+25           ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+26           ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc25
	stx	__rc3
	ldx	__rc30
	stx	__rc6
	ldx	__rc30
	stx	__rc7
	ldx	__rc29
	lda	__rc20
	jsr	__mulsi3
	sta	__rc20
	stx	__rc25
	ldx	__rc2
	stx	__rc24
	ldx	__rc22
	stx	__rc4
	ldx	.Lnewton_step_sstk+5            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc31
	stx	__rc2
	ldx	__rc31
	stx	__rc3
	ldx	__rc28
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	ldx	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	lda	.Lnewton_step_sstk+17           ; 1-byte Folded Reload
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	sec
	lda	__rc20
	sbc	__rc3
	tax
	lda	__rc25
	sbc	__rc4
	tay
	lda	__rc24
	sbc	__rc2
	sty	__rc2
	sta	__rc3
	ldy	__rc21
	sty	__rc4
	ldy	__rc27
	sty	__rc5
	ldy	__rc23
	sty	__rc6
	ldy	__rc26
	sty	__rc7
	lda	#0
	jsr	__divsi3
	tay
	stx	__rc5
	ldx	.Lnewton_step_sstk+24           ; 1-byte Folded Reload
	stx	__rc4
	cpx	#1
	lda	.Lnewton_step_sstk+23           ; 1-byte Folded Reload
	sta	__rc7
	sbc	#2
	lda	.Lnewton_step_sstk+22           ; 1-byte Folded Reload
	sta	__rc9
	sbc	#0
	lda	.Lnewton_step_sstk+21           ; 1-byte Folded Reload
	sta	__rc6
	sbc	#0
	bvc	.LBB0_36
; %bb.35:
	eor	#128
.LBB0_36:
	ldx	#2
	stz	__rc8
	cmp	#0
	bpl	.LBB0_41
; %bb.37:
	ldx	__rc4
	cpx	#0
	lda	__rc7
	sbc	#254
	lda	__rc9
	sbc	#255
	lda	__rc6
	sbc	#255
	bvc	.LBB0_39
; %bb.38:
	eor	#128
.LBB0_39:
	ldx	__rc4
	stx	__rc8
	tax
	bpl	.LBB0_42
; %bb.40:
	ldx	#254
	stz	__rc8
.LBB0_41:
	stx	__rc7
.LBB0_42:
	cpy	#1
	lda	__rc5
	sbc	#2
	lda	__rc2
	sbc	#0
	lda	__rc3
	sbc	#0
	bvc	.LBB0_44
; %bb.43:
	eor	#128
.LBB0_44:
	ldx	#2
	stz	__rc4
	cmp	#0
	bpl	.LBB0_49
; %bb.45:
	cpy	#0
	lda	__rc5
	sbc	#254
	lda	__rc2
	sbc	#255
	lda	__rc3
	sbc	#255
	bvc	.LBB0_47
; %bb.46:
	eor	#128
.LBB0_47:
	sty	__rc4
	tax
	bpl	.LBB0_50
; %bb.48:
	ldx	#254
	stz	__rc4
.LBB0_49:
	stx	__rc5
.LBB0_50:
	sec
	ldx	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	txa
	sbc	__rc8
	tay
	lda	.Lnewton_step_sstk              ; 1-byte Folded Reload
	sbc	__rc7
	sta	__rc6
	ldx	.Lnewton_step_sstk+8            ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lnewton_step_sstk+9            ; 1-byte Folded Reload
	stx	__rc3
	tya
	sta	(__rc2)
	ldy	#1
	lda	__rc6
	sta	(__rc2),y
	sec
	lda	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	sbc	__rc4
	ldx	.Lnewton_step_sstk+6            ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lnewton_step_sstk+7            ; 1-byte Folded Reload
	stx	__rc3
	sta	(__rc2)
	lda	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	sbc	__rc5
	sta	(__rc2),y
.LBB0_51:
	ldx	.Lnewton_step_sstk+34           ; 1-byte Folded Reload
	stx	__rc31
	ldx	.Lnewton_step_sstk+33           ; 1-byte Folded Reload
	stx	__rc30
	ldx	.Lnewton_step_sstk+32           ; 1-byte Folded Reload
	stx	__rc29
	ldx	.Lnewton_step_sstk+31           ; 1-byte Folded Reload
	stx	__rc28
	ldx	.Lnewton_step_sstk+30           ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Lnewton_step_sstk+29           ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lnewton_step_sstk+28           ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Lnewton_step_sstk+27           ; 1-byte Folded Reload
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
.Lfunc_end0:
	.size	newton_step, .Lfunc_end0-newton_step
                                        ; -- End function
	.type	.Lstatic_stack,@object          ; @static_stack
	.section	.noinit,"aw",@nobits
	.p2align	4, 0x0
.Lstatic_stack:
	.zero	35
	.size	.Lstatic_stack, 35

.Lnewton_step_sstk = .Lstatic_stack
	.size	.Lnewton_step_sstk, 35
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

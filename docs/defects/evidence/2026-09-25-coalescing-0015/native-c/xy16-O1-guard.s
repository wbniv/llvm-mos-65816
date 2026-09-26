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
	ldx	__rc4
	stx	__rc24
	ldx	__rc5
	stx	__rc25
	ldx	__rc2
	stx	__rc4
	ldx	__rc3
	stx	__rc5
	ldx	__rc4
	stx	.Lnewton_step_sstk+4            ; 1-byte Folded Spill
	ldx	__rc5
	stx	.Lnewton_step_sstk+5            ; 1-byte Folded Spill
	rep	#32
	lda	(__rc2)
	sta	__rc30
	eor	#32768
	cmp	#32768
	bcc	.LBB0_2
; %bb.1:
	sep	#32
	ldx	#0
	bra	.LBB0_3
.LBB0_2:
	sep	#32
	ldx	#255
.LBB0_3:
	stx	.Lnewton_step_sstk+8            ; 1-byte Folded Spill
	rep	#32
	lda	(__rc24)
	sta	__rc4
	sep	#32
	ldx	__rc4
	stx	__rc2
	ldx	__rc5
	stx	__rc3
	ldx	__rc2
	stx	.Lnewton_step_sstk              ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+1            ; 1-byte Folded Spill
	rep	#32
	eor	#32768
	cmp	#32768
	bcc	.LBB0_5
; %bb.4:
	sep	#32
	stz	__rc28
	bra	.LBB0_6
.LBB0_5:
	sep	#32
	ldx	#255
	stx	__rc28
.LBB0_6:
	clc
	lda	__rc30
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc3
	ldy	__rc2
	sty	__rc8
	stx	__rc9
	adc	__rc8
	sta	__rc4
	lda	__rc31
	adc	__rc9
	tay
	lda	.Lnewton_step_sstk+8            ; 1-byte Folded Reload
	sta	__rc3
	sta	__rc2
	lda	__rc28
	adc	__rc2
	sta	__rc6
	lda	__rc28
	adc	__rc2
	sta	__rc7
	sec
	lda	__rc30
	sbc	__rc8
	tax
	lda	__rc31
	sbc	__rc9
	sta	__rc2
	lda	__rc3
	sbc	__rc28
	stz	__rc21
	sta	__rc3
	sty	__rc5
	lda	#0
	jsr	__mulsi3
	ldx	__rc2
	stx	__rc23
	ldx	__rc3
	stx	__rc22
	bpl	.LBB0_8
; %bb.7:
	ldx	#255
	stx	__rc21
.LBB0_8:
	ldx	__rc3
	stx	__rc20
	rep	#32
	lda	__rc20
	asl
	sta	.Lnewton_step_sstk+14           ; 2-byte Folded Spill
	sep	#32
	lda	__rc30
	asl
	ldx	__rc31
	stx	__rc2
	rol	__rc2
	ldx	.Lnewton_step_sstk+8            ; 1-byte Folded Reload
	stx	__rc3
	rol	__rc3
	stz	__rc21
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	tax
	lda	#0
	jsr	__mulsi3
	ldy	__rc2
	ldx	__rc3
	stx	__rc29
	ldx	__rc30
	stx	__rc2
	ldx	__rc31
	stx	__rc3
	ldx	__rc2
	stx	.Lnewton_step_sstk+6            ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+7            ; 1-byte Folded Spill
	lda	__rc29
	bpl	.LBB0_10
; %bb.9:
	ldx	#255
	stx	__rc21
.LBB0_10:
	ldx	__rc29
	stx	__rc20
	rep	#32
	lda	__rc20
	sta	.Lnewton_step_sstk+10           ; 2-byte Folded Spill
	sep	#32
	ldx	__rc23
	stx	__rc2
	ldx	__rc22
	stx	__rc3
	rep	#32
	lda	__rc2
	asl
	clc
	adc	__rc2
	sta	__rc4
	sep	#32
	sty	__rc2
	ldx	__rc29
	stx	__rc3
	rep	#32
	lda	__rc2
	asl
	clc
	adc	__rc2
	sta	__rc2
	lda	__rc4
	cmp	#32768
	ror
	sta	__rc30
	eor	#32768
	cmp	#32768
	sep	#32
	ldx	#1
	bcs	.LBB0_12
; %bb.11:
	ldx	#0
.LBB0_12:
	stx	__rc4
	rep	#32
	lda	.Lnewton_step_sstk+10           ; 2-byte Folded Reload
	asl
	sta	.Lnewton_step_sstk+10           ; 2-byte Folded Spill
	sep	#32
	lda	__rc4
	beq	.LBB0_14
; %bb.13:
	sty	.Lnewton_step_sstk+17           ; 1-byte Folded Spill
	ldx	#0
	rep	#32
	bra	.LBB0_15
.LBB0_14:
	sty	.Lnewton_step_sstk+17           ; 1-byte Folded Spill
	ldx	#255
	rep	#32
.LBB0_15:
	lda	__rc2
	cmp	#32768
	ror
	sta	__rc20
	eor	#32768
	cmp	#32768
	sep	#32
	ldy	__rc23
	sty	.Lnewton_step_sstk+16           ; 1-byte Folded Spill
	bcc	.LBB0_17
; %bb.16:
	ldy	__rc24
	sty	.Lnewton_step_sstk+2            ; 1-byte Folded Spill
	ldy	__rc25
	sty	.Lnewton_step_sstk+3            ; 1-byte Folded Spill
	stz	__rc26
	bra	.LBB0_18
.LBB0_17:
	ldy	__rc24
	sty	.Lnewton_step_sstk+2            ; 1-byte Folded Spill
	ldy	__rc25
	sty	.Lnewton_step_sstk+3            ; 1-byte Folded Spill
	ldy	#255
	sty	__rc26
.LBB0_18:
	stx	__rc2
	stx	__rc3
	ldy	__rc30
	sty	__rc4
	ldy	__rc31
	sty	__rc5
	stx	__rc6
	stx	__rc7
	ldx	__rc31
	lda	__rc30
	jsr	__mulsi3
	sta	__rc27
	stx	__rc23
	ldx	__rc2
	stx	__rc25
	ldx	__rc3
	stx	__rc24
	ldx	__rc26
	stx	__rc2
	ldx	__rc26
	stx	__rc3
	ldx	__rc20
	stx	__rc4
	ldx	__rc21
	stx	__rc5
	ldx	__rc26
	stx	__rc6
	ldx	__rc26
	stx	__rc7
	ldx	__rc21
	lda	__rc20
	jsr	__mulsi3
	sta	__rc4
	txy
	clc
	lda	__rc27
	adc	__rc4
	tax
	tya
	adc	__rc23
	sta	__rc4
	lda	__rc25
	adc	__rc2
	sta	__rc2
	lda	__rc24
	adc	__rc3
	tay
	txa
	stx	.Lnewton_step_sstk+18           ; 1-byte Folded Spill
	ldx	__rc2
	stx	__rc3
	ldx	__rc2
	stx	.Lnewton_step_sstk+19           ; 1-byte Folded Spill
	sty	.Lnewton_step_sstk+20           ; 1-byte Folded Spill
	tyx
	bne	.LBB0_22
; %bb.19:
	ldx	__rc3
	bne	.LBB0_22
; %bb.20:
	ldx	__rc4
	bne	.LBB0_22
; %bb.21:
	tax
	bne	.LBB0_22
; %bb.50:
	jmp	.LBB0_49
.LBB0_22:
	ldx	__rc4
	stx	.Lnewton_step_sstk+21           ; 1-byte Folded Spill
	ldx	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Lnewton_step_sstk+5            ; 1-byte Folded Reload
	stx	__rc27
	ldx	__rc26
	stx	.Lnewton_step_sstk+4            ; 1-byte Folded Spill
	ldx	__rc27
	stx	.Lnewton_step_sstk+5            ; 1-byte Folded Spill
	ldx	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	stx	__rc24
	ldx	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	stx	__rc25
	ldx	__rc24
	stx	.Lnewton_step_sstk+2            ; 1-byte Folded Spill
	ldx	__rc25
	stx	.Lnewton_step_sstk+3            ; 1-byte Folded Spill
	rep	#32
	lda	__rc20
	eor	#32768
	cmp	#32768
	sep	#32
	ldx	#0
	bcs	.LBB0_24
; %bb.23:
	ldx	#1
.LBB0_24:
	ldy	__rc20
	sty	.Lnewton_step_sstk+12           ; 1-byte Folded Spill
	ldy	__rc21
	sty	.Lnewton_step_sstk+13           ; 1-byte Folded Spill
	rep	#32
	lda	.Lnewton_step_sstk+14           ; 2-byte Folded Reload
	sta	__rc26
	lda	.Lnewton_step_sstk+10           ; 2-byte Folded Reload
	sta	__rc24
	sep	#32
	ldy	#255
	sty	__rc20
	tya
	ldy	.Lnewton_step_sstk+16           ; 1-byte Folded Reload
	cpx	#0
	bne	.LBB0_26
; %bb.25:
	lda	#0
.LBB0_26:
	sta	.Lnewton_step_sstk+22           ; 1-byte Folded Spill
	ldx	__rc30
	stx	__rc2
	ldx	__rc31
	stx	__rc3
	ldx	__rc2
	stx	.Lnewton_step_sstk+10           ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+11           ; 1-byte Folded Spill
	rep	#32
	lda	__rc30
	eor	#32768
	cmp	#32768
	sep	#32
	ldx	#255
	stx	__rc30
	bcc	.LBB0_28
; %bb.27:
	stz	__rc30
.LBB0_28:
	ldx	__rc27
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	ldx	__rc22
	tya
	jsr	__mulsi3
	sta	__rc24
	stx	__rc23
	ldx	__rc2
	stx	__rc21
	ldx	__rc25
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	.Lnewton_step_sstk+6            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+7            ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lnewton_step_sstk+8            ; 1-byte Folded Reload
	stx	__rc6
	stx	__rc7
	ldx	__rc29
	lda	.Lnewton_step_sstk+17           ; 1-byte Folded Reload
	jsr	__mulsi3
	sta	__rc3
	clc
	lda	__rc24
	adc	__rc3
	txa
	adc	__rc23
	sta	__rc26
	lda	__rc21
	adc	__rc2
	ldx	#255
	sta	__rc31
	tay
	bmi	.LBB0_30
; %bb.29:
	ldx	#0
.LBB0_30:
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	asl
	sta	__rc2
	sep	#32
	lda	__rc3
	cmp	#128
	sta	__rc2
	ror	__rc2
	ldx	__rc2
	stx	.Lnewton_step_sstk+14           ; 1-byte Folded Spill
	ror
	sta	__rc24
	ror	__rc31
	ror	__rc26
	ldx	__rc27
	stx	__rc2
	ldx	__rc27
	stx	__rc3
	ldx	.Lnewton_step_sstk+6            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+7            ; 1-byte Folded Reload
	stx	__rc5
	ldx	.Lnewton_step_sstk+8            ; 1-byte Folded Reload
	stx	__rc6
	stx	__rc7
	ldx	__rc22
	lda	.Lnewton_step_sstk+16           ; 1-byte Folded Reload
	jsr	__mulsi3
	sta	__rc23
	stx	__rc22
	ldx	__rc2
	stx	__rc21
	ldx	__rc25
	stx	__rc2
	ldx	__rc25
	stx	__rc3
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldx	__rc28
	stx	__rc6
	ldx	__rc28
	stx	__rc7
	ldx	__rc29
	lda	.Lnewton_step_sstk+17           ; 1-byte Folded Reload
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	ldx	__rc23
	cpx	__rc3
	lda	__rc22
	sbc	__rc4
	tax
	lda	__rc21
	sbc	__rc2
	stx	__rc2
	sta	__rc3
	rep	#32
	lda	__rc2
	clc
	adc	#65280
	cmp	#32768
	ror
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcc	.LBB0_32
; %bb.31:
	sep	#32
	stz	__rc20
.LBB0_32:
	sep	#32
	ldx	__rc20
	stx	__rc23
	ldx	__rc20
	stx	__rc2
	ldx	__rc20
	stx	__rc3
	ldx	.Lnewton_step_sstk+10           ; 1-byte Folded Reload
	stx	__rc20
	ldx	.Lnewton_step_sstk+11           ; 1-byte Folded Reload
	stx	__rc21
	ldy	__rc20
	sty	__rc4
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc30
	stx	__rc7
	ldx	__rc9
	lda	__rc8
	ldy	__rc8
	sty	.Lnewton_step_sstk+8            ; 1-byte Folded Spill
	ldy	__rc9
	sty	.Lnewton_step_sstk+9            ; 1-byte Folded Spill
	jsr	__mulsi3
	sta	__rc22
	stx	__rc27
	ldx	__rc2
	stx	__rc28
	ldy	__rc24
	sty	.Lnewton_step_sstk+25           ; 1-byte Folded Spill
	sty	__rc2
	ldx	.Lnewton_step_sstk+14           ; 1-byte Folded Reload
	stx	__rc3
	stx	.Lnewton_step_sstk+14           ; 1-byte Folded Spill
	ldx	.Lnewton_step_sstk+12           ; 1-byte Folded Reload
	stx	__rc24
	ldx	.Lnewton_step_sstk+13           ; 1-byte Folded Reload
	stx	__rc25
	ldy	__rc24
	sty	__rc4
	stx	__rc5
	ldx	.Lnewton_step_sstk+22           ; 1-byte Folded Reload
	stx	__rc29
	stx	__rc6
	stx	__rc7
	ldx	__rc31
	ldy	__rc26
	sty	.Lnewton_step_sstk+26           ; 1-byte Folded Spill
	lda	__rc26
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	clc
	lda	__rc22
	adc	__rc3
	tay
	lda	__rc27
	adc	__rc4
	tax
	lda	__rc28
	adc	__rc2
	stx	__rc2
	sta	__rc3
	ldx	.Lnewton_step_sstk+18           ; 1-byte Folded Reload
	stx	__rc22
	stx	__rc4
	ldx	.Lnewton_step_sstk+21           ; 1-byte Folded Reload
	stx	__rc28
	stx	__rc5
	ldx	.Lnewton_step_sstk+19           ; 1-byte Folded Reload
	stx	__rc26
	stx	__rc6
	ldx	.Lnewton_step_sstk+20           ; 1-byte Folded Reload
	stx	__rc27
	stx	__rc7
	tyx
	lda	#0
	jsr	__divsi3
	sta	.Lnewton_step_sstk+24           ; 1-byte Folded Spill
	stx	.Lnewton_step_sstk+23           ; 1-byte Folded Spill
	ldx	__rc2
	stx	.Lnewton_step_sstk+17           ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Lnewton_step_sstk+16           ; 1-byte Folded Spill
	ldx	.Lnewton_step_sstk+25           ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lnewton_step_sstk+14           ; 1-byte Folded Reload
	stx	__rc3
	ldx	__rc20
	stx	__rc4
	ldx	__rc21
	stx	__rc5
	ldx	__rc30
	stx	__rc6
	ldx	__rc30
	stx	__rc7
	ldx	__rc31
	lda	.Lnewton_step_sstk+26           ; 1-byte Folded Reload
	jsr	__mulsi3
	sta	__rc20
	stx	__rc30
	ldx	__rc2
	stx	__rc21
	ldx	__rc23
	stx	__rc2
	ldx	__rc23
	stx	__rc3
	ldx	__rc24
	stx	__rc4
	ldx	__rc25
	stx	__rc5
	ldx	__rc29
	stx	__rc6
	ldx	__rc29
	stx	__rc7
	ldx	.Lnewton_step_sstk+8            ; 1-byte Folded Reload
	stx	__rc8
	ldx	.Lnewton_step_sstk+9            ; 1-byte Folded Reload
	lda	__rc8
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	sec
	lda	__rc20
	sbc	__rc3
	tax
	lda	__rc30
	sbc	__rc4
	tay
	lda	__rc21
	sbc	__rc2
	sty	__rc2
	sta	__rc3
	ldy	__rc22
	sty	__rc4
	ldy	__rc28
	sty	__rc5
	ldy	__rc26
	sty	__rc6
	ldy	__rc27
	sty	__rc7
	lda	#0
	jsr	__divsi3
	sta	__rc12
	ldy	__rc2
	sty	__rc14
	ldy	__rc3
	sty	__rc13
	ldy	.Lnewton_step_sstk+24           ; 1-byte Folded Reload
	sty	__rc5
	cpy	#1
	ldy	.Lnewton_step_sstk+23           ; 1-byte Folded Reload
	sty	__rc4
	tya
	sbc	#2
	ldy	.Lnewton_step_sstk+17           ; 1-byte Folded Reload
	sty	__rc18
	tya
	sbc	#0
	lda	.Lnewton_step_sstk+16           ; 1-byte Folded Reload
	sta	__rc15
	sbc	#0
	sta	__rc19
	ldy	.Lnewton_step_sstk+4            ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Lnewton_step_sstk+5            ; 1-byte Folded Reload
	sty	__rc3
	pha
	lda	__rc2
	sta	__rc8
	pla
	sty	__rc9
	bvc	.LBB0_34
; %bb.33:
	eor	#128
	sta	__rc19
.LBB0_34:
	ldy	.Lnewton_step_sstk+2            ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Lnewton_step_sstk+3            ; 1-byte Folded Reload
	sty	__rc3
	lda	__rc2
	sta	__rc6
	sty	__rc7
	ldy	.Lnewton_step_sstk+6            ; 1-byte Folded Reload
	sty	__rc2
	ldy	.Lnewton_step_sstk+7            ; 1-byte Folded Reload
	sty	__rc3
	lda	__rc2
	sta	__rc10
	sty	__rc11
	lda	__rc4
	ldy	__rc19
	bmi	.LBB0_36
; %bb.35:
	lda	#2
	stz	__rc5
	stz	__rc18
	stz	__rc15
.LBB0_36:
	ldy	__rc5
	cpy	#0
	sta	__rc3
	sbc	#254
	lda	__rc18
	sbc	#255
	lda	__rc15
	sbc	#255
	bvc	.LBB0_38
; %bb.37:
	eor	#128
.LBB0_38:
	tay
	bpl	.LBB0_40
; %bb.39:
	ldy	#254
	sty	__rc3
	stz	__rc5
.LBB0_40:
	ldy	__rc12
	cpy	#1
	txa
	sbc	#2
	ldy	__rc14
	sty	__rc2
	lda	__rc14
	sbc	#0
	lda	__rc13
	sbc	#0
	bvc	.LBB0_42
; %bb.41:
	eor	#128
.LBB0_42:
	tay
	bmi	.LBB0_44
; %bb.43:
	ldx	#2
	stz	__rc12
	stz	__rc2
	stz	__rc13
.LBB0_44:
	ldy	__rc12
	cpy	#0
	txa
	sbc	#254
	lda	__rc2
	sbc	#255
	lda	__rc13
	sbc	#255
	bvc	.LBB0_46
; %bb.45:
	eor	#128
.LBB0_46:
	ldy	__rc5
	sty	__rc2
	tay
	bpl	.LBB0_48
; %bb.47:
	ldx	#254
	stz	__rc12
.LBB0_48:
	ldy	__rc12
	sty	__rc4
	stx	__rc5
	rep	#32
	lda	__rc10
	sec
	sbc	__rc2
	sta	(__rc8)
	sep	#32
	ldx	.Lnewton_step_sstk              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Lnewton_step_sstk+1            ; 1-byte Folded Reload
	stx	__rc3
	rep	#32
	lda	__rc2
	sec
	sbc	__rc4
	sta	(__rc6)
	sep	#32
.LBB0_49:
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

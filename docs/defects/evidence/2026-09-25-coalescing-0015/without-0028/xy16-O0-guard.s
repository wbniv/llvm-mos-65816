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
	clc
	lda	__rc0
	adc	#196
	sta	__rc0
	lda	__rc1
	adc	#255
	sta	__rc1
	ldx	__rc20
	phx
	ldx	__rc21
	phx
	ldx	__rc22
	phx
	ldx	__rc23
	phx
	lda	__rc24
	ldy	#7
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
	tyx
	stx	__rc20
	inx
	stx	__rc21
	clc
	lda	__rc0
	adc	#58
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	__rc2
	sta	(__rc6)
	clc
	sep	#32
	lda	__rc0
	adc	#56
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	__rc4
	sta	(__rc2)
	lda	(__rc6)
	sta	__rc4
	clc
	sep	#32
	lda	__rc0
	adc	#54
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	(__rc4)
	sta	(__rc6)
	lda	(__rc2)
	sta	__rc2
	clc
	sep	#32
	lda	__rc0
	adc	#52
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	(__rc2)
	sta	(__rc4)
	lda	(__rc6)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_1
	bra	.LBB0_2
.LBB0_1:
	bra	.LBB0_3
.LBB0_2:
	sep	#32
	bra	.LBB0_4
.LBB0_3:
	sep	#32
	bra	.LBB0_5
.LBB0_4:
	ldx	#255
	bra	.LBB0_6
.LBB0_5:
	ldx	#0
	bra	.LBB0_6
.LBB0_6:
	clc
	lda	__rc0
	adc	#54
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_7
	bra	.LBB0_8
.LBB0_7:
	bra	.LBB0_9
.LBB0_8:
	sep	#32
	bra	.LBB0_10
.LBB0_9:
	sep	#32
	bra	.LBB0_11
.LBB0_10:
	ldy	#255
	bra	.LBB0_12
.LBB0_11:
	ldy	#0
	bra	.LBB0_12
.LBB0_12:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc24
	stx	__rc23
	ldx	__rc2
	stx	__rc22
	clc
	lda	__rc0
	adc	#52
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_13
	bra	.LBB0_14
.LBB0_13:
	bra	.LBB0_15
.LBB0_14:
	sep	#32
	bra	.LBB0_16
.LBB0_15:
	sep	#32
	bra	.LBB0_17
.LBB0_16:
	ldx	#255
	bra	.LBB0_18
.LBB0_17:
	ldx	#0
	bra	.LBB0_18
.LBB0_18:
	clc
	lda	__rc0
	adc	#52
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_19
	bra	.LBB0_20
.LBB0_19:
	bra	.LBB0_21
.LBB0_20:
	sep	#32
	bra	.LBB0_22
.LBB0_21:
	sep	#32
	bra	.LBB0_23
.LBB0_22:
	ldy	#255
	bra	.LBB0_24
.LBB0_23:
	ldy	#0
	bra	.LBB0_24
.LBB0_24:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	ldx	__rc24
	cpx	__rc3
	lda	__rc23
	sbc	__rc4
	tax
	lda	__rc22
	sbc	__rc2
	stx	__rc2
	sta	__rc3
	clc
	lda	__rc0
	adc	#50
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	__rc2
	sta	(__rc4)
	clc
	sep	#32
	lda	__rc0
	adc	#54
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_25
	bra	.LBB0_26
.LBB0_25:
	bra	.LBB0_27
.LBB0_26:
	sep	#32
	bra	.LBB0_28
.LBB0_27:
	sep	#32
	bra	.LBB0_29
.LBB0_28:
	ldx	#255
	bra	.LBB0_30
.LBB0_29:
	ldx	#0
	bra	.LBB0_30
.LBB0_30:
	clc
	lda	__rc0
	adc	#52
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_31
	bra	.LBB0_32
.LBB0_31:
	bra	.LBB0_33
.LBB0_32:
	sep	#32
	bra	.LBB0_34
.LBB0_33:
	sep	#32
	bra	.LBB0_35
.LBB0_34:
	ldy	#255
	bra	.LBB0_36
.LBB0_35:
	ldy	#0
	bra	.LBB0_36
.LBB0_36:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	stx	__rc3
	ldx	__rc2
	stx	__rc5
	asl
	rol	__rc3
	rol	__rc5
	ldx	__rc3
	stx	__rc4
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	__rc4
	sta	(__rc2)
	clc
	sep	#32
	lda	__rc0
	adc	#50
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_37
	bra	.LBB0_38
.LBB0_37:
	bra	.LBB0_39
.LBB0_38:
	sep	#32
	bra	.LBB0_40
.LBB0_39:
	sep	#32
	bra	.LBB0_41
.LBB0_40:
	ldx	#255
	bra	.LBB0_42
.LBB0_41:
	ldx	#0
	bra	.LBB0_42
.LBB0_42:
	clc
	lda	__rc0
	adc	#54
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_43
	bra	.LBB0_44
.LBB0_43:
	bra	.LBB0_45
.LBB0_44:
	sep	#32
	bra	.LBB0_46
.LBB0_45:
	sep	#32
	bra	.LBB0_47
.LBB0_46:
	ldy	#255
	bra	.LBB0_48
.LBB0_47:
	ldy	#0
	bra	.LBB0_48
.LBB0_48:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc24
	stx	__rc23
	ldx	__rc2
	stx	__rc22
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_49
	bra	.LBB0_50
.LBB0_49:
	bra	.LBB0_51
.LBB0_50:
	sep	#32
	bra	.LBB0_52
.LBB0_51:
	sep	#32
	bra	.LBB0_53
.LBB0_52:
	ldx	#255
	bra	.LBB0_54
.LBB0_53:
	ldx	#0
	bra	.LBB0_54
.LBB0_54:
	clc
	lda	__rc0
	adc	#52
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_55
	bra	.LBB0_56
.LBB0_55:
	bra	.LBB0_57
.LBB0_56:
	sep	#32
	bra	.LBB0_58
.LBB0_57:
	sep	#32
	bra	.LBB0_59
.LBB0_58:
	ldy	#255
	bra	.LBB0_60
.LBB0_59:
	ldy	#0
	bra	.LBB0_60
.LBB0_60:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	ldx	__rc24
	cpx	__rc3
	lda	__rc23
	sbc	__rc4
	tax
	lda	__rc22
	sbc	__rc2
	stx	__rc2
	sta	__rc3
	clc
	lda	__rc0
	adc	#46
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	__rc2
	sta	(__rc4)
	clc
	sep	#32
	lda	__rc0
	adc	#50
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_61
	bra	.LBB0_62
.LBB0_61:
	bra	.LBB0_63
.LBB0_62:
	sep	#32
	bra	.LBB0_64
.LBB0_63:
	sep	#32
	bra	.LBB0_65
.LBB0_64:
	ldx	#255
	bra	.LBB0_66
.LBB0_65:
	ldx	#0
	bra	.LBB0_66
.LBB0_66:
	clc
	lda	__rc0
	adc	#52
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_67
	bra	.LBB0_68
.LBB0_67:
	bra	.LBB0_69
.LBB0_68:
	sep	#32
	bra	.LBB0_70
.LBB0_69:
	sep	#32
	bra	.LBB0_71
.LBB0_70:
	ldy	#255
	bra	.LBB0_72
.LBB0_71:
	ldy	#0
	bra	.LBB0_72
.LBB0_72:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc24
	stx	__rc22
	ldx	__rc2
	stx	__rc23
	clc
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc8
	eor	#32768
	cmp	#32768
	bcs	.LBB0_73
	bra	.LBB0_74
.LBB0_73:
	bra	.LBB0_75
.LBB0_74:
	sep	#32
	bra	.LBB0_76
.LBB0_75:
	sep	#32
	bra	.LBB0_77
.LBB0_76:
	ldx	#255
	bra	.LBB0_78
.LBB0_77:
	ldx	#0
	bra	.LBB0_78
.LBB0_78:
	clc
	lda	__rc0
	adc	#54
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_79
	bra	.LBB0_80
.LBB0_79:
	bra	.LBB0_81
.LBB0_80:
	sep	#32
	bra	.LBB0_82
.LBB0_81:
	sep	#32
	bra	.LBB0_83
.LBB0_82:
	ldy	#255
	bra	.LBB0_84
.LBB0_83:
	ldy	#0
	bra	.LBB0_84
.LBB0_84:
	stx	__rc2
	stx	__rc3
	sty	__rc6
	sty	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	clc
	lda	__rc24
	adc	__rc3
	lda	__rc22
	adc	__rc4
	tax
	lda	__rc23
	adc	__rc2
	stx	__rc2
	sta	__rc3
	clc
	lda	__rc0
	adc	#44
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	__rc2
	sta	(__rc4)
	clc
	sep	#32
	lda	__rc0
	adc	#46
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sec
	sbc	__rc20
	sta	__rc2
	clc
	sep	#32
	lda	__rc0
	adc	#42
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	rep	#32
	lda	__rc2
	sta	(__rc6)
	clc
	sep	#32
	lda	__rc0
	adc	#40
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc4)
	sta	(__rc2)
	clc
	sep	#32
	lda	__rc0
	adc	#50
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_85
	bra	.LBB0_86
.LBB0_85:
	bra	.LBB0_87
.LBB0_86:
	sep	#32
	bra	.LBB0_88
.LBB0_87:
	sep	#32
	bra	.LBB0_89
.LBB0_88:
	ldx	#255
	bra	.LBB0_90
.LBB0_89:
	ldx	#0
	bra	.LBB0_90
.LBB0_90:
	lda	#3
	stz	__rc2
	stz	__rc3
	stx	__rc6
	stx	__rc7
	ldx	#0
	jsr	__mulsi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#38
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	__rc2
	sta	(__rc4)
	clc
	sep	#32
	lda	__rc0
	adc	#48
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc4
	eor	#32768
	cmp	#32768
	bcs	.LBB0_91
	bra	.LBB0_92
.LBB0_91:
	bra	.LBB0_93
.LBB0_92:
	sep	#32
	bra	.LBB0_94
.LBB0_93:
	sep	#32
	bra	.LBB0_95
.LBB0_94:
	ldx	#255
	bra	.LBB0_96
.LBB0_95:
	ldx	#0
	bra	.LBB0_96
.LBB0_96:
	lda	#3
	stz	__rc2
	stz	__rc3
	stx	__rc6
	stx	__rc7
	ldx	#0
	jsr	__mulsi3
	sta	__rc2
	stx	__rc3
	clc
	lda	__rc0
	adc	#36
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	__rc2
	sta	(__rc4)
	clc
	sep	#32
	lda	__rc0
	adc	#42
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc2
	eor	#32768
	cmp	#32768
	bcs	.LBB0_97
	bra	.LBB0_98
.LBB0_97:
	bra	.LBB0_99
.LBB0_98:
	sep	#32
	bra	.LBB0_100
.LBB0_99:
	sep	#32
	bra	.LBB0_101
.LBB0_100:
	lda	#255
	bra	.LBB0_102
.LBB0_101:
	lda	#0
	bra	.LBB0_102
.LBB0_102:
	cmp	#128
	tax
	stx	__rc4
	ror	__rc4
	ror
	ldx	__rc3
	stx	__rc5
	ror	__rc5
	tax
	lda	__rc2
	ror
	clc
	pha
	lda	__rc0
	adc	#32
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	pla
	sta	(__rc2)
	ldy	#1
	lda	__rc5
	sta	(__rc2),y
	iny
	txa
	sta	(__rc2),y
	iny
	lda	__rc4
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#40
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc2
	eor	#32768
	cmp	#32768
	bcs	.LBB0_103
	bra	.LBB0_104
.LBB0_103:
	bra	.LBB0_105
.LBB0_104:
	sep	#32
	bra	.LBB0_106
.LBB0_105:
	sep	#32
	bra	.LBB0_107
.LBB0_106:
	lda	#255
	bra	.LBB0_108
.LBB0_107:
	lda	#0
	bra	.LBB0_108
.LBB0_108:
	cmp	#128
	tax
	stx	__rc4
	ror	__rc4
	ror
	ldx	__rc3
	stx	__rc5
	ror	__rc5
	tax
	lda	__rc2
	ror
	clc
	pha
	lda	__rc0
	adc	#28
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	pla
	sta	(__rc2)
	ldy	#1
	lda	__rc5
	sta	(__rc2),y
	iny
	txa
	sta	(__rc2),y
	iny
	lda	__rc4
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#38
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc2
	eor	#32768
	cmp	#32768
	bcs	.LBB0_109
	bra	.LBB0_110
.LBB0_109:
	bra	.LBB0_111
.LBB0_110:
	sep	#32
	bra	.LBB0_112
.LBB0_111:
	sep	#32
	bra	.LBB0_113
.LBB0_112:
	lda	#255
	bra	.LBB0_114
.LBB0_113:
	lda	#0
	bra	.LBB0_114
.LBB0_114:
	cmp	#128
	tax
	stx	__rc4
	ror	__rc4
	ror
	ror	__rc3
	ldx	__rc3
	stx	__rc5
	tax
	lda	__rc2
	ror
	clc
	pha
	lda	__rc0
	adc	#24
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	pla
	sta	(__rc2)
	ldy	#1
	lda	__rc5
	sta	(__rc2),y
	iny
	txa
	sta	(__rc2),y
	iny
	lda	__rc4
	sta	(__rc2),y
	clc
	lda	__rc0
	adc	#36
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc2
	eor	#32768
	cmp	#32768
	bcs	.LBB0_115
	bra	.LBB0_116
.LBB0_115:
	bra	.LBB0_117
.LBB0_116:
	sep	#32
	bra	.LBB0_118
.LBB0_117:
	sep	#32
	bra	.LBB0_119
.LBB0_118:
	lda	#255
	bra	.LBB0_120
.LBB0_119:
	lda	#0
	bra	.LBB0_120
.LBB0_120:
	cmp	#128
	tax
	stx	__rc4
	ror	__rc4
	ror
	ror	__rc3
	sta	__rc5
	lda	__rc2
	ror
	clc
	pha
	lda	__rc0
	adc	#20
	sta	__rc20
	lda	__rc1
	adc	#0
	sta	__rc21
	pla
	sta	(__rc20)
	ldy	#1
	lda	__rc3
	sta	(__rc20),y
	tyx
	iny
	lda	__rc5
	sta	(__rc20),y
	ldy	#2
	sty	__rc7
	iny
	lda	__rc4
	sta	(__rc20),y
	ldy	#3
	sty	__rc9
	clc
	lda	__rc0
	adc	#24
	sta	__rc10
	lda	__rc1
	adc	#0
	sta	__rc11
	lda	(__rc10)
	sta	__rc8
	stx	__rc5
	ldy	__rc5
	lda	(__rc10),y
	tax
	ldy	__rc7
	lda	(__rc10),y
	sta	__rc2
	ldy	__rc9
	lda	(__rc10),y
	sta	__rc3
	lda	(__rc10)
	sta	__rc4
	ldy	__rc5
	lda	(__rc10),y
	sta	__rc5
	ldy	__rc7
	lda	(__rc10),y
	sta	__rc6
	sty	__rc26
	ldy	__rc9
	lda	(__rc10),y
	sta	__rc7
	lda	__rc8
	jsr	__mulsi3
	sta	__rc25
	stx	__rc24
	ldx	__rc2
	stx	__rc22
	ldx	__rc3
	stx	__rc23
	lda	(__rc20)
	sta	__rc8
	ldy	#1
	lda	(__rc20),y
	tyx
	sta	__rc9
	ldy	__rc26
	sty	__rc6
	ldy	__rc6
	lda	(__rc20),y
	sta	__rc2
	ldy	#3
	lda	(__rc20),y
	sty	__rc7
	sta	__rc3
	lda	(__rc20)
	sta	__rc4
	txy
	lda	(__rc20),y
	sta	__rc5
	ldx	#1
	stx	__rc26
	ldy	__rc6
	lda	(__rc20),y
	sta	__rc6
	ldy	__rc7
	lda	(__rc20),y
	ldx	#3
	stx	__rc20
	sta	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc4
	stx	__rc5
	clc
	lda	__rc0
	adc	#16
	sta	__rc6
	lda	__rc1
	adc	#0
	sta	__rc7
	clc
	lda	__rc25
	adc	__rc4
	sta	(__rc6)
	lda	__rc24
	adc	__rc5
	ldx	__rc26
	stx	__rc5
	ldy	__rc5
	sta	(__rc6),y
	lda	__rc22
	adc	__rc2
	sta	__rc4
	lda	__rc23
	adc	__rc3
	sta	__rc2
	ldy	#2
	lda	__rc4
	sta	(__rc6),y
	tyx
	lda	__rc2
	ldy	__rc20
	sta	(__rc6),y
	lda	(__rc6)
	sta	__rc2
	ldy	__rc5
	lda	(__rc6),y
	sta	__rc3
	txy
	lda	(__rc6),y
	sta	__rc4
	ldy	__rc20
	lda	(__rc6),y
	bne	.LBB0_125
	bra	.LBB0_121
.LBB0_121:
	lda	__rc4
	bne	.LBB0_125
	bra	.LBB0_122
.LBB0_122:
	lda	__rc3
	bne	.LBB0_125
	bra	.LBB0_123
.LBB0_123:
	lda	__rc2
	beq	.LBB0_124
	bra	.LBB0_125
.LBB0_124:
; %bb.147:
	jmp	.LBB0_146
.LBB0_125:
	clc
	lda	__rc0
	adc	#32
	sta	__rc20
	lda	__rc1
	adc	#0
	sta	__rc21
	lda	(__rc20)
	sta	__rc8
	ldy	#1
	lda	(__rc20),y
	sta	__rc9
	tyx
	clc
	lda	__rc0
	adc	#24
	sta	__rc24
	lda	__rc1
	adc	#0
	sta	__rc25
	iny
	lda	(__rc20),y
	sta	__rc2
	ldy	#2
	sty	__rc6
	iny
	lda	(__rc20),y
	ldy	#3
	sty	__rc7
	sta	__rc3
	lda	(__rc24)
	sta	__rc4
	txy
	lda	(__rc24),y
	sta	__rc5
	stx	__rc26
	ldy	__rc6
	lda	(__rc24),y
	sta	__rc6
	inx
	stx	__rc29
	ldy	__rc7
	lda	(__rc24),y
	sta	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc22
	stx	__rc23
	ldx	__rc2
	stx	__rc28
	clc
	lda	__rc0
	adc	#28
	sta	__rc30
	lda	__rc1
	adc	#0
	sta	__rc31
	lda	(__rc30)
	sta	__rc8
	ldy	__rc26
	lda	(__rc30),y
	sty	__rc4
	sta	__rc9
	clc
	lda	__rc0
	adc	#20
	sta	__rc26
	lda	__rc1
	adc	#0
	sta	__rc27
	ldy	__rc29
	lda	(__rc30),y
	sty	__rc6
	sta	__rc2
	ldx	#3
	txy
	lda	(__rc30),y
	sty	__rc7
	sta	__rc3
	lda	(__rc26)
	tax
	ldy	__rc4
	lda	(__rc26),y
	sta	__rc5
	ldy	__rc6
	lda	(__rc26),y
	sta	__rc6
	ldy	__rc7
	lda	(__rc26),y
	stx	__rc4
	sta	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	clc
	lda	__rc22
	adc	__rc3
	sta	__rc8
	lda	__rc23
	adc	__rc4
	tax
	lda	__rc28
	adc	__rc2
	sta	__rc3
	clc
	lda	__rc0
	adc	#16
	sta	__rc28
	lda	__rc1
	adc	#0
	sta	__rc29
	lda	(__rc28)
	sta	__rc4
	ldy	#1
	lda	(__rc28),y
	sta	__rc5
	iny
	lda	(__rc28),y
	sta	__rc6
	iny
	lda	(__rc28),y
	stx	__rc2
	sta	__rc7
	ldx	__rc8
	lda	#0
	jsr	__divsi3
	clc
	pha
	lda	__rc0
	adc	#12
	sta	__rc22
	lda	__rc1
	adc	#0
	sta	__rc23
	pla
	sta	(__rc22)
	ldy	#1
	txa
	sta	(__rc22),y
	sty	__rc4
	ldx	#2
	txy
	lda	__rc2
	sta	(__rc22),y
	sty	__rc5
	inx
	stx	__rc2
	lda	__rc3
	ldy	__rc2
	sta	(__rc22),y
	lda	(__rc30)
	sta	__rc8
	ldy	__rc4
	sty	__rc10
	ldy	__rc10
	lda	(__rc30),y
	sta	__rc9
	ldy	__rc5
	lda	(__rc30),y
	sta	__rc2
	sty	__rc6
	txy
	lda	(__rc30),y
	sty	__rc7
	sta	__rc3
	lda	(__rc24)
	sta	__rc4
	ldy	__rc10
	lda	(__rc24),y
	sta	__rc5
	ldy	__rc6
	lda	(__rc24),y
	sta	__rc6
	ldy	__rc7
	lda	(__rc24),y
	ldx	#3
	stx	__rc30
	sta	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc25
	stx	__rc24
	ldx	__rc2
	stx	__rc31
	lda	(__rc20)
	sta	__rc8
	ldx	#1
	txy
	lda	(__rc20),y
	sta	__rc9
	ldy	#2
	lda	(__rc20),y
	sty	__rc6
	sta	__rc2
	ldy	__rc30
	lda	(__rc20),y
	sty	__rc7
	sta	__rc3
	lda	(__rc26)
	sta	__rc4
	txy
	lda	(__rc26),y
	sta	__rc5
	stx	__rc20
	ldy	__rc6
	lda	(__rc26),y
	sta	__rc6
	inx
	stx	__rc30
	ldy	__rc7
	lda	(__rc26),y
	sty	__rc21
	sta	__rc7
	ldx	__rc9
	lda	__rc8
	jsr	__mulsi3
	sta	__rc3
	stx	__rc4
	sec
	lda	__rc25
	sbc	__rc3
	tax
	lda	__rc24
	sbc	__rc4
	sta	__rc8
	lda	__rc31
	sbc	__rc2
	sta	__rc3
	lda	(__rc28)
	sta	__rc4
	ldy	__rc20
	lda	(__rc28),y
	sta	__rc5
	ldy	__rc30
	lda	(__rc28),y
	sta	__rc6
	ldy	__rc21
	lda	(__rc28),y
	ldy	__rc8
	sty	__rc2
	sta	__rc7
	lda	#0
	jsr	__divsi3
	clc
	pha
	lda	__rc0
	adc	#8
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	pla
	sta	(__rc4)
	ldy	__rc20
	txa
	sta	(__rc4),y
	sty	__rc6
	ldy	__rc30
	lda	__rc2
	sta	(__rc4),y
	tyx
	ldy	__rc21
	lda	__rc3
	sta	(__rc4),y
	sty	__rc2
	lda	(__rc22)
	cmp	#1
	ldy	__rc6
	lda	(__rc22),y
	sbc	#2
	txy
	lda	(__rc22),y
	sbc	#0
	ldy	__rc2
	lda	(__rc22),y
	sbc	#0
	bvs	.LBB0_126
	bra	.LBB0_127
.LBB0_126:
	eor	#128
	bra	.LBB0_128
.LBB0_127:
	bra	.LBB0_128
.LBB0_128:
	tax
	bpl	.LBB0_129
	bra	.LBB0_130
.LBB0_129:
	clc
	lda	__rc0
	adc	#12
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	#0
	sta	(__rc2)
	ldy	#1
	lda	#2
	sta	(__rc2),y
	tay
	lda	#0
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	bra	.LBB0_130
.LBB0_130:
	clc
	lda	__rc0
	adc	#12
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	(__rc2)
	ldy	#1
	cmp	#0
	lda	(__rc2),y
	iny
	sbc	#254
	lda	(__rc2),y
	iny
	sbc	#255
	lda	(__rc2),y
	sbc	#255
	bvs	.LBB0_131
	bra	.LBB0_132
.LBB0_131:
	eor	#128
	bra	.LBB0_133
.LBB0_132:
	bra	.LBB0_133
.LBB0_133:
	tax
	bmi	.LBB0_134
	bra	.LBB0_135
.LBB0_134:
	clc
	lda	__rc0
	adc	#12
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	#0
	sta	(__rc2)
	ldy	#1
	lda	#254
	sta	(__rc2),y
	iny
	inc
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	bra	.LBB0_135
.LBB0_135:
	clc
	lda	__rc0
	adc	#8
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	(__rc2)
	ldy	#1
	cmp	#1
	lda	(__rc2),y
	iny
	sbc	#2
	lda	(__rc2),y
	iny
	sbc	#0
	lda	(__rc2),y
	sbc	#0
	bvs	.LBB0_136
	bra	.LBB0_137
.LBB0_136:
	eor	#128
	bra	.LBB0_138
.LBB0_137:
	bra	.LBB0_138
.LBB0_138:
	tax
	bpl	.LBB0_139
	bra	.LBB0_140
.LBB0_139:
	clc
	lda	__rc0
	adc	#8
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	#0
	sta	(__rc2)
	ldy	#1
	lda	#2
	sta	(__rc2),y
	tay
	lda	#0
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	bra	.LBB0_140
.LBB0_140:
	clc
	lda	__rc0
	adc	#8
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	(__rc2)
	ldy	#1
	cmp	#0
	lda	(__rc2),y
	iny
	sbc	#254
	lda	(__rc2),y
	iny
	sbc	#255
	lda	(__rc2),y
	sbc	#255
	bvs	.LBB0_141
	bra	.LBB0_142
.LBB0_141:
	eor	#128
	bra	.LBB0_143
.LBB0_142:
	bra	.LBB0_143
.LBB0_143:
	tax
	bmi	.LBB0_144
	bra	.LBB0_145
.LBB0_144:
	clc
	lda	__rc0
	adc	#8
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	lda	#0
	sta	(__rc2)
	ldy	#1
	lda	#254
	sta	(__rc2),y
	iny
	inc
	sta	(__rc2),y
	iny
	sta	(__rc2),y
	bra	.LBB0_145
.LBB0_145:
	clc
	lda	__rc0
	adc	#54
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc2
	clc
	sep	#32
	lda	__rc0
	adc	#12
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	lda	(__rc4)
	tax
	ldy	#1
	lda	(__rc4),y
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc2
	sec
	sbc	__rc4
	sta	__rc2
	clc
	sep	#32
	lda	__rc0
	adc	#58
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	(__rc4)
	sta	__rc4
	lda	__rc2
	sta	(__rc4)
	clc
	sep	#32
	lda	__rc0
	adc	#52
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)
	sta	__rc2
	clc
	sep	#32
	lda	__rc0
	adc	#8
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	lda	(__rc4)
	tax
	lda	(__rc4),y
	stx	__rc4
	sta	__rc5
	rep	#32
	lda	__rc2
	sec
	sbc	__rc4
	sta	__rc2
	clc
	sep	#32
	lda	__rc0
	adc	#56
	sta	__rc4
	lda	__rc1
	adc	#0
	sta	__rc5
	rep	#32
	lda	(__rc4)
	sta	__rc4
	lda	__rc2
	sta	(__rc4)
	sep	#32
	bra	.LBB0_146
.LBB0_146:
	ldy	#0
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
	plx
	stx	__rc23
	plx
	stx	__rc22
	plx
	stx	__rc21
	plx
	stx	__rc20
	clc
	lda	__rc0
	adc	#60
	sta	__rc0
	lda	__rc1
	adc	#0
	sta	__rc1
	rts
.Lfunc_end0:
	.size	newton_step, .Lfunc_end0-newton_step
                                        ; -- End function
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

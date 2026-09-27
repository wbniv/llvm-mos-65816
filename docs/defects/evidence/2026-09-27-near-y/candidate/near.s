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
	.file	"near-decode.c"
	.section	.text.decode_near,"ax",@progbits
	.globl	decode_near                     ; -- Begin function decode_near
	.type	decode_near,@function
decode_near:                            ; @decode_near
; %bb.0:
	ldy	__rc20
	phy
	ldy	__rc21
	phy
	ldy	__rc22
	phy
	ldy	__rc23
	phy
	ldy	__rc24
	sty	.Ldecode_near_sstk+14           ; 1-byte Folded Spill
	ldy	__rc25
	sty	.Ldecode_near_sstk+15           ; 1-byte Folded Spill
	ldy	__rc26
	sty	.Ldecode_near_sstk+16           ; 1-byte Folded Spill
	ldy	__rc27
	sty	.Ldecode_near_sstk+17           ; 1-byte Folded Spill
	ldy	__rc28
	sty	.Ldecode_near_sstk+18           ; 1-byte Folded Spill
	ldy	__rc29
	sty	.Ldecode_near_sstk+19           ; 1-byte Folded Spill
	ldy	__rc30
	sty	.Ldecode_near_sstk+20           ; 1-byte Folded Spill
	ldy	__rc31
	sty	.Ldecode_near_sstk+21           ; 1-byte Folded Spill
	sta	__rc28
	stx	__rc29
	ldx	__rc6
	lda	__rc7
	ldy	__rc2
	sty	.Ldecode_near_sstk              ; 1-byte Folded Spill
	ldy	__rc3
	sty	.Ldecode_near_sstk+1            ; 1-byte Folded Spill
	ldy	__rc4
	sty	.Ldecode_near_sstk+8            ; 1-byte Folded Spill
	ldy	__rc5
	sty	.Ldecode_near_sstk+9            ; 1-byte Folded Spill
	ldy	__rc6
	sty	.Ldecode_near_sstk+12           ; 1-byte Folded Spill
	stx	__rc30
	ldx	__rc7
	stx	.Ldecode_near_sstk+13           ; 1-byte Folded Spill
	sta	__rc31
	stz	__rc25
	ldx	#0
	stx	__rc2
	ldx	#0
	stx	__rc3
	ldx	__rc2
	stx	.Ldecode_near_sstk+10           ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ldecode_near_sstk+11           ; 1-byte Folded Spill
	ldx	#1
	stx	__rc22
	stz	__rc26
	stz	__rc27
	stz	__rc20
	stz	__rc21
.LBB0_1:                                ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB0_4 Depth 2
                                        ;       Child Loop BB0_16 Depth 3
	rep	#32
	lda	__rc20
	cmp	__rc28
	bcc	.LBB0_2
; %bb.36:
	jmp	.LBB0_28
.LBB0_2:                                ;   in Loop: Header=BB0_1 Depth=1
	lda	__rc26
	cmp	__rc30
	bcc	.LBB0_3
; %bb.38:
	jmp	.LBB0_28
.LBB0_3:                                ;   in Loop: Header=BB0_1 Depth=1
	lda	__rc20
	inc
	sta	__rc2
	sep	#32
	ldx	__rc2
	stx	.Ldecode_near_sstk+4            ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ldecode_near_sstk+5            ; 1-byte Folded Spill
	ldx	.Ldecode_near_sstk              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldecode_near_sstk+1            ; 1-byte Folded Reload
	stx	__rc3
	rep	#16
	ldy	__rc20
	lda	(__rc2),y
	sta	.Ldecode_near_sstk+2            ; 1-byte Folded Spill
	sep	#16
	ldx	#0
	stx	.Ldecode_near_sstk+3            ; 1-byte Folded Spill
	ldx	#0
	ldy	.Ldecode_near_sstk+4            ; 1-byte Folded Reload
	sty	__rc20
	ldy	.Ldecode_near_sstk+5            ; 1-byte Folded Reload
	ldy	.Ldecode_near_sstk+4            ; 1-byte Folded Reload
	ldy	.Ldecode_near_sstk+5            ; 1-byte Folded Reload
	sty	__rc21
.LBB0_4:                                ;   Parent Loop BB0_1 Depth=1
                                        ; =>  This Loop Header: Depth=2
                                        ;       Child Loop BB0_16 Depth 3
	cpx	#8
	bne	.LBB0_5
; %bb.54:                               ;   in Loop: Header=BB0_1 Depth=1
	jmp	.LBB0_1
.LBB0_5:                                ;   in Loop: Header=BB0_4 Depth=2
	rep	#32
	lda	__rc26
	cmp	__rc30
	bcc	.LBB0_6
; %bb.40:                               ;   in Loop: Header=BB0_1 Depth=1
	jmp	.LBB0_1
.LBB0_6:                                ;   in Loop: Header=BB0_4 Depth=2
	sep	#32
	stx	__rc23
	stx	__rc2
	ldx	#0
	lda	__rc22
	jsr	__ashlhi3
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sep	#32
	ldx	.Ldecode_near_sstk+2            ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldecode_near_sstk+3            ; 1-byte Folded Reload
	stx	__rc3
	rep	#32
	and	__rc2
	sta	__rc2
	sep	#32
	lda	__rc3
	bne	.LBB0_8
; %bb.7:                                ;   in Loop: Header=BB0_4 Depth=2
	lda	__rc2
	bne	.LBB0_8
; %bb.42:                               ;   in Loop: Header=BB0_4 Depth=2
	jmp	.LBB0_23
.LBB0_8:                                ;   in Loop: Header=BB0_4 Depth=2
	rep	#32
	lda	__rc20
	clc
	sep	#32
	ldx	#1
	bcs	.LBB0_10
; %bb.9:                                ;   in Loop: Header=BB0_4 Depth=2
	ldx	#0
.LBB0_10:                               ;   in Loop: Header=BB0_4 Depth=2
	stx	__rc10
	rep	#32
	adc	#mos16(2)
	sta	__rc2
	lda	__rc28
	cmp	__rc2
	bcs	.LBB0_11
; %bb.44:
	jmp	.LBB0_26
.LBB0_11:                               ;   in Loop: Header=BB0_4 Depth=2
	sep	#32
	ldx	.Ldecode_near_sstk              ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Ldecode_near_sstk+1            ; 1-byte Folded Reload
	stx	__rc5
	ldy	__rc4
	sty	__rc6
	stx	__rc7
	rep	#32
	lda	__rc4
	sep	#32
	ldx	__rc10
	cpx	#1
	rep	#32
	adc	__rc20
	sta	__rc4
	sep	#32
	rep	#16
	ldy	__rc20
	lda	(__rc6),y
	sta	__rc24
	sep	#16
	ldy	#1
	tyx
	lda	(__rc4),y
	sta	__rc12
	sta	__rc4
	stz	__rc5
	rep	#32
	lda	__rc4
	asl
	asl
	asl
	asl
	and	#3840
	sta	__rc6
	ora	__rc24
	sta	__rc4
	sep	#32
	lda	__rc5
	bne	.LBB0_12
; %bb.46:                               ;   in Loop: Header=BB0_4 Depth=2
	jmp	.LBB0_25
.LBB0_12:                               ;   in Loop: Header=BB0_4 Depth=2
	rep	#32
	lda	__rc26
	cmp	__rc4
	bcs	.LBB0_13
; %bb.48:
	jmp	.LBB0_26
.LBB0_13:                               ;   in Loop: Header=BB0_4 Depth=2
	sep	#32
	stx	__rc22
	ldx	.Ldecode_near_sstk+8            ; 1-byte Folded Reload
	stx	__rc4
	ldx	.Ldecode_near_sstk+9            ; 1-byte Folded Reload
	stx	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	__rc26
	sta	__rc4
	lda	__rc6
	ora	__rc24
	sta	__rc6
	sep	#32
	ldx	.Ldecode_near_sstk+10           ; 1-byte Folded Reload
	stx	__rc10
	ldx	.Ldecode_near_sstk+11           ; 1-byte Folded Reload
	stx	__rc11
	rep	#32
	lda	__rc10
	sec
	sbc	__rc6
	sta	__rc6
	sep	#32
	lda	__rc12
	and	#15
	clc
	adc	#3
	sta	__rc10
	bra	.LBB0_16
.LBB0_14:                               ;   in Loop: Header=BB0_16 Depth=3
	rep	#16
	sta	__rc10
	ldy	__rc6
	lda	(__rc4),y
	sta	(__rc4)
	rep	#32
	lda	__rc26
	inc
	sta	__rc26
	sep	#32
	inc	__rc4
	bne	.LBB0_16
; %bb.15:                               ;   in Loop: Header=BB0_16 Depth=3
	inc	__rc5
.LBB0_16:                               ;   Parent Loop BB0_1 Depth=1
                                        ;     Parent Loop BB0_4 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	rep	#32
	sep	#16
	lda	__rc26
	cmp	__rc30
	sep	#32
	ldx	#0
	bcs	.LBB0_18
; %bb.17:                               ;   in Loop: Header=BB0_16 Depth=3
	ldx	#1
.LBB0_18:                               ;   in Loop: Header=BB0_16 Depth=3
	lda	__rc10
	clc
	adc	#255
	bcs	.LBB0_20
; %bb.19:                               ;   in Loop: Header=BB0_16 Depth=3
	ldx	#0
.LBB0_20:                               ;   in Loop: Header=BB0_16 Depth=3
	txy
	bne	.LBB0_14
; %bb.21:                               ;   in Loop: Header=BB0_4 Depth=2
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
.LBB0_22:                               ;   in Loop: Header=BB0_4 Depth=2
	stx	__rc21
	ldx	__rc23
	inx
; %bb.30:                               ;   in Loop: Header=BB0_4 Depth=2
	jmp	.LBB0_4
.LBB0_23:                               ;   in Loop: Header=BB0_4 Depth=2
	rep	#32
	lda	__rc20
	cmp	__rc28
	bcc	.LBB0_24
; %bb.50:
	jmp	.LBB0_26
.LBB0_24:                               ;   in Loop: Header=BB0_4 Depth=2
	lda	__rc20
	inc
	sta	__rc2
	sep	#32
	ldx	__rc2
	stx	.Ldecode_near_sstk+4            ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ldecode_near_sstk+5            ; 1-byte Folded Spill
	ldx	.Ldecode_near_sstk              ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldecode_near_sstk+1            ; 1-byte Folded Reload
	stx	__rc3
	rep	#16
	ldy	__rc20
	lda	(__rc2),y
	sta	__rc4
	rep	#32
	lda	__rc26
	inc
	sta	__rc2
	sep	#48
	ldx	__rc2
	stx	.Ldecode_near_sstk+6            ; 1-byte Folded Spill
	ldx	__rc3
	stx	.Ldecode_near_sstk+7            ; 1-byte Folded Spill
	ldx	.Ldecode_near_sstk+8            ; 1-byte Folded Reload
	stx	__rc2
	ldx	.Ldecode_near_sstk+9            ; 1-byte Folded Reload
	stx	__rc3
	lda	__rc4
	rep	#16
	ldy	__rc26
	sta	(__rc2),y
	sep	#16
	ldx	.Ldecode_near_sstk+6            ; 1-byte Folded Reload
	stx	__rc26
	ldx	.Ldecode_near_sstk+7            ; 1-byte Folded Reload
	ldx	.Ldecode_near_sstk+6            ; 1-byte Folded Reload
	ldx	.Ldecode_near_sstk+7            ; 1-byte Folded Reload
	stx	__rc27
	ldx	.Ldecode_near_sstk+4            ; 1-byte Folded Reload
	stx	__rc20
	ldx	.Ldecode_near_sstk+5            ; 1-byte Folded Reload
	ldx	.Ldecode_near_sstk+4            ; 1-byte Folded Reload
	ldx	.Ldecode_near_sstk+5            ; 1-byte Folded Reload
; %bb.32:                               ;   in Loop: Header=BB0_4 Depth=2
	jmp	.LBB0_22
.LBB0_25:                               ;   in Loop: Header=BB0_4 Depth=2
	lda	__rc4
	beq	.LBB0_26
; %bb.52:                               ;   in Loop: Header=BB0_4 Depth=2
	jmp	.LBB0_12
.LBB0_26:
	sep	#32
	ldx	#0
.LBB0_27:
	sep	#32
	lda	__rc25
	ldy	.Ldecode_near_sstk+21           ; 1-byte Folded Reload
	sty	__rc31
	ldy	.Ldecode_near_sstk+20           ; 1-byte Folded Reload
	sty	__rc30
	ldy	.Ldecode_near_sstk+19           ; 1-byte Folded Reload
	sty	__rc29
	ldy	.Ldecode_near_sstk+18           ; 1-byte Folded Reload
	sty	__rc28
	ldy	.Ldecode_near_sstk+17           ; 1-byte Folded Reload
	sty	__rc27
	ldy	.Ldecode_near_sstk+16           ; 1-byte Folded Reload
	sty	__rc26
	ldy	.Ldecode_near_sstk+15           ; 1-byte Folded Reload
	sty	__rc25
	ldy	.Ldecode_near_sstk+14           ; 1-byte Folded Reload
	sty	__rc24
	ply
	sty	__rc23
	ply
	sty	__rc22
	ply
	sty	__rc21
	ply
	sty	__rc20
	rts
.LBB0_28:
	sep	#32
	ldx	#0
	rep	#32
	lda	__rc26
	cmp	__rc30
	bne	.LBB0_27
; %bb.29:
	sep	#32
	ldx	.Ldecode_near_sstk+12           ; 1-byte Folded Reload
	stx	__rc25
	ldx	.Ldecode_near_sstk+13           ; 1-byte Folded Reload
; %bb.34:
	jmp	.LBB0_27
.Lfunc_end0:
	.size	decode_near, .Lfunc_end0-decode_near
                                        ; -- End function
	.section	.text.main,"ax",@progbits
	.globl	main                            ; -- Begin function main
	.type	main,@function
main:                                   ; @main
; %bb.0:
	rep	#32
	lda	source
	sta	__rc2
	lda	destination
	sta	__rc4
	sep	#32
	lda	#210
	ldy	#160
	ldx	#2
	sty	__rc6
	stx	__rc7
	dex
	jsr	decode_near
	cpx	#2
	bne	.LBB1_3
; %bb.1:
	cmp	#160
	bne	.LBB1_3
; %bb.2:
	ldx	#1
	bra	.LBB1_4
.LBB1_3:
	ldx	#0
.LBB1_4:
	ldy	#mos16lo(output)
	sty	__rc2
	ldy	#mos16hi(output)
	sty	__rc3
	ldy	#mos16lo(expected)
	sty	__rc4
	ldy	#mos16hi(expected)
	sty	__rc5
	stz	__rc6
	ldy	#2
	lda	#160
	sta	__rc8
	sty	__rc9
.LBB1_5:                                ; =>This Inner Loop Header: Depth=1
	lda	__rc9
	beq	.LBB1_13
.LBB1_6:                                ;   in Loop: Header=BB1_5 Depth=1
	lda	(__rc2)
	cmp	(__rc4)
	beq	.LBB1_8
; %bb.7:                                ;   in Loop: Header=BB1_5 Depth=1
	ldx	#0
	stz	__rc6
.LBB1_8:                                ;   in Loop: Header=BB1_5 Depth=1
	inc	__rc2
	bne	.LBB1_10
; %bb.9:                                ;   in Loop: Header=BB1_5 Depth=1
	inc	__rc3
.LBB1_10:                               ;   in Loop: Header=BB1_5 Depth=1
	inc	__rc4
	bne	.LBB1_12
; %bb.11:                               ;   in Loop: Header=BB1_5 Depth=1
	inc	__rc5
.LBB1_12:                               ;   in Loop: Header=BB1_5 Depth=1
	rep	#32
	lda	__rc8
	dec
	sta	__rc8
	sep	#32
	bra	.LBB1_5
.LBB1_13:                               ;   in Loop: Header=BB1_5 Depth=1
	lda	__rc8
	bne	.LBB1_6
; %bb.14:
	lda	__rc6
	bne	.LBB1_16
; %bb.15:
	txa
	beq	.LBB1_19
.LBB1_16:
	ldx	#92
	ldy	#240
.LBB1_17:
	sty	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	sta	corpus_result
	sep	#32
.LBB1_18:                               ; =>This Inner Loop Header: Depth=1
	;APP
	wai
	;NO_APP
	bra	.LBB1_18
.LBB1_19:
	ldx	#165
	ldy	#15
	bra	.LBB1_17
.Lfunc_end1:
	.size	main, .Lfunc_end1-main
                                        ; -- End function
	.type	source,@object                  ; @source
	.section	.data.source,"aw",@progbits
source:
	.short	compressed
	.size	source, 2

	.type	destination,@object             ; @destination
	.section	.data.destination,"aw",@progbits
destination:
	.short	output
	.size	destination, 2

	.type	output,@object                  ; @output
	.section	.bss.output,"aw",@nobits
output:
	.zero	672
	.size	output, 672

	.type	expected,@object                ; @expected
	.section	.rodata.expected,"a",@progbits
expected:
	.ascii	"\000\r\032'4AN[hu\202\217\234\251\266\303\320\335\352\367\004\021\036+8ER_ly\206\223\240\255\272\307\324\341\356\373\b\025\"/<IVcp}\212\227\244\261\276\313\330\345\362\377\f\031&3@MZgt\201\216\233\250\265\302\317\334\351\366\003\020\035*7DQ^kx\205\222\237\254\271\306\323\340\355\372\007\024!.;HUbo|\211\226\243\260\275\312\327\344\361\376\013\030%2?LYfs\200\215\232\247\264\301\316\333\350\365\002\017\034)6CP]jw\204\221\236\253\270\305\322\337\354\371\006\023 -:GTan{\210\225\242\257\274\311\326\343\360\375\n\027$1>KXer\177\214\231\246\263\300\315\332\347\364\001\016\033(5BO\\iv\203\220\235\252\267\304\321\336\353\370\005\022\037,9FS`mz\207\224\241\256\273\310\325\342\357\374\t\026#0=JWdq~\213\230\245\262\277\314\331\346\363+8ER_ly\206\223\240\255\272\307\324\341\356\373\b\025\"/<IVcp}\212\227\244\261\276\313\330\345\362\377\f\031&3@MZgt\201\216\233\250\265\302\317\334\351\366\003\020\035*7DQ^kx\205\222\237\254\271\306\323\340\355\372\007\024!.;HUbo|\211\226\243\260\275\312\327\344\361\376\013\030%2?LYfs\200\215\232\247\264\301\316\333\350\365\002\017\034)6CP]jw\204\221\236s\200\215\232\247\264\301\316\333\350\365\002\017\034)6CP]jw\204\221\236\253\270\305\322\337\354\371\006\023 -:GTan{\210\225\242\257\274\311\326\343\360\375\n\027$1>KXer\177\214\231\246\263\300\315\332\347\364\001\016\033(5BO\\iv\203\220\235\252\267\304\321\336\353\370\005\022\037,9FS`mz\207\224\241\256\273\310\325\342\357\374\t\026#0=JWdq~\213\230\245\262\277\314\331\346\363+8ER_ly\206\223\240\255\272\307\324\341\356\373\b\025\"/<IVcp}\212\227\244\261\276\313\330\345\362\377\f\031&3@MZgt\201\216\233\250\265\302\317\334\351\366\003\020\035*7DQ^kx\205\222\237\254\271\306\323\340\355\372\007\024!.;HUbo|\211\226\243\260\275\312\327\344\361\376\013\030%2?LYfs\200\215\232\247\264\301\316\333\350\365\002\017\034)6CP]jw\204\221\236s\200\215\232\247\264\301\316\333\350\365\002\017\034)6CP]jw\204\221\236\253\270\305\322\337\354\371"
	.size	expected, 672

	.type	corpus_result,@object           ; @corpus_result
	.section	.bss.corpus_result,"aw",@nobits
	.globl	corpus_result
corpus_result:
	.short	0                               ; 0x0
	.size	corpus_result, 2

	.type	compressed,@object              ; @compressed
	.section	.rodata.compressed,"a",@progbits
compressed:
	.ascii	"\000\000\r\032'4AN[\000hu\202\217\234\251\266\303\000\320\335\352\367\004\021\036+\0008ER_ly\206\223\000\240\255\272\307\324\341\356\373\000\b\025\"/<IVc\000p}\212\227\244\261\276\313\000\330\345\362\377\f\031&3\000@MZgt\201\216\233\000\250\265\302\317\334\351\366\003\000\020\035*7DQ^k\000x\205\222\237\254\271\306\323\000\340\355\372\007\024!.;\000HUbo|\211\226\243\000\260\275\312\327\344\361\376\013\000\030%2?LYfs\000\200\215\232\247\264\301\316\333\000\350\365\002\017\034)6C\000P]jw\204\221\236\253\000\270\305\322\337\354\371\006\023\000 -:GTan{\000\210\225\242\257\274\311\326\343\000\360\375\n\027$1>K\000Xer\177\214\231\246\263\000\300\315\332\347\364\001\016\033\000(5BO\\iv\203\000\220\235\252\267\304\321\336\353\000\370\005\022\037,9FS\000`mz\207\224\241\256\273\000\310\325\342\357\374\t\026#\0000=JWdq~\213\000\230\245\262\277\314\331\346\363\000+8ER_ly\206\000\223\240\255\272\307\324\341\356\000\373\b\025\"/<IV\000cp}\212\227\244\261\276\000\313\330\345\362\377\f\031&\0003@MZgt\201\216\000\233\250\265\302\317\334\351\366\000\003\020\035*7DQ^\000kx\205\222\237\254\271\306\000\323\340\355\372\007\024!.\000;HUbo|\211\226\000\243\260\275\312\327\344\361\376\000\013\030%2?LYf\000s\200\215\232\247\264\301\316\000\333\350\365\002\017\034)6\000CP]jw\204\221\236\377\001\037\001\037\001\037\001\037\001\037\001\037\001\037\001\037\377\001\037\001\037\001\037\001\037\001\037\001\037\001\037\001\037"
	.size	compressed, 466

	.type	.Lstatic_stack,@object          ; @static_stack
	.section	.noinit..Lstatic_stack,"aw",@nobits
.Lstatic_stack:
	.zero	22
	.size	.Lstatic_stack, 22

.Ldecode_near_sstk = .Lstatic_stack
	.size	.Ldecode_near_sstk, 22
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym decode_near
	.addrsig_sym source
	.addrsig_sym destination
	.addrsig_sym output
	.addrsig_sym corpus_result
	.addrsig_sym compressed
	.addrsig_sym .Lstatic_stack
	;Declaring this symbol tells the CRT that there is something in .bss, so it may need to be zeroed.
	.globl	__do_zero_bss
	;Declaring this symbol tells the CRT that there is something in .data, so it may need to be copied from LMA to VMA.
	.globl	__do_copy_data
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

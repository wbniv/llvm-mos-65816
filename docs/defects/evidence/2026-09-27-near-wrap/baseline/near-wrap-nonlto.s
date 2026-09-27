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
	.file	"near-wrap.c"
                                        ; Start of file scope inline assembly
	.text
	.globl	wrap_bank7e
wrap_bank7e:
	php
	.byte	139
	.byte	244
	.byte	126
	.byte	126
	.byte	171
	.byte	171
	jsr	near_wrap
	.byte	171
	plp
	rts

                                        ; End of file scope inline assembly
	.section	.text.near_wrap,"ax",@progbits
	.globl	near_wrap                       ; -- Begin function near_wrap
	.type	near_wrap,@function
near_wrap:                              ; @near_wrap
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#16
	ldy	__rc4
	lda	(__rc2),y
	sep	#16
	rts
.Lfunc_end0:
	.size	near_wrap, .Lfunc_end0-near_wrap
                                        ; -- End function
	.section	.text.main,"ax",@progbits
	.globl	main                            ; -- Begin function main
	.type	main,@function
main:                                   ; @main
; %bb.0:
	ldx	#6
	stx	__rc2
	ldx	#168
	stx	__rc3
	lda	#90
	sta	8300546
	lda	#195
	sta	8366082
	lda	#252
	ldx	#255
	jsr	wrap_bank7e
	cmp	#90
	bne	.LBB1_2
; %bb.1:
	ldx	#92
	ldy	#240
	sty	__rc2
	stx	__rc3
	rep	#32
	bra	.LBB1_3
.LBB1_2:
	stz	__rc3
	sta	__rc2
	rep	#32
	lda	__rc2
	ora	#42240
	sta	__rc2
.LBB1_3:
	lda	__rc2
	sta	corpus_result
	sep	#32
.LBB1_4:                                ; =>This Inner Loop Header: Depth=1
	;APP
	wai
	;NO_APP
	bra	.LBB1_4
.Lfunc_end1:
	.size	main, .Lfunc_end1-main
                                        ; -- End function
	.type	corpus_result,@object           ; @corpus_result
	.section	.bss.corpus_result,"aw",@nobits
	.globl	corpus_result
corpus_result:
	.short	0                               ; 0x0
	.size	corpus_result, 2

	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym near_wrap
	.addrsig_sym corpus_result
	;Declaring this symbol tells the CRT that there is something in .bss, so it may need to be zeroed.
	.globl	__do_zero_bss
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

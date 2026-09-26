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
	.file	"input.ll"
	.text
	.globl	trunc_imag8_i1                  ; -- Begin function trunc_imag8_i1
	.type	trunc_imag8_i1,@function
trunc_imag8_i1:                         ; @trunc_imag8_i1
; %bb.0:                                ; %entry
	tay
	txa
	and	#1
	beq	.LBB0_2
; %bb.1:                                ; %subtract
	stx	__rc2
	sec
	tya
	sbc	__rc2
	rts
.LBB0_2:
	tya
	rts
.Lfunc_end0:
	.size	trunc_imag8_i1, .Lfunc_end0-trunc_imag8_i1
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

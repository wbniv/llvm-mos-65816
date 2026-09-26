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
	.file	"far-memset.ll"
	.text
	.globl	far_constant_fill               ; -- Begin function far_constant_fill
	.type	far_constant_fill,@function
far_constant_fill:                      ; @far_constant_fill
; %bb.0:
	ldx	#0
	stx	__rc4
	ldx	#32
	stx	__rc5
	ldx	#126
	stx	__rc6
	ldx	#0
	stx	__rc7
	lda	#66
	ldx	#16
	stx	__rc2
	stz	__rc3
	stz	__rc8
	ldx	#0
	jmp	__memset
.Lfunc_end0:
	.size	far_constant_fill, .Lfunc_end0-far_constant_fill
                                        ; -- End function
	.globl	far_variable_fill               ; -- Begin function far_variable_fill
	.type	far_variable_fill,@function
far_variable_fill:                      ; @far_variable_fill
; %bb.0:
	stz	__rc3
	stz	__rc8
	jmp	__memset
.Lfunc_end1:
	.size	far_variable_fill, .Lfunc_end1-far_variable_fill
                                        ; -- End function
	.globl	near_variable_fill              ; -- Begin function near_variable_fill
	.type	near_variable_fill,@function
near_variable_fill:                     ; @near_variable_fill
; %bb.0:
	jmp	__memset
.Lfunc_end2:
	.size	near_variable_fill, .Lfunc_end2-near_variable_fill
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

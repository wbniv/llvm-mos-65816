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
	.file	"immediate-width-printer.mir"
	.text
	.globl	native_immediates               ; -- Begin function native_immediates
	.type	native_immediates,@function
native_immediates:                      ; @native_immediates
; %bb.0:
	adc	#66
	eor	#255
	cmp	#5
	lda	#256
	ldx	#0
	ldy	#65535
	adc	#66
	rts
.Lfunc_end0:
	.size	native_immediates, .Lfunc_end0-native_immediates
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

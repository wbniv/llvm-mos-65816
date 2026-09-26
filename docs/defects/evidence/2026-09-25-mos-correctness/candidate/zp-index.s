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
	.file	"zp-index.c"
	.section	.text.load_zp,"ax",@progbits
	.globl	load_zp                         ; -- Begin function load_zp
	.type	load_zp,@function
load_zp:                                ; @load_zp
; %bb.0:
	tax
	lda	17,x
	rts
.Lfunc_end0:
	.size	load_zp, .Lfunc_end0-load_zp
                                        ; -- End function
	.section	.text.store_zp,"ax",@progbits
	.globl	store_zp                        ; -- Begin function store_zp
	.type	store_zp,@function
store_zp:                               ; @store_zp
; %bb.0:
	tay
	txa
	pha
	tya
	tax
	pla
	sta	17,x
	rts
.Lfunc_end1:
	.size	store_zp, .Lfunc_end1-store_zp
                                        ; -- End function
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

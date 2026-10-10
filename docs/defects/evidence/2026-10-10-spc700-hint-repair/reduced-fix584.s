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
	.file	"boids-reduced.ll"
	.text
	.globl	main                            ; -- Begin function main
	.type	main,@function
main:                                   ; @main
; %bb.0:
	mov	x,__rc20
	push	x
	mov	x,__rc21
	push	x
	mov	x,__rc22
	push	x
	mov	__rc20,__rc2
	mov	__rc21,__rc3
	mov	__rc22,#95
.LBB0_1:                                ; =>This Inner Loop Header: Depth=1
	mov	y,#0
	mov	a,[__rc20]+y
	mov	__rc18,a
	inc	y
	mov	a,[__rc20]+y
	mov	__rc19,a
	mov	__rc17,#95
	mov	__rc2,#0
	mov	__rc3,#0
	mov	__rc4,#0
	mov	__rc5,#0
	call	__rc17
	bra	.LBB0_1
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

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
	.file	"return-address-spc700.ll"
	.text
	.globl	return_address                  ; -- Begin function return_address
	.type	return_address,@function
return_address:                         ; @return_address
; %bb.0:
	mov	x,s
	mov	a,257+x
	mov	__rc2,a
	mov	x,s
	mov	a,258+x
	mov	__rc3,a
	ret
.Lfunc_end0:
	.size	return_address, .Lfunc_end0-return_address
                                        ; -- End function
	.globl	return_address_after_push       ; -- Begin function return_address_after_push
	.type	return_address_after_push,@function
return_address_after_push:              ; @return_address_after_push
; %bb.0:
	mov	x,__rc20
	push	x
	mov	__rc20,a
	call	keep
	mov	a,__rc20
	call	keep
	mov	x,s
	mov	a,258+x
	mov	__rc2,a
	mov	x,s
	mov	a,259+x
	mov	__rc3,a
	pop	x
	mov	__rc20,x
	ret
.Lfunc_end1:
	.size	return_address_after_push, .Lfunc_end1-return_address_after_push
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

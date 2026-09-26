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
	.file	"additional-controls.ll"
	.text
	.globl	dynamic_frame                   ; -- Begin function dynamic_frame
	.type	dynamic_frame,@function
dynamic_frame:                          ; @dynamic_frame
; %bb.0:
	mov	y,__rc30
	push	y
	mov	y,__rc31
	push	y
	mov	__rc30,__rc0
	mov	__rc31,__rc1
	mov	__rc2,a
	mov	__rc3,x
	mov	a,__rc0
	mov	y,__rc1
	setc
	sbc	a,__rc2
	mov	__rc2,a
	mov	a,y
	sbc	a,__rc3
	mov	__rc3,a
	mov	__rc0,__rc2
	mov	__rc1,__rc3
	call	sink
	clrc
	mov	__rc2,__rc30
	mov	__rc3,__rc31
	mov	__rc0,__rc30
	mov	__rc1,__rc31
	pop	x
	mov	__rc31,x
	pop	x
	mov	__rc30,x
	ret
.Lfunc_end0:
	.size	dynamic_frame, .Lfunc_end0-dynamic_frame
                                        ; -- End function
	.globl	return_address_sign_branch      ; -- Begin function return_address_sign_branch
	.type	return_address_sign_branch,@function
return_address_sign_branch:             ; @return_address_sign_branch
; %bb.0:
	mov	x,s
	mov	a,257+x
	mov	__rc4,a
	mov	x,s
	mov	a,258+x
	mov	__rc2,#0
	mov	__rc3,#0
	mov	x,__rc4
	cmp	x,__rc2
	sbc	a,__rc3
	bvc	.LBB1_2
; %bb.1:
	eor	a,#128
.LBB1_2:
	mov	x,a
	bpl	.LBB1_4
; %bb.3:                                ; %then
	jmp	yes
.LBB1_4:                                ; %else
	jmp	no
.Lfunc_end1:
	.size	return_address_sign_branch, .Lfunc_end1-return_address_sign_branch
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

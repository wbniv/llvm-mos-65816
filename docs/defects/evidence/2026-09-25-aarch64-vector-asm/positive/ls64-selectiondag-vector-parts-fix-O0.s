	.file	"ls64.ll"
	.text
	.globl	ls64                            // -- Begin function ls64
	.p2align	2
	.type	ls64,@function
ls64:                                   // @ls64
	.cfi_startproc
// %bb.0:
	ldr	x2, [x0]
	ldr	x16, [x0, #8]
	ldr	x15, [x0, #16]
	ldr	x14, [x0, #24]
	ldr	x13, [x0, #32]
	ldr	x12, [x0, #40]
	ldr	x11, [x0, #48]
	ldr	x10, [x0, #56]
                                        // kill: def $x2 killed $x2 def $x2_x3_x4_x5_x6_x7_x8_x9
	mov	x3, x16
	mov	x4, x15
	mov	x5, x14
	mov	x6, x13
	mov	x7, x12
	mov	x8, x11
	mov	x9, x10
	//APP
	//NO_APP
	mov	x10, x2
	str	x10, [x0]
	mov	x10, x3
	str	x10, [x0, #8]
	mov	x10, x4
	str	x10, [x0, #16]
	mov	x10, x5
	str	x10, [x0, #24]
	mov	x10, x6
	str	x10, [x0, #32]
	mov	x10, x7
	str	x10, [x0, #40]
	mov	x10, x8
	str	x10, [x0, #48]
	mov	x8, x9
	str	x8, [x0, #56]
	ret
.Lfunc_end0:
	.size	ls64, .Lfunc_end0-ls64
	.cfi_endproc
                                        // -- End function
	.section	".note.GNU-stack","",@progbits

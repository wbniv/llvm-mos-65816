	.file	"supported.ll"
	.text
	.globl	small                           // -- Begin function small
	.p2align	2
	.type	small,@function
small:                                  // @small
	.cfi_startproc
// %bb.0:
	ldr	x8, [x0]
	//APP
	//NO_APP
	str	x8, [x0]
	ret
.Lfunc_end0:
	.size	small, .Lfunc_end0-small
	.cfi_endproc
                                        // -- End function
	.globl	floating                        // -- Begin function floating
	.p2align	2
	.type	floating,@function
floating:                               // @floating
	.cfi_startproc
// %bb.0:
	ldp	w9, w8, [x0]
	//APP
	//NO_APP
	ret
.Lfunc_end1:
	.size	floating, .Lfunc_end1-floating
	.cfi_endproc
                                        // -- End function
	.section	".note.GNU-stack","",@progbits

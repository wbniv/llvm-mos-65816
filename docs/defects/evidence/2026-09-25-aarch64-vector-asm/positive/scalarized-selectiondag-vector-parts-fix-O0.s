	.file	"scalarized.ll"
	.text
	.globl	scalarized                      // -- Begin function scalarized
	.p2align	2
	.type	scalarized,@function
scalarized:                             // @scalarized
	.cfi_startproc
// %bb.0:
	ldr	w11, [x0, #12]
	ldr	w10, [x0, #8]
	ldr	w9, [x0, #4]
	ldr	w8, [x0]
	//APP
	//NO_APP
	str	w11, [x0, #12]
	str	w10, [x0, #8]
	str	w9, [x0, #4]
	str	w8, [x0]
	ret
.Lfunc_end0:
	.size	scalarized, .Lfunc_end0-scalarized
	.cfi_endproc
                                        // -- End function
	.section	".note.GNU-stack","",@progbits

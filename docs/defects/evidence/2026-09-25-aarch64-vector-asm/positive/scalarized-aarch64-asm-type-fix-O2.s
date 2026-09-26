	.file	"scalarized.ll"
	.text
	.globl	scalarized                      // -- Begin function scalarized
	.p2align	2
	.type	scalarized,@function
scalarized:                             // @scalarized
	.cfi_startproc
// %bb.0:
	ldp	w9, w8, [x0, #8]
	ldp	w11, w10, [x0]
	//APP
	//NO_APP
	stp	w9, w8, [x0, #8]
	stp	w11, w10, [x0]
	ret
.Lfunc_end0:
	.size	scalarized, .Lfunc_end0-scalarized
	.cfi_endproc
                                        // -- End function
	.section	".note.GNU-stack","",@progbits

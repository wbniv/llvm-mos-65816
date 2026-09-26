	.file	"ls64.ll"
	.text
	.globl	ls64                            // -- Begin function ls64
	.p2align	2
	.type	ls64,@function
ls64:                                   // @ls64
	.cfi_startproc
// %bb.0:
	ldp	x8, x9, [x0, #48]
	ldp	x6, x7, [x0, #32]
	ldp	x4, x5, [x0, #16]
	ldp	x2, x3, [x0]
	//APP
	//NO_APP
	stp	x8, x9, [x0, #48]
	stp	x6, x7, [x0, #32]
	stp	x4, x5, [x0, #16]
	stp	x2, x3, [x0]
	ret
.Lfunc_end0:
	.size	ls64, .Lfunc_end0-ls64
	.cfi_endproc
                                        // -- End function
	.section	".note.GNU-stack","",@progbits

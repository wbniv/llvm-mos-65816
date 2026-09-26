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
	.file	"native-copy-controls.ll"
	.text
	.globl	runtime_far_to_near             ; -- Begin function runtime_far_to_near
	.type	runtime_far_to_near,@function
runtime_far_to_near:                    ; @runtime_far_to_near
; %bb.0:
	rep	#32
	lda	[__rc4]
	sta	nearword
	sep	#32
	rts
.Lfunc_end0:
	.size	runtime_far_to_near, .Lfunc_end0-runtime_far_to_near
                                        ; -- End function
	.globl	runtime_far_to_far              ; -- Begin function runtime_far_to_far
	.type	runtime_far_to_far,@function
runtime_far_to_far:                     ; @runtime_far_to_far
; %bb.0:
	rep	#32
	lda	[__rc4]
	sta	[__rc8]
	sep	#32
	rts
.Lfunc_end1:
	.size	runtime_far_to_far, .Lfunc_end1-runtime_far_to_far
                                        ; -- End function
	.globl	global_far_to_runtime           ; -- Begin function global_far_to_runtime
	.type	global_far_to_runtime,@function
global_far_to_runtime:                  ; @global_far_to_runtime
; %bb.0:
	rep	#32
	lda	mos24(farword)
	sta	[__rc4]
	sep	#32
	rts
.Lfunc_end2:
	.size	global_far_to_runtime, .Lfunc_end2-global_far_to_runtime
                                        ; -- End function
	.globl	runtime_far_copy_order          ; -- Begin function runtime_far_copy_order
	.type	runtime_far_copy_order,@function
runtime_far_copy_order:                 ; @runtime_far_copy_order
; %bb.0:
	rep	#32
	lda	[__rc4]
	sta	__rc2
	sep	#32
	lda	#146
	sta	mos24(farword)
	lda	#16
	sta	mos24(farword+1)
	rep	#32
	lda	__rc2
	sta	[__rc8]
	sep	#32
	rts
.Lfunc_end3:
	.size	runtime_far_copy_order, .Lfunc_end3-runtime_far_copy_order
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

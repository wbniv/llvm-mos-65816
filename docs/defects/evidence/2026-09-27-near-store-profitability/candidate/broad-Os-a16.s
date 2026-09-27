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
	.file	"broad.c"
	.section	.text.absolute_decrement,"ax",@progbits
	.globl	absolute_decrement              ; -- Begin function absolute_decrement
	.type	absolute_decrement,@function
absolute_decrement:                     ; @absolute_decrement
; %bb.0:
	sta	g
	stx	g+1
	dec
	cmp	#255
	bne	.LBB0_2
; %bb.1:
	dex
.LBB0_2:
	rts
.Lfunc_end0:
	.size	absolute_decrement, .Lfunc_end0-absolute_decrement
                                        ; -- End function
	.section	.text.indirect_decrement,"ax",@progbits
	.globl	indirect_decrement              ; -- Begin function indirect_decrement
	.type	indirect_decrement,@function
indirect_decrement:                     ; @indirect_decrement
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	sta	(__rc2)
	sep	#32
	lda	__rc4
	dec
	cmp	#255
	bne	.LBB1_2
; %bb.1:
	dex
.LBB1_2:
	rts
.Lfunc_end1:
	.size	indirect_decrement, .Lfunc_end1-indirect_decrement
                                        ; -- End function
	.section	.text.volatile_increment,"ax",@progbits
	.globl	volatile_increment              ; -- Begin function volatile_increment
	.type	volatile_increment,@function
volatile_increment:                     ; @volatile_increment
; %bb.0:
	sta	__rc4
	sta	(__rc2)
	ldy	#1
	txa
	sta	(__rc2),y
	inc	__rc4
	bne	.LBB2_2
; %bb.1:
	inc
.LBB2_2:
	tax
	lda	__rc4
	rts
.Lfunc_end2:
	.size	volatile_increment, .Lfunc_end2-volatile_increment
                                        ; -- End function
	.section	.text.volatile_decrement,"ax",@progbits
	.globl	volatile_decrement              ; -- Begin function volatile_decrement
	.type	volatile_decrement,@function
volatile_decrement:                     ; @volatile_decrement
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	sta	(__rc2)
	sep	#32
	lda	__rc4
	dec
	cmp	#255
	bne	.LBB3_2
; %bb.1:
	dex
.LBB3_2:
	rts
.Lfunc_end3:
	.size	volatile_decrement, .Lfunc_end3-volatile_decrement
                                        ; -- End function
	.section	.text.indirect_add_two,"ax",@progbits
	.globl	indirect_add_two                ; -- Begin function indirect_add_two
	.type	indirect_add_two,@function
indirect_add_two:                       ; @indirect_add_two
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	sta	(__rc2)
	lda	__rc4
	clc
	adc	#mos16(2)
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	rts
.Lfunc_end4:
	.size	indirect_add_two, .Lfunc_end4-indirect_add_two
                                        ; -- End function
	.section	.text.indirect_increment_result,"ax",@progbits
	.globl	indirect_increment_result       ; -- Begin function indirect_increment_result
	.type	indirect_increment_result,@function
indirect_increment_result:              ; @indirect_increment_result
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	sta	(__rc2)
	lda	__rc4
	inc
	sta	g
	sep	#32
	rts
.Lfunc_end5:
	.size	indirect_increment_result, .Lfunc_end5-indirect_increment_result
                                        ; -- End function
	.section	.text.indirect_decrement_result,"ax",@progbits
	.globl	indirect_decrement_result       ; -- Begin function indirect_decrement_result
	.type	indirect_decrement_result,@function
indirect_decrement_result:              ; @indirect_decrement_result
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	sta	(__rc2)
	lda	__rc4
	dec
	sta	g
	sep	#32
	rts
.Lfunc_end6:
	.size	indirect_decrement_result, .Lfunc_end6-indirect_decrement_result
                                        ; -- End function
	.section	.text.indirect_twice_increment,"ax",@progbits
	.globl	indirect_twice_increment        ; -- Begin function indirect_twice_increment
	.type	indirect_twice_increment,@function
indirect_twice_increment:               ; @indirect_twice_increment
; %bb.0:
	sta	__rc6
	stx	__rc7
	rep	#32
	lda	__rc6
	sta	(__rc2)
	lda	__rc6
	sta	(__rc4)
	lda	__rc6
	inc
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	rts
.Lfunc_end7:
	.size	indirect_twice_increment, .Lfunc_end7-indirect_twice_increment
                                        ; -- End function
	.section	.text.indirect_return_call,"ax",@progbits
	.globl	indirect_return_call            ; -- Begin function indirect_return_call
	.type	indirect_return_call,@function
indirect_return_call:                   ; @indirect_return_call
; %bb.0:
	ldx	__rc20
	phx
	ldx	__rc21
	phx
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	jsr	produce
	sta	(__rc20)
	sta	__rc2
	ldy	#1
	txa
	sta	(__rc20),y
	lda	__rc2
	ply
	sty	__rc21
	ply
	sty	__rc20
	rts
.Lfunc_end8:
	.size	indirect_return_call, .Lfunc_end8-indirect_return_call
                                        ; -- End function
	.section	.text.indirect_call_increment,"ax",@progbits
	.globl	indirect_call_increment         ; -- Begin function indirect_call_increment
	.type	indirect_call_increment,@function
indirect_call_increment:                ; @indirect_call_increment
; %bb.0:
	ldx	__rc20
	phx
	ldx	__rc21
	phx
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	jsr	produce
	sta	__rc2
	stx	__rc3
	rep	#32
	lda	__rc2
	inc
	sta	(__rc20)
	sep	#32
	plx
	stx	__rc21
	plx
	stx	__rc20
	rts
.Lfunc_end9:
	.size	indirect_call_increment, .Lfunc_end9-indirect_call_increment
                                        ; -- End function
	.section	.text.indirect_byte_load,"ax",@progbits
	.globl	indirect_byte_load              ; -- Begin function indirect_byte_load
	.type	indirect_byte_load,@function
indirect_byte_load:                     ; @indirect_byte_load
; %bb.0:
	lda	byte
	sta	(__rc2)
	ldy	#1
	lda	#0
	sta	(__rc2),y
	rts
.Lfunc_end10:
	.size	indirect_byte_load, .Lfunc_end10-indirect_byte_load
                                        ; -- End function
	.section	.text.indirect_byte_pointer,"ax",@progbits
	.globl	indirect_byte_pointer           ; -- Begin function indirect_byte_pointer
	.type	indirect_byte_pointer,@function
indirect_byte_pointer:                  ; @indirect_byte_pointer
; %bb.0:
	lda	(__rc4)
	sta	(__rc2)
	ldy	#1
	lda	#0
	sta	(__rc2),y
	rts
.Lfunc_end11:
	.size	indirect_byte_pointer, .Lfunc_end11-indirect_byte_pointer
                                        ; -- End function
	.section	.text.indirect_byte_native,"ax",@progbits
	.globl	indirect_byte_native            ; -- Begin function indirect_byte_native
	.type	indirect_byte_native,@function
indirect_byte_native:                   ; @indirect_byte_native
; %bb.0:
	sta	__rc4
	stz	__rc5
	rep	#32
	lda	h
	clc
	adc	#mos16(42)
	sta	h
	lda	__rc4
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end12:
	.size	indirect_byte_native, .Lfunc_end12-indirect_byte_native
                                        ; -- End function
	.section	.text.indirect_byte_return,"ax",@progbits
	.globl	indirect_byte_return            ; -- Begin function indirect_byte_return
	.type	indirect_byte_return,@function
indirect_byte_return:                   ; @indirect_byte_return
; %bb.0:
	sta	(__rc2)
	sta	__rc4
	ldy	#1
	lda	#0
	sta	(__rc2),y
	tax
	lda	__rc4
	rts
.Lfunc_end13:
	.size	indirect_byte_return, .Lfunc_end13-indirect_byte_return
                                        ; -- End function
	.section	.text.indirect_byte_call,"ax",@progbits
	.globl	indirect_byte_call              ; -- Begin function indirect_byte_call
	.type	indirect_byte_call,@function
indirect_byte_call:                     ; @indirect_byte_call
; %bb.0:
	ldx	__rc20
	phx
	ldx	__rc21
	phx
	ldx	__rc22
	phx
	ldx	__rc23
	phx
	sta	__rc22
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	jsr	opaque
	stz	__rc23
	rep	#32
	lda	__rc22
	sta	(__rc20)
	sep	#32
	plx
	stx	__rc23
	plx
	stx	__rc22
	plx
	stx	__rc21
	plx
	stx	__rc20
	rts
.Lfunc_end14:
	.size	indirect_byte_call, .Lfunc_end14-indirect_byte_call
                                        ; -- End function
	.section	.text.indirect_byte_twice,"ax",@progbits
	.globl	indirect_byte_twice             ; -- Begin function indirect_byte_twice
	.type	indirect_byte_twice,@function
indirect_byte_twice:                    ; @indirect_byte_twice
; %bb.0:
	sta	__rc6
	stz	__rc7
	rep	#32
	lda	__rc6
	sta	(__rc2)
	lda	__rc6
	sta	(__rc4)
	sep	#32
	rts
.Lfunc_end15:
	.size	indirect_byte_twice, .Lfunc_end15-indirect_byte_twice
                                        ; -- End function
	.section	.text.loaded_pointer_byte,"ax",@progbits
	.globl	loaded_pointer_byte             ; -- Begin function loaded_pointer_byte
	.type	loaded_pointer_byte,@function
loaded_pointer_byte:                    ; @loaded_pointer_byte
; %bb.0:
	sta	__rc4
	stz	__rc5
	rep	#32
	lda	(__rc2)
	sta	__rc2
	lda	__rc4
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end16:
	.size	loaded_pointer_byte, .Lfunc_end16-loaded_pointer_byte
                                        ; -- End function
	.section	.text.loaded_pointer_increment,"ax",@progbits
	.globl	loaded_pointer_increment        ; -- Begin function loaded_pointer_increment
	.type	loaded_pointer_increment,@function
loaded_pointer_increment:               ; @loaded_pointer_increment
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	(__rc2)
	sta	__rc2
	lda	__rc4
	sta	(__rc2)
	lda	__rc4
	inc
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	rts
.Lfunc_end17:
	.size	loaded_pointer_increment, .Lfunc_end17-loaded_pointer_increment
                                        ; -- End function
	.section	.text.absolute_decrement_call,"ax",@progbits
	.globl	absolute_decrement_call         ; -- Begin function absolute_decrement_call
	.type	absolute_decrement_call,@function
absolute_decrement_call:                ; @absolute_decrement_call
; %bb.0:
	ldy	__rc20
	phy
	ldy	__rc21
	phy
	sta	__rc20
	stx	__rc21
	jsr	opaque
	rep	#32
	lda	__rc20
	sta	g
	lda	__rc20
	dec
	sta	__rc2
	sep	#32
	ldx	__rc3
	lda	__rc2
	ply
	sty	__rc21
	ply
	sty	__rc20
	rts
.Lfunc_end18:
	.size	absolute_decrement_call, .Lfunc_end18-absolute_decrement_call
                                        ; -- End function
	.section	.text.absolute_decrement_native,"ax",@progbits
	.globl	absolute_decrement_native       ; -- Begin function absolute_decrement_native
	.type	absolute_decrement_native,@function
absolute_decrement_native:              ; @absolute_decrement_native
; %bb.0:
	tay
	rep	#32
	lda	h
	clc
	adc	#mos16(42)
	sta	h
	sep	#32
	sty	g
	stx	g+1
	tya
	dec
	cmp	#255
	bne	.LBB19_2
; %bb.1:
	dex
.LBB19_2:
	rts
.Lfunc_end19:
	.size	absolute_decrement_native, .Lfunc_end19-absolute_decrement_native
                                        ; -- End function
	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym g
	.addrsig_sym byte
	.addrsig_sym h
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

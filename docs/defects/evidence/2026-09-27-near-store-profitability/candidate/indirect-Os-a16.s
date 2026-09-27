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
	.file	"indirect.c"
	.section	.text.simple,"ax",@progbits
	.globl	simple                          ; -- Begin function simple
	.type	simple,@function
simple:                                 ; @simple
; %bb.0:
	sta	(__rc2)
	ldy	#1
	txa
	sta	(__rc2),y
	rts
.Lfunc_end0:
	.size	simple, .Lfunc_end0-simple
                                        ; -- End function
	.section	.text.vol,"ax",@progbits
	.globl	vol                             ; -- Begin function vol
	.type	vol,@function
vol:                                    ; @vol
; %bb.0:
	sta	(__rc2)
	ldy	#1
	txa
	sta	(__rc2),y
	rts
.Lfunc_end1:
	.size	vol, .Lfunc_end1-vol
                                        ; -- End function
	.section	.text.ret,"ax",@progbits
	.globl	ret                             ; -- Begin function ret
	.type	ret,@function
ret:                                    ; @ret
; %bb.0:
	sta	(__rc2)
	sta	__rc4
	ldy	#1
	txa
	sta	(__rc2),y
	lda	__rc4
	rts
.Lfunc_end2:
	.size	ret, .Lfunc_end2-ret
                                        ; -- End function
	.section	.text.twice,"ax",@progbits
	.globl	twice                           ; -- Begin function twice
	.type	twice,@function
twice:                                  ; @twice
; %bb.0:
	sta	__rc6
	stx	__rc7
	rep	#32
	lda	__rc6
	sta	(__rc2)
	lda	__rc6
	sta	(__rc4)
	sep	#32
	rts
.Lfunc_end3:
	.size	twice, .Lfunc_end3-twice
                                        ; -- End function
	.section	.text.abs_and_indir,"ax",@progbits
	.globl	abs_and_indir                   ; -- Begin function abs_and_indir
	.type	abs_and_indir,@function
abs_and_indir:                          ; @abs_and_indir
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	sta	(__rc2)
	lda	__rc4
	sta	g
	sep	#32
	rts
.Lfunc_end4:
	.size	abs_and_indir, .Lfunc_end4-abs_and_indir
                                        ; -- End function
	.section	.text.offset,"ax",@progbits
	.globl	offset                          ; -- Begin function offset
	.type	offset,@function
offset:                                 ; @offset
; %bb.0:
	sta	__rc4
	stx	__rc5
	ldy	#2
	rep	#32
	lda	__rc4
	sta	(__rc2),y
	sep	#32
	rts
.Lfunc_end5:
	.size	offset, .Lfunc_end5-offset
                                        ; -- End function
	.section	.text.indexed,"ax",@progbits
	.globl	indexed                         ; -- Begin function indexed
	.type	indexed,@function
indexed:                                ; @indexed
; %bb.0:
	sta	__rc6
	stx	__rc8
	ldx	__rc4
	stx	__rc9
	stz	__rc7
	rep	#32
	lda	__rc6
	asl
	sta	__rc4
	lda	__rc2
	clc
	adc	__rc4
	sta	__rc2
	lda	__rc8
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end6:
	.size	indexed, .Lfunc_end6-indexed
                                        ; -- End function
	.section	.text.call,"ax",@progbits
	.globl	call                            ; -- Begin function call
	.type	call,@function
call:                                   ; @call
; %bb.0:
	ldy	__rc20
	phy
	ldy	__rc21
	phy
	ldy	__rc22
	phy
	ldy	__rc23
	phy
	sta	__rc22
	stx	__rc23
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	jsr	opaque
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
.Lfunc_end7:
	.size	call, .Lfunc_end7-call
                                        ; -- End function
	.section	.text.conditional,"ax",@progbits
	.globl	conditional                     ; -- Begin function conditional
	.type	conditional,@function
conditional:                            ; @conditional
; %bb.0:
	ldy	__rc20
	phy
	ldy	__rc21
	phy
	ldy	__rc22
	phy
	ldy	__rc23
	phy
	sta	__rc22
	stx	__rc23
	ldx	__rc2
	stx	__rc20
	ldx	__rc3
	stx	__rc21
	lda	__rc4
	beq	.LBB8_2
; %bb.1:
	jsr	opaque
.LBB8_2:
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
.Lfunc_end8:
	.size	conditional, .Lfunc_end8-conditional
                                        ; -- End function
	.section	.text.result,"ax",@progbits
	.globl	result                          ; -- Begin function result
	.type	result,@function
result:                                 ; @result
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
	ldy	#1
	txa
	sta	(__rc20),y
	plx
	stx	__rc21
	plx
	stx	__rc20
	rts
.Lfunc_end9:
	.size	result, .Lfunc_end9-result
                                        ; -- End function
	.section	.text.add,"ax",@progbits
	.globl	add                             ; -- Begin function add
	.type	add,@function
add:                                    ; @add
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	__rc4
	clc
	adc	#mos16(42)
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end10:
	.size	add, .Lfunc_end10-add
                                        ; -- End function
	.section	.text.copy,"ax",@progbits
	.globl	copy                            ; -- Begin function copy
	.type	copy,@function
copy:                                   ; @copy
; %bb.0:
	rep	#32
	lda	g
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end11:
	.size	copy, .Lfunc_end11-copy
                                        ; -- End function
	.section	.text.mixed,"ax",@progbits
	.globl	mixed                           ; -- Begin function mixed
	.type	mixed,@function
mixed:                                  ; @mixed
; %bb.0:
	sta	__rc4
	sta	(__rc2)
	ldy	#1
	txa
	sta	(__rc2),y
	inc	__rc4
	bne	.LBB12_2
; %bb.1:
	inc
.LBB12_2:
	tax
	lda	__rc4
	rts
.Lfunc_end12:
	.size	mixed, .Lfunc_end12-mixed
                                        ; -- End function
	.section	.text.native_context,"ax",@progbits
	.globl	native_context                  ; -- Begin function native_context
	.type	native_context,@function
native_context:                         ; @native_context
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	h
	clc
	adc	#mos16(42)
	sta	h
	lda	__rc4
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end13:
	.size	native_context, .Lfunc_end13-native_context
                                        ; -- End function
	.section	.text.loadptr,"ax",@progbits
	.globl	loadptr                         ; -- Begin function loadptr
	.type	loadptr,@function
loadptr:                                ; @loadptr
; %bb.0:
	sta	__rc4
	stx	__rc5
	rep	#32
	lda	(__rc2)
	sta	__rc2
	lda	__rc4
	sta	(__rc2)
	sep	#32
	rts
.Lfunc_end14:
	.size	loadptr, .Lfunc_end14-loadptr
                                        ; -- End function
	.section	.text.byte_value,"ax",@progbits
	.globl	byte_value                      ; -- Begin function byte_value
	.type	byte_value,@function
byte_value:                             ; @byte_value
; %bb.0:
	sta	(__rc2)
	ldy	#1
	lda	#0
	sta	(__rc2),y
	rts
.Lfunc_end15:
	.size	byte_value, .Lfunc_end15-byte_value
                                        ; -- End function
	.section	.text.third,"ax",@progbits
	.globl	third                           ; -- Begin function third
	.type	third,@function
third:                                  ; @third
; %bb.0:
	tay
	rep	#32
	lda	__rc4
	sta	(__rc2)
	sep	#32
	sty	g
	stx	g+1
	rts
.Lfunc_end16:
	.size	third, .Lfunc_end16-third
                                        ; -- End function
	.type	g,@object                       ; @g
	.section	.bss.g,"aw",@nobits
	.globl	g
g:
	.short	0                               ; 0x0
	.size	g, 2

	.type	h,@object                       ; @h
	.section	.bss.h,"aw",@nobits
	.globl	h
h:
	.short	0                               ; 0x0
	.size	h, 2

	.ident	"clang version 23.0.0git (https://github.com/llvm-mos/llvm-mos.git 8be0546128a55e78c63ca571d466aa72a782cd36)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym g
	.addrsig_sym h
	;Declaring this symbol tells the CRT that there is something in .bss, so it may need to be zeroed.
	.globl	__do_zero_bss
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

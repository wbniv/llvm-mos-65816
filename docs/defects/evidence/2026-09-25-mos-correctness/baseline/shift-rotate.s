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
	.file	"shift-rotate.ll"
	.text
	.globl	shl_1                           ; -- Begin function shl_1
	.type	shl_1,@function
shl_1:                                  ; @shl_1
; %bb.0:                                ; %entry
	stx	__rc2
	asl
	rol	__rc2
	ldx	__rc2
	rts
.Lfunc_end0:
	.size	shl_1, .Lfunc_end0-shl_1
                                        ; -- End function
	.globl	shl_2                           ; -- Begin function shl_2
	.type	shl_2,@function
shl_2:                                  ; @shl_2
; %bb.0:                                ; %entry
	stx	__rc2
	asl
	rol	__rc2
	asl
	rol	__rc2
	ldx	__rc2
	rts
.Lfunc_end1:
	.size	shl_2, .Lfunc_end1-shl_2
                                        ; -- End function
	.globl	shl_4                           ; -- Begin function shl_4
	.type	shl_4,@function
shl_4:                                  ; @shl_4
; %bb.0:                                ; %entry
	stx	__rc2
	asl
	rol	__rc2
	asl
	rol	__rc2
	asl
	rol	__rc2
	asl
	rol	__rc2
	ldx	__rc2
	rts
.Lfunc_end2:
	.size	shl_4, .Lfunc_end2-shl_4
                                        ; -- End function
	.globl	shl_5                           ; -- Begin function shl_5
	.type	shl_5,@function
shl_5:                                  ; @shl_5
; %bb.0:                                ; %entry
	sta	__rc2
	stx	__rc3
	lsr	__rc3
	ror	__rc2
	lda	#0
	ror
	lsr	__rc3
	ror	__rc2
	ror
	lsr	__rc3
	ror	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end3:
	.size	shl_5, .Lfunc_end3-shl_5
                                        ; -- End function
	.globl	shl_7                           ; -- Begin function shl_7
	.type	shl_7,@function
shl_7:                                  ; @shl_7
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	lsr
	ror	__rc2
	lda	#0
	ror
	ldx	__rc2
	rts
.Lfunc_end4:
	.size	shl_7, .Lfunc_end4-shl_7
                                        ; -- End function
	.globl	shl_8                           ; -- Begin function shl_8
	.type	shl_8,@function
shl_8:                                  ; @shl_8
; %bb.0:                                ; %entry
	tax
	lda	#0
	rts
.Lfunc_end5:
	.size	shl_8, .Lfunc_end5-shl_8
                                        ; -- End function
	.globl	shl_15                          ; -- Begin function shl_15
	.type	shl_15,@function
shl_15:                                 ; @shl_15
; %bb.0:                                ; %entry
	lsr
	lda	#0
	ror
	tax
	lda	#0
	ror
	rts
.Lfunc_end6:
	.size	shl_15, .Lfunc_end6-shl_15
                                        ; -- End function
	.globl	shl_32_1                        ; -- Begin function shl_32_1
	.type	shl_32_1,@function
shl_32_1:                               ; @shl_32_1
; %bb.0:                                ; %entry
	stx	__rc4
	asl
	rol	__rc4
	rol	__rc2
	rol	__rc3
	ldx	__rc4
	rts
.Lfunc_end7:
	.size	shl_32_1, .Lfunc_end7-shl_32_1
                                        ; -- End function
	.globl	lshr_1                          ; -- Begin function lshr_1
	.type	lshr_1,@function
lshr_1:                                 ; @lshr_1
; %bb.0:                                ; %entry
	stx	__rc2
	lsr	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end8:
	.size	lshr_1, .Lfunc_end8-lshr_1
                                        ; -- End function
	.globl	lshr_2                          ; -- Begin function lshr_2
	.type	lshr_2,@function
lshr_2:                                 ; @lshr_2
; %bb.0:                                ; %entry
	stx	__rc2
	lsr	__rc2
	ror
	lsr	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end9:
	.size	lshr_2, .Lfunc_end9-lshr_2
                                        ; -- End function
	.globl	lshr_4                          ; -- Begin function lshr_4
	.type	lshr_4,@function
lshr_4:                                 ; @lshr_4
; %bb.0:                                ; %entry
	stx	__rc2
	lsr	__rc2
	ror
	lsr	__rc2
	ror
	lsr	__rc2
	ror
	lsr	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end10:
	.size	lshr_4, .Lfunc_end10-lshr_4
                                        ; -- End function
	.globl	lshr_5                          ; -- Begin function lshr_5
	.type	lshr_5,@function
lshr_5:                                 ; @lshr_5
; %bb.0:                                ; %entry
	sta	__rc3
	stx	__rc2
	asl	__rc3
	rol	__rc2
	lda	#0
	rol
	asl	__rc3
	rol	__rc2
	rol
	asl	__rc3
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end11:
	.size	lshr_5, .Lfunc_end11-lshr_5
                                        ; -- End function
	.globl	lshr_7                          ; -- Begin function lshr_7
	.type	lshr_7,@function
lshr_7:                                 ; @lshr_7
; %bb.0:                                ; %entry
	stx	__rc2
	asl
	rol	__rc2
	lda	#0
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end12:
	.size	lshr_7, .Lfunc_end12-lshr_7
                                        ; -- End function
	.globl	lshr_8                          ; -- Begin function lshr_8
	.type	lshr_8,@function
lshr_8:                                 ; @lshr_8
; %bb.0:                                ; %entry
	txa
	ldx	#0
	rts
.Lfunc_end13:
	.size	lshr_8, .Lfunc_end13-lshr_8
                                        ; -- End function
	.globl	lshr_15                         ; -- Begin function lshr_15
	.type	lshr_15,@function
lshr_15:                                ; @lshr_15
; %bb.0:                                ; %entry
	txa
	asl
	lda	#0
	rol
	tay
	lda	#0
	rol
	tax
	tya
	rts
.Lfunc_end14:
	.size	lshr_15, .Lfunc_end14-lshr_15
                                        ; -- End function
	.globl	ashr_1                          ; -- Begin function ashr_1
	.type	ashr_1,@function
ashr_1:                                 ; @ashr_1
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	ror
	ror	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end15:
	.size	ashr_1, .Lfunc_end15-ashr_1
                                        ; -- End function
	.globl	ashr_2                          ; -- Begin function ashr_2
	.type	ashr_2,@function
ashr_2:                                 ; @ashr_2
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	ror
	ror	__rc2
	cmp	#128
	ror
	ror	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end16:
	.size	ashr_2, .Lfunc_end16-ashr_2
                                        ; -- End function
	.globl	ashr_4                          ; -- Begin function ashr_4
	.type	ashr_4,@function
ashr_4:                                 ; @ashr_4
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	ror
	ror	__rc2
	cmp	#128
	ror
	ror	__rc2
	cmp	#128
	ror
	ror	__rc2
	cmp	#128
	ror
	ror	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end17:
	.size	ashr_4, .Lfunc_end17-ashr_4
                                        ; -- End function
	.globl	ashr_5                          ; -- Begin function ashr_5
	.type	ashr_5,@function
ashr_5:                                 ; @ashr_5
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	bpl	.LBB18_2
; %bb.1:                                ; %entry
	ldx	#255
	jmp	.LBB18_3
.LBB18_2:                               ; %entry
	ldx	#0
.LBB18_3:                               ; %entry
	asl	__rc2
	rol
	stx	__rc3
	rol	__rc3
	asl	__rc2
	rol
	rol	__rc3
	asl	__rc2
	rol
	rol	__rc3
	ldx	__rc3
	rts
.Lfunc_end18:
	.size	ashr_5, .Lfunc_end18-ashr_5
                                        ; -- End function
	.globl	ashr_7                          ; -- Begin function ashr_7
	.type	ashr_7,@function
ashr_7:                                 ; @ashr_7
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	bpl	.LBB19_2
; %bb.1:                                ; %entry
	ldx	#255
	jmp	.LBB19_3
.LBB19_2:                               ; %entry
	ldx	#0
.LBB19_3:                               ; %entry
	asl	__rc2
	rol
	stx	__rc2
	rol	__rc2
	ldx	__rc2
	rts
.Lfunc_end19:
	.size	ashr_7, .Lfunc_end19-ashr_7
                                        ; -- End function
	.globl	ashr_8                          ; -- Begin function ashr_8
	.type	ashr_8,@function
ashr_8:                                 ; @ashr_8
; %bb.0:                                ; %entry
	stx	__rc2
	txa
	bpl	.LBB20_2
; %bb.1:                                ; %entry
	lda	#255
	jmp	.LBB20_3
.LBB20_2:                               ; %entry
	lda	#0
.LBB20_3:                               ; %entry
	stx	__rc3
	asl	__rc3
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end20:
	.size	ashr_8, .Lfunc_end20-ashr_8
                                        ; -- End function
	.globl	ashr_15                         ; -- Begin function ashr_15
	.type	ashr_15,@function
ashr_15:                                ; @ashr_15
; %bb.0:                                ; %entry
	stx	__rc2
	txa
	bpl	.LBB21_2
; %bb.1:                                ; %entry
	lda	#255
	jmp	.LBB21_3
.LBB21_2:                               ; %entry
	lda	#0
.LBB21_3:                               ; %entry
	asl	__rc2
	ldx	#1
	bcs	.LBB21_5
; %bb.4:                                ; %entry
	ldx	#0
.LBB21_5:                               ; %entry
	rol
	bpl	.LBB21_7
; %bb.6:                                ; %entry
	ldy	#255
	jmp	.LBB21_8
.LBB21_7:                               ; %entry
	ldy	#0
.LBB21_8:                               ; %entry
	cpx	#1
	rol
	sty	__rc2
	rol	__rc2
	ldx	__rc2
	rts
.Lfunc_end21:
	.size	ashr_15, .Lfunc_end21-ashr_15
                                        ; -- End function
	.globl	ashr_16                         ; -- Begin function ashr_16
	.type	ashr_16,@function
ashr_16:                                ; @ashr_16
; %bb.0:                                ; %entry
	ldy	__rc2
	ldx	__rc3
	stx	__rc4
	bpl	.LBB22_2
; %bb.1:                                ; %entry
	lda	#255
	jmp	.LBB22_3
.LBB22_2:                               ; %entry
	lda	#0
.LBB22_3:                               ; %entry
	ldx	__rc3
	stx	__rc2
	asl	__rc2
	rol
	sta	__rc2
	sta	__rc3
	ldx	__rc4
	tya
	rts
.Lfunc_end22:
	.size	ashr_16, .Lfunc_end22-ashr_16
                                        ; -- End function
	.globl	rol_1                           ; -- Begin function rol_1
	.type	rol_1,@function
rol_1:                                  ; @rol_1
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end23:
	.size	rol_1, .Lfunc_end23-rol_1
                                        ; -- End function
	.globl	rol_2                           ; -- Begin function rol_2
	.type	rol_2,@function
rol_2:                                  ; @rol_2
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end24:
	.size	rol_2, .Lfunc_end24-rol_2
                                        ; -- End function
	.globl	rol_4                           ; -- Begin function rol_4
	.type	rol_4,@function
rol_4:                                  ; @rol_4
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end25:
	.size	rol_4, .Lfunc_end25-rol_4
                                        ; -- End function
	.globl	rol_5                           ; -- Begin function rol_5
	.type	rol_5,@function
rol_5:                                  ; @rol_5
; %bb.0:                                ; %entry
	stx	__rc2
	stx	__rc3
	lsr	__rc3
	ror
	ror	__rc2
	ldx	__rc2
	stx	__rc3
	lsr	__rc3
	ror
	ror	__rc2
	ldx	__rc2
	stx	__rc3
	lsr	__rc3
	ror
	ror	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end26:
	.size	rol_5, .Lfunc_end26-rol_5
                                        ; -- End function
	.globl	rol_7                           ; -- Begin function rol_7
	.type	rol_7,@function
rol_7:                                  ; @rol_7
; %bb.0:                                ; %entry
	stx	__rc2
	stx	__rc3
	lsr	__rc3
	ror
	ror	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end27:
	.size	rol_7, .Lfunc_end27-rol_7
                                        ; -- End function
	.globl	rol_8                           ; -- Begin function rol_8
	.type	rol_8,@function
rol_8:                                  ; @rol_8
; %bb.0:                                ; %entry
	stx	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end28:
	.size	rol_8, .Lfunc_end28-rol_8
                                        ; -- End function
	.globl	rol_15                          ; -- Begin function rol_15
	.type	rol_15,@function
rol_15:                                 ; @rol_15
; %bb.0:                                ; %entry
	stx	__rc2
	sta	__rc3
	lsr	__rc3
	ror	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end29:
	.size	rol_15, .Lfunc_end29-rol_15
                                        ; -- End function
	.globl	ror_1                           ; -- Begin function ror_1
	.type	ror_1,@function
ror_1:                                  ; @ror_1
; %bb.0:                                ; %entry
	stx	__rc2
	sta	__rc3
	lsr	__rc3
	ror	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end30:
	.size	ror_1, .Lfunc_end30-ror_1
                                        ; -- End function
	.globl	ror_2                           ; -- Begin function ror_2
	.type	ror_2,@function
ror_2:                                  ; @ror_2
; %bb.0:                                ; %entry
	stx	__rc2
	sta	__rc3
	lsr	__rc3
	ror	__rc2
	ror
	sta	__rc3
	lsr	__rc3
	ror	__rc2
	ror
	ldx	__rc2
	rts
.Lfunc_end31:
	.size	ror_2, .Lfunc_end31-ror_2
                                        ; -- End function
	.globl	ror_4                           ; -- Begin function ror_4
	.type	ror_4,@function
ror_4:                                  ; @ror_4
; %bb.0:                                ; %entry
	stx	__rc2
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end32:
	.size	ror_4, .Lfunc_end32-ror_4
                                        ; -- End function
	.globl	ror_5                           ; -- Begin function ror_5
	.type	ror_5,@function
ror_5:                                  ; @ror_5
; %bb.0:                                ; %entry
	stx	__rc2
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	cmp	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end33:
	.size	ror_5, .Lfunc_end33-ror_5
                                        ; -- End function
	.globl	ror_7                           ; -- Begin function ror_7
	.type	ror_7,@function
ror_7:                                  ; @ror_7
; %bb.0:                                ; %entry
	stx	__rc2
	cmp	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end34:
	.size	ror_7, .Lfunc_end34-ror_7
                                        ; -- End function
	.globl	ror_8                           ; -- Begin function ror_8
	.type	ror_8,@function
ror_8:                                  ; @ror_8
; %bb.0:                                ; %entry
	stx	__rc2
	tax
	lda	__rc2
	rts
.Lfunc_end35:
	.size	ror_8, .Lfunc_end35-ror_8
                                        ; -- End function
	.globl	ror_15                          ; -- Begin function ror_15
	.type	ror_15,@function
ror_15:                                 ; @ror_15
; %bb.0:                                ; %entry
	sta	__rc2
	txa
	cpx	#128
	rol	__rc2
	rol
	tax
	lda	__rc2
	rts
.Lfunc_end36:
	.size	ror_15, .Lfunc_end36-ror_15
                                        ; -- End function
	.section	".note.GNU-stack","",@progbits
	;Declaring this symbol tells the CRT that the stack pointer needs to be initialized.
	.globl	__do_init_stack

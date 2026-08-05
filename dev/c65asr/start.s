; Bare-metal 65CE02 reset for MAME's c65 driver.
; A fall-through .init section: the llvm-mos .init.* chain is concatenated in
; numeric order and ends by calling main, so this must NOT jump to main itself
; (that would skip soft-stack init and the data copy).
	.section .init.20,"axR",@progbits
	sei                     ; no C65 IRQ setup here; vectors point at rti anyway
	cld
	ldx #$ff
	txs
	.section .text._irq_default,"axR",@progbits
	.globl _irq_default
_irq_default:
	rti

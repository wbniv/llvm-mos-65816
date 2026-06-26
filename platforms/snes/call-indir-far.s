; #320 follow-up (a) — FAR FUNCTION POINTERS: the bank-0 trampoline for an
; INDIRECT call through a far (24-bit) code pointer. clang's `far` (== long_call)
; call-rewrite materializes the callee's full 24-bit address into the runtime slot
; __mos_far_target and emits `JSL __call_indir_far`; this thunk then does a single
; long-indirect jump ($DC, JML (abs)) through that slot to the far target. The far
; target is .far_* (RTL-returning), so its RTL pops the 3-byte PBR:PC the caller's
; JSL pushed — control returns to the original call site. No PEA/push here (unlike
; __call_near_from_far): the JML transfers straight to the far target and never
; comes back to the thunk, so the stack the caller's JSL set up is exactly what the
; far target's RTL consumes.
;
; Both symbols are referenced (not defined) by clang's far-call lowering
; (CGExpr: getOrInsertGlobal "__mos_far_target" + a runtime call to
; "__call_indir_far"); this is their sole definition. __mos_far_target is a 4-byte
; bank-0 RAM slot (an i32 — 24-bit target + a pad byte) the caller volatile-stores
; before the JSL.
;
; Own gc-able sections so --gc-sections drops both from any ROM that makes no far
; indirect call (near-only ROMs stay byte-identical; pulled only when a JSL to
; __call_indir_far exists). Assembled with -mcpu=mosw65816 (JML is 65816-only).

.section .text.__call_indir_far,"ax",@progbits
.global __call_indir_far
__call_indir_far:
	jml	(__mos_far_target)	; $DC long-indirect jump through the 24-bit slot

.section .noinit,"aw",@nobits
.global __mos_far_target
__mos_far_target:
	.zero 4

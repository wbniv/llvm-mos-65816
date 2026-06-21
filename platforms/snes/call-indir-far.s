; #320 far-calls follow-up (a) — far function pointers: an INDIRECT far call. The
; far analog of common/crt/call-indir.S (`jmp (__rc18)`): mirror it with the 65816
; indirect-LONG jump so the program bank follows the pointer. The (far) target's RTL
; returns to the original call site, past this stub (it is a tail jump, pushes
; nothing).
;
; IR-rep #1 (front-end): a call through a far function pointer lowers to a VOLATILE
; store of the 24-bit target into the `__mos_far_target` slot (the "set far target"
; step) + a direct `call @__call_indir_far(args)`. MOSCallLowering emits that call as
; JSL (it pushed a 3-byte PBR:PC; the far target's RTL pops exactly those 3 back to
; the original caller). Args forward untouched (the slot store + JSL don't disturb
; the arg registers). The pointer MUST target a far (.far_*, RTL-returning) function.
;
; Stack walk: caller `JSL __call_indir_far` pushes [PBR:PCh:PCl] (3). `jml
; (__mos_far_target)` reads the 24-bit target and long-jumps (no push). The far
; target runs and `RTL`s, popping those 3 -> back to the original caller, PBR
; restored.
;
; Own section so --gc-sections drops the stub from any ROM that makes no far indirect
; call. __mos_far_target is a 4-byte bank-0 RAM slot, written (volatile) just before
; each call and consumed by the `jml` immediately after — transient, so re-entrant
; like the near `__call_indir`/RS9 scratch.

.section .text.__call_indir_far,"ax",@progbits
.global __call_indir_far
__call_indir_far:
	jml	(__mos_far_target)	; $DC indirect-long jump through the 24-bit slot

; The far indirect-call target slot (low 3 bytes = lo,hi,bank; 4th = 0 for a 24-bit
; far pointer's high byte). Bank-0 RAM so `jml (abs)` can fetch the pointer.
.section .noinit,"aw",@nobits
.global __mos_far_target
__mos_far_target:
	.zero 4

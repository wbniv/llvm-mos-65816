; #320 far-calls follow-up (a) — far function pointers: an INDIRECT far call. The
; far analog of common/crt/call-indir.S (`jmp (__rc18)`): mirror it with the 65816
; indirect-LONG jump so the program bank follows the pointer. JSRing/JSLing to this
; stub performs an indirect far call — the RTL in the (far) callee returns to the
; original call site, past this stub (it is a tail jump, pushes nothing).
;
; Contract: the caller puts the 24-bit far code pointer in __rc18(lo):__rc19(hi):
; __rc20(bank) (RS9 + the next byte — the same scratch the near indirect call uses,
; extended by one bank byte) and executes `JSL __call_indir_far`. The pointer MUST
; target a far (.far_*, RTL-returning) function: JSL pushed a 3-byte PBR:PC, and the
; target's RTL pops exactly those 3 back to the original caller. Emitted by
; MOSCallLowering::lowerCall for an indirect call whose callee is an addrspace-2
; (far, p2) function pointer on W65816.
;
; Stack walk: caller `JSL __call_indir_far` pushes [PBR:PCh:PCl] (3). `jml [__rc18]`
; reads the 24-bit target and long-jumps (no push). The far target runs and `RTL`s,
; popping those 3 -> back to the original caller, PBR restored.
;
; Own section so --gc-sections drops it from any ROM that makes no far indirect call.

.section .text.__call_indir_far,"ax",@progbits
.global __call_indir_far
__call_indir_far:
	jml	(__rc18)	; $DC indirect-long jump through the 24-bit ptr at __rc18..20

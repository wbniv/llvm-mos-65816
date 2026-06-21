; #320 far-calls follow-up (b) — mixed-banking: a FAR function (bank $01) calling
; a NEAR function (bank $00). A near JSR out of bank $01 would keep the program
; bank at $01 and execute the wrong bank's bytes; the only ops that switch the
; program bank are JSL/RTL/JML/RTI, and a near RTS cannot restore the caller's
; bank. So a far->near call is routed through this bank-0 thunk via JSL: it pushes
; a near RTS-style return, near-indirect-jumps to the callee (now at PBR=$00), and
; when the callee's RTS lands back here, RTL pops the far caller's 3-byte return
; and restores PBR=$01.
;
; Contract (mirrors __call_indir): the caller puts the near callee's 16-bit address
; in __rc18:__rc19 (RS9, the indirect-call scratch — never holds arguments) and
; executes `JSL __call_near_from_far`. Emitted only by MOSCallLowering::lowerCall
; for a far (.far_*) function's direct call to a near callee on W65816.
;
; Stack walk (grows down): JSL pushes [PBR:PCh:PCl] (3). PEA pushes [back-1] (2).
; JMP (__rc18) -> callee at PBR=$00; callee RTS pops (back-1)+1 = .Lback. RTL pops
; the 3-byte far return -> back to the far caller, PBR=$01.
;
; Its own section so --gc-sections drops it from any ROM that makes no far->near
; call (keeps the near-only corpus byte-identical; only referenced when a JSL to
; this symbol exists).

.section .text.__call_near_from_far,"ax",@progbits
.global __call_near_from_far
__call_near_from_far:
	pea	.Lback-1	; push the near RTS target ( = .Lback, minus 1 for RTS's +1)
	jmp	(__rc18)	; near indirect jump to the callee (PBR stays $00)
.Lback:
	rtl			; pop the far caller's 3-byte return; PBR -> $01

# `longjmp` broken on the 65816 — common `setjmp.S` is 6502-only (8-bit page-1 stack)

**Status:** CONFIRMED bug, root-caused. Surfaced while scoping demo **#35** (`setjmp`/`longjmp` backtracking
solver) of the compiler stress-test battery. **`setjmp` works; `longjmp` does not return** — it corrupts the
stack pointer and jumps to a garbage address. Fails in **both** default-8-bit **and** `+mos-a16`, so it is a
**pre-existing upstream llvm-mos-sdk** bug, **not** introduced by the `+mos-a16` (#321) fork.

## Repro (minimal, on bsnes-jg)

```c
#include <setjmp.h>
#include <stdint.h>
volatile uint16_t corpus_result;
static jmp_buf jb;
__attribute__((noinline)) static void jump(void){ longjmp(jb, 7); }
int main(void){
  int r = setjmp(jb);
  if (r == 0) { corpus_result = 0x1111u; jump(); }   // longjmp from here
  corpus_result = (uint16_t)(0x2000u + r);            // expected final: 0x2007
  for(;;){}
}
```

- **Expected** (host + any conforming target): `corpus_result == 0x2007` (longjmp returns to `setjmp` with `r=7`).
- **Observed** on bsnes-jg (default-8-bit AND `+mos-a16`): `corpus_result == 0x1111` — the value written
  *immediately before* `longjmp`. Control **never returns** to the `setjmp` site; the CPU is lost after the
  jump.
- A `setjmp`-only control (normal return, never `longjmp`ed): **PASS** in both modes (`corpus_result`
  correctly reflects `r==0`). So `setjmp` save + ordinary `rts` is fine; the **`longjmp` restore** is the bug.

## Root cause — `vendor/llvm-mos-sdk/mos-platform/common/c/setjmp.S` is 6502-only

`setjmp` saves the return address and hard stack pointer assuming the **6502 page-$0100 8-bit hardware stack**:

```asm
setjmp:
  tsx                 ; X = LOW 8 bits of the stack pointer only
  lda $101,x          ; read return addr lo from HARDCODED page $0100
  ...
  lda $102,x          ; read return addr hi from page $0100
  ...
  txa                 ; save only the 8-bit hard SP
  ...                 ; (soft SP __rc0/1 + CSRs __rc18..31 saved correctly)
```

`longjmp` restores it symmetrically:

```asm
longjmp:
  ...
  lda (__rc2),y       ; the saved 8-bit hard SP
  tax
  txs                 ; S <- X
  ...                 ; then pushes the saved return addr and rts
```

On the **65816 in native mode** — which the SNES crt0 enters via `XCE` — the stack pointer **S is 16-bit and
not confined to page $0100**. The common routine:

1. **Saves only 8 bits of S** (`tsx`/`txa`) — the high byte of the 16-bit native SP is lost.
2. **Reads the return address from a hardcoded `$0100` page** (`lda $101,x` / `$102,x`) — valid only if the
   stack physically sits in page 1.
3. **Restores S from that 8-bit value** (`tax; txs`) — so after `longjmp`, S's high byte is wrong (and the
   return-address fetch was page-1-relative), and the subsequent `rts` reads the return address from the
   **wrong stack location** → jumps to garbage → hang. This is the observed failure.

It correctly saves/restores the **soft** stack pointer (`__rc0`/`__rc1`) and the callee-saved imaginary
registers (`__rc18..__rc31`) — the bug is purely the **hardware 16-bit S** handling.

## Fix direction (an llvm-mos-sdk contribution, 65816-aware)

A 65816 `setjmp.S` (or a `+mos-a16`/65816 platform override of the common one) must use the **16-bit** stack
ops instead of the 8-bit page-1 ones:

- Save/restore the full 16-bit S with `tsc`/`tcs` (transfer S↔C, 16-bit) rather than `tsx`/`txa`/`tax`/`txs`.
- Read/replace the return address **relative to the actual 16-bit S** (e.g. via stack-relative addressing
  `lda 1,s` / `lda 2,s`), not a hardcoded `$0101`/`$0102`.
- Mind the M/X register widths (`rep`/`sep`) around the 16-bit transfers.

This is a runtime/library fix (SDK assembly), distinct from the `+mos-a16` **codegen** work of #321, but it
is a genuine correctness defect: **any** C program using `longjmp` on the 65816 SNES platform mis-executes.

## Impact on the demo battery

- **#35 (`setjmp`/`longjmp` backtracking solver) is BLOCKED** on this bug — a demo whose whole premise is
  `longjmp`-to-checkpoint cannot run correctly until `setjmp.S` is 65816-aware. Per the stress-demo protocol
  the demo is **not** reshaped to dodge the bug; it waits on the fix.
- This is precisely the kind of defect the battery exists to surface (idea #35 was explicitly flagged
  "verify toolchain support first — a gap is a finding"). Logged for the upstream queue.

## Fix (landed 2026-07-02) — `platforms/snes/setjmp.S`, a 65816-aware shadow

The fix rides with the **SNES platform** (not the upstream `common/` tree), because `common/c/setjmp.S`
is compiled once with the 6502 default (`__mosw65816__` undefined there) and merged into every platform's
`libc.a`. A new **`platforms/snes/setjmp.S`**, built with `-mcpu=mosw65816` and added to `snes-c`
**ahead of** `add_platform_library`'s POST-BUILD append of `common-c`, precedes common's 6502
`setjmp.S.obj` in `libc.a` — so the linker resolves `setjmp`/`longjmp` from it and common's copy is never
pulled (verified: the two `setjmp.S.obj` members sit at archive indices 1 and 8; index 1 is the snes one).
`snes-far`/`snes-hirom` (`PARENT snes`) fall through to `snes/lib/libc.a`, so they inherit it. `snes-c`
also links `common-asminc` so the override's `.include "imag.inc"` resolves the `__rc*` registers.

Design choice — **no `jmp_buf` ABI change.** The SNES hardware stack is confined to page 1 by the platform
contract (crt0 sets `S = $01FF`; the 256-byte page-1 stack never leaves page 1), so the override saves only
the **low byte** of `S` (byte-layout-identical to the 6502 `jmp_buf`: `ret_addr[2], s[1], sp[2], csrs[14]`
= 19 bytes) and **reconstructs** the full 16-bit `S = $01xx` on restore. Concretely, `longjmp` replaces the
6502 `tax; txs` with:

```asm
  ldy #2
  lda (__rc2),y     ; saved low byte of S
  rep #$20
  and #$00ff        ; A = $00xx
  ora #$0100        ; A = $01xx   (reconstruct the invariant page-1 high byte)
  tcs               ; S = $01xx   (16-bit transfer; not the broken $00xx of `txs`)
  sep #$20
```

and reads/writes the return address **stack-relative** (`lda 1,s`/`2,s`, `sta 1,s`/`2,s`) instead of at a
hardcoded `$0101`/`$0102`. `setjmp` likewise reads the return address via `1,s`/`2,s`. Everything else
(soft-SP `__rc0/__rc1`, CSRs `__rc18..__rc31`) is unchanged from the common version.

**Verification** — `corpus/setjmp_sim.c` (the repro above, `corpus_result` must end `0x2007`, not the
pre-`longjmp` sentinel `0x1111`) added as a permanent regression guard and run through the full
differential: **host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg**, all
`0x2007`. See the plan `docs/plans/2026-07-02-35-setjmp-longjmp-65816-fix.md` (numbered steps + evidence) and
the full engineering write-up
[`2026-07-02-setjmp-longjmp-65816-fix-analysis.md`](2026-07-02-setjmp-longjmp-65816-fix-analysis.md)
(design decisions, the archive-order shadow, the two non-bug detours, Round 6 hardening).

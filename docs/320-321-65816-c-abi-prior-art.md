# 65816 C calling-convention prior art (WDC816CC / ORCA-C) — for the #320/#321 ABI discussion

*A reference for the llvm-mos #320/#321 calling-convention decision: documented 1990s commercial
65816 C ABIs, read from **primary sources** — the WDC816CC compiler manual and the ORCA/C compiler
source — not recollection. Every claim below cites the manual page or the `Gen.pas` line it came
from.*

*Sources are vendored locally under `docs/refs/65816-c-abi/` (gitignored — they are
redistribution-restricted third-party docs; see `docs/refs/65816-c-abi/SOURCES.md` for URLs, sha256,
and `dev/fetch-refs.sh` to re-fetch). Page numbers are from `816cc.pdf` ("W65C816S C
Compiler/Optimizer User Guide", WDC, 2013-09-12); line numbers are from ORCA/C `Gen.pas`.*

---

## Why this is relevant

llvm-mos's 6502 backend uses a **soft "static stack"** plus zero-page **imaginary registers**; it has
no hardware-stack frame (non-recursive programs may use no stack at all). The 65816 adds a real 16-bit
stack pointer and stack-relative addressing, so #320/#321 re-open the calling-convention question with
options the 6502 never had.

The two compilers that shipped commercial 65816 C — **WDC816CC** (WDC's product; same lineage as
"Zardoz", which shipped SNES titles) and **ORCA/C** (Apple IIGS, Byte Works) — **independently
converged on the same frame design**. That convergence, read from the actual manual and the actual
code generator, is a concrete reference point for the decision.

---

## The shared shape: a *hybrid* stack + Direct-Page-window frame

A common framing is "DP frame **vs.** hardware-stack frame." The prior art is more precise — both
compilers use **both**: arguments are passed on the **hardware stack**, then on entry the frame is
remapped into the **Direct Page** for fast access.

**Argument passing — on the hardware stack, in reverse (right-to-left) order.** WDC manual p.21:
*"the arguments are pushed onto the stack in reverse order, starting with the last argument. The last
argument pushed is the first one listed in the function call."* The manual's own example:

```
;  func(a, b);
        LDA  b
        PHA
        LDA  a
        PHA
        JSR  __func
```

(For varargs, the callee can't know the count, so the caller pushes the total argument-byte count + 2
as an extra word — `PEA #6` in the manual's two-`int` example — and the prototype drives who pops.)

**Prologue — save DP, repoint it at the frame.** WDC manual p.22: *"The direct page register is saved
on the stack and then is modified to point at the beginning of the temporary and local variables. All
references to arguments and local variables are made via the direct page addressing mode."* ORCA/C
does this literally in its `GenEnt` prologue (`Gen.pas:6182–6202`): `tsc; phd; tcd` (no locals), or
`tsc; sec; sbc #localSize; tcs; phd; tcd` (reserve `localSize` bytes, then remap DP to the new frame
base). So locals/args are reached by **Direct-Page addressing with an 8-bit offset** — materially
faster on the 65816 than stack-relative (`S`-indexed) addressing, whose instruction coverage is
limited.

### The trade-off: a 256-byte frame ceiling

Because DP access uses an **8-bit** offset, the whole frame must fit in 256 bytes. WDC manual p.22,
verbatim:

> "the total size of the arguments, return address, local variables and temporary variables may not
> exceed **256 bytes**. This is partly done for speed. NOTE: If you require more variables in a
> function, you must put them in a global area."

This is the crux for llvm-mos: **the DP-window buys 8-bit-offset speed at the cost of a hard 256-byte
per-frame cap.** A pure stack-relative frame removes the cap but pays per-access cost.

### Return values: A (low) + X (high)

WDC manual p.21, verbatim: *"Functions called by a C function and C functions themselves return
values in the X register and the Accumulator. The high word of the result, if any, is in the X
register, while the low word is in the Accumulator."* ORCA/C matches it — its longword return class is
`A_X` (`Gen.pas:43`, used by `SaveRetValue` at `Gen.pas:661`). 64-bit/aggregate returns go via a
caller-supplied pointer.

This aligns cleanly with #321's dual-width `A16` work: a 16-bit result already lands in A, and the
32-bit case is just "high half in X."

**Adopted by #321 (2026-06-17).** This A (low) / X (high) return convention is now a locked, tested ABI
invariant for `+mos-a16` — it is *already what llvm-mos emits* (emergent from `CC_MOS` byte-splitting), so
adopting it cost no codegen change, only a regression guard: `examples/65816/a16ret.c` + `dev/a16ret.sh`
(`dev/run.sh a16ret`) asserts host == default == `+mos-a16` value agreement on MAME + bsnes-jg plus a disasm
gate that the `i16` return is `ldx <high>; lda <low>; rts` and the `i8` return is in A alone. See
[`docs/investigations/65816-calling-convention-decision.md`](investigations/65816-calling-convention-decision.md)
§"Return values — adopted" and [`docs/plans/2026-06-17-321-ax-return-convention.md`](plans/2026-06-17-321-ax-return-convention.md).

**Index registers across calls follow the same posture (2026-06-21).** Under `+mos-xy16` the 16-bit index
registers are *caller-saved* and 8-bit at every call/return boundary — `+mos-xy16` is an in-function
optimization, not a cross-call mode. A 16-bit index held live across a call survives in a callee-saved ZP
imaginary-register pair (reloaded into X16 at the point of use), so the boundary is correct by construction.
This is consistent with the WDC/ORCA "high word of a longword result in X" prior art: the future 32-bit
result's high word would live in a 16-bit X only while xy16 is active and would be caller-saved like any other
index value — but a census found realistic code returns no i32 across calls, so that lever stays shelved. See
the CC-decision doc §"Index registers across calls — adopted" and `dev/run.sh xy16call`.

### Memory models / near–far (directly informs #320)

WDC816CC has four models, selected by code-size × data-size (manual p.22):

| | <64K code | >64K code |
|---|---|---|
| **<64K data** | **Small** (code 16, data 16; all globals in the zero bank) | **Medium** (code 32, data 16) |
| **64K data** | **Compact** (code 16, data 32) | **Large** (code 32, data 32) |

Beyond the model default, the `near`/`far` keywords act as storage-class modifiers (manual pp.23–26):
`near` = 16-bit reference within the current bank; `far` = 24-bit reference anywhere (long-absolute
data; `JSL`/`RTL` for calls). Notable specifics that map onto #320's address-space design:

- *"YOU CAN NEVER ASSIGN A NEAR FUNCTION TO A FAR POINTER OR VICE VERSA"* (p.26) — near/far are
  distinct pointer types, exactly the addrspace distinction #320 models.
- The `-SO` "positive short indexing" option makes far-pointer increment affect only the low 16 bits
  (`-SO0S` disables it) (p.26) — i.e. pointer arithmetic that does **not** cross banks, the same
  decision #320's "runtime far-pointer operations" item faces.

ORCA/C, by contrast, has a **single small memory model** plus an optional `dataBank` flag that
saves/sets the Data Bank register around the frame (`Gen.pas:6209` — `phb; phb; pla; sta bankLoc`) for
multi-bank data, rather than a full far-pointer model.

---

## What this means for the llvm-mos #320/#321 decision

Three concrete frame options, with the prior art as the documented reference for the first:

| Option | Arg passing | Local access | Pros | Cons |
|--------|-------------|--------------|------|------|
| **(a) WDC816CC/ORCA hybrid** — stack-pass + `tsc/phd/tcd` DP-window | hardware stack | DP, 8-bit offset (fast) | proven in shipping commercial code; fast locals; A/X return aligns with #321 | **256-byte frame cap**; prologue/epilogue cost; recursion needs care |
| **(b) Pure hardware-stack-relative** (`S`-indexed) | hardware stack | `S`-indexed (slower, limited instr coverage) | no frame-size cap; straightforward recursion | per-access cost; fewer addressing modes |
| **(c) llvm-mos 6502 soft static stack** (carried over) | static / ZP imaginary regs | zero page | reuses existing backend machinery; no native-mode dependency | doesn't exploit the 65816 hardware stack |

Observations for the maintainers:

- llvm-mos already leans on the zero page (imaginary registers), so the **DP-window idea in (a) is
  philosophically close to what the backend already does** — but per-frame via `TCD` rather than a
  fixed global ZP block. The 256-byte cap is the friction point.
- The **A/X return convention is essentially free to adopt** and aligns with the #321 `A16` work —
  worth taking from the prior art regardless of which frame option wins.
- The `near`/`far` keyword model and the `-SO` short-indexing decision are direct prior art for #320's
  address-space layout and its "far-pointer arithmetic crosses banks or not?" question.
- (a) requires native mode (`XCE`) + the native-mode crt0 already tracked in #321 stage 1; it is not
  independent of that work.

This note **makes no recommendation** — llvm-mos's stance is that an ABI is blessed only behind a
high-quality implementation. It surfaces the documented design so the choice is made against real
prior art, not memory.

---

## Caveats

- **Zardoz vs. WDC816CC ABI identity is genuinely open.** WDC816CC is the surviving, documented
  product, and "Zardoz" is the earlier name of the same lineage. Whether the *exact* frame ABI above
  was already present in the Zardoz-era compiler that shipped SNES games is **not documented** — treat
  this as "WDC816CC as documented (2013 manual)," the strongest surviving primary source.
- **ORCA/C is Apple IIGS-coupled and source-available, not OSI-open / not redistributable.** Useful as
  an ABI reference (its `Gen.pas` is the authority cited here), not as a portable codebase.
- This is prior art, not a constraint. The value is that two independent commercial compilers, read
  firsthand, converged on the same stack-pass + DP-window frame and the same A/X return.

## Sources

Vendored + manifested at `docs/refs/65816-c-abi/` (`SOURCES.md`; binaries gitignored; re-fetch with
`dev/fetch-refs.sh`):

- **WDC816CC manual** — `816cc.pdf`, "W65C816S C Compiler/Optimizer User Guide" (WDC, 2013-09-12).
  Argument passing + return values **p.21**; stack frame / DP trick + 256-byte cap + startup **p.22**;
  memory models + `near`/`far` **pp.22–26**. <https://www.westerndesigncenter.com/wdc/documentation/816cc.pdf>
- **ORCA/C `Gen.pas`** (Byte Works) — `GenEnt` prologue `tsc/phd/tcd` **lines 6182–6202**; `dataBank`
  **line 6209**; `A_X` return class **line 43**, `SaveRetValue` **line 661**.
  <https://github.com/byteworksinc/ORCA-C>

# #320 upstream design note — a running far-pointer slice to anchor the design discussion

**Date:** 2026-06-14 · **Status:** Planned (not started). · **Milestone:** M1 → upstream engagement
(the "#320 full model + upstream" + "WDC816CC/ORCA-C ABI prior art" TODO items). **Builds on:**
Increments [1](2026-06-14-320-far-pointer-codegen.md),
[2](2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md),
[2b](2026-06-14-320-increment-2b-multi-bank-rom-far-read.md) (the running slice this note summarizes).

## Context

Three increments have landed a **running, verified far-pointer slice** for llvm-mos #320:
addrspace-2 far pointers lower to 65816 absolute-long (`LDA/STA $xxxxxx`, AF/8F), gated on `W65816`,
6502 untouched; verified at the disassembly level (Inc 1), executing in MAME in bank $00 (Inc 2), and
crossing a real ROM bank boundary into bank $01 (Inc 2b). Per the llvm-mos culture — `@mysterymath`:
*"I'll consider that a given ABI might satisfy [high quality] only after someone shows me a
high-quality compiler for it"* (INVESTIGATION.md) — a working slice is the artifact that earns ABI
input, not a spec proposal. The deliverable is a **self-contained design note** that summarizes the
slice, states the address-space-numbering divergence from `@asiekierka`'s proposed model and how to
reconcile it, surfaces the open ABI decisions the slice informs (incl. the documented WDC816CC/ORCA-C
calling-convention prior art), and proposes next steps — ready to post to the Discord / issue #320.

This addresses two open TODO items: "#320 full model + upstream" and "Surface WDC816CC/ORCA-C ABI
prior art in #320/#321." Writing/docs task — no code change.

## Deliverable

A new in-repo doc, **`docs/320-upstream-far-pointer-note.md`**, written to be copy-pasteable into a
GitHub #320 comment / Discord post. Posting it upstream is a **separate, user-triggered step** (a
public comment on a maintainer's issue — out of scope here; the note is drafted and ready).

## Structure (the note's sections)

1. **TL;DR.** One paragraph: a running, non-breaking far-pointer slice for #320 exists in
   [wbniv/llvm-mos-65816]; it wires GlobalISel to the *already-shipped* 65816 MC instructions, is
   verified end-to-end in MAME, and is offered to anchor the #320 design discussion. Links to the
   branch/patch and the test bench.
2. **What's implemented + verified** (lead with evidence). Condense the three increments:
   - addrspace 2 = far, data layout `…-p2:32:8-…`, `AS_Far=2` (quote `MOSInstrInfo.h` enum); gated on
     `FeatureW65816`; addrspace 0 (16-bit absolute, 6502 default) **untouched** → non-breaking
     (6502 corpus 7/7 on the patched toolchain).
   - far `G_LOAD/STORE` → `case 32` → `G_LOAD_FAR_ABS/G_STORE_FAR_ABS` → `LDA/STA_AbsoluteLong`
     (existing MC instrs — *no new instructions*; the assembler's 65816 set was already complete).
   - emulation-mode: absolute-long carries the full 24-bit address and ignores the DBR, so far
     accesses run with no native-mode/`XCE` setup.
   - verification ladder: disasm (`af 34 12 7e`), MAME bank $00 (`SMOKE: PASS got=0xF3`), MAME bank
     $01 (`lda $018000` → `af 00 80 01`, cross-bank round-trip). One-line each, with the harness names
     (`dev/run.sh far` / `far-run` / `far-bank1`).
3. **Scope — what it deliberately does NOT do yet** (honesty up front).
   Constant/global far addresses only (no runtime far-pointer arithmetic / indirect-long `[dp]` — a
   far access that can't be matched as absolute *fails to legalize* rather than miscompiling); 8-bit
   registers only (#321 untouched, no `REP/SEP`); no calling-convention change; no native mode; far
   *data* only (no far code / `JSL` yet). It is the foundational #320 layer as a minimal additive
   slice — not the full model.
4. **Address-space numbering: slice vs proposal, and how to reconcile** (the core ask). The
   side-by-side table (slice: `0`=abs/`1`=DP/`2`=far·32-bit; proposal: `0`=far·32-bit default /
   `1`=DP / `2`=abs / `3`=packed-24 / `4`=zero-bank). State the **deliberate divergence**: we added
   `2`=far *additively* to keep addrspace 0 (6502 default) unchanged, so the slice is non-breaking and
   needs no module-wide ABI commitment. Adopting `@asiekierka`'s `0`=32-bit-far-**default** is exactly
   the ABI decision that needs maintainer blessing (the "32-bit is cheaper than 24-bit on the 65816"
   finding). Framing: **Option A (additive, shipped here as evidence) → Option B (default-far, the
   real ABI)**; reconcile to his numbering for the full model once the default-pointer-width call is
   made. Flag this so the numbering divergence reads as conscious, not accidental.
5. **Open ABI decisions the slice informs but doesn't decide.**
   - Default pointer width (32-bit far default vs 16-bit-default + opt-in far).
   - Five-space layout adoption + final numbering (incl. packed-24 `3`, zero-bank `4`).
   - **Calling convention** — surface the documented **WDC816CC/ORCA-C** prior art (PHD/TCD
     direct-page frame, A+X split return values) vs hardware-stack-relative (now viable) vs the 6502
     soft static stack. This is the low-effort, high-value prior-art contribution (the "point at the
     manual, not a memory" item). Keep it to a tight summary + pointer.
6. **Proposed next steps.** Discord/#320 discussion to reconcile numbering + default → implement the
   full five-space model behind ABI blessing → #321 (16-bit A / REP-SEP) + hardware-stack ABI. Note
   the SNES test bench (llvm-mos-sdk#415-shaped) already exists here as the regression baseline.
7. **Links.** Repo + the three increment plans/commits, the test bench (`dev/`), and #32 / #320 /
   #321 / sdk#415.

## Critical files

| File | Role |
|------|------|
| `docs/320-upstream-far-pointer-note.md` | **new** — the design note (the deliverable) |
| `TODO.md` | mark "#320 full model + upstream" in progress; tick the WDC816CC/ORCA-C prior-art item as folded into the note |
| `docs/ROADMAP.md` | (optional) link the note from the Upstream/Links section |

**Sources to draw from (read, don't restate blindly):** `docs/INVESTIGATION.md` (asiekierka's
five-space table; players/culture; WDC816CC/ORCA-C prior art; rival SNES-Dev w65 psABI),
`patches/llvm-mos/0001-320-far-addrspace.patch` (exact enum + `p2:32:8` + the `case 32` legalizer),
the three `docs/plans/2026-06-14-320-*` plans (verification evidence to cite), `docs/ROADMAP.md`
(milestone framing). Reuse the precise wording already in the patch comments and plans rather than
paraphrasing the technical claims.

## Verification (accuracy + readiness — it's a document)

1. **Technical accuracy:** every addrspace/data-layout/opcode claim matches
   `0001-320-far-addrspace.patch` and `MOSInstrInfo.h`; every "verified" claim matches a recorded
   plan/commit (cite the commit short-SHAs: 3358a1a / a8dd8a5 / ec2aa31). No claim the slice does
   something it doesn't (cross-check against each plan's "out of scope").
2. **Numbering table correctness:** the slice column matches the patch; the proposal column matches
   the INVESTIGATION.md table (which quotes asiekierka's 2024-03-14 #320 comment).
3. **Links resolve:** issue links (#32/#320/#321/sdk#415), repo paths, and the
   jackoalan/asiekierka references are correct.
4. **Render + read:** `task md -- docs/320-upstream-far-pointer-note.md` renders cleanly; the note is
   self-contained and scannable (a busy maintainer can read the TL;DR + table and get the ask). No
   repo-internal jargon that wouldn't make sense to an outside reader (expand `dev/run.sh far-bank1`
   etc. on first use).

## Out of scope

- **Posting upstream** (GitHub #320 comment / Discord) — user-triggered; the note is drafted and ready.
- Any **codegen/ABI implementation** (the full five-space model, default-far flip, #321, hardware
  stack) — those follow the discussion this note opens.
- A formal **psABI** document — premature; the culture wants the implementation first, and SNES-Dev's
  ahead-of-implementation w65 psABI is the cautionary example (INVESTIGATION.md).

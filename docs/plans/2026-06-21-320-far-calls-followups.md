# #320 far-calls follow-ups — (a) far function pointers + (b) mixed-banking (far → near)

**Date:** 2026-06-21 · **Status:** PLAN (not started) · **Issue:** #320 (M1, far pointers/calls)
**Builds on:** [Inc 4 Ph1 far calls](2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md) — the direct
`JSL`/`RTL` far-call MECHANISM (landed 2026-06-20, two-emulator verified) — and the in-flight
[far-pointer CC study](2026-06-20-320-far-pointer-cc-build-all-variants.md) (`wt/320-far-cc`, variant
(a) Imag32 done) whose 24-bit `p2` representation (a) reuses.

---

## Context — what landed, and the two precise gaps

Inc 4 Phase 1 shipped the **far-call mechanism**: a **direct** call to a `.far_*`-sectioned function is
emitted as `JSL` ($22, pushes a 3-byte `PBR:PC`); that function returns with `RTL` ($6B, pops 3). Both
sides are driven by the **same section attribute** (`MOSCallLowering.cpp` `lowerCall`/`lowerReturn`,
`STI.hasW65816()`-gated, a16-independent, in `0001`). Gate: `examples/65816/far_call.c`.

Two capabilities were deferred as follow-ups (the TODO's #320 follow-ups bullet):

- **(a) Far function pointers** — an *indirect* call through a far code pointer. Today every indirect
  call stays **near** (`jsr __call_indir`); a far function reached through a pointer is mis-called in the
  current bank.
- **(b) Mixed-banking** — a far function that calls a **near** function. Today a far function is
  constrained to be a leaf (or call only other far functions).

This plan also clarifies a scope point the older docs blurred (see *Measured findings* §1):
**far → far already works** (a `.far_*` caller `JSL`s a `.far_*` callee, which `RTL`s back — a non-leaf
chain that the current code handles). The real (b) gap is exclusively **far → near**.

(c) far tail calls remains a **separate** follow-up (the tail-call peephole keys on `MOS::JSR`, so a
`JSL` is already never tail-converted — conservative/safe today); it is **out of scope** here and stays
its own TODO line.

---

## Measured findings (host-compile probes, 2026-06-21 — "measure, don't assume")

Run against the built `build/llvm-mos-install/bin/mos-clang` (`-mcpu=mosw65816`). These reshaped the
plan; record them so the next agent doesn't re-assume.

1. **Far → far is NOT a leaf restriction.** `lowerCall` emits `JSL` for any `.far_*` *callee* and
   `lowerReturn` emits `RTL` for any `.far_*` *current function*, independently. So a `.far_*` function
   calling another `.far_*` function already produces a correct `JSL … RTL` pair. The leaf wording in
   `far_call.c` / `link.ld` is about far **→ near** specifically. **(b) = far → near only.**

2. **A far function pointer cannot be spelled with `address_space(2)`** (the mechanism far *data* uses,
   `#define FAR __attribute__((address_space(2)))`). clang **hard-forbids** address-space-qualified
   function types:
   ```
   error: function type may not be qualified with an address space
   ```
   (`clang/.../DiagnosticSemaKinds.td:3611`). Both natural spellings fail:
   - `typedef uint8_t far_fn_t(uint8_t) FAR;` → error above.
   - `uint8_t (FAR *fp)(uint8_t);` → same error (+ a near/far function-pointer-type mismatch).
   A local `(* FAR fp)` instead binds AS2 to the pointer's *storage* → "automatic variable qualified
   with an address space". **There is no address-space route to a far code pointer.**

3. **`__attribute__((far))` / `((long_call))` exists but is MIPS-only.** `Attr.td:2249` defines them as
   `MipsLongCall : TargetSpecificAttr<TargetAnyMips>` — **not** available on MOS. So the GCC-compatible
   `far` spelling is a *candidate front-end*, but only after it's enabled for MOS (a clang change), and
   even then it is a *function-declaration* attribute, not a pointer-type one.

4. **Taking a far function's address yields only 16 bits today.** `sink = far_leaf;` (where `far_leaf`
   is `.far_text`) compiles to `lda #mos16lo(far_leaf); lda #mos16hi(far_leaf)` — **no bank byte**. A far
   code pointer needs the 24-bit address (`R_MOS_ADDR24`), which is not materialized for a function
   symbol today.

5. **The near indirect path is confirmed** the gap: a reinterpreted near function pointer call emits
   `stx __rc18; … jsr __call_indir`, and `__call_indir` is just `jmp (__rc18)`
   (`mos-platform/common/crt/call-indir.S`) — a tail-jump thunk: the target's `RTS` returns past the
   thunk to the original caller. The far analog must mirror this exactly (below).

6. **The far-pointer representation is settled:** `p2:32:8` — addrspace 2 is a 32-bit pointer whose low
   24 bits are the address (`MOSTargetMachine.cpp:77`, `MOSInstrInfo.h:158`). Any far **code** pointer
   reuses this layout; the far-CC study's Imag32 (`RL#`) quad is its register home.

**Net:** (b) is fully expressible **today** (section attribute + backend-only work, no front-end). (a)
requires a **front-end far-code-pointer story that does not exist yet** — the larger, decision-bearing
half. This argues for **(b) first** (see *Sequencing*).

---

## (b) Mixed-banking: a far function calling a near function

### Why it's broken and what's fundamentally required

A far function runs with `PBR=$01`. A near function's code lives in bank $00, and all its internal
`JSR`/`RTS`/branches are program-bank-relative, so it **must run with `PBR=$00`**. (Its *data* access is
fine regardless — crt0 pins `DBR=$00`.) The only ways to change `PBR` are `JSL`/`RTL`/`JML`/`RTI`. A near
`RTS` cannot restore the caller's bank. Therefore **an `RTL` must execute on the way back**, and that
`RTL` must be reached by the near callee's `RTS`. The minimal construct that satisfies this is a **bank-0
veneer** — there is no way to avoid it without changing the near callee.

### Recommended mechanism — per-callee bank-0 veneer ("call gate")

For a far caller `F` (bank $01) calling near `g` (bank $00), emit at the call site:
```
    jsl  g.far_veneer        ; 4 bytes; PBR -> $00 (veneer is in bank 0), pushes 3-byte PBR:PC
```
and synthesize once per distinct near callee a tiny veneer in `.text` (bank $00):
```
g.far_veneer:                ; reached only via JSL from far code; runs at PBR=$00
    jsr  g                   ; near call; g runs at PBR=$00; g's RTS returns here
    rtl                      ; pops the far caller's 3-byte return; PBR -> $01
```
Trace: `JSL`(push3, PBR→0) → veneer `JSR g`(push2) → `g` runs near, `RTS`(pop2)→veneer → veneer
`RTL`(pop3)→`F`, PBR→1. **`g` is byte-for-byte unchanged** (still near, still `RTS`); near callers of `g`
are untouched. Cost: **+1 byte** at the call site (`JSL` vs `JSR`) + **4 bytes** per distinct near callee
(deduplicated) + ≈ **+14 cycles** per far→near call (`JSL`+`JSR`+`RTL` vs `JSR`). This is the 65816 form
of an ARM/AArch64 long-branch **veneer**.

**Where the veneer is synthesized:** in `MOSAsmPrinter`. During `lowerCall`, when far→near is detected
(below), redirect the call's target to a veneer `MCSymbol` (`<g>.far_veneer`) and record the need in a
per-module set keyed by the near callee; at `emitEndOfAsmFile`/module end, print each veneer once. (This
mirrors how LLVM emits compiler stubs; it avoids fabricating a `MachineFunction` mid-GISel.)

**Detection in `lowerCall`** (extends the existing `IsFar` block, `MOSCallLowering.cpp:415-423`):
```cpp
bool CallerIsFar = STI.hasW65816() &&
                   MF.getFunction().getSection().starts_with(".far_");
bool CalleeIsFar = Info.Callee.isGlobal() &&
                   Info.Callee.getGlobal()->getSection().starts_with(".far_");
// direct callee:
//   caller near, callee near  -> JSR  (today)
//   caller *,    callee far   -> JSL  (today: far-call mechanism)
//   caller far,  callee near  -> JSL <callee>.far_veneer   (NEW: mixed-banking)
```
The first two rows are unchanged (proven byte-identical default stays byte-identical — `CallerIsFar` is
false off-65816 and for every near function). Only the third row is new.

### Alternative (documented, likely a measured control, not the ship)

**Whole-module "large code model"** — an off-by-default feature (`+mos-code-far`/`-mcmodel=large`-style)
under which **every** function uses `JSL`/`RTL` and every call is long. Trivially correct and uniform,
but pays the long-call cost on *every* call including all-near programs → only sensible when far code
dominates. Keep it as the **fallback** if per-callee veneer synthesis proves unexpectedly hard, and as a
**measurement baseline** (veneer vs uniform-far on a mixed-bank workload). Recommendation: **ship the
veneer**, because it preserves the cheap near ABI and pays only at the boundary (the project's
conservative "never regress the common shape" stance, governing lesson #2/#3).

### (b) gates

- `examples/65816/far_near_call.c` + `dev/far_near_call.sh`: a `.far_text` function (bank $01) that
  calls a **near** helper (bank $00) which itself makes a near call (proves `PBR=$00` held across the
  near callee's own `JSR`/`RTS`), returning a sentinel checked host == default == far on **MAME +
  bsnes-jg**. Disasm gate: `JSL …far_veneer` at the far call site, the veneer body `jsr <g>` + `6b`
  (rtl), and `<g>` itself still ends in `60` (rts). (Far calls are a16-independent → can also run the
  default 8-bit build for a true 4-way.)
- Regression: corpus 7/7 (near `JSR`/`RTS` intact), existing `far_call`/`far_store` still PASS, fuzz +
  a torture spot 0-mismatch, `0001` round-trips a16-free.

---

## (a) Far function pointers: indirect far call

### Backend + runtime (the tractable half — mirror `__call_indir`)

Symmetric to the near indirect thunk. A 24-bit far code pointer is copied into a 3-byte ZP slot, then:
```
__call_indir_far:            ; reached via JSL (3-byte return already on stack)
    jml  [__rc18]            ; $DC, indirect-LONG tail jump: reads 3 bytes at __rc18, PBR follows
```
Call site (in `lowerCall`'s `IsIndirect` path, for a **far** callee value):
```
    ; copy the 24-bit far code ptr into __rc18..__rc20 (low,high,bank)
    jsl  __call_indir_far    ; pushes 3-byte PBR:PC of the caller
    ; far target runs, RTL pops 3 -> returns to the ORIGINAL caller (any bank)
```
Trace: `JSL`(push3) → `__call_indir_far` `JML [ptr]`(tail, no push) → far target `RTL`(pop3) → original
caller, PBR restored. Works regardless of the **caller's** bank (near or far). The instruction exists:
`JML_Indirect16` ($DC, `MOSInstrInfo.td:779`).

**Hard contract:** a far function pointer **must** point to a far (`RTL`-returning) function — `RTL`
against a near `RTS` callee corrupts the stack. A proper far-code-pointer *type* (front-end, below) is
what enforces this; an integer/builtin route leaves it to the user (document loudly).

**The 24-bit slot.** The near path uses `RS9` = `__rc18:__rc19` (16-bit). The far path needs 3 contiguous
bytes reachable by `jml [__rc18]` — i.e. `__rc18..__rc20` (the bank byte at `__rc20`). Settle this as
either (i) reuse the Imag32 `RL#` quad the far-CC study added (natural: a far code pointer *is* a `p2`),
loading its low 3 bytes into the fixed `jml` slot, or (ii) a dedicated reserved triple analogous to
`RS9`. Prefer (i) for representation unity; confirm the `jml [abs]` operand can name the ZP base.

**Lowering changes** (`MOSCallLowering.cpp` `lowerCall`, `IsIndirect` branch, `:383-407` + the call-build
at `:419-430`):
- Detect "this indirect callee is far" (from the callee value's type/addrspace — see front-end).
- Copy the 24-bit value into the far slot (3 bytes) instead of `RS9` (2 bytes).
- `Info.Callee.ChangeToES("__call_indir_far")`.
- Emit `JSL` (not `JSR`) so the 3-byte return is pushed; add the slot reg as an implicit use.
- SPC700 has its own `__rc17` thunk path — far indirect is **65816-only**; leave SPC700 unchanged.

**Runtime stub home.** Add `__call_indir_far` as a **project-owned** stub in `platforms/snes-far/`
(a new `call-indir-far.s`, wired through its `CMakeLists.txt` — `snes-far` is a `COMPLETE PARENT snes`
platform, so it can add object files), **not** the shared `vendor/llvm-mos-sdk` common crt. Keeps the
shared SDK untouched and the stub tracked in-repo. (If upstreamed later, it moves to the SDK common crt
behind a 65816 guard.)

### Front-end (the decision-bearing half — nothing exists today)

A far code pointer must be **expressible** and **materializable** in C. Three options, smallest-footprint
first:

| Option | Spelling | Front-end change | Ergonomics | Enforces far-only? |
|---|---|---|---|---|
| **F1 builtin** | `__builtin_mos_far_addr(&g)` → `uint32_t`; `__builtin_mos_call_far(addr, args…)` | new builtins (no type-system change); awkward for arbitrary signatures | low | no (user-managed) |
| **F2 `far` fn attribute for MOS** *(recommended)* | enable `[[gnu::far]]`/`long_call` for MOS on functions **and** function-pointer typedefs | un-gate `MipsLongCall` → a MOS-available attr (or new `MOSFarCall`) + Sema + an IR marker the backend reads | medium; GCC-compatible spelling | partial (decl/typedef-scoped) |
| **F3 far-fn-ptr type** | a MOS qualifier producing a `p2` pointer-to-function, bypassing the forbidden addrspace-on-function path | Sema/AST work to attach far-ness to the *pointee* without the addrspace diagnostic | high; cleanest C | yes (type-enforced) |

**Recommendation:** validate the **backend+runtime half first against hand-authored IR/asm** (decoupled
from the front-end), then adopt **F2** for the shippable C surface (GCC-compatible `far`, least Sema
risk, marks both a far function and a far-callable typedef), with **F1 builtins** as the spike/escape
hatch if F2's attribute-on-pointer-types proves fiddly. **F3** is the ideal end state (type-enforced
far-only contract) but is the largest clang change — defer unless F2 is inadequate. **This front-end fork
is the one genuine open decision in this plan** (see *Open decision*).

**Materialization (finding §4).** Independent of the call: taking `&g` for a `.far_*` `g` must yield the
24-bit address (`R_MOS_ADDR24`), not 16-bit. Whichever front-end option, the address-of a far function
must lower to the `p2` 24-bit form (reuse the far *data* address materialization — `0001` already emits
`R_MOS_ADDR24` for far data symbols; extend it to function symbols when the pointer type is far).

### (a) dependency

(a) **reuses the far-pointer CC's `p2`/Imag32 representation** (the value is a 24-bit code pointer). The
backend+runtime half can proceed in parallel with the far-CC study, but if a far function pointer is ever
**passed as an argument or returned**, that rides the far-CC outcome (currently `wt/320-far-cc`, variant
(a) Imag32 done). Calling through a *local* far pointer needs only the type + materialization + indirect
lowering, not the cross-call CC.

### (a) gates

- **Backend/runtime (no front-end):** `examples/65816/farfp.ll` — hand-authored IR (or a `.S` driver)
  constructing an indirect far call through a 24-bit pointer; `llc`/assemble gate asserts `jsl
  __call_indir_far` + the stub's `dc` (`jml [__rc18]`); a ROM driver checks the far target ran and
  returned across the bank boundary on MAME + bsnes-jg.
- **End-to-end C (after the chosen front-end):** `examples/65816/far_fnptr.c` + `dev/far_fnptr.sh` — take
  `&far_leaf` as a far code pointer, launder through a `volatile`, call through it; host == default == far
  on both emulators. Disasm: 24-bit materialization of `&far_leaf` (bank byte present) + `jsl
  __call_indir_far`.
- Regression: near indirect calls (`jsr __call_indir`) unchanged for all non-far pointers; corpus + fuzz
  + torture spot 0-mismatch.

---

## Sequencing (recommended)

1. **(b) mixed-banking first.** Self-contained: section-driven detection + an AsmPrinter veneer +
   a C gate. No front-end change, no CC dependency, low risk. Delivers a visible capability (far code can
   call the near runtime/helpers) and lifts the "far must be a leaf-or-far-only" constraint.
2. **(a) backend+runtime half second** — `__call_indir_far` stub + JSL-indirect lowering + the 24-bit
   slot, validated on hand-authored IR/asm (no front-end blocker).
3. **(a) front-end** — pick F2/F1 per the *Open decision*; wire the C surface + 24-bit `&far_fn`
   materialization; land the end-to-end C gate.

(b) and (a)-backend are independent and could be done in either order; (a)-front-end gates only the C
ergonomics, not the capability.

---

## Patch placement & worktree

- **Compiler changes** (`lowerCall` far→near + far-indirect detection, AsmPrinter veneer, `&far_fn`
  24-bit materialization, any clang front-end for (a)) are **`HasW65816`-gated, a16-independent** → land
  in **`0001-320-far-addrspace.patch`** (which already spans `clang/lib/Basic/Targets` +
  `llvm/lib/Target/MOS` + `llvm/lib/TargetParser`). Confirm `0001` stays a16-free
  (`grep -c accum16 patches/llvm-mos/0001-*.patch` == 0) and absorbs no foreign hunks. The far-indirect
  24-bit slot may touch the same `MOSRegisterInfo`/`AnyRegBank` lines the far-CC `0004` edits — if so,
  coordinate with `wt/320-far-cc` (stack after, as `0004` did, rather than splitting a shared line).
- **Project-tracked files** (normal commit): `platforms/snes-far/call-indir-far.s` + its
  `CMakeLists.txt` wiring, the `examples/65816/*.c|.ll` + `dev/*.sh` gates, this plan, the TODO update.
- **Worktree.** This is compiler-changing on the hot shared `vendor/` → run on a feature worktree
  (`wt/320-far-followups`) off `main` HEAD with its own `vendor/` + warm-copied `build/`
  ([howto-feature-worktree.md](../howto-feature-worktree.md) §compiler-changing); register it in the
  agent-handoff Active-worktrees table while live. Durable artifacts (gates, stub, plan, decision record)
  merge back; retain the worktree until the #320 work merges upstream (worktree-retention policy).

---

## Verification (the project differential gate)

The bar is unchanged: **host == default(non-`+mos-a16`)@MAME == far@MAME == far@bsnes-jg**, plus
`-verify-machineinstrs` clean. Far calls are a16-independent, so each gate runs in the default 8-bit build
too (genuine 4-way when the callee takes/returns ≤16-bit).

1. **(b)** `dev/run.sh far_near_call` → disasm shows `JSL …far_veneer` at the far call, veneer = `jsr
   <g>` + `6b` (rtl), `<g>` still `60` (rts); MAME + bsnes-jg agree on the sentinel; far→far still works.
2. **(a) backend** `dev/run.sh farfp` (the `.ll`/`.S` gate) → `jsl __call_indir_far` + `dc` (jml [abs])
   present; ROM round-trips the far target on both emulators.
3. **(a) e2e** `dev/run.sh far_fnptr` → 24-bit `&far_leaf` (bank byte present), `jsl __call_indir_far`;
   host == default == far on both emulators.
4. **No regression:** corpus 7/7; near `JSR`/`RTS`/`jsr __call_indir` byte-identical for non-far code;
   `dev/run.sh fuzz 200+` and a torture spot 0-mismatch/0-new-crash; all prior far ROMs PASS.
5. **Patch hygiene:** `0001` regenerates and round-trips; staged set is exactly the authored files;
   `0001` stays a16-free; `0002`/`0003` untouched.
6. **Docs/upstream:** update this plan with results; point the TODO + implementation-status at what
   shipped; if the result is upstream-worthy (a 65816 far-call ABI: veneer + `__call_indir_far`), queue
   an evidence note in [upstream-contribution-status.md](../upstream-contribution-status.md) (posting is
   user-triggered).

---

## Out of scope / non-goals

- **(c) far tail calls** — separate TODO line; already conservative-safe (tail peephole keys on `JSR`).
- **The far-pointer *data* CC** (passing/returning a `p2` value) — the in-flight `wt/320-far-cc` study;
  (a) reuses its representation but does not re-open it.
- **SPC700 indirect-far** — 65816-only; SPC700's `__rc17` thunk path is untouched.
- **Auto-promoting near callees to far** — (b) keeps near callees byte-identical; no whole-program ABI
  change ships (the uniform-far code model is a measured control/fallback, not the default).

---

## Open decision (flagged for the user)

**(a)'s front-end spelling for far function pointers** (F1 builtin / F2 MOS `far` attribute / F3 far-fn-
ptr type — table above). It sets the public API and the size of the clang change. The plan **recommends
F2** (GCC-compatible `far`, least Sema risk) with **F1** as the spike, and sequences (a)'s **backend +
runtime** half *before* this so it isn't blocked. Confirm or redirect before (a)'s front-end step.

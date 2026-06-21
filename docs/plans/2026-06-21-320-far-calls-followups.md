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

> **Cross-agent A0 spike (from `wt/320-far-cc`, 2026-06-21; this branch is canonical, that one stood
> down) — receipts for 2/4 + two extra *backend* gaps, re-confirmed here 2026-06-21.** A parallel
> host-side spike (`mos-clang`, relocs via `llvm-objdump -r`) confirms points 2/4 and surfaces that (a)'s
> **backend** half isn't free either — the front-end story (1–4) is necessary but not sufficient:
> - **Receipts:** `&far_leaf` relocs `R_MOS_ADDR16_LO`/`_HI` (bank lost) vs a far *data* access
>   `R_MOS_ADDR24` (bank baked — but bound to the abs-long load, not to address-of). IR shows
>   `define i8 @far_leaf` in the **default** AS: `address_space(2)` on a function *declaration* is
>   **silently ignored** (no warning) — so the point-3 MIPS-`far`-style *decl* attribute won't by itself
>   place the function in AS2; it still needs address-of→24-bit (`R_MOS_ADDR24`) plumbing.
> - **Backend gap A — p2-value formation crashes** (re-reproduced: `/tmp/gapA.c`): returning `&far_sym`
>   as a far pointer → `unable to legalize G_TRUNC %_(p2)` / `G_UNMERGE_VALUES %_(p2)` bad-machine-code.
> - **Backend gap B — p2-value store/decompose crashes** (re-reproduced: `/tmp/gapB.c`): `G_STORE (p2)` →
>   *"unable to legalize"*; decomposing into the `jml` slot also hits the unsupported `s32→4×s8 G_UNMERGE`.
>
> **These p2-VALUE legalizations are exactly the class the far-CC study already solved** to pass/return a
> `p2` across a call — shipped as **variant (a) Imag32, default-on, in stacked patch `0004-320-far-cc.patch`
> on `wt/320-far-cc`** (it returns a `p2` from `make_far_ptr()`), **but `0004` is not on `main` yet.** So
> **(a) is gated on `0004` reaching `main`** (or being stacked into this worktree): build (a)'s
> `__call_indir_far` + indirect lowering **on top of** the Imag32 p2 representation, then fix any residual
> p2-value legalization (`G_STORE p2`, the byte-decompose) the CC path didn't need. Net: **(a) = front-end
> story + the far-CC p2 base (`0004`) + the stub/indirect lowering + residual legalizer fixes** — a
> multi-stage effort, not the "tractable backend half" the first draft implied. **(b) is unaffected** (no
> p2 anywhere) and proceeds independently.

---

## (b) Mixed-banking: a far function calling a near function

### Why it's broken and what's fundamentally required

A far function runs with `PBR=$01`. A near function's code lives in bank $00, and all its internal
`JSR`/`RTS`/branches are program-bank-relative, so it **must run with `PBR=$00`**. (Its *data* access is
fine regardless — crt0 pins `DBR=$00`.) The only ways to change `PBR` are `JSL`/`RTL`/`JML`/`RTI`. A near
`RTS` cannot restore the caller's bank. Therefore **an `RTL` must execute on the way back**, and that
`RTL` must be reached by the near callee's `RTS`. The minimal construct that satisfies this is a **bank-0
veneer** — there is no way to avoid it without changing the near callee.

### Implemented mechanism — generic bank-0 runtime thunk `__call_near_from_far`

**Chosen over the per-callee veneer (below) after a measure-the-implementation check (2026-06-21):**
`MOSAsmPrinter` has only basic operand target-flags (`MO_LO/MO_HI/MO_HI_JT/MO_ZEROPAGE`) and **no
`emitEndOfAsmFile` hook**, so a per-callee veneer needs ~5 new touch-points (a `MO_FAR_VENEER` flag,
its MCInstLower plumbing, an AsmPrinter end-of-file override, a per-module callee set, section-aware
label+MCInst emission). The generic thunk needs only `lowerCall` + a static, disasm-inspectable `.s`
stub, and — decisively — **reuses the exact "copy address → ZP slot, `ChangeToES`, emit `JSL`" plumbing
that (a)'s `__call_indir_far` also needs**, so doing (b) this way de-risks (a). The byte cost lands only
on the rare far→near path; the per-callee veneer remains a clean future byte-optimization.

A single stub lives in bank $00 (project-owned `.s`, like `__call_indir`):
```
__call_near_from_far:        ; reached via JSL from far code (3-byte far return on stack); PBR now = $00
    pea  .Lback-1            ; push a 2-byte NEAR return ( = g's RTS target) above the far return
    jmp  (__rc18)            ; $6C near indirect jump to g (g's 16-bit addr in __rc18); g runs at PBR=$00
.Lback:
    rtl                      ; pop the far caller's 3-byte return; PBR -> $01
```
The far caller materializes `g`'s 16-bit address into `RS9` (`__rc18:__rc19`, the established
indirect-call scratch) and emits `JSL __call_near_from_far`. Trace: `JSL`(push3, PBR→0) → stub
`PEA .Lback-1`(push2) → `JMP (__rc18)`→`g`(PBR=$00) → `g`'s `RTS`(pop2)→`.Lback` → `RTL`(pop3)→far
caller, PBR→1. **`g` is byte-for-byte unchanged** (still near, still `RTS`); near callers of `g` are
untouched. Cost: per far→near site ≈ address-load (~8 B) + `JSL` (4 B) vs near `JSR` (3 B), plus the
one-time ~7 B stub — paid only on the cross-bank path. (`PEA`=$F4, `JMP (abs)`=$6C, both present.)

**Detection in `lowerCall`** (extends the existing `IsFar` block, `MOSCallLowering.cpp:415-423`):
```cpp
bool CallerIsFar = STI.hasW65816() &&
                   MF.getFunction().getSection().starts_with(".far_");
bool CalleeIsFar = Info.Callee.isGlobal() &&
                   Info.Callee.getGlobal()->getSection().starts_with(".far_");
// direct callee:
//   caller near, callee near  -> JSR  (today)
//   caller *,    callee far   -> JSL  to the callee (today: far-call mechanism)
//   caller far,  callee near  -> materialize &g into RS9; ChangeToES("__call_near_from_far"); emit JSL  (NEW)
```
The first two rows are unchanged (proven byte-identical default stays byte-identical — `CallerIsFar` is
false off-65816 and for every near function). Only the third row is new. **Scope:** direct far→near only;
indirect-from-far is (a)'s territory (a runtime pointer's near/far-ness isn't known here).

### Alternatives (documented, not shipped)

- **Per-callee bank-0 veneer** (`g.far_veneer: jsr g; rtl`, reached by `jsl g.far_veneer`) — the
  ARM/AArch64 long-branch-veneer form; ~4 B/site + 4 B/callee, more byte-efficient than the generic thunk
  when a near callee is hot, but needs the AsmPrinter synthesis above. **Future optimization** if a
  census shows far→near is common.
- **Whole-module "large code model"** (`+mos-code-far`: every function `JSL`/`RTL`) — trivially correct,
  uniform, but pays on *every* call including all-near programs. A measurement **control/fallback**, not a
  default (it would regress the common near shape — governing lesson #2/#3).

### (b) gates

- `examples/65816/far_near_call.c` + `dev/far_near_call.sh`: a `.far_text` function (bank $01) that
  calls a **near** helper (bank $00) which itself makes a near call (proves `PBR=$00` held across the
  near callee's own `JSR`/`RTS`), returning a sentinel checked host == default == far on **MAME +
  bsnes-jg**. Disasm gate: `JSL __call_near_from_far` at the far call site (`22`), the stub body `f4`
  (pea) + `6c` (jmp ind) + `6b` (rtl), and the near helper `<g>` still ends in `60` (rts). (Far calls are
  a16-independent → can also run the default 8-bit build for a true 4-way.)
- Regression: corpus 7/7 (near `JSR`/`RTS` intact), existing `far_call`/`far_store` still PASS, fuzz +
  a torture spot 0-mismatch, `0001` round-trips a16-free.

---

## (a) Far function pointers: indirect far call

### ⚠ Layer-3 blocker (measured 2026-06-21): a far fn pointer can't be a far-addrspace IR callee

The first draft assumed the backend trigger is "the indirect callee is a `p2` value" — **LLVM IR forbids
this.** The verifier rejects `call … %fp` where `%fp` is `ptr addrspace(2)`: *"defined with type 'ptr
addrspace(2)' but expected 'ptr'"* — a call's callee **must** be in the program address space (0). The MOS
datalayout has no `P<n>` field ⇒ program addrspace = 0 ⇒ function pointers are 16-bit near; there is **no
per-pointer far callee**, and an `addrspacecast` p2→p0 truncates 32→16, dropping the bank. So the 24-bit
far address **cannot ride the IR `call` callee** — it must be threaded explicitly. Three IR
representations (a real design decision, *on top of* the F2 surface syntax):

1. **"set-far-target" intrinsic + named-thunk call** *(most tractable)* — `@llvm.mos.set_far_target(p2 %fp)`
   stashes the 24-bit address in the slot, then a normal `call @__call_indir_far(args)` forwards args; the
   backend emits `JSL` for the `__call_indir_far` symbol. Testable, args forward via the CC untouched.
2. **A custom calling convention** (`MOS_FarIndirect`) where the `p2` is an explicit operand; `lowerCall`
   keys on `Info.CallConv`, not the (impossible) callee type.
3. **A full call intrinsic** `@llvm.mos.call_indir_far(p2, …)` — clean but awkward for arbitrary signatures.

**Status:** the runtime stub `__call_indir_far` (`jml (__rc18)`) is **built + assembled + kept** on the
worktree (the design-independent half — every approach long-indirect-jumps through a ZP slot). The
`lowerCall` "detect p2 callee" trigger was **prototyped and backed out** — it is *untriggerable* (no real
IR yields a `p2` callee), so it can't be tested and would be dead/speculative. **Resuming (a) starts from
the IR-representation choice above** (lean toward #1), not from `lowerCall` detection. The mechanism below
is still the correct *runtime* shape; only its *trigger* changes.

### Runtime mechanism (correct; the trigger is the open design above)

Symmetric to the near indirect thunk. A 24-bit far code pointer is copied into a 3-byte ZP slot, then:
```
__call_indir_far:            ; reached via JSL (3-byte return already on stack)
    jml  (__rc18)            ; $DC, indirect-LONG tail jump: reads 3 bytes at __rc18, PBR follows
```
Call site (in `lowerCall`'s `IsIndirect` path, for a **far** callee value):
```
    ; copy the 24-bit far code ptr into __rc18..__rc20 (low,high,bank)
    jsl  __call_indir_far    ; pushes 3-byte PBR:PC of the caller
    ; far target runs, RTL pops 3 -> returns to the ORIGINAL caller (any bank)
```
Trace: `JSL`(push3) → `__call_indir_far` `JML (ptr)`(tail, no push) → far target `RTL`(pop3) → original
caller, PBR restored. Works regardless of the **caller's** bank (near or far). The instruction exists:
`JML_Indirect16` ($DC, `MOSInstrInfo.td:779`).

**Hard contract:** a far function pointer **must** point to a far (`RTL`-returning) function — `RTL`
against a near `RTS` callee corrupts the stack. A proper far-code-pointer *type* (front-end, below) is
what enforces this; an integer/builtin route leaves it to the user (document loudly).

**The 24-bit slot (settled in the build).** `jml`'s assembler syntax is `jml (__rc18)` (not `[…]`; opcode
`$DC`). The slot is `RS9` (`__rc18:__rc19`, the established near-indirect scratch) + the bank in `RC20`
(`__rc20`) — 3 contiguous bytes. RS9/RC20 aren't reserved (only RS0/RS8/frame are); like the near path,
they work as fixed scratch via copy→implicit-use (verified RS9 is convention, not reservation). An Imag32
`RL#` can't align to `__rc18` (RL`K` ⊃ `RS2K:RS2K+1`, and `RL4 ⊃ RS8` is the reserved scavenger), so the
RS9+RC20 triple is the slot.

**Lowering (trigger superseded — see the Layer-3 blocker).** The slot-fill + `JSL` + `ChangeToES(
"__call_indir_far")` sequence is right, and the byte-decompose (`ptrtoint`+`trunc`+`lshr` → RS9/RC20,
mirroring 0004's `assignCustomValue`) works. But it must be **driven by the front-end's IR representation**
(intrinsic / custom-CC), **not** by "callee is `p2`" (impossible — Layer-3). SPC700 stays on its `__rc17`
near thunk; far indirect is 65816-only.

**Runtime stub home (done).** `__call_indir_far` is a **project-owned** stub at `platforms/snes/call-indir-
far.s` (body `jml (__rc18)`), wired into `snes-crt0-o` with a per-file `-mcpu=mosw65816` (the platform
otherwise builds crt0 objects without it) and placed in its own section so `--gc-sections` drops it until
referenced — exactly like the (b) `__call_near_from_far` thunk. It is **built + assembled** on the worktree
(`dc` = `jml ($0)`→`__rc18`) and is currently unreferenced (gc'd) pending the lowering trigger.

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
  __call_indir_far` + the stub's `dc` (`jml (__rc18)`); a ROM driver checks the far target ran and
  returned across the bank boundary on MAME + bsnes-jg.
- **End-to-end C (after the chosen front-end):** `examples/65816/far_fnptr.c` + `dev/far_fnptr.sh` — take
  `&far_leaf` as a far code pointer, launder through a `volatile`, call through it; host == default == far
  on both emulators. Disasm: 24-bit materialization of `&far_leaf` (bank byte present) + `jsl
  __call_indir_far`.
- Regression: near indirect calls (`jsr __call_indir`) unchanged for all non-far pointers; corpus + fuzz
  + torture spot 0-mismatch.

---

## Sequencing (recommended)

1. **(b) mixed-banking first.** ✅ **DONE 2026-06-21** (verified both emulators — see *Status*). Self-
   contained: section-driven `lowerCall` detection + the `__call_near_from_far` generic thunk + a C gate.
   No front-end change, no CC dependency, low risk. Lifts the "far must be a leaf-or-far-only" constraint.
2. **(a) far-CC p2 base must land first** — (a) needs the p2-VALUE legalization (form/return/store/
   decompose a `p2`), which is the far-CC study's already-shipped Imag32 work in **`0004-320-far-cc.patch`**
   (`wt/320-far-cc`). Land `0004` on `main` (or stack it into this worktree) **before** (a)'s backend, else
   the two confirmed crashes (gaps A/B above) block it.
3. **(a) backend+runtime** — on top of the Imag32 p2 base: `__call_indir_far` stub + JSL-indirect lowering
   + the 24-bit slot; fix any residual p2-value legalization (`G_STORE p2`, byte-decompose) the CC path
   didn't need. Validate on hand-authored IR/asm.
4. **(a) front-end** — pick F2/F1 per the *Open decision*; wire the C surface + 24-bit `&far_fn`
   materialization (`R_MOS_ADDR24` for a function symbol); land the end-to-end C gate.

(b) was independent and is done. (a) is now a multi-stage effort **gated on `0004`**; its front-end is a
separate open decision on top.

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

1. **(b)** ✅ `dev/run.sh far_near_call` → far call emits `JSL __call_near_from_far`, thunk body =
   `f4` (pea) + `6c` (jmp ind) + `6b` (rtl), near helper still `60` (rts); MAME + bsnes-jg both got
   `0xE0`; far→far + corpus + the prior far ROMs still PASS; thunk gc'd from near ROMs (byte-identical).
2. **(a) backend** `dev/run.sh farfp` (the `.ll`/`.S` gate) → `jsl __call_indir_far` + `dc` (jml (abs))
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

## Decisions (resolved 2026-06-21)

- **(b) far→near: SHIPPED.** Generic `__call_near_from_far` thunk merged to `main` (`5717f6b`), verified
  both emulators. Done.
- **(a) direction: PAUSE — (a) is a follow-up.** (b) ships now; (a) is gated on the far-CC Imag32 p2 base
  (`0004`) reaching `main` and is picked up then. The worktree (`wt/320-far-followups`) + this plan are
  left ready; do **not** tear it down (retention policy).
- **(a) front-end spelling: F2 — MOS `far` attribute** (user, 2026-06-21). When (a) is built: enable a
  GCC-compatible `far`/`long_call`-style attribute for MOS on functions **and** function-pointer typedefs
  (least Sema risk). F1 builtins remain the spike/escape hatch; F3 (type-enforced far-fn-ptr) is the
  deferred ideal. The **backend** half (the `0004` p2 base + `__call_indir_far`/indirect lowering +
  residual `G_TRUNC`/`G_UNMERGE`/`G_STORE` p2 legalization) can be validated on hand-authored IR first,
  decoupled from F2.

# #320 far-calls follow-ups — combined PLAN + HANDOFF

**Date:** 2026-06-21 · **Issue:** #320 (M1, far pointers/calls) · **Worktree:** `wt/320-far-followups`
(`/home/will/SRC/llvm-mos-65816-far-followups`, retained) · **Builds on:** Inc 4 Ph1 (direct `JSL`/`RTL`
far calls, landed 2026-06-20). This document is **both** the plan (designs + remaining work) and the
handoff (current state + how to resume) for the two #320 follow-ups. It supersedes the earlier draft of
this file (see `.history/`).

---

## 0. TL;DR — status

| Sub-task | State | Where |
|---|---|---|
| **(b) mixed-banking: far → near** | ✅ **DONE + SHIPPED to `main`** (`5717f6b`), verified both emulators | `main` |
| **(a) far function pointers** | 🚧 **IN PROGRESS** — call mechanism built+verified; p2-value path is a deep multi-layer 0004 sub-project (2 layers fixed, 3 open) + clang front-end | worktree `vendor/` |
| **(c) far tail calls** | ⛔ out of scope (separate; already conservative-safe) | — |

**One-line resume for (a):** finish 0004's p2-value handling — **Layer 3** (`SelectImm` with an illegal
Imag8 condition in the p2→i32 decompose) + **Gap B** (`G_STORE p2`) + **Gap A** (`&far_sym`→24-bit) — then
the **clang F2** `far` attribute + CodeGen, then the **e2e runtime gate**. Root-cause each layer with
`dev/run.sh asserts-build` (the release build only SIGSEGVs). The call mechanism + 2 RA-hint fixes are
already built (§5, §6).

---

## 1. Background & sharpened scope

Inc 4 Ph1 shipped the **direct** far-call mechanism: a call to a `.far_*`-sectioned function → `JSL` ($22,
3-byte `PBR:PC` push); that function returns `RTL` ($6B, pops 3). Both driven by the function's section,
`STI.hasW65816()`-gated, a16-independent (in `0001-320-far-addrspace.patch`).

**Measured scope correction (probes, 2026-06-21):** **far → far already works** — `lowerCall` emits `JSL`
for any `.far_*` callee and `lowerReturn` emits `RTL` for any `.far_*` function, independently, so a far
function calling another far function is already a correct non-leaf `JSL…RTL` chain. The "far must be a
leaf" wording was only ever about far → **near**. So the real gaps are:

- **(a) far function pointers** — an *indirect* call through a far code pointer.
- **(b) mixed-banking** — a far function calling a **near** function.

---

## 2. (b) Mixed-banking (far → near) — DONE + SHIPPED

A far function (bank $01, `PBR=$01`) calling a near function (bank $00) is broken because a near function's
code/`JSR`/`RTS` are program-bank-relative (must run at `PBR=$00`), and a near `RTS` can't restore the
caller's bank — only `JSL`/`RTL`/`JML`/`RTI` change `PBR`. So an `RTL` must execute on the way back,
reached by the near callee's `RTS`. The minimal construct is a **bank-0 thunk**.

**Mechanism (shipped):** a far → near direct call routes through a generic bank-0 thunk
**`__call_near_from_far`** reached by `JSL`:

```asm
; platforms/snes/call-near-from-far.s  (own gc-able section; built -mcpu=mosw65816)
__call_near_from_far:        ; entered via JSL from far code; PBR now = $00
	pea	.Lback-1	; push a near RTS return ( = g's target, minus 1 for RTS's +1)
	jmp	(__rc18)	; $6C near-indirect jump to g (g's 16-bit addr in RS9=__rc18); g runs at PBR=$00
.Lback:
	rtl			; pop the far caller's 3-byte return; PBR -> $01
```

`MOSCallLowering::lowerCall` detects caller-far + direct near callee, materializes `&g` into `RS9`
(`__rc18:__rc19`), `ChangeToES("__call_near_from_far")`, and emits `JSL` (HasW65816-gated; in `0001`,
a16-free). The near callee `g` is byte-for-byte unchanged (still `RTS`); near callers untouched. Per
far→near site: +1 byte (`JSL` vs `JSR`) + ~+14 cycles + a one-time ~7-byte thunk.

**Verified:** `examples/65816/far_near_call.c` + `dev/far_near_call.sh` — `main→far→near→near` chain returns
`0xE0` on **MAME + bsnes-jg** (the near callee ran at `PBR=$00` incl. its *own* near `JSR`); disasm gate
(`jsl __call_near_from_far`; thunk `pea`/`jmp(ind)`/`rtl`; near callee `rts`); corpus **7/7**; thunk
**gc'd from near ROMs** (byte-identical); `-verify-machineinstrs` clean; `0001` round-trips a16-free.

**Realization note:** a *per-callee veneer* (`g.far_veneer: jsr g; rtl`) is more byte-efficient but needs
AsmPrinter synthesis MOS lacks (no `emitEndOfAsmFile`); the generic thunk is simpler and shares the
"copy-address-to-slot + JSL-to-stub" plumbing with (a). Per-callee veneer = future byte-opt.

---

## 3. (a) Far function pointers — the three measured findings

(a) is an *indirect* call through a far code pointer. Three findings (measured, not assumed) define it:

1. **Front-end: no addrspace route.** A far code pointer can't use `__attribute__((address_space(2)))`
   (what far *data* uses) — clang forbids address-space-qualified **function types** ("function type may
   not be qualified with an address space"). `__attribute__((far))`/`long_call` exists but is
   `TargetSpecificAttr<TargetAnyMips>` (MIPS-only). And `&far_fn` currently materializes only 16 bits
   (`mos16lo/hi`, no bank) — **Gap A**.

2. **⚠ Layer-3 IR constraint: a far fn ptr cannot be a `ptr addrspace(2)` *callee*.** LLVM's verifier
   requires a call's callee in the program address space (0): `call … %fp` with `%fp : ptr addrspace(2)`
   → *"defined with type 'ptr addrspace(2)' but expected 'ptr'"*. The MOS datalayout has no `P<n>` field
   (program AS = 0 ⇒ near 16-bit fn ptrs), and `addrspacecast` p2→p0 drops the bank. **So the 24-bit
   address cannot ride the IR `call` callee** — it must be threaded explicitly (intrinsic / custom-CC /
   a stash-then-thunk). A "detect p2 callee in `lowerCall`" trigger is therefore *untriggerable*.

3. **p2-value handling is incomplete (0004).** The far-CC study shipped Imag32 p2 *passing/returning* via
   the CC value-handlers (patch `0004-320-far-cc.patch`), but forming/decomposing/storing a p2 *value*
   crashes (Gaps A/B + the RA-hint/`SelectImm` layers in §6). 0004 is **stacked into this worktree** to
   build (a) on; it is **not on `main`**.

---

## 4. (a) Design — IR-rep #1 (chosen by user 2026-06-21)

A far function pointer is a **`p2` (32-bit, low 24 = address)** value. Because of finding §3.2, calling it
is a **stash-then-thunk**: store the 24-bit target into a runtime slot, then a normal direct call to a
bank-0 thunk that long-indirect-jumps through the slot; the (far) target `RTL`s back to the original
caller.

```
  C:   fp(args)           // fp is a far function pointer (p2)
  IR:  store volatile i32 (ptrtoint p2 %fp to i32), @__mos_far_target   // "set far target"
       %r = call <ret> @__call_indir_far(args)                          // forwards args via the CC
  ASM: ...stash 24-bit target into __mos_far_target...
       jsl __call_indir_far        // pushes 3-byte PBR:PC
  __call_indir_far:  jml (__mos_far_target)   // $DC long-indirect tail jump
       <far target runs, RTL pops 3 -> original caller>
```

- **Front-end spelling = F2** (MOS `far` attribute) — locked by the user. F1 builtins = spike; F3
  (type-enforced far-fn-ptr) = deferred ideal.
- **"set far target" realization = a volatile store to a runtime global slot** `__mos_far_target`, *not* a
  formal LLVM intrinsic. A formal target intrinsic needs a new `IntrinsicsMOS.td` + an edit to the global
  `Intrinsics.td` (regenerates LLVM's intrinsic tables ⇒ heavy LLVM-wide rebuild) for no functional gain;
  the architecture is identical. `volatile` keeps the store from being DCE'd/reordered past the call.
- **`__call_indir_far` is JSL'd, not JSR'd** — `lowerCall` special-cases the symbol so the far target's
  `RTL` (3-byte pop) matches.

**Contract:** a far fn ptr must point to a far (`RTL`-returning) function — F2 enforces this at the type
level; document loudly for any builtin/integer route.

---

## 5. (a) What's BUILT + verified (the call mechanism)

The far-indirect **call mechanism** is built and verified on hand-authored IR with the target as a plain
**`i32`** (`store volatile i32 %t, @__mos_far_target` + `call @__call_indir_far(args)` → the slot store +
`jsl __call_indir_far`, `-verify-machineinstrs` clean). Two tracked + one vendor piece:

**Stub (tracked — committed on the worktree):** `platforms/snes/call-indir-far.s`

```asm
.section .text.__call_indir_far,"ax",@progbits   ; own gc-able section
.global __call_indir_far
__call_indir_far:
	jml	(__mos_far_target)	; $DC indirect-long jump through the 24-bit slot

.section .noinit,"aw",@nobits                    ; 4-byte bank-0 RAM slot
.global __mos_far_target
__mos_far_target:
	.zero 4
```
Wired into `platforms/snes/CMakeLists.txt`'s `snes-crt0-o` with a per-file `-mcpu=mosw65816`
(`set_source_files_properties(... call-indir-far.s PROPERTIES COMPILE_OPTIONS "-mcpu=mosw65816")`); own
section ⇒ `--gc-sections` drops it from ROMs with no far indirect call (near ROMs stay byte-identical).

**`lowerCall` → JSL for `__call_indir_far` (vendor — RECIPE, in `vendor/.../MOSCallLowering.cpp`):**

```cpp
// after CalleeIsFar / IsFarNearThunk, in lowerCall:
bool IsFarIndirThunk = STI.hasW65816() && Info.Callee.isGlobal() &&
                       Info.Callee.getGlobal()->getName() == "__call_indir_far";
// ... IsFar = STI.hasW65816() && (CalleeIsFar || IsFarNearThunk || IsFarIndirThunk);
// (no implicit RS9/RC20 use — the slot is the memory global __mos_far_target,
//  written by the volatile store; ordering is via the store's side effect.)
```

(Gitignored vendor edit; recipe here is the durable record.)

---

## 6. (a) REMAINING — p2-value completeness (the deep sub-project)

Feeding a *real* `p2` far pointer to the verified mechanism requires finishing 0004's p2-value handling.
**Root-cause each layer with `dev/run.sh asserts-build`** then `build/llvm-mos-asserts-install/bin/mos-clang
… -mllvm -verify-machineinstrs` on a repro (the release toolchain only SIGSEGVs). Minimal repros:
`/tmp/p2int.ll` (`define i32 @cvt(ptr addrspace(2) %fp){ ret ptrtoint }`), `/tmp/gapA.c`, `/tmp/gapB.c`,
`/tmp/aii_test.ll` (full p2 store + thunk call) — re-create from the snippets if `/tmp` is cleared.

### ✅ Layer 1 — FIXED: `copyCost` missing the `Imag32` case
`MOSRegisterInfo::copyCost` had GPR/Imag8/Imag16/Anyi1 cases but no `Imag32` → the RA's copy-hint cost hit
`llvm_unreachable("Unexpected physical register copy")` on *any* imag32 (p2) copy. **Fix (vendor recipe):**
```cpp
// in copyCost, after the Imag16RegClass case:
if (AreClasses(MOS::Imag32RegClass, MOS::Imag32RegClass)) {
  return copyCost(MOS::RC0, MOS::RC1, STI) * 4;   // 4 byte copies (mirrors copyPhysRegImpl)
}
```

### ✅ Layer 2 — FIXED: `getRegAllocationHints` costs size-mismatched pairs
The p2 decompose's sub-register copies make `getRegAllocationHints` call `copyCost(imag16, imag8)`
(cross-size) → same unreachable. **Fix (vendor recipe):** guard both cost loops:
```cpp
const auto &SizeMismatch = [&](Register SelfReg) {
  return !SelfReg || !OtherReg ||
         TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(SelfReg)) !=
             TRI.getRegSizeInBits(*TRI.getMinimalPhysRegClass(OtherReg));
};
// for (Register R : Order) { ... if (SizeMismatch(SelfReg)) continue; copyCost(...); }
```
**Both fixes regression-clean** (corpus 7/7, far_near_call PASS; they only fire for imag32/p2). They live
in `vendor/.../MOSRegisterInfo.cpp` (not yet patch-tracked — `0004` stacked blocks a clean `0001` regen).

### ⏳ Layer 3 — OPEN: `SelectImm` with an illegal condition
Post-RA, the p2→i32 path emits `$rs1 = SelectImm $rc5, -1, 0` whose **operand 1 is an Imag8 (`$rc5`)** —
`SelectImm`'s condition must be a flag (NZ/C/V) → verify "Illegal physical register". A sext-style
materialization is built with a mis-classed condition register in the decompose/return path. *Start here.*
Likely in `copyPhysRegImpl`'s Anyi1 branch or a sext lowering for the 4×s8 unmerge; root-cause via the
asserts build on `/tmp/p2int.ll` (the minimal `cvt` case reproduces it).

### ⏳ Gap B — `G_STORE (p2)` unable to legalize
Raw store of a p2 value isn't legalized (only the CC value-handler path stores p2, via `ptrtoint`). Needed
if any p2 is stored to arbitrary memory.

### ⏳ Gap A — `&far_sym` → 24-bit (`R_MOS_ADDR24`)
Taking the address of a `.far_*` symbol yields only 16 bits today. Needed to materialize a *real* far
function/data address as a `p2` (and for the e2e runtime test — without it there's no real far target to
point at). Extend the far-data address materialization (`0001` already emits `R_MOS_ADDR24` for far data
*accesses*) to address-of.

### ⏳ clang F2 front-end
Enable a MOS `far` attribute (un-gate `MipsLongCall` for MOS, or add `MOSFarCall`) for functions +
function-pointer typedefs; CodeGen emits `store volatile i32 (ptrtoint fp), @__mos_far_target` + `call
@__call_indir_far(args)` for a far-fn-ptr call. (No `BuiltinsMOS` exists yet.)

### ⏳ e2e runtime gate
After Gap A + F2: `examples/65816/far_fnptr.c` + `dev/far_fnptr.sh` — take `&far_leaf` as a far fn ptr,
launder through `volatile`, call it; host == default == far on MAME + bsnes-jg; disasm shows 24-bit
`&far_leaf` + `jsl __call_indir_far`.

**Suggested order:** Layer 3 → Gap A (unblocks a runtime test of the whole mechanism) → F2 → e2e → Gap B
(only if needed). Then land the lot in `0001` (regen once `0004`'s relationship to `main` is settled).

---

## 7. Handoff — worktree state & how to resume

**Worktree `wt/320-far-followups`** (compiler-changing; own `vendor/` + warm-copied `build/`; **retained**
per policy). Committed there: `1ea7507`/`7ee5f6f` (the (a) stub, CMakeLists, the stacked `0004` patch).
**Uncommitted, gitignored `vendor/` edits (recipes in §5/§6):** `MOSCallLowering.cpp` (`IsFarIndirThunk`),
`MOSRegisterInfo.cpp` (Layers 1+2). The toolchain in the worktree's `build/` is built with all of these
(`0004` + (b) + (a) mechanism + Layers 1/2).

**To resume (a):**
1. `cd /home/will/SRC/llvm-mos-65816-far-followups`
2. Confirm the warm toolchain: `dev/run.sh corpus` (expect 7/7).
3. Root-cause Layer 3: `dev/run.sh asserts-build` then
   `build/llvm-mos-asserts-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature
   -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs -c -o /dev/null /tmp/p2int.ll` → read the precise
   assert. (Re-create `/tmp/p2int.ll` from §6 if cleared.)
4. After each vendor edit: `dev/run.sh toolchain` (confirm `build/llvm-mos-install/bin/clang-23` mtime
   advanced — the `clang` symlink has a stale mtime), then re-run the repro **and** the regression
   (`dev/run.sh corpus` + `dev/run.sh far_near_call`) — these RA paths affect *all* codegen.

**Gotchas:**
- The release build SIGSEGVs on these p2 crashes; **always use the asserts build to root-cause**.
- The worktree's `vendor/` carries a **foreign `MOSInsertREPSEP.cpp` WIP delta** (copied at `cp -a` setup;
  another agent's). Leave it; it's excluded from `0001`; it makes `dev/regen-patch-0001.sh`'s whole-dir
  verify fail (cosmetic — confirm `0001` round-trips for *your* files with the targeted check).
- `0004` is stacked in the worktree's `vendor/` (applied) but its patch file is committed; regen-`0001`
  while `0004` is applied would contaminate `0001` — don't.
- Far-call build needs **both** `dev/run.sh toolchain` (compiler) **and** `dev/run.sh build` (SDK; vendors
  `platforms/snes*` incl. the stubs + `link.ld`); a compiler-only rebuild leaves the installed SDK stale.

**General mechanics** (build/test commands, the differential gate, backend navigation): the auto-loaded
`docs/agent-handoff.md`. The worktree row there points back to this document.

---

## 8. Decisions & verification

**Decisions (2026-06-21):** (b) ship the generic thunk (per-callee veneer = future byte-opt); (a) build
**IR-rep #1** end-to-end; (a) front-end = **F2** (MOS `far` attr); "set far target" realized as a volatile
global-slot store (not a formal intrinsic). (c) far tail calls = separate, out of scope (the tail-call
peephole keys on `MOS::JSR`, so a `JSL` is never tail-converted — conservative-safe already).

**Verification bar** (unchanged): the project differential — host == default(non-`+mos-a16`)@MAME ==
far@MAME == far@bsnes-jg, plus `-verify-machineinstrs` clean. (b) meets it. (a)'s mechanism is verified at
the IR level (i32-target); its e2e differential gate is pending Gap A + F2.

**Patch placement:** (b) is in `0001` (HasW65816-gated, a16-free) on `main`. (a)'s vendor changes are WIP
in the worktree; they land in `0001` (and/or a stacked patch alongside `0004`) when (a) completes.

---

## 9. Commit trail (main)

- `5717f6b` ship (b) far→near to main · `560900c` (a) call mechanism built+verified ·
  `5fd0ff5` Layer-3 IR-callee finding · `93c7336` p2-value multi-layer root-cause + Layers 1/2 fixed.
- Worktree: `dd33017` (b) · `1ea7507` (a) stub+0004 · `7ee5f6f` (a) global-slot stub.

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
| **(a) far function pointers** | ✅ **DONE — backend + clang F2 + e2e VERIFIED both emulators** (2026-06-21) — the full p2-value sub-project (Layer 3 + Gap A + Gap B) **and** the clang `far`/`long_call` attribute (F2) are complete; a **single-file C** far-fn-ptr call (`far_leaf(0x5A)`, no asm / no `.set`) works end-to-end on real silicon. | worktree `vendor/` |
| **(c) far tail calls** | ⛔ out of scope (separate; already conservative-safe) | — |

**(a) is now fully closed** — the clang **F2** front-end (the `far`/`long_call` attribute + call-rewrite)
landed on the worktree 2026-06-21 and the e2e was rewritten to the clean single-file surface
(`__attribute__((section(".far_text"), noinline, far))` + a plain `far_leaf(0x5A)` call — no `.set`, no
hand-rolled `__mos_far_target` plumbing). It compiles to the proven IR shape, `-verify-machineinstrs` clean,
`far_leaf(0x5A)==0xFF` on **MAME + bsnes-jg**, regression-clean (corpus 7/7, far_near_call + xcheck, csmith
0-mismatch). Recipe: §6 "clang F2". The original deep-dive resume follows for history.

**One-line resume for (a) [historical]:** the deep p2-value sub-project is **COMPLETE + e2e-verified** —
✅ **Layer 3** (the *actual* crash, after Layers 1/2, was `selectUnMergeValues` using byte subreg indices
for the `s32→2×s16` unmerge → an ill-sized `Imag16=COPY Imag8`; fixed to size-gated `sublo16`/`subhi16`,
mirroring `selectMergeValues`) · ✅ **Gap A** (`&far_sym`→24-bit: new `buildFarAddrWords` + `MO_ADDR24_*`
flags → `#mos24segmentlo/hi` + `#mos24bank`, composed into an `Imag32`) · ✅ **Gap B** (`G_STORE`/`G_LOAD`
of a `p2` *value* legalized by listing `PF` as a value type). The **e2e gate**
(`examples/65816/far_fnptr.c` + `dev/far_fnptr.sh`, wired into `dev/run.sh` + `dev/xcheck.sh`) **PASSES on
MAME + bsnes-jg** (`far_leaf(0x5A)==0xFF`, bank `$01`, `R_MOS_ADDR24_BANK` reloc, `jsl __call_indir_far`;
a16-only like far_cast/far_indir). Recipes for all backend edits: §6. **The ONLY remaining piece is the
clang F2 `far` attribute + call CodeGen** — pure front-end ergonomics; the backend needs nothing more.

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

### ✅ Layer 3 — FIXED: `selectUnMergeValues` used byte subreg indices for the wide unmerge
The plan's earlier "`SelectImm` illegal Imag8 condition" framing was **stale** — Layers 1/2 had already
moved the crash. The *actual* current crash (asserts build, `/tmp/p2int.ll` = `cvt: ptrtoint p2→i32`) is
`copyPhysRegImpl` "Unexpected physical register copy" on a **dead `$rsN(Imag16) = COPY $rc5(Imag8)`** —
`selectUnMergeValues` (`MOSInstructionSelector.cpp`) unconditionally tagged the unmerge result copies with
the **byte** subreg indices `MOS::sublo`/`MOS::subhi`. For the a16 `s32→2×s16` unmerge the destinations are
16-bit, so the source subreg of an `Imag32` must be the **word** index `sublo16`/`subhi16` (a byte index
resolves to a 1-byte `$rc`, giving the ill-sized 16←8 copy). **Fix (vendor recipe — in the `else` branch of
`selectUnMergeValues`, mirroring the size gate in `selectMergeValues`):**
```cpp
const bool Wide = Builder.getMRI()->getType(Lo) == LLT::scalar(16);
const unsigned LoSub = Wide ? MOS::sublo16 : MOS::sublo;
const unsigned HiSub = Wide ? MOS::subhi16 : MOS::subhi;
LoCopy = Builder.buildCopy(Lo, Src); LoCopy->getOperand(1).setSubReg(LoSub);
HiCopy = Builder.buildCopy(Hi, Src); HiCopy->getOperand(1).setSubReg(HiSub);
```
A 16-bit unmerge result only arises from a16 `s32→2×s16`, so the 8-bit path is byte-for-byte unchanged.
With this, the *whole* mechanism with a real `p2` (`callfar`: `ptrtoint` + `store volatile i32` + thunk
`call`) is verify-clean. (Layers 1/2 stay; the size-mismatch hint guard is now belt-and-suspenders.)

### ✅ Gap B — FIXED: `G_STORE`/`G_LOAD` of a `p2` *value* (list `PF` as a value type)
`legalizeLoad`/`legalizeStore` already convert a *pointer* value to `s32` (`inttoptr`/`ptrtoint`) and re-run
(the `s32` then narrows to bytes) — but a `p2` value never *reached* them: the `{G_LOAD,G_STORE}` action
rule's **value-type** set omitted `PF`, so it fell through to `.maxScalar(0,S8).unsupported()`. **Fix
(vendor recipe — `MOSLegalizerInfo.cpp`):** add `PF` to the value-type cartesian-product set (both the
`hasAccum16()` and the else branch). `PF` is addrspace 2 — only W65816 far code forms one — so it is inert
on every other subtarget. (`G_LOAD p2` had the same gap; this fixes both.)

### ✅ Gap A — FIXED: `&far_sym` → full 24-bit `Imag32` (`R_MOS_ADDR24`)
`selectAddr` crashed (`buildLdImm` asserts dest ≤ 16 bits) on a `p2` `G_GLOBAL_VALUE`. **Fix (vendor recipe,
all in `MOSInstructionSelector.cpp` + `MOSInstrInfo.h` + `MOSMCInstLower.cpp`):**
- `MOSInstrInfo.h` `TOF`: add `MO_ADDR24_SEG_LO`, `MO_ADDR24_SEG_HI`, `MO_ADDR24_BANK`.
- `MOSMCInstLower.cpp` `lowerSymbolOperand`: 3 new cases → `VK_ADDR24_SEGMENT_LO`/`_HI`/`_BANK`
  (the segment 16 bits == a near `R_MOS_ADDR16` would give, but the ADDR24 family is bank-aware/explicit).
- `static isFarSymbol(Op)`: a global is far if `getAddressSpace()==MOS::AS_Far` **or** its aliasee object is
  in a `.far*` section (covers far functions, which are AS0 + `.far_text`).
- `buildFarAddrWords(Builder, GO)`: builds 4 `LDImm` bytes (seg-lo, seg-hi, bank, `#0`) and `composePtr`s
  them into two `Imag16` words `(segment)` and `(bank,0)`; returns the pair.
- `selectAddr` (direct `p2` use): if `isFarSymbol`, `REG_SEQUENCE` the two words into the `Imag32` dest via
  `sublo16`/`subhi16` + `constrainGenericOp`.
- `selectAddrLoHi` (the `s32→2×s16` unmerge fold): if `isFarSymbol`, return the two words. (Only the
  top-level word unmerge of the global ever reaches here, so the word-vs-byte match always holds.)

Verified: `get_addr` (return `p2`) and `addr_i32` (`ptrtoint p2→i32`) emit `#mos24segmentlo/hi` + `#mos24bank`
into an `Imag32`; works in both the a16 *and* the default build (pure immediate loads + `REG_SEQUENCE`).

**All three regression-clean:** corpus **7/7**, `far_near_call` **PASS (0xE0)**, `xcheck` all far ROMs PASS;
they fire only for `p2`/`Imag32`/far-symbol paths. They live in the worktree's gitignored `vendor/`
(`0004` stacked blocks a clean `0001` regen — land them in `0001` once `0004`'s relationship to `main` is
settled).

### ✅ e2e runtime gate — DONE (both emulators)
`examples/65816/far_fnptr.c` + `dev/far_fnptr.sh` (worktree `579b911`, wired into `dev/run.sh` +
`dev/xcheck.sh`): a `.far_text` function's **full 24-bit address** is taken as a far (`p2`) value, stashed
into `__mos_far_target`, and called via `jsl __call_indir_far` (→ `jml (__mos_far_target)`); `far_leaf`
`RTL`s back. **`far_leaf(0x5A) == 0xFF` on MAME + bsnes-jg**, `far_leaf` in bank `$01`, the target
materialization carries a `R_MOS_ADDR24_BANK` reloc, `jsl __call_indir_far` present. **a16-only** (host ==
a16@MAME == a16@bsnes-jg; like `far_cast`/`far_indir`, the default 8-bit build can't decompose a 32-bit
far-pointer value — `s32↔4×s8` (un)merge is `unsupported`, so there is **no default leg**).
*Front-end note:* clang forbids addrspace-qualified function types **and** collapses a far-data alias that
shares a defined AS0 function's name back to a bank-less near address — so the test takes the address through
a **distinct-named** linker alias viewed as far data (`.set __far_leaf_addr, far_leaf`). This hand-emulates
exactly what F2 will hide.

### ✅ clang F2 front-end — DONE (2026-06-21)
C now expresses a far-fn-ptr call in a **single file, no asm, no `.set`**: mark the target function `far`
(`__attribute__((section(".far_text"), noinline, far))`) and call it normally (`far_leaf(0x5A)`); clang
lowers the call to the proven shape
(`store volatile i32 ptrtoint(ptr addrspace(2) @__mos_far_<sym>), @__mos_far_target` + `call
@__call_indir_far(args)`). `-verify-machineinstrs` clean; `far_leaf(0x5A)==0xFF` on **MAME + bsnes-jg**;
corpus 7/7, far_near_call + xcheck PASS, csmith 0-mismatch.

**Design choice (recon-validated):** the `far` attribute rides the **function decl**, intercepted at the
**call site** — *not* a far-fn-ptr value *type*. A typed far-fn-ptr variable (`far_fn_t fp;`) would need
`ConvertType` to map a far-attributed function-pointer type to `ptr addrspace(2)` (32-bit), but
`getTargetAddressSpace` hard-returns the program AS for function pointees and `ConvertType` canonicalizes
away the attribute sugar; worse, clang's `getPointerWidthV(AS2)` reports **16** (not 32) so `sizeof(far*)`
and the IR `p2:32:8` width disagree — a miscompile landmine. The function-attribute + call-site rewrite hits
the *exact* proven IR with **zero** type-system surgery and **no** runtime far-pointer variable (the only p2
value is the transient `ptrtoint(@__mos_far_<sym>)`). The typed-variable / indirect-through-`fp` surface
(`far_fn_t fp = far_leaf; fp(x);`) was built as a **follow-up** —
[plan](2026-06-21-320-far-fnptr-typed-variable.md), DONE 2026-06-21: a `far` bit on the canonical
`FunctionType::ExtInfo` makes a far-attributed function-pointer type lower to `ptr addrspace(2)`, the
`fp = far_leaf` decay materializes the p2 alias, and `fp(x)` ptrtoints the loaded pointer into the slot.
`far_fnptr_var.c` e2e `0xFF` on both emulators, regression-clean. (`getPointerWidthV(AS2)`→32 — for
`sizeof`/aggregate/stored far pointers — is still deferred.)

**Recipe (gitignored `vendor/` edits — durable record; land in `0001` once `0004` settles):**

- **`clang/include/clang/Basic/Attr.td`** — new `def MOSFarCall : InheritableAttr, TargetSpecificAttr<TargetMOS>`
  with `Spellings = [GCC<"long_call">, GCC<"far">]`, `Subjects = [Function]`, `ParseKind = "LongCall"`. The
  `far`/`long_call` GNU spellings already belong to MIPS's `MipsLongCall`; a second owner collides in the
  `getAttrKind` StringMatcher (`report_fatal_error("Had duplicate keys")` at **tablegen time**) unless both
  share a `ParseKind` — exactly how the multi-target `interrupt` spelling is shared. So **also** give
  `MipsLongCall` `let ParseKind = "LongCall";` and **drop its `let SimpleHandler = 1;`** (shared-ParseKind
  attrs dispatch via an explicit handler, like `interrupt`). Tablegen then emits one merged
  `ParsedAttrInfoLongCall` (kind `AT_LongCall`) whose auto-generated `diagAppertainsToDecl` enforces
  function-only and whose `existsInTarget` covers `mos` + the mips arches. **Validate with `clang-tblgen`
  before any clang rebuild** (sub-second): `-gen-clang-attr-parsed-attr-kinds` (no duplicate-key fatal,
  `far`→`AT_LongCall`), `-gen-clang-attr-parsed-attr-impl` (merged info), `-gen-clang-attr-classes`
  (`MOSFarCallAttr`).
- **`clang/lib/Sema/SemaDeclAttr.cpp`** — `static void handleLongCallAttr(Sema&, Decl*, const ParsedAttr&)`
  dispatching on the triple arch (`== llvm::Triple::mos` → `handleSimpleAttribute<MOSFarCallAttr>`, else
  `handleSimpleAttribute<MipsLongCallAttr>`), plus `case ParsedAttr::AT_LongCall: handleLongCallAttr(...);`
  in `ProcessDeclAttribute`. Subject/target appertainment is already enforced by the merged
  `ParsedAttrInfoLongCall` before the handler runs, so no manual checks. (Blast radius: only `Mips.cpp`
  reads `MipsLongCallAttr`; nothing references the old `AT_MipsLongCall` parsed kind.)
- **`clang/lib/CodeGen/CGExpr.cpp`** — `static CGCallee emitMOSFarIndirectCallee(CGF, FnInfo, Sym)` +, in
  `CodeGenFunction::EmitCall(QualType, …)` just before the inner `EmitCall(FnInfo, Callee, …)`, the intercept
  `if (auto *FarFD = dyn_cast_or_null<FunctionDecl>(TargetDecl); FarFD && FarFD->hasAttr<MOSFarCallAttr>())
  Callee = emitMOSFarIndirectCallee(*this, FnInfo, CGM.getMangledName(GlobalDecl(FarFD)));`. The helper: emit
  `module asm ".globl __mos_far_<sym>\n.set __mos_far_<sym>, <sym>"` + an `external addrspace(2) constant i8`
  global named `__mos_far_<sym>` (the **distinct-named** AS2 alias — a same-named alias of the AS0 function
  collapses to a bankless near address; an addrspacecast AS0→AS2 zero-extends/drops the bank), once per
  target; `store volatile i32 ptrtoint(@__mos_far_<sym>), @__mos_far_target` (align 1); then return
  `CGCallee::forDirect(CGM.CreateRuntimeFunction(GetFunctionType(FnInfo), "__call_indir_far"))`. The store
  sits after `EmitCallArgs` and immediately before the call, so a nested far call in an argument can't
  clobber the slot first. (`__call_indir_far` is typed with the target's exact signature → MOSCallLowering
  JSLs it and forwards arg registers untouched.)
- **`examples/65816/far_fnptr.c`** (tracked, worktree) — rewritten to the clean `far` surface; the old
  `.set __far_leaf_addr` / `extern volatile __mos_far_target` / `extern __call_indir_far` hand-emulation
  deleted. (`dev/far_fnptr.sh` unchanged — the disasm/link/exec gates still pass.)

**Status:** the whole of (a) — Layer 3 → Gap A → e2e → Gap B → **F2** — is **done**. Land the backend +
F2 recipes in `0001` (regen once `0004`'s relationship to `main` is settled — F2 touches only `clang/`, so
it composes cleanly with the backend MOS-target edits).

---

## 7. Handoff — worktree state & how to resume

**Worktree `wt/320-far-followups`** (compiler-changing; own `vendor/` + warm-copied `build/`; **retained**
per policy). Committed there: `1ea7507`/`7ee5f6f` (the (a) stub, CMakeLists, the stacked `0004` patch).
**Uncommitted, gitignored `vendor/` edits (recipes in §5/§6):** `MOSCallLowering.cpp` (`IsFarIndirThunk`),
`MOSRegisterInfo.cpp` (Layers 1+2), `MOSInstructionSelector.cpp` (Layer 3 + Gap A: `isFarSymbol`,
`buildFarAddrWords`, `selectAddr`/`selectAddrLoHi`), `MOSInstrInfo.h` (`MO_ADDR24_*`), `MOSMCInstLower.cpp`
(`VK_ADDR24_*` cases), `MOSLegalizerInfo.cpp` (Gap B: `PF` value type). The toolchain in the worktree's
`build/` is built with **all** of these (`0004` + (b) + (a) mechanism + Layers 1/2/3 + Gap A + Gap B).
**Tracked, committed there (`579b911`):** `examples/65816/far_fnptr.c`, `dev/far_fnptr.sh`, the `dev/run.sh`
+ `dev/xcheck.sh` wiring.

**To resume (only F2 remains):**
1. `cd /home/will/SRC/llvm-mos-65816-far-followups`
2. Confirm the warm toolchain + e2e: `dev/run.sh corpus` (7/7), `dev/run.sh far_fnptr` (PASS 0xFF),
   `dev/run.sh xcheck` (all far ROMs PASS incl. `far_fnptr`).
3. Implement F2 (§6 "clang F2 front-end") in `clang/` (the only change left), then `dev/run.sh toolchain`
   (confirm `build/llvm-mos-install/bin/clang-23` mtime advanced — the `clang` symlink has a stale mtime).
   Make the single-file far-fn-ptr call work (replace the `.set`-alias hand-emulation in `far_fnptr.c`).

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

**Verification bar:** the project differential — host == far@MAME == far@bsnes-jg, plus
`-verify-machineinstrs` clean. (b) meets it (a16-independent, incl. the default leg). (a) meets it
**a16-only** (host == a16@MAME == a16@bsnes-jg; like `far_cast`/`far_indir`, the default 8-bit build can't
decompose a 32-bit far-pointer value — no default leg). The e2e (`far_fnptr`), now driven by the clean F2
`far` surface, **PASSES** (`0xFF`, both emulators); backend + F2 are verify-clean. **(a) is fully closed.**
F2 regression-clean: corpus **7/7**, far_near_call + xcheck PASS, a16unmerge PASS, csmith **36/40, 0
mismatch / 0 crash** (the differential fuzzer compiles every program both default and a16 — proof the
`far`-attribute / call-rewrite is inert for all non-`far` code).

**Patch placement:** (b) is in `0001` (HasW65816-gated, a16-free) on `main`. (a)'s vendor changes
(Layers 1/2/3 + Gap A + Gap B + the (a) call mechanism + **F2** clang front-end) are WIP in the worktree's
gitignored `vendor/`; they land in `0001` (and/or a stacked patch alongside `0004`) when `0004`'s
relationship to `main` settles. F2 touches only `clang/` (Attr.td + SemaDeclAttr.cpp + CGExpr.cpp), so it
composes cleanly with the MOS-target backend edits.

---

## 9. Commit trail

- **main:** `5717f6b` ship (b) far→near · `560900c` (a) call mechanism built+verified ·
  `5fd0ff5` Layer-3 IR-callee finding · `93c7336` p2-value multi-layer root-cause + Layers 1/2 fixed ·
  `15df5fe` consolidate plan+handoff.
- **worktree `wt/320-far-followups`:** `dd33017` (b) · `1ea7507` (a) stub+0004 · `7ee5f6f` (a) global-slot
  stub · `579b911` (a) backend p2-value sub-project DONE (Layer 3 + Gap A + Gap B, recipes §6) + e2e
  `far_fnptr` verified both emulators · **(a) clang F2 — the `far`/`long_call` attribute + call-rewrite;
  `far_fnptr.c` rewritten to the clean single-file surface; e2e `0xFF` MAME+bsnes-jg, regression-clean.**

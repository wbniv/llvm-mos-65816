# llvm-mos #320 — a running, non-breaking far-pointer slice (for the design discussion)

*A working implementation of the foundational #320 layer — 24-bit "far" pointers via the existing
65816 absolute-long instructions — brought to anchor the design discussion, in the project's
code-first spirit. Honest about what it does and doesn't do, and where it deliberately diverges from
@asiekierka's proposed address-space numbering so we can reconcile it consciously.*

Repo / working branch: **[wbniv/llvm-mos-65816](https://github.com/wbniv/llvm-mos-65816)** — the
backend change is a single tracked patch (`patches/llvm-mos/0001-320-far-addrspace.patch`, the eventual
upstream diff) applied to a clean `llvm-mos` clone, plus a SNES test bench (an
[llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415)-shaped target + a headless
MAME harness + a 6502 regression corpus).

---

## TL;DR

- **What:** `__attribute__((address_space(2)))` "far" pointers now compile to 65816 **absolute-long**
  loads/stores (`LDA/STA $xxxxxx`, opcodes `AF`/`8F`), gated on `FeatureW65816`. It wires GlobalISel
  to the **already-shipped** 65816 MC instructions — no new instructions, no assembler changes.
- **Non-breaking:** addrspace 0 (the 6502 default) is untouched; the whole 6502 regression corpus
  stays green on the patched toolchain. The far path is purely additive and feature-gated.
- **Verified end-to-end in an emulator:** disassembly (Inc 1), then a real far load+store executing in
  MAME in bank `$00` (Inc 2), then a far read **crossing a ROM bank boundary into bank `$01`** (Inc 2b).
- **The ask:** one conscious divergence to reconcile — this slice uses **addrspace 2 = far**
  (additive, so addrspace 0 stays the 6502 default), whereas the proposed model uses **0 = 32-bit far
  (default)** / **2 = 16-bit absolute**. Adopting `0 = far-default` is a module-wide ABI decision; I
  kept it additive to ship a running slice without pre-committing it. Details + a reconciliation path
  below.

---

## Correction & new findings (2026-06-21)

*Folding in what we learned building toward the full five-address-space model. Three things change how
this note should read.*

**Status since drafting.** This slice has grown well past the foundational layer: runtime far pointers
(`lda [dp]`), near→far casts, far-pointer arithmetic, far calls (`JSL`/`RTL`, far→near, far function
pointers), the far-pointer calling convention (`p2`→`Imag32`), and 16-bit-accumulator (`+mos-a16`)
codegen all landed, dual-emulator-verified. The "what this does **not** do yet" section below is the
*original* snapshot, kept for provenance.

**1. Retraction — a 24-bit pointer is NOT a power-of-two-size problem.** This note justified the 32-bit
"claim 32, use 24" pointer with *"LLVM requires power-of-two pointer sizes."* **That is false.**
`DataLayout::parseSize` accepts any non-zero ≤24-bit value as a pointer size (the only `isPowerOf2`
check is on *alignment*), and `getPointerSize = divideCeil(bits, 8)` — so `p:24` parses and a 24-bit
pointer is exactly **3 bytes**; `getIntPtrType` is `i24`. The GISel backend also carries a genuine
24-bit value (`_BitInt(24)` compiles clean, default and `+mos-a16`). **The real reason far stays
32-bit is `MVT`:** there is no `MVT::i24`, so a 24-bit value can't ride the register-class /
calling-convention (`CCValAssign`) interfaces that still speak `MVT`. "Claim 32, use 24" is a
backend-plumbing convenience, **not an IR-representability limit.**

**2. `0 = far` as the default is architecturally foreclosed in llvm-mos.** The MOS datalayout is a
*single* static string shared by the 6502 **and** every 65816 subtarget — not subtarget-conditional.
Redefining `addrspace 0` to 32-bit far would make *every 6502 pointer* 32-bit and break the non-65816
backend. So the proposal's headline `0 = far-default` can't be taken literally. The faithful way to
express "far by default" is a **clang memory-model flag** that emits plain `T*` into the far space —
`addrspace 0` keeps its 16-bit meaning. This reframes open decision #1 (below): treat the default as a
front-end flag, and lead the argument with runtime cost now that the representability prop is gone.

**3. The packed-24 space (proposal `3`): representable, but recommend deferring on measurement.** Its
1-byte-per-pointer win lands *only* on far pointers **stored in memory** — and we measured that a far
pointer **cannot be stored in memory at all yet**: `sizeof(far*)` reports 2 (not 4), and
storing/loading a far pointer to a global/array/struct fails to legalize (both default and `+mos-a16`).
So packed-24 would size-optimize a capability that doesn't exist; the prerequisite is **completing the
far-pointer value type** (storable + correct `sizeof`), the real next far-*data* work. Defer space `3`
until that lands and real stored-far-pointer byte-pressure is measured. Space `4` (zero-bank) is ≈ a
near pointer — marginal. *(Evidence: the five-address-space plan + `dev/measure-five-space-census.sh`.)*

---

## What's implemented + verified

**Address space + data layout** (additive). A third pointer kind alongside the existing two:

```
// MOSInstrInfo.h
// AS_Memory  (0): 16-bit absolute pointer (6502 default; data-bank-relative on 65816).
// AS_ZeroPage(1): 8-bit direct-page pointer.
// AS_Far     (2): 32-bit "far" pointer — 65816 24-bit address in the low 3 bytes.
enum AddressSpace { AS_Memory, AS_ZeroPage, AS_Far, NumAddrSpaces };

// data layout (all three of MOSTargetMachine / clang MOS.cpp / TargetDataLayout)
"e-m:e-p:16:8-p1:8:8-p2:32:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"
//                  ^^^^^^^ addrspace 2 = 32-bit pointer; only the low 24 bits are
//                          emitted as the 65816 long address (the "claim 32-bit, use 24"
//                          approach — see Correction #1 below: this is an MVT-has-no-i24
//                          plumbing convenience, NOT a power-of-two-size limit).
```

**Codegen path** (all GlobalISel; gated on `W65816`):

- Legalizer: `LLT::pointer(2, 32)` is legal for `G_GLOBAL_VALUE`/`G_LOAD`/`G_STORE`;
  `selectAddressingMode` gains `case 32` → `tryFarAbsoluteAddressing`, which matches a
  constant-or-global far address and rewrites the generic load/store to a far pseudo.
- New GISel pseudos `G_LOAD_FAR_ABS` / `G_STORE_FAR_ABS` (`Predicates = [HasW65816]`) →
  instruction-selector → `LDA_AbsoluteLong` / `STA_AbsoluteLong`. **These MC instructions, the
  `Addr24` fixups, `R_MOS_ADDR24`, `IndirectLong` `[dp]`, and zero-bank relaxation already shipped**
  with the 65816 assembler ([#147](https://github.com/llvm-mos/llvm-mos/issues/147)) — this change
  only teaches codegen to emit them.

**Why no native mode is needed:** absolute-long carries the full 24-bit address (including the bank
byte) and ignores the Data Bank Register, so far loads/stores execute correctly in plain
6502-**emulation** mode — the state the 65816 powers on in. No `XCE`, no register-width setup. (That
keeps this slice cleanly separate from #321 / the hardware stack.)

**Verification ladder** (each step's raw evidence is in the repo's `docs/plans/2026-06-14-320-*`):

| Increment | Proof | Evidence |
|-----------|-------|----------|
| 1 — codegen ([`3358a1a`](https://github.com/wbniv/llvm-mos-65816/commit/3358a1a)) | far → absolute-long at the disassembly level | far const `0x7E1234` → `af 34 12 7e` / `8f 34 12 7e`; far global → `R_MOS_ADDR24`; a near (addrspace 0) access in the same TU stays 3-byte `ad`/`8e`. 6502 corpus 7/7. |
| 2 — executes ([`a8dd8a5`](https://github.com/wbniv/llvm-mos-65816/commit/a8dd8a5)) | the far load+store runs on emulated silicon | a far load (ROM) + far store (WRAM) round-trips in MAME → `SMOKE: PASS got=0xF3`. |
| 2b — crosses a bank ([`ec2aa31`](https://github.com/wbniv/llvm-mos-65816/commit/ec2aa31)) | a far read reaches a *higher* ROM bank | 64 KiB LoROM; far global placed in bank `$01`; linked far load is `af 00 80 01` (`lda $018000`); the cross-bank read round-trips in MAME → `SMOKE: PASS got=0xF3`. |

---

## Scope — what this slice deliberately does **not** do yet

So there's no ambiguity about how much is claimed:

- **Constant/global far addresses only.** Runtime far pointers — near→far casts, far-pointer
  arithmetic, indirect-long `[dp]` — are a later increment. A far access that can't be matched as an
  absolute address currently **fails to legalize rather than miscompiling** (deliberate: loud, not
  silent).
- **8-bit registers only.** No `REP`/`SEP`, no 16-bit accumulator — [#321](https://github.com/llvm-mos/llvm-mos/issues/321)
  is untouched.
- **No calling-convention change.** Far values flow through the existing paths; no ABI surface moved.
- **Emulation mode only**; far **data** only (no far code / `JSL` across banks yet).

It is the **minimal additive form of #320's foundational layer** — enough to be real and verifiable,
small enough to not pre-empt the ABI decisions below.

---

## Address-space numbering: this slice vs the proposed model

@asiekierka's [2024-03-14 #320 proposal](https://github.com/llvm-mos/llvm-mos/issues/320) maps the
65816 pointer zoo to the 8086 near/far model. This slice implements a **subset**, but with a different
number for "far":

| addrspace | **This slice** | **#320 proposal** |
|-----------|----------------|-------------------|
| `0` | 16-bit absolute — **6502 default, untouched** | **32-bit far** (the new default) |
| `1` | 8-bit direct page | 8-bit direct page ✓ |
| `2` | **32-bit far** (`p2:32:8`) | 16-bit absolute |
| `3` | — | 24-bit packed far |
| `4` | — | 16-bit zero-bank |

**Why the divergence is deliberate.** The proposal makes addrspace **0 = 32-bit far the default** —
a module-wide ABI change (every plain pointer becomes far). That is exactly the kind of decision the
project (rightly) wants made behind a real implementation, not ahead of one. To ship a *running,
non-breaking* slice without pre-committing it, I kept addrspace 0 as the 6502's 16-bit default and
added **far as an opt-in at addrspace 2**. Width agrees with the proposal (32-bit, low-24 emitted);
only the *number* and the *default-ness* differ.

Think of it as **Option A → Option B**:
- **Option A (this slice):** additive `2 = far`, default unchanged. Minimal, non-breaking, verifiable
  now. Evidence, not ABI.
- **Option B (the proposal):** `0 = 32-bit far` default + the full five-space layout. The real ABI.

**Reconciliation:** I'm happy to renumber to the proposal's scheme (`0 = far`, `2 = absolute`, add
`3`/`4`) as part of building the full model — once we've made the default-pointer-width call together.
Flagging it here so the divergence reads as conscious, not accidental.

---

## Open ABI decisions this slice informs (but does not decide)

1. **Default pointer width.** *(Reframed by Correction #2: `0 = far-default` is foreclosed by the
   single shared datalayout — this is a **clang memory-model flag**, not a layout change.)* The case
   for far-by-default now rests on the **"32-bit is *cheaper* than 24-bit on the 65816"** finding
   (24-bit arithmetic forces a 16+8 access pair and a mode switch) — the load-bearing argument, since
   the representability prop is retracted (Correction #1) — vs. a 16-bit default with opt-in far (this
   slice). Buildable as a front-end flag, default off, so the decision can ride on measured bytes.
2. **The five-space layout + final numbering** — including packed-24 (`3`) and zero-bank (`4`), which
   this slice doesn't touch yet. *(Correction #3: packed-24 is representable but recommended
   deferred-on-measurement — its win needs far-pointers-stored-in-memory, which isn't complete yet;
   zero-bank ≈ a near pointer, marginal.)*
3. **Calling convention** (still open in #320/#321). Documented prior art, read firsthand from the
   WDC816CC manual (pp.21–26) and ORCA/C `Gen.pas`: both shipped-in-production compilers use a
   **hybrid** frame — arguments on the hardware stack, then `PHD`/`TCD` remap the Direct Page onto the
   frame for fast 8-bit-offset local access (with a hard **256-byte frame cap**), and return values in
   **A** (low) / **X** (high). A concrete reference point for "DP-window hybrid vs. the now-viable
   pure hardware-stack-relative frame vs. the 6502 soft static stack," and its `near`/`far` keyword
   model maps directly onto #320's address-space layout. Written up standalone (primary-sourced,
   sources vendored): [docs/320-321-65816-c-abi-prior-art.md](320-321-65816-c-abi-prior-art.md).

---

## Proposed next steps

1. **Reconcile numbering + the default-pointer-width decision** here / on Discord, using this slice as
   the concrete starting point.
2. **Grow it to the full five-space model** (Option B) behind that decision — renumber, add packed-24
   and zero-bank, flip the default if that's the call.
3. **Then #321** (16-bit A via a late `REP`/`SEP` pass, X/Y fixed-16 — building on the
   [jackoalan POC](https://github.com/jackoalan/llvm-mos/commit/ec070a70ba8d8b3d3a9da24b4216435f9575f6bb))
   and the hardware-stack ABI.

The SNES test bench in the repo (SDK platform + headless MAME corpus, all green on the 6502 backend
and now exercising far pointers) is already the regression baseline this would build on, and is
roughly the target [llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415) asks for.

---

## Links

- Repo / patch / bench: **[wbniv/llvm-mos-65816](https://github.com/wbniv/llvm-mos-65816)**
  (`patches/llvm-mos/0001-320-far-addrspace.patch`; `dev/run.sh far` / `far-run` / `far-bank1`;
  `docs/plans/2026-06-14-320-*` for full verification evidence).
- Upstream issues: [#32](https://github.com/llvm-mos/llvm-mos/issues/32) (umbrella) ·
  [#320](https://github.com/llvm-mos/llvm-mos/issues/320) (24-bit address space — *this note*) ·
  [#321](https://github.com/llvm-mos/llvm-mos/issues/321) (16-bit registers) ·
  [llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415) (SNES target).

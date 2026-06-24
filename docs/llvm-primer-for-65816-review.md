# LLVM in one sitting — a primer for the 65816 patch-series review

Companion to [`65816-patch-series-review-guide.md`](65816-patch-series-review-guide.md). That document
assumes fluency with LLVM's backend machinery — **GlobalISel**, **TableGen**, the **MC layer**, the
**register allocator**. This primer supplies exactly that, and nothing more.

**Who this is for.** You know compiler construction — SSA, instruction selection, register allocation,
calling conventions, peephole/dataflow passes, relocation/linking — as *concepts*. You have not worked inside
LLVM. This maps the concepts you know onto LLVM's specific realization of them, and explains the
LLVM-specific pieces (GlobalISel's pipeline, TableGen, address spaces, the legalizer's action model) that
have no exact analogue elsewhere. Every section ends by pointing at where the review guide uses it.

It is deliberately terse. The [§Glossary](#glossary--quick-reference) at the end is a one-line lookup for
every LLVM term the review guide drops; skim the body once, then use the glossary as a reference while
reading the guide.

---

## Table of contents

- [1. The shape of LLVM](#1-the-shape-of-llvm)
- [2. LLVM IR, in the parts that matter here](#2-llvm-ir-in-the-parts-that-matter-here)
- [3. TableGen: the backend described as data](#3-tablegen-the-backend-described-as-data)
- [4. GlobalISel — where this work lives](#4-globalisel--where-this-work-lives)
  - [4.1 Legalization](#41-legalization)
  - [4.2 Instruction selection](#42-instruction-selection)
  - [4.3 Register banks vs register classes](#43-register-banks-vs-register-classes)
  - [4.4 The combiner](#44-the-combiner)
- [5. MachineIR, passes, and register allocation](#5-machineir-passes-and-register-allocation)
- [6. Calling conventions](#6-calling-conventions)
- [7. The MC layer: encoding, relocations, relaxation](#7-the-mc-layer-encoding-relocations-relaxation)
- [8. The clang front-end touchpoints](#8-the-clang-front-end-touchpoints)
- [9. DWARF — why any of this exists](#9-dwarf--why-any-of-this-exists)
- [10. The MOS backend at a glance](#10-the-mos-backend-at-a-glance)
- [Glossary / quick reference](#glossary--quick-reference)

---

## 1. The shape of LLVM

LLVM is three stages joined by two stable IRs:

```
C source ──clang──▶ LLVM IR ──target backend──▶ MachineIR ──▶ MC layer ──▶ .o / .s
           (front      (target-independent      (target        (encode,
            end)        SSA; the "middle end"    machine         relocate)
                        optimizes here)          instructions)
```

- **clang** is the C/C++ front end: it parses, type-checks (**Sema**), and lowers the AST to **LLVM IR**
  (**CodeGen**, confusingly named — it generates IR, not machine code).
- **LLVM IR** is the target-independent SSA the optimizer works on. A **datalayout** string pins
  target-specific sizes (pointer width, alignment) so even "target-independent" IR knows how big a pointer is.
- A **target backend** (here `llvm/lib/Target/MOS/`) lowers IR to **MachineIR (MIR)** — still SSA at first,
  but in terms of *machine* instructions and registers — then runs target passes, allocates registers, and
  hands off to the **MC layer**, which encodes bytes and emits relocations.

The MOS backend covers the **6502 family**, including the **WDC 65816** (subtarget `mosw65816`). It is part
of the out-of-tree **llvm-mos** fork. Crucially for this review, it uses **GlobalISel** (below), not the
older SelectionDAG path — so "the legalizer" and "the instruction selector" mean GlobalISel's, and the work
is overwhelmingly in those two passes.

> Review guide: the §2.4 pass-pipeline diagram and the whole of §3 are this stage-by-stage flow for the MOS
> target.

---

## 2. LLVM IR, in the parts that matter here

LLVM IR is typed, SSA, with an unlimited supply of virtual registers (`%0`, `%1`, …). You can read it like
a typed three-address code. The pieces the review guide leans on:

- **Integer types** are bit-widths: `i1` (a boolean/predicate), `i8`, `i16`, `i32`. The 65816 work is about
  making `i16` (and `i32`) operations cheap.
- **Pointers carry an *address space*.** `ptr addrspace(N)` is a *distinct pointer kind*, not just an
  annotation — the backend may give each address space a different width and lower it through different
  instructions. This is the entire mechanism of #320:
  - `addrspace(0)` (default near) — 16-bit pointer, bank-0.
  - `addrspace(1)` — 8-bit direct-page pointer.
  - `addrspace(2)` — the 32-bit **far** pointer (24-bit address in the low 3 bytes).
  - `addrspace(3)` — the 24-bit **packed** far pointer (storage form).
  The **datalayout** records each width: `...-p1:8:8-p2:32:8-p3:24:8-...` reads "addrspace 1 pointers are 8
  bits, addrspace 2 are 32, addrspace 3 are 24" (the second number is alignment).
- **`inttoptr` / `ptrtoint`** convert between a pointer and an integer of the same width. The far-pointer
  code uses these to treat a far pointer as a 32-bit value when it has to flow through arithmetic or storage.
- **Building and splitting wide values.** A wide value is often assembled from / taken apart into narrower
  ones. In MIR this is `G_MERGE_VALUES` (e.g. two `i8`s → one `i16`) and `G_UNMERGE_VALUES` (the reverse).
  You will see these constantly: under `+mos-a16` an `i32` is *two* `i16`s, and a far pointer is *four*
  `i8`s, so merges/unmerges are how values cross those width boundaries.

> Review guide: `addrspace(2)`/`addrspace(3)` and the datalayout in §3.1/§3.6; `G_MERGE`/`G_UNMERGE` and
> `inttoptr`/`ptrtoint` throughout §3.2 and §3.6.

---

## 3. TableGen: the backend described as data

Most of a backend is **declarative data**, not C++: register definitions, instruction definitions, calling
conventions, subtarget features, and selection patterns. LLVM writes these in **TableGen** (`.td` files); a
build-time tool expands them into C++ tables the backend links against. You don't need to write TableGen to
read this review, only to recognize three idioms:

- **`SubtargetFeature`** — an opt-in target feature with a generated accessor. `+mos-a16` is one:
  ```tablegen
  def FeatureAccum16 : SubtargetFeature<"mos-a16", "HasAccum16", "true", "...">;
  ```
  This creates `Subtarget->hasAccum16()` in C++ and the `-mattr=+mos-a16` flag. A **`Predicate`**
  (`def HasAccum16 : Predicate<"Subtarget->hasAccum16()">`) exposes the same gate to TableGen, so an
  instruction can be defined `let Predicates = [HasAccum16]` — present only when the feature is on.
- **Instruction / register / register-class definitions** live in `.td` too (`MOSInstr*.td`,
  `MOSRegisterInfo.td`). A register class is just "this set of registers" (e.g. `GPR = {A,X,Y}`).
- **`TSFlags`** — Target-Specific Flags, a small bitfield carried on every instruction's descriptor. The MOS
  backend stores a one-bit **`MLow`** flag there to mark "this instruction must run with the 16-bit
  accumulator (M=0)"; a later pass reads it to place `rep`/`sep`.

> Review guide: the `FeatureAccum16`/`FeatureIndex16` block and the `MLow` TSFlag in §3.2(1)/(2);
> `CCIfPtrAddrSpace` (TableGen calling-convention rules) in §3.4/§3.8.

---

## 4. GlobalISel — where this work lives

**GlobalISel (GISel)** is LLVM's newer instruction-selection framework (the MOS target is GISel-only). It
replaces the monolithic SelectionDAG with a pipeline of four MachineFunction passes, each operating on
**MIR**:

```
LLVM IR ─▶ IRTranslator ─▶ Legalizer ─▶ RegBankSelect ─▶ InstructionSelector ─▶ (selected MIR)
            1:1 IR→generic   make every    assign each      match generic ops
            MIR opcodes      generic op     vreg a register  to real MOS
                             legal for      bank             instructions
                             the target
```

- **IRTranslator** turns each IR instruction into a **generic MIR opcode** — `G_ADD`, `G_LOAD`, `G_STORE`,
  `G_ICMP`, `G_SHL`, `G_PTR_ADD`, `G_BRCOND`, `G_MERGE_VALUES`, … These are target-independent machine
  opcodes: the same `G_ADD` exists on every target. They operate on **virtual registers** typed by a
  **low-level type (LLT)** — `s16` (a 16-bit scalar), `s32`, `p0` (a pointer in addrspace 0), etc. (LLT is
  coarser than IR types: no signedness, just size+kind.)
- The next three passes are the ones you'll read about constantly. They get their own subsections.

> Review guide: the §2.4 pipeline diagram is exactly this, with the two custom MOS passes appended.

### 4.1 Legalization

A generic op may not be directly implementable at a given type — the 6502 has no 16-bit `G_ADD`. The
**Legalizer** rewrites every generic instruction into a form the target *can* select, according to rules the
target declares in **`LegalizerInfo`** (`MOSLegalizerInfo.cpp`). Each (opcode, type) pair maps to an
**action**:

| Action | Meaning |
|--------|---------|
| **legal** | leave it; the selector can handle it |
| **narrowScalar** | split into smaller pieces (e.g. a 16-bit add → two 8-bit adds with carry) |
| **widenScalar** | promote to a wider type |
| **lower** | rewrite into other generic ops (a software expansion) |
| **custom** | call target C++ (`legalizeCustom`) to do something bespoke |
| **unsupported** | reject at compile time (a clean error, never a miscompile) |

This action model *is* the #321 design surface. The default MOS rule narrows a 16-bit `G_ADD` to the 8-bit
byte chain. The `+mos-a16` work, in one sentence, is: **under the `hasAccum16()` gate, mark selected small
`s16` ops *legal* (un-narrowed) instead of narrowing them**, so the selector can emit a single 16-bit
instruction. Same for `s16` compares, shifts, loads/stores. Wide values are handled by *custom* rules:
under `+mos-a16` an `s32` legalizes to **two `s16`s** (not four `s8`s), so the `4×s8 → s32` merge needs a
custom rule to bridge to the legal 2-level form. The deliberate **`unsupported`** for default-build far
storage (§3.5/[C21]) is this table refusing to lower a value it can't, rather than miscompiling it.

Helpers you'll see: `customForCartesianProduct({types}, {types})` declares "these (value-type × ptr-type)
combinations are custom"; `maxScalar`/`minScalar` cap a type's width.

> Review guide: every "the legalizer keeps a small `s16` … un-narrowed under the gate" sentence in §3.2;
> the `PF`-as-value `customForCartesianProduct` hunk in §3.5; the s32↔bytes rules in §3.2's surface table.

### 4.2 Instruction selection

The **InstructionSelector** (`MOSInstructionSelector.cpp`) matches each legal generic op to a concrete MOS
instruction (or a short sequence), turning generic MIR into real MIR. Most selection is pattern-matched from
TableGen, but anything irregular is hand-written C++ in a `select*` method (`selectAlu16Native`,
`selectSbc16`, `selectXY16`, …). The 65816 work selects a legal `s16 G_ADD` to the sequence
`LDAImag16; ADCImag16; STAImag16` on the accumulator — i.e. it picks the *target* instructions that realize
the op, including which registers the value lives in.

A recurring selector concern here is **load folding**: instead of selecting a load to its own instruction,
fold the memory operand into the consuming ALU/compare (`adc abs` instead of `lda abs; …`). That is only
sound if nothing writes that memory between the load and the use — hence the `noStoreBetween` guard the
review guide keeps mentioning.

> Review guide: the `select*` methods and the fold helpers throughout §3.2; §4.4's volatile-tolerant fold rule.

### 4.3 Register banks vs register classes

Two distinct notions, easy to conflate:

- A **register class** is a *set of physical registers* a value may occupy — `GPR = {A,X,Y}`, `Ac16 = {A16}`
  (the 16-bit accumulator), `Imag16` (the zero-page "imaginary register" pairs `$rsN`), `Imag32`, `Imag8`.
  Selection and register allocation work in terms of these.
- A **register bank** is a coarser GISel grouping used by **RegBankSelect** (the pass between legalize and
  select) to decide, per vreg, *which kind* of register file it belongs to before exact selection. The
  review guide mentions `AnyRegBank` — a bank that a value can be copied through; `0004` needed `Imag32` to
  be in it so a far pointer can `COPY` between locations.

Why this matters for #321: the 16-bit accumulator `A16` **aliases** the 8-bit `A` (it *is* `B:A`). If the
register allocator/**coalescer** lets an 8-bit value and a 16-bit value share that physical register through
a `COPY`, it corrupts one of them — the "coalescer crash" the guide describes. The fix is an invariant
(§4.2 of the guide): a live 16-bit value's home is an **`Imag16`** zero-page pair; `A16` is entered only
transiently via load/store, never via a `COPY` between an 8- and 16-bit class — so there is nothing for the
coalescer to merge incorrectly.

> Review guide: the `Imag16`-resident invariant in §3.2(3) and §4; the `AnyRegBank` line in §3.4; the C3
> coalescer crash.

### 4.4 The combiner

GISel has a **combiner** (`MOSCombiner.cpp`) — a generic-MIR peephole framework that runs *before*
legalization (and can run after). Each combine is a **match** predicate + an **apply** rewrite, much like a
SelectionDAG `DAGCombine` or a hand-rolled peephole, but on generic MIR. The 65816 work adds combines that
fuse, e.g., a global-to-global 16-bit copy or an add-chain into one bracketed sequence.

> Review guide: the `copy16abs`/`add_chain16`/`alu16_abs` combines named in §3.2's surface table.

---

## 5. MachineIR, passes, and register allocation

After selection, the function is **MIR**: `MachineBasicBlock`s of `MachineInstr`s over a mix of **virtual**
and **physical** registers. A sequence of **MachineFunction passes** then runs; order matters enormously,
because some run **before register allocation (pre-RA)** — when there are still infinite vregs — and some
**after (post-RA)** — when every operand is a physical register.

- **Register allocation (RA)** maps vregs to the finite physical registers, inserting **spills** (store a
  value to a stack slot and reload it) when it runs out. The MOS target's "stack" for spills is the
  zero-page imaginary-register file plus a soft stack, not a hardware frame.
- The **register coalescer** (part of RA) eliminates `COPY`s by making source and destination share a
  register — the pass that, mishandled, merges `A16` with `A` (§4.3).
- The **register scavenger** is a late helper that finds a free register on demand (e.g. to materialize a
  frame index) post-RA; it assumes certain registers/flags are dead at that point. The `+mos-a16` pressure
  exposes an upstream scavenger bug where the processor-status flags are still live ([C19] in the guide).
- **`-verify-machineinstrs`** runs the MachineVerifier, a structural checker (register sizes match, no use
  of an undefined register, …). "verify-clean" in the guide means it passes; several bugs there are
  verifier failures, not wrong output.
- **Pseudo-instructions** are stand-in MIs that expand to real instructions later (often post-RA, in
  `expand*` code). The compare-branch pseudos (`CmpBrImag16`, …) and the spill helpers are pseudos.

The two **custom MOS passes** this work adds/extends both run **post-RA**, and that timing is a correctness
argument, not an accident:

- **`MOSInsertREPSEP`** — a dataflow pass that tracks the `M` (accumulator-width) and `X` (index-width) mode
  bits across the CFG and inserts the `rep`/`sep` instructions that switch them, only at real transitions.
  It reads each instruction's `MLow` TSFlag. Post-RA, because it must see the final instruction stream.
- **`MOSLateOptimization`** — post-RA peephole. `threadAccum16` there removes the redundant
  `STAImag16; LDAImag16` round-trips between dependent 16-bit ops. Post-RA is deliberate: RA has *already*
  chosen `$a16` on both sides, so the peephole cannot reintroduce the coalescer hazard.

> Review guide: §2.4 places both passes; the spill-path fixes (F3/[C18]), the coalescer crash ([C3]), the
> scavenger bug ([C19]) and `-verify-machineinstrs` are all this section.

---

## 6. Calling conventions

A target's calling convention is declared in TableGen (`MOSCallingConv.td`) as an ordered list of rules, and
applied by **CallLowering** (`MOSCallLowering.cpp`, GISel's call-lowering hook) when lowering calls/returns.
You read the rules top-down; the first matching rule assigns each argument:

- **`CCAssignToReg<[regs…]>`** — put the value in the next free register from the list.
- **`CCIfType` / `CCIfPtr` / `CCIfPtrAddrSpace<N, …>`** — guards: apply the inner rule only for that type /
  any pointer / a pointer in address space `N`.

`0008` (and `0004`) are exactly this: a pointer in a given address space was falling through to a generic
rule that gave it the wrong-sized register, so they add a `CCIfPtrAddrSpace<N, CCAssignToReg<…>>` rule
*before* the generic one. llvm-mos's default CC keeps C locals in the imaginary-register file rather than a
hardware frame — which is why the frame-ABI experiments ([C1]) found nothing to optimize.

> Review guide: §3.4 (far-pointer CC), §3.8 (the DP-pointer-arg fix), and the CC discussion in §3.2.

---

## 7. The MC layer: encoding, relocations, relaxation

After MIR is finalized, the **MC layer** turns `MCInst`s into bytes. Three concepts surface in the guide:

- **Relocations** — a placeholder the linker fills once addresses are known. The MOS target emits
  `R_MOS_ADDR16` for a 16-bit absolute (`abs`) operand and `R_MOS_ADDR24` for a 24-bit absolute-long
  (`long`) operand. The distinction is load-bearing: `abs` is resolved *relative to the data-bank register*
  (`DBR:addr`), while `long` carries its own bank and is DBR-independent.
- **Fixups** are the in-assembler representation of those not-yet-known values before they become
  relocations.
- **Relaxation** — the assembler choosing a *longer* instruction encoding when the short one can't reach
  (cf. branch relaxation elsewhere). `MOSAsmBackend::fixupNeedsRelaxationAdvanced` decides whether an `abs`
  access must grow to `long` (to reach a non-zero bank). `0007` is one guard in that function: a *near*
  (bank-0) symbol must **not** be relaxed to `long`, because that just wastes a byte — the compiler already
  emits `long` explicitly whenever a far access is genuinely needed.
- **`AsmPrinter`** emits the final assembly/object; `0006` adds a hook there to emit a 3-byte packed-pointer
  relocation triple.

> Review guide: §3.6 (`AsmPrinter` hook), §3.7 (`fixupNeedsRelaxationAdvanced`), and the DBR contract in §4 /
> Appendix B.6.

---

## 8. The clang front-end touchpoints

#320 needs the C front end to *spell* a far pointer. The relevant clang layers:

- **AST + Sema** — the type system and semantic analysis. A type **attribute** (`__far` / the `far` /
  `long_call` attribute) is parsed here and attached to a type.
- **CodeGen** (`clang/lib/CodeGen/`, esp. `CGExpr.cpp`) — lowers the AST to LLVM IR. The far-call work
  intercepts call emission here to rewrite a `far`-attributed call into the proven indirect-call shape.
- **`ConvertType`** maps a C type to an LLVM IR type — this is where a `far`-attributed pointer becomes
  `ptr addrspace(2)`.
- **`getPointerWidthV(AS)`** and the target datalayout tell clang `sizeof(far*) == 4` — the front-end and
  backend must agree on the width string from §2.

> Review guide: §3.1's "clang `__far` surface" and the front-end items ([C20]) in Appendix C.

---

## 9. DWARF — why any of this exists

**DWARF** is the standard debug-info format (the `.debug_*` sections): it maps machine addresses back to
source lines, types, and variable locations, so a debugger can step C source and inspect variables. LLVM
already produces DWARF; that's the point of the project (see the review guide's intro): an *optimizing* 65816
C compiler that emits DWARF lets **drmon** do modern source-level debugging of optimized SNES code, which the
older COFF/assembler debug formats couldn't. The compiler is the missing producer; DWARF is the interface to
everything downstream.

> Review guide: the intro "Motivation" and Appendix A.1.

---

## 10. The MOS backend at a glance

The files the review guide names, and the role each plays (all under
[`llvm/lib/Target/MOS/`](https://github.com/llvm-mos/llvm-mos) in the vendored tree):

| File | Role (from the sections above) |
|------|--------------------------------|
| `MOSFeatures.td` | SubtargetFeatures (`+mos-a16`, `+mos-xy16`) — §3 |
| `MOSRegisterInfo.td` | register classes (`GPR`, `Ac16`, `Imag16/32`) — §4.3 |
| `MOSRegisterBanks.td` | register banks (`AnyRegBank`) — §4.3 |
| `MOSInstr*.td` | instruction + pseudo definitions, `MLow` TSFlag — §3 |
| `MOSLegalizerInfo.cpp` | the legalization rules — §4.1 |
| `MOSInstructionSelector.cpp` | `select*`, the fold helpers — §4.2 |
| `MOSCombiner.cpp` | pre-legalizer combines — §4.4 |
| `MOSInsertREPSEP.cpp` | M/X-mode dataflow → place `rep`/`sep` — §5 |
| `MOSLateOptimization.cpp` | post-RA peephole (`threadAccum16`) — §5 |
| `MOSCallingConv.td` + `MOSCallLowering.cpp` | calling convention — §6 |
| `MCTargetDesc/MOSAsmBackend.cpp` | fixups / relaxation — §7 |
| `MOSAsmPrinter.cpp` | object/asm emission — §7 |

---

## Glossary / quick reference

| Term | One-line meaning |
|------|------------------|
| **LLVM IR** | target-independent typed SSA; the optimizer's language |
| **datalayout** | string pinning pointer/scalar sizes + alignment per target (and per address space) |
| **address space** | `ptr addrspace(N)` — a distinct pointer kind with its own width/lowering (#320: 1=DP, 2=far, 3=packed) |
| **`inttoptr`/`ptrtoint`** | cast a pointer to/from a same-width integer |
| **LLT** | low-level type on MIR vregs — size+kind only (`s16`, `s32`, `p0`); no signedness |
| **GlobalISel (GISel)** | the selection framework the MOS target uses: translate → legalize → regbankselect → select |
| **generic opcode `G_*`** | target-independent machine op (`G_ADD`, `G_LOAD`, `G_ICMP`, `G_MERGE/UNMERGE_VALUES`, `G_SHL`…) |
| **MIR** | MachineIR — machine instructions/registers, SSA until register allocation |
| **Legalizer / `LegalizerInfo`** | rewrites generic ops to selectable forms via actions: legal / narrow / widen / lower / custom / unsupported |
| **narrowScalar** | legalize a wide op by splitting into narrower ops (16-bit add → 8-bit chain) |
| **custom (legalize)** | hand-written C++ legalization for an irregular case |
| **unsupported** | compile-time rejection of an unimplementable op (clean error, not a miscompile) |
| **InstructionSelector** | matches legal generic ops to real MOS instructions; `select*` methods for irregular cases |
| **combiner** | generic-MIR peephole (match + apply), pre-legalization |
| **register class** | a set of physical registers a value may occupy (`GPR`, `Ac16`, `Imag16`) |
| **register bank** | coarse GISel grouping assigned by RegBankSelect before exact selection (`AnyRegBank`) |
| **vreg / physreg** | virtual (pre-RA, unlimited) vs physical (post-RA) register |
| **`COPY`** | a generic register-to-register move; the coalescer tries to eliminate them |
| **register allocation (RA)** | map vregs → physregs, inserting spills when out of registers |
| **coalescer** | RA sub-pass that removes `COPY`s by sharing a register — the `A16`/`A` aliasing hazard |
| **register scavenger** | post-RA on-demand free-register finder; assumes certain regs/flags dead ([C19] bug) |
| **spill** | store a register to memory and reload it (here: to the ZP imaginary-register file / soft stack) |
| **pseudo-instruction** | a placeholder MI expanded to real instructions later (often post-RA) |
| **post-RA** | a pass running after register allocation (every operand is a physical register) |
| **`-verify-machineinstrs`** | the MachineVerifier; "verify-clean" = passes its structural checks |
| **TableGen / `.td`** | declarative backend data (instructions, registers, features, CCs, patterns) compiled to C++ tables |
| **SubtargetFeature** | an opt-in target feature + generated `has*()` accessor (`+mos-a16` → `hasAccum16()`) |
| **Predicate** | a TableGen gate exposing a C++ condition so defs can be `let Predicates = [...]` |
| **TSFlags** | per-instruction target-specific flag bits; MOS stores the `MLow` (16-bit-A) bit here |
| **CallLowering / `CallingConv.td`** | lower calls/returns per declarative CC rules (`CCAssignToReg`, `CCIfPtrAddrSpace`) |
| **MC layer** | post-MIR: encode `MCInst`s to bytes, emit relocations/fixups |
| **relocation (`R_MOS_ADDR16/24`)** | linker placeholder; ADDR16 = DBR-relative `abs`, ADDR24 = DBR-independent `long` |
| **relaxation** | assembler picking a longer encoding when needed (`abs`→`long`); gated in `MOSAsmBackend` |
| **AsmPrinter / AsmBackend** | emit final asm/object; decide fixups/relaxation |
| **DBR** | 65816 data-bank register; supplies the bank for `abs` accesses (pinned to 0 by the crt0) |
| **`Imag8/16/32`** | the zero-page "imaginary register" classes (`$rcN`/`$rsN`) llvm-mos uses as its register file |
| **`Ac16`** | the 16-bit accumulator register class (`A16` = `B:A`), which aliases the 8-bit `A` |
| **`MLow`** | TSFlag bit: "this instruction needs the 16-bit accumulator (M=0)"; read by `MOSInsertREPSEP` |
| **DWARF** | standard debug-info format mapping addresses → source lines/vars; the project's reason to emit it |

---

*Read this once for orientation, then keep the glossary open beside
[`65816-patch-series-review-guide.md`](65816-patch-series-review-guide.md).*

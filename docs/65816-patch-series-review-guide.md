# 65816 C codegen for llvm-mos — patch-series review guide

This document is a reviewer's map of the patch stack that adds native **16-bit-accumulator** and
**far-pointer (24-bit address)** C codegen for the WDC 65816 to [llvm-mos](https://github.com/llvm-mos/llvm-mos),
together with an SNES target to exercise it. It exists to make the series **cheap to review**: every change
is opt-in and gated so the default 8-bit code generator is byte-identical, every claim is backed by a
four-way differential test you can re-run, and the stack splits into two units (#320 far, #321 16-bit) that
review almost independently.

**Motivation — modern source-level debugging of the SNES.** This is *why the compiler work exists.*
Source-level debugging of SNES code is not new to *drdevtools* — its debugger **drmon** already reads the
legacy **assembler** symbol formats (`.sld`, COFF, ca65 `.dbg`, WLA-DX `.sym` — the COFF / Zardoz /
drdevtools-SPASM lineage). What drmon lacks is the **modern** path: an **ELF/DWARF** loader fed by an
*optimizing C compiler* on fully-open tooling. llvm-mos already emits **DWARF** (spec landed Dec 2025) and
ships the 65816 assembler/linker — but had **no 65816 C codegen**, the one missing producer. This series is
that producer: it closes the loop *optimizing C → SNES ROM + DWARF → source-level debug in drmon*, upgrading
drmon from assembler-tied debug info to standard DWARF from optimized C. The 16-bit/far codegen below is the
means; debuggable optimized C in drmon is the end. (Detail: [Appendix A.1](#a1-drmon) ·
[`INVESTIGATION.md`](INVESTIGATION.md) · [`ROADMAP.md`](ROADMAP.md) step 6, the DWARF round-trip.)

It addresses the two open, design-only upstream issues —
[#320 24-bit address space](https://github.com/llvm-mos/llvm-mos/issues/320) and
[#321 16-bit register mode](https://github.com/llvm-mos/llvm-mos/issues/321) — code-first, the posture the
maintainers ask for (ABI is blessed behind a running implementation, not ahead of it).

**Audience:** someone comfortable writing LLVM/GISel target code. We show the load-bearing hunk per step and
point at the full `.patch` for the rest; we do not reproduce 7 k lines of diff inline (that would defeat the
purpose). Per-step depth lives in the linked `docs/plans/YYYY-MM-DD-*.md` files.

---

## Table of contents

- [1. What's being submitted, and how to read it](#1-whats-being-submitted-and-how-to-read-it)
  - [1.1 The patch stack at a glance](#11-the-patch-stack-at-a-glance)
  - [1.2 The one invariant that makes this reviewable](#12-the-one-invariant-that-makes-this-reviewable)
  - [1.3 The correctness bar](#13-the-correctness-bar)
  - [1.4 Suggested review order](#14-suggested-review-order)
- [2. Architecture, dependencies, sequencing & timeline](#2-architecture-dependencies-sequencing--timeline)
  - [2.1 The 65816 in one screen](#21-the-65816-in-one-screen)
  - [2.2 Dependency graph](#22-dependency-graph)
  - [2.3 Milestone sequencing](#23-milestone-sequencing)
  - [2.4 Where the new passes sit](#24-where-the-new-passes-sit)
  - [2.5 Timeline](#25-timeline)
- [3. The narrative: each step, with need / patch / proof](#3-the-narrative-each-step-with-need--patch--proof)
  - [3.1 `0001` — #320 far address space (M1)](#31-0001--320-far-address-space-m1)
  - [3.2 `0002` — #321 16-bit accumulator (M2)](#32-0002--321-16-bit-accumulator-m2)
  - [3.3 `0003` — TXY/TYX dead-flag peephole](#33-0003--txytyx-dead-flag-peephole)
  - [3.4 `0004` — far-pointer calling convention](#34-0004--far-pointer-calling-convention)
  - [3.5 `0005` — far-pointer value legalization](#35-0005--far-pointer-value-legalization)
  - [3.6 `0006` — packed-24 (AS3) storage form](#36-0006--packed-24-as3-storage-form)
  - [3.7 `0007` — near-abs bank-relaxation](#37-0007--near-abs-bank-relaxation)
  - [3.8 `0008` — DP-pointer-argument CC (upstream bug)](#38-0008--dp-pointer-argument-cc-upstream-bug)
- [4. Cross-cutting correctness arguments](#4-cross-cutting-correctness-arguments)
- [Appendix A — Testing setup](#appendix-a--testing-setup)
- [Appendix B — SNES platform changes & requirements](#appendix-b--snes-platform-changes--requirements)
- [Appendix C — Dead ends, experiments & spikes](#appendix-c--dead-ends-experiments--spikes)

---

## 1. What's being submitted, and how to read it

### 1.1 The patch stack at a glance

Eight patches, applied bottom-up (`git am 0001..0008`); the files are under [`patches/llvm-mos/`](https://github.com/wbniv/llvm-mos-65816/tree/main/patches/llvm-mos) (full
name in each step of [§3](#3-the-narrative-each-step-with-need--patch--proof)). LOC is patch size, not net
source change.

| Patch | Issue · M | LOC | What it does | Risk |
|-------|-----------|----:|--------------|------|
| **0001** far‑addrspace | #320 · M1 | 1471 | `addrspace(2)` far pointers: 32-bit ptr holding a 24-bit address; far load/store/deref/cast/arith (`lda long`), far calls (`JSL`/`RTL`), far function pointers, the clang `__far` surface | **High** — new address space, clang + backend |
| **0002** accum16 | #321 · M2 | 4478 | The 16-bit accumulator: `+mos-a16` feature, the `MOSInsertREPSEP` mode-tracking pass, native s16 ALU / compares / shifts / load-store / chains, A16-threading, plus `+mos-xy16` 16-bit index regs | **High** — the core contribution |
| **0003** txy‑dead‑flag | upstream | 71 | One-line peephole fix: reusing a dead `LDImm` as `TXY`/`TYX` must clear the source's dead flag | **Trivial** — bug fix + MIR test |
| **0004** far‑cc | #320 · M1 | 509 | Far-pointer **calling convention**: pass/return `addrspace(2)` in one `Imag32` ZP reg (winner of a 4-variant bake-off) | Medium |
| **0005** far‑value‑legalize | #320 · M1 | 24 | One legalizer hunk: a far pointer held *as a value* (not just an access ptr) is a legal load/store value type. Split out because it is `+mos-a16`-context-entangled | Trivial |
| **0006** packed24 | #320 · M1 | 387 | `addrspace(3)` packed-24: a 3-byte in-memory storage form of a far pointer (banked-asset / jump tables); −25 % table storage | Medium |
| **0007** near‑abs‑relax | #320 · M1 | 28 | Don't bank-relax (`abs`→`long`) a **near** symbol — saves 1 B per A-register near-global access (~284 sites in the examples) | Low |
| **0008** dp‑arg‑cc | upstream | 51 | Upstream bug fix: an 8-bit `addrspace(1)` direct-page pointer **argument** was assigned a 16-bit register → illegal `COPY`. Reproduces on stock `mos6502` | Trivial — bug fix + `.ll` test |

Two patches (`0003`, `0008`) are pure **upstream bug fixes** surfaced by this work and are independently
postable; they are included so the stack applies clean.

### 1.2 The one invariant that makes this reviewable

> **Everything new is opt-in (`+mos-a16` / `+mos-xy16` / `addrspace(2)`) and gated so it cannot alter
> non-opted-in codegen. The existing 6502/65816 8-bit code generator is byte-identical with the stack
> applied.**

This is enforced, not asserted. The differential fuzzer ([Appendix A](#appendix-a--testing-setup)) compiles
every program **both** default and `+mos-a16` and compares both to a host oracle, so a gate that leaks into
the 8-bit path surfaces immediately as a `default@MAME ≠ host` mismatch (this caught a real
leak<sup>[[C16]](#c16-seed-42--legalizeicmp-swap-leak)</sup>). A reviewer can therefore trust that
**reviewing `0002` is reviewing *added* behavior**, never a silent change to what ships today. The gating
discipline is spelled out in [§4](#4-cross-cutting-correctness-arguments).

### 1.3 The correctness bar

Every value-level change clears a **four-way differential**:

```
host-computed  ==  default(8-bit)@MAME  ==  +mos-a16@MAME  ==  +mos-a16@bsnes-jg
```

plus `llc -verify-machineinstrs` clean. Two independent emulators (MAME, used because it matches the
[drmon/drdevtools](#a1-drmon) debug backend; and the cycle-accurate bsnes-jg) rule out emulator-specific
quirks. Any
disagreement or crash is treated as a real defect with a concrete cause — never a "glitch". Full mechanics:
[Appendix A](#appendix-a--testing-setup).

### 1.4 Suggested review order

The stack is two near-independent units. `0002` (#321) depends on `0001` only for **shared-file context**
(both edit `MOSInstrLogical.td`, `MOSLegalizerInfo.cpp`), not for semantics; `0004`–`0006` (#320) depend on
`0002` for a few `+mos-a16`-gated lines (the `Ac16`/`AnyRegBank` register-class entries). So:

1. **Skim** [§2](#2-architecture-dependencies-sequencing--timeline) (the machine + the graph).
2. **#320 reviewers:** `0001` → `0004` → `0005` → `0006` → `0007` → `0008`.
3. **#321 reviewers:** `0002` → `0003` as a self-contained unit.
4. `0003` and `0008` are 5-minute bug-fix reviews; do them first to warm up.

---

## 2. Architecture, dependencies, sequencing & timeline

### 2.1 The 65816 in one screen

The 65816 is the 6502's 16-bit successor (the SNES CPU). What matters for codegen:

- **Two CPU modes.** Powers on in **6502-emulation mode** (`E=1`); software flips to **native mode**
  (`E=0`) via `XCE`. Native mode is the prerequisite for *any* 16-bit register. The SNES crt0 does this for
  every program ([Appendix B](#appendix-b--snes-platform-changes--requirements)).
- **Two width flags.** In native mode, status bits **`M`** (accumulator) and **`X`** (index X/Y) each select
  8- or 16-bit width, toggled by `REP`/`SEP`. `M=0` ⇒ `lda`/`adc`/`cmp`/`sta` are 16-bit and read/write two
  bytes. This is the entire lever #321 pulls — and the entire cost: a misplaced `rep`/`sep` is a correctness
  bug or a size regression.
- **24-bit address, banked.** Addresses are 24-bit = `bank:offset`. Three addressing classes matter:
  `abs` (16-bit operand, **DBR-relative**, reloc `R_MOS_ADDR16`); `long` (24-bit operand, **DBR-independent**,
  `R_MOS_ADDR24`); and zero-page/direct-page. #320 is about giving C a pointer that carries the bank.
- **`DBR`** (data bank register) supplies the bank for `abs`. The platform pins `DBR=0` so near data and MMIO
  resolve to bank 0 ([§4](#4-cross-cutting-correctness-arguments)).

llvm-mos keeps C locals **register-resident** in a fixed zero-page file of "imaginary registers" (`__rc0…`),
not on a hardware frame. The 16-bit work reuses that idea: a live 16-bit value's home is an **`Imag16`**
zero-page pair; the physical accumulator `A16` is entered only transiently (this is the key allocator-safety
property — [§3.2](#32-0002--321-16-bit-accumulator-m2), [§4](#4-cross-cutting-correctness-arguments)).

### 2.2 Dependency graph

Solid arrow = real dependency (semantic, or shared-file context that must apply in order). The numeric order
is the `git am` order. `0007`/`0008` stack at the top but are semantically standalone.

```mermaid
flowchart TD
    SNES["M0 · SNES target + dual-emulator harness<br/>(Appendix A &amp; B — no codegen change)"]

    subgraph far["#320 — far pointers (M1)"]
        P1["0001 far-addrspace<br/>addrspace(2), JSL/RTL, clang __far"]
        P4["0004 far-ptr CC<br/>Imag32 winner"]
        P5["0005 far-ptr value legalize"]
        P6["0006 packed-24 (AS3)"]
        P7["0007 near-abs relax"]
        P8["0008 dp-arg CC (upstream fix)"]
    end

    subgraph a16["#321 — 16-bit accumulator (M2)"]
        P2["0002 accum16<br/>REP/SEP + native s16 + xy16"]
        P3["0003 TXY dead-flag (upstream fix)"]
    end

    SNES --> P1
    SNES --> P2
    P1 -.context.-> P2
    P2 --> P3
    P1 --> P4
    P2 -->|Ac16/AnyRegBank| P4
    P2 -->|a16-gated hunk| P5
    P4 --> P6
    P5 --> P6
    P6 -.apply-order.-> P7
    P7 -.apply-order.-> P8
```

The graph's shape is the reviewability claim: **two columns, one thin coupling.** #321 (`0002`) does not need
to understand far pointers; #320's later patches need only a handful of a16-gated register-class lines from
`0002`.

### 2.3 Milestone sequencing

One track, three milestones — each is the *test bench* for the next. The naive "ship a cheap 8-bit
intermediate, then optimize" framing is a false split: the bulk of the "cheap intermediate" is the SNES
target + emulator/CI loop, which is mandatory infrastructure for testing *any* codegen. So M0 is built once
with the existing 6502 backend (the throwaway 8-bit machine code is free), then #320 and #321 layer on with a
regression baseline already in hand. **M1 and M2 then proceed in parallel** against the same differential
harness.

```mermaid
flowchart LR
    M0["M0 — bench<br/>SNES crt0 + linker + ROM header<br/>MAME + bsnes-jg + corpus + fuzzer<br/>(no new codegen)"]
    M1["M1 — #320 far<br/>multi-bank, unoptimized<br/>(0001,0004,0005,0006,0007,0008)"]
    M2["M2 — #321 16-bit<br/>the optimizing payoff<br/>(0002,0003)"]
    M0 --> M1
    M0 --> M2
    M1 -. "corpus = M2 regression baseline" .-> M2
```

### 2.4 Where the new passes sit

`0002` adds/extends three target passes. Placement is the correctness-critical design choice — the mode
pass runs **after** register allocation so it sees final widths, and the threading peephole runs **post-RA**
so it cannot reintroduce the allocator hazard it would otherwise risk ([§3.2](#32-0002--321-16-bit-accumulator-m2)).

```mermaid
flowchart LR
    IR["LLVM IR"] --> LEG["MOSLegalizerInfo<br/>keep s16 ops un-narrowed<br/>under +mos-a16 (gated)"]
    LEG --> ISEL["MOSInstructionSelector<br/>select to Imag16-resident<br/>16-bit pseudos (MLow=1)"]
    ISEL --> RA["Register allocation"]
    RA --> LATE["MOSLateOptimization<br/>threadAccum16 (post-RA peephole)<br/>+ TXY dead-flag (0003)"]
    LATE --> REPSEP["MOSInsertREPSEP<br/>M/X width dataflow → place rep/sep"]
    REPSEP --> MC["MC / asm / ELF"]
```

### 2.5 Timeline

12 days, 416 commits, 127 plan files. M1 and M2 overlap deliberately.

```mermaid
gantt
    title 65816 codegen — milestone timeline (2026-06)
    dateFormat YYYY-MM-DD
    axisFormat %m-%d

    section M0 bench
    SNES target + smoke + corpus        :m0, 2026-06-13, 2d

    section M1 #320 far
    far load/store (0001)               :2026-06-14, 1d
    runtime deref/cast/arith            :2026-06-20, 1d
    far calls JSL/RTL + far fn ptrs     :2026-06-20, 2d
    far-ptr CC bake-off (0004)          :2026-06-20, 2d
    packed-24 AS3 (0006)                :2026-06-21, 2d
    near-abs relax + dp-arg (0007,0008) :2026-06-22, 1d

    section M2 #321 16-bit
    Inc 1a-1d native s16 ALU (0002)     :2026-06-14, 2d
    compares / shifts / load-store      :2026-06-15, 2d
    eq-as-value + A16-threading         :2026-06-17, 1d
    cross-block REP/SEP + xy16          :2026-06-18, 3d
    surface consolidation + close       :2026-06-22, 1d
```

---

## 3. The narrative: each step, with need / patch / proof

Per step: **Need** (evidence it's required), **Patch** (the load-bearing change; full diff in the named
`.patch`), **Proof** (the differential test + why it can't regress the default path).

### 3.1 `0001` — #320 far address space (M1)

**Need.** C on the 65816 needs a pointer that can address all 24 bits (cross-bank data tables, banked code).
Upstream llvm-mos has a 65816 *assembler/linker* but no C path to a far pointer — a default near pointer is
16-bit and bank-0-only. asiekierka's design sketch in #320 proposes a multi-address-space data layout; this
patch implements the load-bearing subset and proves it on silicon.

**Patch.** [`patches/llvm-mos/0001-320-far-addrspace.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0001-320-far-addrspace.patch) (clang AST/Sema/CodeGen + the MOS backend;
25 files). The spine is a new address space + a 32-bit pointer datalayout:

```cpp
// llvm/lib/Target/MOS/MOSInstrInfo.h
enum AddressSpace { AS_Memory, AS_ZeroPage, AS_Far, NumAddrSpaces };  // AS_Far == 2

// datalayout (clang Targets/MOS.cpp, must match MOSTargetMachine.cpp):
//   ...-p1:8:8-p2:32:8-...        p1 = direct-page (8-bit), p2 = far (32-bit ptr / 24-bit addr)
```

A far pointer is a **32-bit** value whose low 24 bits are the 65816 address (4th byte stays zero). Far
accesses lower to absolute-`long` (`R_MOS_ADDR24`, DBR-independent); a `.far_*`-sectioned global lands in a
high bank and a far call emits `JSL`/`RTL` (the backend infers the callee's bank from its section, so the
call mechanism needs no ABI commitment). The clang side adds the `__far` type-attribute surface, a typed
`far_fn_t`, and `sizeof(far*) == 4`. Far function pointers can't be an `addrspace(2)` IR callee (LLVM forbids
a non-program-addrspace callee), so they thread the 24-bit target through a runtime slot + a generic
`__call_indir_far` stub<sup>[[C20]](#c20-far-fn-pointer-ir-representation)</sup>.

**Proof.** `dev/run.sh far-run far-bank1 far_indir far_cast far_arith far_call far_fnptr` — a far global in
bank `$01` reads back through `lda $018000` (`af 00 80 01`) on **both** MAME and bsnes-jg; `JSL`/`RTL` cross
the bank boundary; corpus stays **7/7**. The whole patch is `HasW65816`/addrspace-gated, so default 8-bit
codegen is untouched (csmith 0-mismatch). M1 acceptance evidence is in
[`docs/ROADMAP.md`](ROADMAP.md) steps 3–4. The far-pointer **CC**, **value**, and **packed** stories are the
later patches `0004`/`0005`/`0006`; two residuals are closed by-design, not as
fork hacks<sup>[[C21]](#c21-far-value-residuals)</sup>.

### 3.2 `0002` — #321 16-bit accumulator (M2)

This is the core contribution and the largest patch — the full diff is
[`patches/llvm-mos/0002-321-accum16.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0002-321-accum16.patch)
(23 files across the MOS backend). It is best understood as: (1) a feature gate, (2) a mode-tracking pass,
(3) a coalescer-safe residency model, (4) a per-op native-s16 surface built increment by increment behind
that model, (5) the same machinery extended to 16-bit index registers (`+mos-xy16`).

**Need.** #321: model the accumulator as 16-bit and place `REP`/`SEP` at a late stage. 16-bit arithmetic in
8-bit codegen is a multi-byte carry chain; a single `M=0` `adc` does it in one op. The payoff is real but
**conditional** — a native 16-bit op routes operands through a zero-page `Imag16` pair inside a `rep`/`sep`
bracket, which *loses* to a tight 8-bit path when an operand is register-resident or consumed as bytes
([governing lesson 2](CLAUDE.md)). So every native form is gated to fire only where it wins.

**(1) The gate.** `MOSFeatures.td`:

```tablegen
def FeatureAccum16 : SubtargetFeature<"mos-a16", "HasAccum16", "true",
    "16-bit accumulator mode (insert REP/SEP) on the WDC 65816.">;
// NOT implied by FamilyW65816 — default mosw65816 (far-pointer) codegen is unaffected.

def FeatureIndex16 : SubtargetFeature<"mos-xy16", "HasIndex16", "true",
    "16-bit index register mode (insert REP/SEP X) on the WDC 65816.", [FeatureAccum16]>;
```

Everything downstream guards on `STI.hasAccum16()` (C++) or `let Predicates = [HasAccum16]` (tablegen). The
gate predicate must be the *same* one that enables the behavior — gating on a looser operand-shape test is
exactly the seed-42 leak<sup>[[C16]](#c16-seed-42--legalizeicmp-swap-leak)</sup>.

**(2) The mode pass.** `MOSInsertREPSEP.cpp` runs **after RA** and tracks an M-width lattice
(`{None, M8, M16, Conflict}`) by forward dataflow, placing `rep`/`sep` only at genuine transitions — inside a
block (seeded from the block's entry width) and on CFG edges `P→B` where `Out[P] ≠ In[B]`. Function entry,
calls, and returns are pinned 8-bit (the ABI boundary). Each instruction declares the width it needs via a
**`MLow`** TSFlag (bit 0 of the instruction format):

```cpp
// MOSInstrFormats.td:  bit MLow = 0;  let TSFlags{0} = MLow;
// MOSInsertREPSEP.cpp:  if (!STI.hasAccum16()) return;          // whole pass is gated
//                       if (MI.getDesc().TSFlags & MOS::TSFlagMLow) ... // op wants M=0
```

Cross-block tracking is what makes a 16-bit loop body hold `M=0` across iterations (`rep` hoists to the
preheader, `sep` sinks to the exit) instead of re-bracketing every iteration. The parallel **X-width** lattice
(for `+mos-xy16`) lives in the same pass.

**(3) Coalescer-safe residency — the central design decision.** The first prototype kept the s16 value
resident in `A16` across ops; because `A16`'s low byte *aliases* the 8-bit `A`, an 8-bit `LDImm` coalesced
into it and produced a malformed `$a16 = LDImm`<sup>[[C3]](#c3-gisel-native-s16-coalescer-crash)</sup>. The
shipped model instead keeps the value's home in an **`Imag16`** zero-page pair and enters the physical `A16`
**only** via load/store (`LDAImag16 → OP → STAImag16`), never via a COPY between 8- and 16-bit classes — so
there is nothing for the coalescer to corrupt. This invariant is load-bearing across the whole patch
(it is also why the spill paths needed fixing — F3<sup>[[C18]](#c18-f3--selectimm-a16-spill-crash)</sup>).

**(4) The native-s16 surface.** Built and measured one op-class at a time; each is a legalizer rule that
keeps a small s16 op un-narrowed under the gate + a selector that emits the `MLow=1` form on the transient
`A16`. Summary (each row has a committed differential micro-test):

| Op class | Mechanism | Test | Result |
|----------|-----------|------|--------|
| ALU add/sub/and/or/xor (global/local/imm) | `Imag16`-resident `LDA;OP;STA`; imm folds to `adc #i16`; near-abs operand folds to `adc abs` | `a16add` `a16local*` `a16imm` `a16loadfold` `a16mixfold` | add 31 B vs 48 B |
| ALU chains (add, bitwise, imm terms) | thread running sum through `A16`, one bracket | `a16chain*` `a16bitchain` | −N×(sta;lda) round-trips |
| Compares — unsigned/signed ordering, equality (branch) | keep s16 `G_SBC`/`ICMP` un-narrowed → `rep;lda;cmp;sep;bcc`; fused `CmpBr*16` pseudos; signed = unsigned on sign-flipped operands | `a16cmp` `a16scmp` `a16eq` `a16abscmp` | drops 8-bit `cpx/cpy` chain |
| Equality **as a value** `b=(a==c)` | route Z through `buildNZSelect`→`G_BRCOND_IMM`→`CmpBr*16`; **4 operand-residency-gated** wins only | `a16eqval{p,g,c}` | v3 both-global −24 % |
| Shifts ×1–7 (left, unsigned/signed right) | `asl/lsr` ×k on `A16`; ASHR = `cmp #$8000; ror a` per bit | `a16shift` `a16ashift` | no `rol/ror` pairs, no libcall |
| `inc a`/`dec a` (reg ±1, global ±1) | keep s16 `±1` un-narrowed → `INCAcc16`/`DECAcc16` | `a16incdec` `a16incabs` | no byte inc/carry chain |
| Load/store — indirect `(zp)`, absolute, indexed `abs,x`/`(zp),y` | route s16 `G_LOAD/STORE` to `*16_{INDIR,ABS,IDX}` (`MLow=1`) | `a16ptr` `a16abs` `a16absidx` `a16indiry` | one 16-bit op vs byte pair |
| s32 (`long`/`int32_t`) | s16 is the narrow type, so s32 = 2×s16; `4×s8→s32` merge custom-legalized | csmith seed-50/113 gates | `int32_t` works under a16 |
| Spill (static + reentrant soft-stack) | spill `Ac16` via 16-bit `LD/STAbs16`/`*Indir16`, never a GPR COPY | `a16spill*` | F3 fix |

**A16-threading** (`threadAccum16` in `MOSLateOptimization.cpp`, **post-RA**) then erases the redundant
`STAImag16 R; LDAImag16 R` round-trips a dependent chain leaves between self-contained ops — the value threads
through `$a16`. Post-RA is deliberate: RA has already chosen `$a16` on both sides, so the peephole cannot
reintroduce the C3 crash. Measured −31/−36 % on dependent chains. A 300-program scan retired "Phase 2" as
already-optimal and deferred "Phase 3" (RA-level residency) behind a concrete
trigger<sup>[[C2]](#c2-a16-threading-phase-3--ra-level-residency)</sup>.

**(5) `+mos-xy16`** reuses the whole apparatus for 16-bit X/Y: register classes `Xc16`/`Yc16`, the parallel
X-lattice, `selectXY16` direct + indexed handlers, and spill paths. Its one subtlety — narrowing `sep #$10`
**zeroes** the index high byte, so a non-index value must never be parked in `X16` across a narrowing point —
was a real miscompile, cvise-reduced and fixed<sup>[[C17]](#c17-xy16-index-high-byte-clobber)</sup>. The
xy16 calling convention is correct by construction (a cross-call-live index parks in a callee-saved `Imag16`
pair; physical `X16` is never live across a call).

**Proof.** The build-up:

```mermaid
flowchart LR
    A["1a STZ<br/>fuse"] --> B["1b dual-width<br/>A16 ALU"] --> C["1c value<br/>lives in A16"]
    C --> D["1d native<br/>(crash)"] --> E["1d-retry<br/>Imag16-resident"]
    E --> F["compares<br/>shifts<br/>load/store"] --> G["eq-as-value<br/>(gated ×4)"]
    G --> H["A16-threading<br/>post-RA"] --> I["cross-block<br/>REP/SEP"] --> J["+mos-xy16"]
```

Four-way differential on every micro-test; `-verify-machineinstrs` clean (including `a16localx`, the C3
guard); csmith **0-mismatch** over seeds 1–500; gcc c-torture **1098** PASS (-O1) / **1114** PASS (-Os),
4-way; corpus **7/7** at every step. Whole-surface measurement
([`dev/measure-native-s16-surface.sh`](https://github.com/wbniv/llvm-mos-65816/blob/main/dev/measure-native-s16-surface.sh)): the sustained-16-bit-arithmetic class the #321 bar names wins
decisively — dependent-chain **−63 %**, multi-value **−65 %**, `k_isort` **−39 %**, aggregate **−22 %
(−220 B)**. Honestly: 8/16-interleave **stress** kernels are *larger* under `+mos-a16` (`k_crc16` +27 %,
`k_prng` +60 %) — pure `rep`/`sep`+`Imag16` overhead with no asymmetric libcall — which is *exactly* why the
feature is opt-in and per-op-gated, not blanket. Two pathological residuals (an `-Os` RA-pressure crash; an
upstream scavenger N/Z crash) are `XFAIL`-pinned with XPASS guards that fire the moment a fix
lands<sup>[[C2]](#c2-a16-threading-phase-3--ra-level-residency)</sup><sup>[[C19]](#c19-upstream-register-scavenger-nz-crash)</sup>.
Per-increment detail: the ~25 plans linked from [`docs/ROADMAP.md`](ROADMAP.md) step 5.

### 3.3 `0003` — TXY/TYX dead-flag peephole

**Need.** A pre-existing `MOSLateOptimization` peephole rewrites a redundant `LDImm` into a `TXY`/`TYX`
transfer when an identical constant is already in the other index register. When the source `LDImm` was
RA-rematerialized and marked `dead`, reusing it as a transfer source left the `dead` flag set → the verifier
rejects "Using an undefined physical register". This is a **stock llvm-mos** latent bug, surfaced by 65816
codegen (which exercises `TXY`/`TYX`).

**Patch.** [`patches/llvm-mos/0003-late-opt-txy-dead-flag.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0003-late-opt-txy-dead-flag.patch) — clear the dead flag on the reused source,
+ two MIR regression tests (`ldimm_to_txy_clears_dead_source`, `…_tyx_…`):

```cpp
// MOSLateOptimization.cpp combineLdImm(): when reusing LoadX/LoadY as the transfer source
Load = &LoadX;   // (the fix clears Load->getOperand(0).setIsDead(false) before re-emit)
```

**Proof.** [`llvm/test/CodeGen/MOS/late-opt-65816.mir`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0003-late-opt-txy-dead-flag.patch) — both new functions crash pre-fix, pass post.
Independent of any feature flag; **upstream-bound** (postable as a standalone fix).

### 3.4 `0004` — far-pointer calling convention

**Need.** Once a far pointer is a C value (`0001`), it must pass to and return from functions. The mechanism
in `0001` only handles direct far *calls*; a far pointer flowing through the ABI needs a CC slot. Four ABI
encodings are plausible; the choice is an ABI commitment, so it was **measured**, not guessed.

**Patch.** [`patches/llvm-mos/0004-320-far-cc.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0004-320-far-cc.patch). All four variants — (a) one `Imag32` ZP reg, (b)
`Imag16`+bank reg, (c) `A:X`+`Y`, (d) hardware stack — were built behind feature flags and two-emulator
measured. **Variant (a) `Imag32` won** and ships; the losers stayed a measured spike. It needs `Imag32` in
`AnyRegBank` (a COPY-through class constraint shared with `0002`, which is why `0004` stacks on `0002`):

```tablegen
// far (addrspace 2) pointer passed/returned in one 32-bit Imag32 location;
// guarded on the 32-bit-pointer shape — the only 32-bit pointer is a far ptr,
// so near ptrs / varargs scalars are untouched.
```

**Proof.** `dev/run.sh far_cc` round-trips `0xF3` MAME+bsnes-jg; default build **byte-identical**; csmith
0-mismatch. Measurement write-up: [`docs/320-upstream-far-cc-measurement-note.md`](320-upstream-far-cc-measurement-note.md);
study [plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md).

### 3.5 `0005` — far-pointer value legalization

**Need.** A far pointer held *in a variable* (loaded/stored as data, not used as the access pointer) must be
a legal load/store **value** type. This is one hunk, split out of `0001` only because it is
`+mos-a16`-context-entangled (it interacts with the s16↔bytes narrowing that `0002` introduces) — keeping it
separate keeps `0001` a16-free and round-trip-provable.

**Patch.** [`patches/llvm-mos/0005-320-far-ptr-value-legalize.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0005-320-far-ptr-value-legalize.patch) — add `PF` (the far-pointer value type)
to the legalizer's Cartesian product of load/store value types:

```cpp
// MOSLegalizerInfo.cpp — a PF value routes through legalizeLoad/Store, which
// inttoptr/ptrtoint it to s32 and re-runs; the s32 then narrows to bytes.
// PF is addrspace 2 — only W65816 far code forms one — so this is inert elsewhere.
B.customForCartesianProduct({S8, S16, PZ, P, PF}, {PZ, P, PF});   // was {S8,S16,PZ,P}
B.customForCartesianProduct({S8, PZ, P, PF}, {PZ, P, PF});
```

**Proof.** Inert on every non-W65816 subtarget (no `addrspace(2)` exists there). Exercised by the far suite's
store/load/array/struct cases; corpus 7/7.

### 3.6 `0006` — packed-24 (AS3) storage form

**Need.** A far pointer is 32-bit in a register but only 24 bits are meaningful. For **storage** — a jump
table or banked-asset table of N far pointers — the 4th byte is pure waste. `addrspace(3)` packed-24 is the
3-byte in-memory form (`p3:24:8`): `sizeof(packed*) == 3`, so a 16-entry table is 48 B instead of 64 B.

**Patch.** [`patches/llvm-mos/0006-320-packed24.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0006-320-packed24.patch). Two non-obvious findings drove the implementation
(neither was the predicted "s24-narrowing" job): (1) `CodeGenPrepare` crashes on an invalid `MVT::i24` for a
24-bit pointer load → the packed pointer's *register* form is the 32-bit far form (`getPointerTy(AS3)→i32`),
memory footprint stays 3 B via datalayout; (2) the artifact combiner doesn't look through `inttoptr/ptrtoint`,
so packed↔bytes routes via `G_MERGE/UNMERGE{PFP,S8}` (no `s24` value), which **folds** against the adjacent
unmerge/merge in every shape clang emits. A static-initialized table also needed an
`AsmPrinter::emitNonStandardSizedConstant` hook to emit the `R_MOS_ADDR24_{SEGMENT_LO,HI,BANK}` triple per
entry (a single `R_MOS_ADDR8` was wrong).

**Proof.** `dev/run.sh packed24 packed24_table` → `0xF3`/`0xA5` on both emulators — the `0xF3` proves the
**bank byte survives** 3-byte packing (target is bank `$01`). Storage **48 B vs 64 B (−25 %)**; measured
break-even N≥1 ([`dev/measure-packed24.sh`](https://github.com/wbniv/llvm-mos-65816/blob/main/dev/measure-packed24.sh)). Opt-in (`addrspace(3)`), so default/near codegen is unchanged.

### 3.7 `0007` — near-abs bank-relaxation

**Need.** The 65816 assembler bank-relaxes `abs`→`long` when a symbol might live in a non-zero bank. But every
plain (non-`.far`) symbol accessed via the **A register** was being grown to 4-byte absolute-`long`
(`R_MOS_ADDR24`) and lld doesn't shrink it back, so the bloat reached the linked ROM — ~284 sites in the a16
examples, +1 B each. (X/Y escaped: they have no long form.)

**Patch.** [`patches/llvm-mos/0007-65816-near-abs-bank-relax.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0007-65816-near-abs-bank-relax.patch) — one guard in
`MOSAsmBackend::fixupNeedsRelaxationAdvanced`:

```cpp
// A NEAR (non-.far) symbol via plain absolute addressing must stay 16-bit: the
// compiler emits the explicit long form whenever it genuinely needs a far access,
// so a plain-symbol Absolute is by construction a near access — valid under DBR=0.
// Conservative: a misclassification can only MISS the size win, never emit a
// wrong-bank access.
if (BankRelax && !Sec->getName().starts_with(".far"))
    return false;
```

**Proof.** Rests on the same `DBR=0` invariant the existing `STX`/`STY` near abs-stores already need
([§4](#4-cross-cutting-correctness-arguments)). Far data (`.far*`) still relaxes to `long`. ROM
**byte-identical** except the −1 B/site shrink; full `0001`–`0007` combined-stack gate green on both
emulators (corpus 7/7, packed24, far suite, the six a16 disasm gates made relaxation-form-tolerant).

### 3.8 `0008` — DP-pointer-argument CC (upstream bug)

**Need.** An 8-bit `addrspace(1)` direct-page pointer passed **as an argument** crashed the backend: the CC
had no rule for it, so it fell through to the generic `CCIfPtr` and got a 16-bit `RS` register → an illegal
size-mismatched `(p1) = COPY $rs` (def 8 / src 16). **Reproduces on stock `mos6502`** — a pre-existing
upstream defect, surfaced by the far-pointer work, fixed here so the stack is clean.

**Patch.** [`patches/llvm-mos/0008-mos-dp-arg-cc.patch`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0008-mos-dp-arg-cc.patch) — an 8-bit-slot rule before the generic `CCIfPtr`
(mirrors the i8 pool and the `0004` far rules), covering returns too:

```tablegen
// CC_MOS, before CCIfPtr:
CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2, RC3, RC4, RC5, RC6, RC7, RC8,
                                   RC9, RC10, RC11, RC12, RC13, RC14, RC15]>>,
```

**Proof.** New [`llvm/test/CodeGen/MOS/dp-pointer-arg.ll`](https://github.com/wbniv/llvm-mos-65816/blob/main/patches/llvm-mos/0008-mos-dp-arg-cc.patch) — `load_dp`/`store_dp` crash pre-fix, post-fix emit
the correct zero-page-indexed `lda 0,x` / `sta 0,x` and pass `-verify-machineinstrs`. Corpus 7/7. Drafted as
upstream [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563) (`Fixes #561`).

---

## 4. Cross-cutting correctness arguments

Four invariants underpin the whole stack; a reviewer who accepts these can trust the per-step proofs.

1. **Gating discipline — gate on the feature predicate, not an operand shape.** Every `+mos-a16` change
   (including operand canonicalizations and helper predicates, not just instruction defs) is guarded by the
   *same* predicate that enables the feature behavior (e.g. `NativeS16Eq = hasAccum16() && Type==S16 &&
   Pred==ICMP_EQ`). A looser guard once let an EQ-only operand swap reverse a `<` compare in the *default*
   build<sup>[[C16]](#c16-seed-42--legalizeicmp-swap-leak)</sup>. The differential fuzzer's default leg is
   the standing enforcement.

2. **The `Imag16`-resident invariant — the accumulator is entered only by load/store.** A live 16-bit value's
   home is a zero-page `Imag16` pair; `A16` (whose low byte aliases the 8-bit `A`) is transient, entered via
   `LDAImag16`/left via `STAImag16`, **never** by a COPY between 8- and 16-bit register classes. This is what
   keeps the register coalescer from corrupting `$a16`<sup>[[C3]](#c3-gisel-native-s16-coalescer-crash)</sup>,
   and it is why both spill paths (static + reentrant) were fixed to spill `Ac16` via 16-bit load/store rather
   than a GPR COPY<sup>[[C18]](#c18-f3--selectimm-a16-spill-crash)</sup>.

3. **The `DBR=0` addressing contract.** Near data (8-bit `abs`, `R_MOS_ADDR16`) and MMIO are DBR-relative;
   the crt0 pins `DBR=0` explicitly (`phk; plb`) so they resolve to bank 0. The native-16 `long` path
   (`R_MOS_ADDR24`) is DBR-independent. `0007`'s near-abs relaxation and the `STX`/`STY` near-stores both rest
   on this single invariant ([Appendix B §6](#b6-the-dbr0-addressing-contract)).

4. **Volatile-tolerant, clobber-safe load folding.** An a16 fold that reads a memory operand at the *user's*
   point bails if any `mayStore`/`isCall` sits between def and user (`noStoreBetween`), so a load is never
   folded across a mutation (the pr34768 class). The upstream AA-precise `shouldFoldMemAccess` bails on
   volatile loads the #321 corpus folds single-use, so the fold helpers use the volatile-tolerant tailoring;
   the two were later unified in an AA-precise `noClobberBetween` (−26 B, 0 regressions).

---

## Appendix A — Testing setup

The bench is the credibility artifact: it lets a reviewer **re-run every claim**.

### A.1 The four-way differential gate

The bar for any value-level change:

```
host-computed  ==  default(8-bit)@MAME  ==  +mos-a16@MAME  ==  +mos-a16@bsnes-jg     + -verify-machineinstrs
```

<a id="a1-drmon"></a>

**drmon / drdevtools — the project's reason for being, and why MAME is primary.** *drdevtools* is the
open-source SNES development-tools suite this compiler feeds; *drmon* is its DAP source-level debugger
(coming to Linux), which today reads legacy assembler symbol formats (`.sld`/COFF/ca65/WLA-DX) and gains a
modern ELF/DWARF path from this work — see the [Motivation](#) note up top + [`INVESTIGATION.md`](INVESTIGATION.md). drmon's emulation core is **MAME's
`snes` driver**, so a ROM that is green on the MAME CI leg is by construction attachable in drmon. The
end-to-end goal this serves: *compile → optimized SNES ROM → llvm-mos DWARF symbols → source-level debug in
drmon*, entirely on open tooling (the compiler is the missing link; everything downstream already exists in
drdevtools). That is why MAME — not only the cycle-accurate bsnes-jg — is the primary CI emulator; the
DWARF round-trip is [`ROADMAP.md`](ROADMAP.md) step 6.

- **Two emulators.** **MAME** (`snes` driver, 0.285) is the primary because it matches the
  drmon/drdevtools debug backend (green-in-CI ⇒ attachable-in-drmon). **bsnes-jg** (cycle-accurate) is the
  independent second opinion — and is *deterministic* (fixed frame count + direct WRAM read, no Lua settle
  window), so its leg is load-insensitive and can run on a contended box. MAME's leg needs a **quiet box**
  (concurrent docker/MAME load flakes its settle window). A third emulator (Mesen2) was
  abandoned<sup>[[C23]](#c23-mesen2-abandoned)</sup>.
- **The default leg is the safety net.** Because each program is compiled *both* ways and both compared to
  the host oracle, an a16 helper that leaks into the 8-bit path shows up as `default@MAME ≠ host`. This is how
  gating discipline is enforced, not just asserted.

### A.2 Micro-tests (the per-feature gates)

Each value-level feature gets `examples/65816/a16<name>.c` + `dev/a16<name>.sh`: a `corpus_result` the script
asserts across host/default/a16 on both emulators, usually with a **disasm gate** (e.g. assert a native 16-bit
`cmp` is present and no 8-bit `cpx/cpy` remains). Wired into [`dev/run.sh`](https://github.com/wbniv/llvm-mos-65816/blob/main/dev/run.sh); closed with
`emu_verdict` (which rewrites the "both emulators" claim honestly under a bsnes-jg-only run). Templates:
`a16eqval*`. ~40 such tests exist (the table in [§3.2](#32-0002--321-16-bit-accumulator-m2)).

### A.3 The corpus

[`examples/snes/corpus/`](https://github.com/wbniv/llvm-mos-65816/tree/main/examples/snes/corpus) — small self-contained C programs (ALU, control flow, arrays/`.rodata`,
structs/pointers, recursion, `.data`/`.bss` init), host-checked against `expected.tsv`. `dev/run.sh corpus`
⇒ **7/7**. This is the M0 regression baseline that M1/M2 must never break.

### A.4 Differential fuzzers

- **builtin** ([`tools/a16_fuzz.py`](https://github.com/wbniv/llvm-mos-65816/blob/main/tools/a16_fuzz.py)): random UB-free C over mixed 8/16-bit vars + the full `+mos-a16` operator
  set; compiles twice, runs 4-way, delta-reduces on mismatch; reproducible seeds. Found three real defects on
  day one (a signed-shift compile hang, an `asl/lsr` carry-clobber miscompile, the F3 spill crash) — each now
  a committed regression test.
- **Csmith** (the default generator): language-level programs; seeds 1–500 run **0-mismatch** (a few legitimately
  SKIP when csmith's `main` diverges before `corpus_result`). Csmith caught the xy16 high-byte
  clobber<sup>[[C17]](#c17-xy16-index-high-byte-clobber)</sup> at seeds 247/445.

### A.5 GCC c-torture

Host prereq [`dev/fetch-torture.sh`](https://github.com/wbniv/llvm-mos-65816/blob/main/dev/fetch-torture.sh) (pinned gcc-14.2.0, sha256-verified) + a host-only compile/link filter
([`tools/torture_filter.py`](https://github.com/wbniv/llvm-mos-65816/blob/main/tools/torture_filter.py), 1253/1656 in-scope). `dev/run.sh torture [N] [--opt …] [--sample N]` runs the
emulator differential — the **default build is the oracle**, so a non-PASS default ⇒ SKIP and any FAIL is a
real defect; known a16 crashes ⇒ XFAIL. Result: **1098** PASS (-O1) / **1114** PASS (-Os), 4-way, no
data-row XFAILs remaining.

### A.6 CI

[`.github/workflows/smoke.yml`](https://github.com/wbniv/llvm-mos-65816/blob/main/.github/workflows/smoke.yml) (`workflow_dispatch`), four jobs: `smoke` (corpus in MAME), `xcheck` (build the
from-source toolchain + SDK, bsnes-jg + secret-gated `corpus-a16`), `torture`, `fuzz-csmith` (both 4-way,
`needs: xcheck`). A `mode` input picks `sampled` (seeded subset) or `full`; all secret-gated (skip, don't
fail, without the SPC700 BIOS). `task ci-watch` streams step transitions + verdict.

### A.7 Build / disasm cheats (for re-running locally)

```sh
# compile + MIR-verify on the host (no container):
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs -c FILE.c -o /tmp/x.o
# disasm / per-function size:
build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mosw65816 /tmp/x.o
# emulator differential (Docker; quiet box for MAME):
dev/run.sh <name>          # e.g. a16add, far_call, corpus, fuzz 50 1
```

> **Gotcha worth knowing as a reviewer:** `build/.../bin/clang` is a symlink with a stale mtime; the real
> binary is `clang-23`. Confirm a rebuild took by checking `clang-23`'s mtime — a stale build silently serving
> old codegen has burned this project before. Full mechanics: [`docs/agent-handoff.md`](agent-handoff.md).

---

## Appendix B — SNES platform changes & requirements

The SNES target is M0: it adds no codegen, but it is the environment every codegen test runs in. It lives in
[`platforms/snes/`](https://github.com/wbniv/llvm-mos-65816/tree/main/platforms/snes) (+ [`platforms/snes-far/`](https://github.com/wbniv/llvm-mos-65816/tree/main/platforms/snes-far)) and is mirrored into a `vendor/llvm-mos-sdk` clone for
reconciliation with upstream sdk#415 ([§B.5](#b5-relationship-to-upstream-sdk415)).

### B.1 Files

| File | Purpose |
|------|---------|
| [`platforms/snes/crt0.c`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes/crt0.c) | 65816 native-mode reset preamble (the contract below) + weak `nmi`/`irq` |
| [`platforms/snes/link.ld`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes/link.ld) | LoROM 32 KiB memory map, sections, near-code budget, vectors |
| [`platforms/snes-far/link.ld`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes-far/link.ld) | LoROM 64 KiB (bank `$00` + bank `$01` for `.far_text`/`.far_rodata`) |
| [`platforms/snes/header.s`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes/header.s) | Cartridge header ($FFB0–$FFDF): title, map mode, checksum placeholders |
| [`platforms/snes/snes.h`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes/snes.h) | Minimal register HAL (`INIDISP`, `NMITIMEN`, …) |
| [`platforms/snes/clang.cfg`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes/clang.cfg) | `-mcpu=mosw65816` (platform default) + `-mlto-zp=224` + `-D__SNES__` — see [§B.7](#b7-mcpu-flow) |
| [`platforms/snes/call-near-from-far.s`](https://github.com/wbniv/llvm-mos-65816/blob/main/platforms/snes/call-near-from-far.s) | `__call_near_from_far` mixed-banking thunk |
| [`tools/snes-checksum.py`](https://github.com/wbniv/llvm-mos-65816/blob/main/tools/snes-checksum.py) | Post-link ROM-size byte + checksum/complement patcher |

### B.2 The crt0 native-mode contract

The 65816 boots in emulation mode and fetches the emulation RESET vector at `$FFFC` → `_start`. The 24-byte
`.init.50` fragment establishes the contract the codegen depends on, then force-blanks the PPU. Shown as
65816 assembly; the actual `crt0.c` emits the six 65816-only ops (`xce`, `rep`, the 16-bit `ldx`, `sep`,
`phk`, `plb`) as `.byte` because the platform builds its crt0 objects without `-mcpu=mosw65816`
([§B.7](#b7-mcpu-flow)):

```asm
.section .init.50          ; runs at reset ($FFFC emulation RESET vector -> _start)
  sei
  cld
  clc
  xce                      ; E = 0  -> 65816 native mode
  rep #$10                 ; 16-bit index regs (so the txs below transfers 16 bits)
  ldx #$01ff               ; an 8-bit txs would set SP=$00FF, colliding with the direct page
  txs                      ; SP -> $01FF (page-1 hardware stack)
  sep #$30                 ; M=1, X=1: 8-bit A + index — the codegen default
  phk                      ; push program bank (= 0)
  plb                      ; DBR := 0 (explicit; abs globals + the MMIO writes below read DBR:addr)
  lda #$00
  sta $4200                ; NMITIMEN: no NMI / IRQ / auto-joypad
  lda #$8f
  sta $2100                ; INIDISP: force blank, brightness 0
```

| Reg | Value | Why |
|-----|-------|-----|
| `E` | 0 native | `XCE` — prerequisite for any 16-bit register |
| `SP` | `$01FF` | page-1 hardware stack via a transient 16-bit `txs` |
| `M`/`X` | 1/1 (8-bit) | `SEP #$30` — codegen default; 16-bit regions bracketed by `rep/sep` |
| `DBR` | 0 | `PHK; PLB` — near `abs` data + MMIO are DBR-relative ([§B.6](#b6-the-dbr0-addressing-contract)) |
| `DP` | 0 | reset default; never moved |

After `.init.50` the common init chain runs (`.init.100` soft-stack, `.init.200` `.data`/`.bss`,
`.init.300` ctors, `jsr main`, spin). Native mode is the default for *every* program, not a per-test opt-in:
with M/X pinned 8-bit it runs the existing 8-bit generator identically. Full walkthrough:
[`docs/snes-bootup-sequence.md`](snes-bootup-sequence.md).

### B.3 Linker scripts

`snes/link.ld` (32 KiB LoROM) carves the fixed header/vectors into their own region so the near-code budget
is an enforced link-time contract:

```ld
MEMORY {
  zp     : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)  /* $0020-$00FF DP, past the imaginary regs */
  ram    : ORIGIN = 0x0200,     LENGTH = 0x1E00                /* $0200-$1FFF low WRAM (soft stack) */
  rom    : ORIGIN = 0x8000,     LENGTH = 0x7FB0                /* $8000-$FFAF near-code budget = 32688 B */
  romhdr : ORIGIN = 0xFFB0,     LENGTH = 0x0050                /* $FFB0-$FFFF header + vectors */
}
```

Over-budget now fails loudly (`region 'rom' overflowed by N bytes`) instead of an obscure `.snes_header`
overlap — this is the "near/far code model" decision: **no `-mcmodel` codegen mode**; near (`JSR`/`RTS`,
2-byte fn ptr) is the default and far is per-symbol opt-in. `snes-far/link.ld` adds
`rom_1 : ORIGIN = 0x018000, LENGTH = 0x8000` for `.far_rodata`/`.far_text` in bank `$01`, so a global tagged
`__attribute__((section(".far_rodata")))` gets VMA `$018xxx` → `R_MOS_ADDR24`.

### B.4 ROM header

`$FFB0–$FFDF`: title `"LLVM-MOS SNES"`, map mode `$20` (LoROM/slow), ROM-size byte + checksum/complement
patched post-link by [`tools/snes-checksum.py`](https://github.com/wbniv/llvm-mos-65816/blob/main/tools/snes-checksum.py) (checksum = sum of bytes mod `$10000`; complement =
checksum ^ `$FFFF`). Vectors: native at `$FFE0–$FFEF`, emulation at `$FFF0–$FFFF` with `$FFFC` RESET →
`_start`.

### B.5 Relationship to upstream sdk#415

[llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415) (@Phillip-May, stalled) is an
**8-bit/emulation-mode-only** SNES target (no `-mcpu=mosw65816`, no native mode) — SDK scaffolding, not
codegen, but real (a Celeste port runs on it). The posture is **additive, not replace**: keep the backend
codegen (this fork's contribution) in `llvm-mos`; contribute the native-mode crt0 + the dual-emulator CI
harness *on top of* #415; reuse his richer register header + multi-bank linker layout with credit. Detail:
[`docs/415-snes-target-reconciliation.md`](415-snes-target-reconciliation.md).

### B.6 The DBR=0 addressing contract

Worth stating plainly because three patches rest on it. Near scalar globals use 16-bit `abs`
(`R_MOS_ADDR16`), which reads **`DBR:addr`** — so they only resolve to bank-0 low WRAM if `DBR=0`. The crt0
pins it explicitly (`phk; plb`) rather than relying on the reset default, so a later bank switch / `MVN`/`MVP`
/ interrupt can't silently break it. The native-16 `long` path (`R_MOS_ADDR24`) carries its own bank and is
DBR-independent — so a single function can touch the *same* global both ways (low byte via `abs`, high via
`long`). `0007`'s near-abs relaxation and the `STX`/`STY` near-stores depend on exactly this invariant; gate
`dev/run.sh crt0native` asserts the `4b ab` (`phk; plb`) bytes are present in the linked ROM.

<a id="b7-mcpu-flow"></a>

### B.7 The `-mcpu` flow — three codegen levels

`-mcpu=mosw65816` is the *middle* of three codegen levels, routinely conflated (asiekierka raised exactly
this on [sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415)):

| Level | How you get it | What it gives |
|-------|----------------|---------------|
| 1 — bare 6502 | nothing | the stock 6502 code generator |
| 2 — `-mcpu=mosw65816` | **the SNES platform default** (`clang.cfg`) | the upstream **Tier-1** 65816 ISA (`TXY`/`JSL`/`MVN`/`PEA`…) — free, *not* this work |
| 3 — `+mos-a16` / `+mos-xy16` / `addrspace(2)` | explicit opt-in, layered on level 2 | **this contribution** — 16-bit accumulator / far pointers (**Tier-2**) |

The SNES platform's `clang.cfg` sets level 2 as the default (`snes-far` inherits it via `@mos-snes.cfg`).
Three things keep this safe and orthogonal to the #320/#321 work: (1) the differential harness passes
`-mcpu=mosw65816` **explicitly** on *both* the default-oracle and feature legs — the only per-leg difference
is the target-feature — so the differential does not depend on the platform default; (2) the platform's
internal crt0/header objects are still built **without** `-mcpu` (the hand-encoded `.byte` preamble in
[§B.2](#b2-the-crt0-native-mode-contract)); (3) only a *bare* `mos-snes-clang` build is affected, and it
gets the free Tier-1 instruction wins. The M0 corpus (**7/7**) and smoke (`sentinel == 0x42`) pass unchanged.

---

## Appendix C — Dead ends, experiments & spikes

The main body footnotes here by tag. These are the measured negatives and rejected approaches — kept because
"we tried the obvious thing and it lost, here's the number" is itself a reviewable finding (and several are
publishable upstream results). Disposition codes: **WON'T-DO** (measured net-negative, closed),
**measured-null** (no opportunity in real code), **deferred** (parked behind a concrete re-open trigger),
**reverted→fixed** (crashed, root-caused, solved differently), **upstream** (not our defect).

The three governing lessons these illustrate: (1) **measure, don't assume** — predicted codegen is routinely
wrong here; (2) **a native 16-bit op is not automatically smaller** — it depends on operand residency and
schedule; (3) **gate, don't blanket** — a blanket change that regresses common shapes to win a sub-case is
wrong.

### ABI / frame

#### C1. Frame-ABI three-way (DP-window vs stack-relative vs soft-static) — *measured-null*
Built P0 scaffolding + an A0 census to compare three 65816 frame strategies. The census short-circuited the
build: **0/13 realistic functions profit** (11/13 have *zero* static-stack spills — llvm-mos keeps locals
register-resident in `__rc`, and `&local`/arrays route through a pointer *in* `__rc`). A DP-window would
*tax* the abundant `__rc` accesses. Soft static stack retained; (a)/(b) confirmed-shelved by measurement, not
paper reasoning. Drafted as the [#321 CC design note](321-upstream-cc-frame-abi-note.md). Durable artifacts
(`frameabi_*`, census script) on `main`.

<a id="c2-a16-threading-phase-3--ra-level-residency"></a>

#### C2. A16-threading Phase 3 — RA-level `Ac16` residency — *deferred*
Phases 1/1.5 (post-RA peephole) already capture −31/−36 % on chains; a 300-program scan left **1** genuine
remainder. Phase 3 (keep values in `Ac16` at allocation time) is capped by the single 65816 accumulator (two
live 16-bit values must spill to `Imag16` anyway) and re-risks the C3 coalescer crash. **Re-open trigger:** a
2nd independent realistic regalloc crash, or a real function crossing ~10/14 `Imag16` pairs. The same
deferred core is the `globals.c`/`a16regpress.c` `-Os` RA-pressure crash (XFAIL + XPASS-guarded).

### 16-bit codegen-form spikes

<a id="c3-gisel-native-s16-coalescer-crash"></a>

#### C3. GISel-native s16 coalescer crash (Increment 1d) — *reverted→fixed*
First native-s16 prototype kept the value in `A16` across ops; an 8-bit `LDImm` coalesced into `A16` (whose
low byte aliases the 8-bit `A`) → malformed `$a16 = LDImm`. Reverted to keep the tree green. **Solved
differently** by 1d-retry: value home = `Imag16`, `A16` transient via load/store only — the
invariant in [§4.2](#4-cross-cutting-correctness-arguments). Shipped in `0002`.

<a id="c6-ordering-as-value-branchless"></a>

#### C6. Ordering-as-value, branchless — both forms — *WON'T-DO*
`b = (a < c)` materialized branchlessly instead of via the select-diamond. Built **both** the 8-bit `adc`-tail
(v1) and the 16-bit `rol`-tail at M16 (candidate A) in full. v1: `a16cmpaudit` **+262 B**. Candidate A:
**+654 B** (both-widths) / +78 B (gated), whole a16 corpus **+340 B, ZERO programs improve** — *worse* than
v1. The select-diamond is the ambient-16-bit optimum: it folds inversion free, its M8 tail matches the
post-loop ambient mode, and it keeps the bool in `X` (not an `Imag16` slot that cascades to spills). Both
forms closed; candidate A preserved as `docs/plans/spikes/2026-06-21-321-ordering-value-candidate-a-spike.patch`.
A textbook "isolated-leaf win (42 B) that evaporates in realistic context".

#### C7. `inc abs` / `dec abs` memory-RMW — *WON'T-DO (unsafe)*
Global 16-bit `g ± 1` as a single `inc abs` instead of `lda; inc a; sta`. Rejected: the 65816 has **no
`inc long`**, and `inc abs` is **DBR-relative** — it only "happens to work" via the low-8 KB WRAM mirror and
would silently wrap for any data above `$1FFF` or in another bank. The accumulator form keeps the compiler's
DBR-independent long addressing. Reverted to the 3-instruction form.

#### C8–C12. EQ-as-value full-native materialize — *WON'T-DO / gated*
A family of attempts to materialize equality-as-a-value natively. **Blanket** native compare regresses common
shapes (register/global operands pay `Imag16`+`rep/sep` overhead that 8-bit `cpx;cmp` avoids) → split into
**four operand-residency-gated wins** instead (v1 indirect −4 B, v3 both-global −24 %, g==imm, v2 computed),
each measured no-regression and shipped in `0002`. The full-native tails lost: Option A (reuse-ops, carry→
diamond) **+14 B** on every shape (the flag→byte diamond is already optimal; arithmetic before it only adds
cost); Option B (branchless `rol`/`adc` tail) **+16…+28 B** (forgoes the `CmpBr` compare-fusion). Variable
shifts similarly stay 8-bit (inline loop > `__ashlhi3` libcall at -Os); `x == 0`-as-value stays 8-bit (+5 B
native).

### Address-space spikes

#### C13. AS4 zero-bank — *measured-null*
The 5th address space in asiekierka's model (a bank-0-restricted 16-bit pointer for size). **0/13** programs
benefit — no realistic code fits the constraint without spill pressure that doesn't exist. With this measured,
the five-address-space model is **complete**: AS0 near, AS1 DP, AS2 far (`0001`), AS3 packed-24 (`0006`), AS4
null.

#### C14–C15. AS3 packed-24 — *shipped, but the surprises are instructive*
Increment A (3-byte type) shipped cleanly. Increment B (codegen) was **not** the predicted s24-narrowing job
— see [§3.6](#36-0006--packed-24-as3-storage-form): the register form is i32 (the `MVT::i24`
`CodeGenPrepare` crash) and packed↔bytes routes via `G_MERGE/UNMERGE` (the combiner doesn't see through
`inttoptr`). Both findings are the kind a reviewer of a 24-bit-pointer target will hit.

### Correctness bugs found & fixed (regression-guarded)

<a id="c16-seed-42--legalizeicmp-swap-leak"></a>

#### C16. seed-42 — `legalizeICmp` swap leak — *fixed*
An EQ-only operand swap was guarded by a predicate that checked neither `hasAccum16()` nor `Pred==EQ`, so a
non-EQ `<`/`>` compare in the **default** build hit `std::swap(LHS,RHS)` and reversed. Caught by the fuzzer's
default leg. The origin of the [§4.1](#4-cross-cutting-correctness-arguments) gating rule.

<a id="c17-xy16-index-high-byte-clobber"></a>

#### C17. xy16 index high-byte clobber (seeds 247/445) — *fixed*
A non-index s16 value classed `Xc16`, loaded into `X16`, left live across an 8-bit-index op whose `sep #$10`
**zeroes** the index high byte → high byte lost. cvise-reduced to 8 lines. Fix (approach B): `selectXY16`
emits `LDXAbs16`/`LDYAbs16` only when the value is genuinely an index, else reclasses to `Imag16`. 4-way +
csmith 101–500 (0/400) + c-torture 60/60.

<a id="c18-f3--selectimm-a16-spill-crash"></a>

#### C18. F3 — `SelectImm $a16` spill crash — *fixed*
When an `Ac16` value is forced live across a call, the spill path only special-cased `Imag16`, so `Ac16` fell
through to a single-byte path emitting `GPR = COPY A16` → lowered to the invalid `SelectImm $a16`. Fix: spill
`Ac16` via direct 16-bit `LD/STAbs16` (static) / `*Indir16` (reentrant) to the frame slot — never a GPR COPY.
Restores the [§4.2](#4-cross-cutting-correctness-arguments) invariant. Tests `a16spill*`.

### Upstream bugs found (not our defects)

<a id="c19-upstream-register-scavenger-nz-crash"></a>

#### C19. Register-scavenger N/Z crash — *upstream, deferred*
`+mos-a16 -O1/-Os` pressure keeps N/Z live where the upstream scavenger asserts them dead → `$p is not a GPR`
on 8/500 seeds. Pristine-upstream (no scavenger change in `0002`). XFAIL + XPASS-guarded; issue drafted
([`docs/321-upstream-scavenger-nz-issue.md`](321-upstream-scavenger-nz-issue.md)). Fix is high-risk/low-reward
for a pathological frequency — deferred.

#### C22. DP-pointer-argument CC crash (#561) — *upstream, fixed here*
See [§3.8](#38-0008--dp-pointer-argument-cc-upstream-bug). Reproduces on stock `mos6502`; fixed as `0008` +
upstream [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563).

### Infrastructure abandoned

<a id="c20-far-fn-pointer-ir-representation"></a>

#### C20. Far fn-pointer IR representation
A far fn ptr can't be an `addrspace(2)` IR callee (LLVM forbids a non-program-addrspace callee). Threaded
instead via a volatile store of the 24-bit target to `__mos_far_target` + `call @__call_indir_far` (the stub
does `jml (__mos_far_target)`). The clang `far`/`long_call` attribute rewrites a `far`-attributed call into
that shape, reusing the MIPS `long_call`/`far` GNU spelling via a shared `ParseKind`.

<a id="c21-far-value-residuals"></a>

#### C21. Far-value residuals — *closed by-design*
Two far-pointer-as-value cases are intentionally not codegen'd: **dp→near** is the upstream C22 CC bug (no fork
hack); **default-8-bit far storage** is un-legalized **by design** — the 32-bit value's `s32↔bytes` bridge is
`+mos-a16`-gated, so a default build gets a clean `unable to legalize` rejection, never a miscompile.

<a id="c23-mesen2-abandoned"></a>

#### C23. Mesen2 abandoned
A third emulator (Mesen2) crashed on the Ubuntu 26.04 glibc-2.43 base (`free(): invalid pointer`) from a
prebuilt binary. MAME + bsnes-jg already give a two-emulator cross-check; parked pending a source build.

---

*Generated from: [`docs/ROADMAP.md`](ROADMAP.md), [`docs/implementation-status.md`](implementation-status.md),
[`docs/agent-handoff.md`](agent-handoff.md), the [`patches/llvm-mos/`](../patches/llvm-mos) stack, and the
[plan index](investigations/plan-index.md). Keep it current when the stack changes.*

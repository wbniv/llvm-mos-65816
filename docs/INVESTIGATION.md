# llvm-mos 65816 C Backend — Current Status & Contribution Question

**Date:** 2026-06-13
**Method:** Primary-source reconstruction of the llvm-mos issue tracker via the GitHub
API — full comment threads of issues [#32](https://github.com/llvm-mos/llvm-mos/issues/32),
[#320](https://github.com/llvm-mos/llvm-mos/issues/320),
[#321](https://github.com/llvm-mos/llvm-mos/issues/321),
[#454](https://github.com/llvm-mos/llvm-mos/issues/454) read verbatim; rival/abandoned forks
inspected directly. Supersedes the time-bounded llvm-mos section of the
[Zardoz investigation](2026-06-12-zardoz-65816-compiler.md) (which was anchored to Oct 2024 / Jan 2026).

---

## Bottom line

As of June 2026, **llvm-mos ships a production-quality 65816 assembler and linker but
no C compiler backend.** The compiler half has never been started beyond design notes and one
abandoned proof-of-concept. The person who did the assembler work and wrote the codegen design
(@asiekierka) put the backend "on hold" and, in his own words, "never did" it. No one has
picked it up. Every barrier *around* codegen has now fallen — assembler, linker, ELF, and (as
of Dec 2025) a DWARF debug-info specification — which means the remaining work is unusually
well-isolated: it is pure LLVM code generation, with the surrounding toolchain already built and
tested. **This is the exact "optimizing open-source 65816 C compiler" gap that Zardoz/WDC816CC
filled commercially in the 1990s, and it remains open.**

The verbatim status, from the maintainer-adjacent author of the work
([#454, 2024-10-25](https://github.com/llvm-mos/llvm-mos/issues/454)):

> @davidgiven: "Is the status in the top comment up-to-date? … it looks like things are mostly there."
> @asiekierka: "Yes; every checkbox that is checked has shipped in a production version of
> LLVM-MOS. The rest was put on hold until I got around to porting the compiler backend proper,
> which I never did. **In short — LLVM-MOS ships a 65816 assembler and linker, but not a compiler.**"

Nothing in the tracker between then and June 2026 changes that. The Dec 2025 – Jan 2026 activity
on [#32](https://github.com/llvm-mos/llvm-mos/issues/32) is design musing and infrastructure, not
codegen.

---

## What exists today (shipped)

| Layer | Status | Evidence |
|-------|--------|----------|
| 65816 instruction set in the assembler | **Shipped** | [#147](https://github.com/llvm-mos/llvm-mos/issues/147) (merged 2022), follow-up PRs ~2023; @asiekierka: "every checkbox that is checked has shipped in a production version" |
| SPC700 assembler (SNES audio CPU) | **Shipped** | [#510](https://github.com/llvm-mos/llvm-mos/pull/510) (SPC700 BRA opcode fixes) |
| ELF object format + LLD linker (incl. relaxation infra) | **Shipped** | [ELF spec](https://llvm-mos.org/wiki/ELF_specification); used by all targets |
| DWARF debug-info specification | **Shipped (new, Dec 2025)** | @johnwbyrd, [#32 2025-12-31](https://github.com/llvm-mos/llvm-mos/issues/32): "Another piece of the puzzle has fallen into place: https://llvm-mos.org/wiki/DWARF_specification … regardless of whatever convoluted calling convention we come up with, we now have an infrastructure to describe it to debuggers." |
| **65816 C/C++ code generation** | **Does not exist** | see below |

The assembler is feature-complete enough that `.a8`/`.a16`/`.i8`/`.i16` register-width directives
and the full instruction set are usable today for hand-written and inline 65816 assembly — but
clang will not *generate* 65816 machine code. You can assemble 65816; you cannot compile C to it.

---

## What's missing — the codegen work, decomposed

In 2023 @asiekierka split the umbrella issue [#32](https://github.com/llvm-mos/llvm-mos/issues/32)
into two concrete, still-open tracking issues. These are the actual backend:

### [#320 — 24-bit address space support](https://github.com/llvm-mos/llvm-mos/issues/320) (open, design only)

LLVM cannot model a 24-bit pointer directly (it requires power-of-two address sizes), so the
65816 must be presented to LLVM as a 32-bit-addressed machine where only 24 bits are emitted —
johnwbyrd's original framing: *"lie to codegen and claim that the 65816 is actually a 32-bit
processor, of which only the first 24 bits are used."* @asiekierka's most recent proposal
([2024-03-14](https://github.com/llvm-mos/llvm-mos/issues/320)) lays out a five-address-space LLVM
data layout, mapping the 65816's pointer zoo to the 8086 "near/far" model:

| LLVM addrspace | Width | 65816 meaning |
|----------------|-------|---------------|
| `0` | 32-bit | `far` pointer — easiest for LLVM, matches ELF address size, best perf |
| `1` | 8-bit | `direct page` pointer (the 6502 "zero page") |
| `2` | 16-bit | `absolute` pointer (relative to the Data Bank register) |
| `3` | 24-bit | `packed far` — same as `0` but stored in 3 bytes |
| `4` | 16-bit | `zero bank` — artifact of direct-page conversions and stack frames (`$00xxxx`) |

A subtle but important design finding, surfaced on the 6502.org forum and recorded in the issue:
**32-bit pointers are *cheaper* than 24-bit pointers** on the 65816, because 24-bit arithmetic
forces a 16-bit + 8-bit access pair and an extra CPU-mode switch. So the default pointer should be
32-bit, with 24-bit "packed" as a space-saving option.

### [#321 — 16-bit register mode support](https://github.com/llvm-mos/llvm-mos/issues/321) (open, design only)

The hard part. The 65816's M and X status flags switch A and X/Y between 8- and 16-bit at
runtime via `REP`/`SEP`. @asiekierka's proposed two-stage plan:

1. **Basic `xy16` + `a8`/`a16`.** Model X, Y, and C (the 16-bit accumulator) as 16-bit and A as
   8-bit; insert `REP`/`SEP` opcodes at a late codegen stage based on which registers each
   instruction touches. "This is still hard, but at least concrete." This follows the LCC (1994)
   and TCC 65816 ports, which keep X/Y permanently 16-bit and toggle only A.
2. **`xy8`/`xy16` switching.** "This may well be a pipe dream with our current resources."

The design rests on a real-world insight from a former commercial SNES developer, @Felice-Enellen
([#32, 2024-01-09](https://github.com/llvm-mos/llvm-mos/issues/32)): 8/16-bit accumulator switching
is **not** niche — `XBA` effectively gives you a second "B" accumulator, and good 65816 code leans
on it heavily. @asiekierka's refinement after further research: A-width switching is essential,
but X/Y-width switching is genuinely niche (used for narrow optimizations like 256-byte table
wraparound), which is why stage 1 freezes X/Y at 16-bit.

**The only codegen prototype that ever existed** is a proof-of-concept "emit REP/SEP" pass in the
abandoned [jackoalan/llvm-mos](https://github.com/jackoalan/llvm-mos) fork
([commit ec070a7](https://github.com/jackoalan/llvm-mos/commit/ec070a70ba8d8b3d3a9da24b4216435f9575f6bb),
2022-01-30, "Experimental work on 65816 subtarget"). Stale since Feb 2022, but a useful reference.

### The third pillar — the hardware stack

Not yet a separate issue, but called out by @asiekierka (relayed by johnwbyrd,
[#32 2024-02-26](https://github.com/llvm-mos/llvm-mos/issues/32)): the 65816 has a real 16-bit
stack pointer and stack-relative addressing modes, making a hardware-stack ABI viable (unlike the
6502, where llvm-mos uses a soft "static stack"). His three-category summary of the whole job:

> (a) Adding support for the 24-bit address space; tracking data accesses and distinguishing
> between "near" and "far" jumps.
> (b) Adding support for 16-bit registers; … X/Y become permanently 16-bit, while A is switched
> at runtime.
> (c) Adding support for the 65C816's hard stack; it has a 16-bit pointer and addressing modes
> that allow reading stack-offsetted variables.
> "The rest is fairly minor… the 65C816 is hard but it's not, IMO, a fundamental rethinking of
> code generation, at least for a first pass."

---

## The cheap intermediate path (worth knowing)

@asiekierka floated a low-effort way to make llvm-mos emit *working* 65816 ROMs **before** real
codegen exists ([#32, 2023-06-16](https://github.com/llvm-mos/llvm-mos/issues/32)): run the
existing 8-bit 6502 code generator on a 65816 in native 8-bit mode, with crt0 patched to
initialize the stack pointer to `$01FF` instead of `$FF`.

> "This would allow using llvm-mos as an 65816 C compiler in a sense, though not a very efficient
> one for sure! However, this would still allow building support for 65816 *targets* in the
> meantime, as they could unlock later code-generation benefits with time."

This produces 6502-quality code (no 16-bit registers, no banking) but unblocks SNES *targets* in
llvm-mos-sdk now. It is the minimum-viable on-ramp, not the goal.

---

## How llvm-mos works (why this is tractable at all)

The reason llvm-mos is the most plausible host for an open-source optimizing 65816 compiler is its
architecture, which already solved the "LLVM expects registers, the 6502 has almost none" problem:

- **Imaginary registers.** llvm-mos reserves a block of zero-page memory as 16 two-byte
  "imaginary registers" (`__rc0`…, `__rs0`…), allocated by the linker and used by a real LLVM
  register allocator alongside the physical A/X/Y. They need not be contiguous.
  ([Imaginary registers wiki](https://llvm-mos.org/wiki/Imaginary_registers))
- **Soft/static stack.** `RS0` is a soft stack pointer; non-recursive programs may need no stack
  at all. The 65816's *hardware* stack would replace this for the new target —
  pillar (c) above.
- **Throw-one-away culture.** Maintainer @mysterymath
  ([#32, 2021-09-20](https://github.com/llvm-mos/llvm-mos/issues/32)): "Pretty much our whole 6502
  code generator is designed to be thrown away… we could replace our whole calling convention in a
  week or two (I just did)." The codegen is deliberately modular and replaceable — favorable ground
  for adding a sibling target.

LLVM's optimizer (GlobalISel, the legalizer, link-time optimization) is already wired up; the
65816 work is writing lowering rules and a register/stack model, **not** building an optimizer
from scratch. That is the structural advantage over cc65 (8-bit-only codegen, would need a
dual-width rewrite) and over 816-tcc/PVSnesLib (single-pass, no optimizer by design).

---

## Who the players are

| Person | Handle | Role |
|--------|--------|------|
| Daniel Thornburgh | [@mysterymath](https://github.com/mysterymath) | **Lead / maintainer.** Built the 6502 C backend. Gatekeeper on ABI and design taste. Won't bless an ABI without a high-quality implementation behind it. |
| — | [@johnwbyrd](https://github.com/johnwbyrd) | Opened [#32](https://github.com/llvm-mos/llvm-mos/issues/32). Strong architect voice, "code-first." Active in discussion (Dec 2025–Jan 2026) but not implementing the backend. |
| — | [@asiekierka](https://github.com/asiekierka) | **Did the 65816 + SPC700 assembler; wrote the entire codegen design** (#320/#321). The natural implementer — but stepped away ("never did" the backend). Holds the most domain context. |

The most valuable single thing a funder/contributor could do is **get @asiekierka (or
@mysterymath) the time to resume**, because the design work is already done and lives in their
heads and in #320/#321.

---

## Rival & dead-end efforts (don't reinvent these)

- **[SNES-Dev](https://github.com/SNES-Dev/SNES-Dev)** (@chorman0773, @rdrpenguin04) — an
  *independent* GNU-based w65 toolchain with its own registered ELF ABI (`EM_65816` = 257,
  registered with generic-abi), a working binutils assembler, and a published
  [w65 psABI](https://github.com/SNES-Dev/SNES-Dev/blob/main/docs/abi/v1.md). The monorepo is
  **active** (pushed 2026-05-26, 35★, now advertising C/C++/Rust over LLVM+GNU) — but its **GCC
  backend has been stale since 2021** (`gcc` submodule untouched), i.e. the actual optimizing C
  compiler never shipped. In 2021 there was friction with llvm-mos over ABI standardization;
  @mysterymath's position stands: *"I'll consider that a given ABI might satisfy [high quality]
  only after someone shows me a high-quality compiler for it."* Standardizing an ABI ahead of an
  implementation is explicitly unwelcome here.
- **[jeremysrand/llvm-65816](https://github.com/jeremysrand/llvm-65816)** (2016, 28★, abandoned) —
  an attempt on *mainline* LLVM (not llvm-mos) targeting ORCA/M assembly for the Apple IIGS. Hit
  the exact wall the new work must avoid: *"LLVM seems to promote everything to 32-bit if you say
  the machine has 32-bit or better registers even if I have indicated that the native bit width is
  16."* Historical reference only — predates llvm-mos entirely.
- **[jackoalan/llvm-mos](https://github.com/jackoalan/llvm-mos)** (2022) — the REP/SEP POC pass
  noted above. The only real codegen prototype; stale but worth reading.

---

## The contribution / funding question — assessment

**Is it worth it?** For a fully-open SNES C toolchain, yes — this is the keystone. PVSnesLib's
816-tcc works but doesn't optimize; Calypsi optimizes but is closed and hobby-licensed; WDC816CC
is commercial. An llvm-mos 65816 backend would be the first *open-source, optimizing, actively
maintained* 65816 C compiler — and it would emit DWARF (spec landed Dec 2025), which a source-level
debugger can consume. (See [toolchain survey](2026-06-11-snes-65816-toolchains.md) and
[Zardoz investigation](2026-06-12-zardoz-65816-compiler.md) for the full landscape.)

**How big is it?** Not a weekend project — johnwbyrd says so repeatedly, and @mysterymath's
own experience building the 6502 backend was "considerably more work than anticipated." His
estimate for a *from-scratch* C compiler was "a year minimum." But the 65816 work is **not** from
scratch: the assembler, linker, ELF, DWARF, optimizer, and register-allocation framework already
exist and are tested. The remaining job is the three codegen pillars (24-bit addressing,
16-bit A / fixed-16-bit X-Y with a REP/SEP pass, hardware stack) plus a calling convention.
Realistically a focused, multi-month effort for one engineer fluent in LLVM backends — months, not
years, given the head start, but specialist months.

**What are the paths, in increasing effort:**

1. **Bring documented ABI prior art to the design discussion.** The calling-convention question
   (PHD/TCD direct-page frame, A+X split return values) is live and undecided in #320/#321. The
   highest-value artifact is the *documented* 1990s prior art — the
   [WDC816CC/ORCA-C ABI](2026-06-12-zardoz-65816-compiler.md#the-wdc816cc-abi-high-confidence) drawn
   from the WDC compiler manual and ORCA/C source — already captured in the Zardoz investigation.
   That is the durable reference to surface, not anyone's recollection: Zardoz users (Will Norris
   among them) shipped commercial SNES titles on it, which confirms the *gap was filled and the
   ABI worked in production*, but the compiler's internals were the compiler author's domain, not
   the game developers'. Low effort, real value — but it's pointing at a manual, not a memory.
2. **Land the cheap intermediate.** Patch llvm-mos-sdk crt0 to `SP = $01FF` and stand up a minimal
   SNES target running 8-bit-mode codegen. Unblocks 65816 *targets* now; small, self-contained PR.
   Note: **there is no SNES SDK target yet** — it's open issue
   [llvm-mos-sdk#415 "[SNES] Add target"](https://github.com/llvm-mos/llvm-mos-sdk/issues/415);
   the SDK ships 46 platforms (8 NES variants, C64, …) but no SNES. So this path *is* building
   that target (crt0, LoROM/HiROM linker scripts, vectors, memory map) — which the real codegen
   path needs anyway (see sequencing below).
3. **Fund the people who already did the design.** A sponsorship targeting @asiekierka or
   @mysterymath to resume #320 → #321 is the highest-leverage spend — the design is done, the
   implementer is identified, the blocker is time, not knowledge.
4. **Implement codegen directly.** Start at [#320](https://github.com/llvm-mos/llvm-mos/issues/320)
   (the foundational 24-bit address-space layer, design already specified down to the five LLVM
   address spaces), then [#321](https://github.com/llvm-mos/llvm-mos/issues/321) stage 1 (xy16 +
   a8/a16 with a late REP/SEP pass, building on the
   [jackoalan POC](https://github.com/jackoalan/llvm-mos/commit/ec070a70ba8d8b3d3a9da24b4216435f9575f6bb)).
   Coordinate on the llvm-mos Discord first — the culture is code-first and ABI-decisions-follow-
   implementation, so a working branch carries far more weight than a spec proposal.

**Recommended sequencing — paths 2 and 4 are one track, not two phases.** "Land the cheap
intermediate then implement codegen" is a false dichotomy: the bulk of the cheap intermediate is
the SNES SDK target ([#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415)) and an
emulator/CI test loop — both **mandatory infrastructure for testing any codegen at all**, since you
can't validate a single far-pointer lowering rule until a target exists to emit into and run. The
only throwaway part is the *generated 8-bit code*, and that's free (the existing 6502 backend
writes it). The assembler subtarget already exists (`FeatureW65816` in `MOSDevices.td`). Concretely,
one track, three milestones:

- **M0 — toy + test bench (no new codegen).** Build the SNES SDK target (#415) + `SP = $01FF` crt0;
  boot a bank-0 C program in Mesen/bsnes on the existing 6502 backend. Proves boot/stack/SDK, stands
  up CI, and earns maintainer credibility (a running target beats a spec proposal). Days, not weeks.
- **M1 — the cheap intermediate, useful form.** M0 + **[#320](https://github.com/llvm-mos/llvm-mos/issues/320)**
  (24-bit far pointers, registers still 8-bit). Now it's a *working, multi-bank, unoptimized* 65816 C
  compiler — and your regression corpus. First real codegen, but the lower-risk foundational layer.
- **M2 — the optimizing payoff.** M1 + **[#321](https://github.com/llvm-mos/llvm-mos/issues/321) stage 1**
  (16-bit A via a late REP/SEP pass; X/Y fixed at 16-bit). Where the "optimizing" value lands. Later:
  hardware-stack ABI and #321 stage 2 (xy8).

#320 is shared by both framings and unavoidable, so it's the first real thing to build after the
bench. Jumping "straight to codegen" doesn't skip M0 — it just does M0's work blind, with no
regression baseline, so your first codegen test is also your first whole-toolchain integration test
(too many unknowns at once). Build the bench, ship M0/M1 validated against the 6502 backend, then
layer M2.

**Where to engage:** GitHub issues [#32](https://github.com/llvm-mos/llvm-mos/issues/32) (umbrella),
[#320](https://github.com/llvm-mos/llvm-mos/issues/320) / [#321](https://github.com/llvm-mos/llvm-mos/issues/321)
(the codegen work), [llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/issues/415) (the SNES
target / M0), and the llvm-mos Discord (where the substantive design discussion actually happens —
the Feb 2024 codegen breakdown originated there).

---

## Why this matters to drdevtools

`drmon` is a source-level debugger being brought to Linux; its value depends on there being
debuggable, symbol-rich C builds to point it at. The June-2026 alignment is notable: llvm-mos just
published its **DWARF specification** (Dec 2025) — the same debug-info format drmon's DAP/symbol
work targets. An optimizing open-source 65816 C compiler emitting DWARF would slot directly into
the drmon debugging story, closing the loop from *compile → optimized SNES ROM → DWARF symbols →
source-level debugging in drmon*, entirely on open tooling. The compiler is the one missing link;
everything downstream of it (debugger, symbol formats) is what drdevtools already builds.

---

## Open questions

1. **Calling convention.** Undecided in #320/#321. Does the team land on a PHD/TCD direct-page
   frame (Zardoz/WDC816CC/ORCA-C all did), a hardware-stack-relative frame (now viable per pillar
   c), or llvm-mos's soft static stack carried over from the 6502? The documented WDC816CC/ORCA-C
   ABI (Zardoz investigation) is the prior-art reference here.
2. **Will @asiekierka resume, or will someone else take #320/#321?** As of June 2026 there is no
   active implementer. This is the single gating fact.
3. **Does the cheap 8-bit-mode path (SP=$01FF) get built first?** It would let llvm-mos-sdk ship a
   SNES target immediately and create pull for the real codegen.

---

## Caveats

- This investigation reflects the public GitHub tracker as of 2026-06-13. Substantive design
  discussion happens on the llvm-mos Discord and is not fully mirrored to issues — the codegen
  decomposition (#32, 2024-02-26) was explicitly relayed from Discord. Discord was not read for
  this report.
- "No active implementer" is an inference from the absence of codegen PRs/branches touching #320 or
  #321 and @asiekierka's own "never did" statement; a private work-in-progress branch can't be
  ruled out.
- Effort/cost estimates are extrapolated from the maintainers' own statements about the 6502
  backend, not from a scoped engineering breakdown. No dollar figure is asserted.
</content>
</invoke>

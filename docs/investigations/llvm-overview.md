# LLVM — Description, Overview, and History

*Background note for this project. `llvm-mos-65816` builds on
[llvm-mos](https://github.com/llvm-mos/llvm-mos), a fork of LLVM that adds 6502-family
backends. This document explains what LLVM is, how it is structured, and where it came
from — the substrate everything else here sits on.*

---

## 1. What LLVM is

**LLVM** is a collection of modular, reusable compiler and toolchain technologies. Despite
the name, it is **not** a virtual machine in the Java/CLR sense, and the acronym ("Low Level
Virtual Machine") was officially dropped in 2011 — today **"LLVM" is just the name of the
project**, which has grown far past its original scope.

At its core, LLVM is built around a well-specified **intermediate representation (IR)**: a
typed, mostly-target-independent, SSA-form (Static Single Assignment) instruction set that
sits between a language front end and a machine back end. The defining design idea is the
**three-phase pipeline with a stable IR in the middle**:

```
┌─────────────┐      ┌──────────────────────────┐      ┌──────────────┐
│  Front end  │ ───▶ │   Optimizer (IR → IR)     │ ───▶ │   Back end   │
│ C/C++/Rust/ │  IR  │ target-independent passes │  IR  │ IR → machine │
│ Swift/...   │      │ (inlining, GVN, LICM, ...)│      │ code (ISel,  │
└─────────────┘      └──────────────────────────┘      │ regalloc,    │
                                                        │ emission)    │
                                                        └──────────────┘
```

Because the IR is the contract, any front end that emits LLVM IR automatically benefits from
**every** optimization pass, and gains **every** back end (target architecture) for free.
Conversely, adding a new target — as llvm-mos does for the 6502 and this project extends
toward the 65816 — makes that target available to *all* the languages that target LLVM.

### Key components

- **LLVM Core** — the IR, the optimization passes, and the code generators for many targets
  (x86, ARM/AArch64, RISC-V, PowerPC, WebAssembly, NVPTX, and out-of-tree targets like MOS).
- **Clang** — the C/C++/Objective-C front end. Fast, standards-conformant, with famously good
  diagnostics; the reference C/C++ compiler for Apple, much of the BSD world, and Android.
- **LLD** — the LLVM linker, a fast drop-in replacement for the system linker.
- **LLDB** — the debugger, sharing Clang's parsing and expression-evaluation machinery.
- **libc++ / libc++abi / compiler-rt** — the C++ standard library and low-level runtime
  (sanitizers, builtins, profiling).
- **MLIR** — a newer multi-level IR framework for domain-specific compilers (ML, HPC,
  hardware). Increasingly a peer to LLVM IR rather than a mere front end to it.
- **MC layer** — the machine-code layer that models instructions, encodings, relocations, and
  assembly/disassembly. (This is the layer `llvm-mos-65816` works in heavily — e.g. the
  `LDA/ADC_Immediate16` instruction definitions and `MLow` TSFlags noted in the #321 work.)

---

## 2. Why LLVM matters (the design payoff)

1. **Library-based, not monolithic.** LLVM was conceived as a set of libraries with clean
   APIs rather than a single `cc` binary. You can embed the optimizer in a JIT, build a custom
   back end, or reuse the register allocator in isolation. This is what makes a project like
   llvm-mos feasible at all: you bolt a new target onto an industrial-strength optimizer
   instead of writing one from scratch.

2. **A stable, typed IR.** The IR can be emitted as human-readable `.ll` text, dense bitcode
   `.bc`, or held in memory — all equivalent. This makes the compiler inspectable and
   testable at every stage (a property this project leans on constantly: "far const
   `0x7E1234` → `af 34 12 7e`" is exactly the kind of IR-to-machine-code assertion LLVM's
   structure enables).

3. **Permissive license.** Since 2019 LLVM uses the **Apache 2.0 license with an LLVM
   exception**, allowing it to be embedded in proprietary and open products alike. This drove
   adoption at Apple, Google, NVIDIA, ARM, Sony, and elsewhere.

4. **Retargetability via TableGen.** Targets describe their registers, instructions, calling
   conventions, and scheduling in **TableGen** (`.td`) files, which generate C++ at build
   time. Adding the 65816's 16-bit accumulator modes or new addressing modes is, in large
   part, a TableGen + selection-DAG/GlobalISel exercise rather than bespoke plumbing.

5. **Two instruction-selection frameworks.** The older **SelectionDAG** ISel and the newer
   **GlobalISel** (GISel) pipeline coexist. (This project's #321 increments are explicitly a
   *"GISel + regalloc"* effort — see the dual-width-accumulator plan.)

---

## 3. History

### Origins (2000–2003) — a research project at UIUC
LLVM began in **2000** as a research project by **Chris Lattner** (with advisor **Vikram
Adve**) at the **University of Illinois at Urbana-Champaign**. The goal was a modern,
SSA-based compilation framework supporting lifelong program analysis and transformation —
optimization not just at compile time but at link time, install time, and run time. The
foundational paper, *"LLVM: A Compilation Framework for Lifelong Program Analysis &
Transformation,"* appeared at **CGO 2004**. The first public release, **LLVM 1.0**, shipped
in **2003**.

### Apple and the rise of Clang (2005–2010)
**Apple hired Chris Lattner in 2005** and invested heavily in LLVM, initially using it for
OpenGL JIT compilation in Mac OS X. At the time the dominant open-source C compiler was
**GCC**, but GCC's monolithic architecture and GPLv3 licensing made it awkward for Apple's
tooling needs. Apple sponsored **Clang** — a new, modular, LLVM-native C/C++/Objective-C
front end — first released around **2007** and maturing through the late 2000s. Clang's
speed, low memory use, reusable libraries (powering IDEs, indexers, and refactoring tools),
and superior error messages drove rapid uptake.

### Mainstream dominance (2010s)
- LLVM/Clang became the **default system compiler on macOS, iOS, and the BSDs**, and the
  basis for Android's NDK toolchain.
- New languages were built **on LLVM from day one**: **Rust**, **Swift** (also created by
  Chris Lattner, announced 2014), **Julia**, **Kotlin/Native**, **Zig**, and many more.
- GPU and accelerator stacks adopted it: **NVIDIA's CUDA** (NVPTX back end), AMD's compute
  stack, and numerous ML compilers.
- The **LLVM Foundation** was established (2014) to steward the project.
- In **2019** the project **relicensed** from the old "UIUC/BSD-style" license to **Apache
  2.0 with the LLVM exception**, resolving long-standing concerns about patent grants and
  embedding.

### Monorepo and MLIR (2019–present)
- The project consolidated its many sub-repositories into a single **monorepo** (2019),
  simplifying cross-component development.
- **MLIR** (Multi-Level IR), originated at Google and contributed to LLVM, became a major new
  pillar — a framework for building reusable, composable IRs, heavily used in machine-learning
  and hardware-design compilers.
- LLVM moved to a roughly **6-month major-release cadence** (e.g. 17, 18, 19, 20...), with
  development on GitHub and governance via the LLVM Foundation and an elected board.

### LLVM and retro / 8-bit targets
Mainline LLVM targets modern 32/64-bit (and some 16-bit) architectures. Small **8-bit
microcontrollers and retro CPUs** were long considered a poor fit because of LLVM's
assumptions about register width, pointer size, and addressing. The **llvm-mos** project
challenged that: it is an out-of-tree (and increasingly capable) fork that adds **6502-family
back ends**, complete with a working C/C++ toolchain, an SDK, and platform support for
machines like the Commodore 64 and NES. **`llvm-mos-65816`** (this repo) extends that effort
toward the **WDC 65816** — the 16-bit superset of the 6502 found in the SNES and Apple IIGS —
exercising LLVM's retargetability at the far edge of what it was designed for (far/banked
pointers, a runtime-width accumulator, REP/SEP mode tracking).

---

## 4. Timeline at a glance

| Year | Milestone |
|------|-----------|
| 2000 | LLVM started by Chris Lattner & Vikram Adve at UIUC |
| 2003 | LLVM 1.0 released |
| 2004 | Foundational CGO paper published |
| 2005 | Apple hires Lattner; begins heavy investment |
| 2007 | Clang front end first released |
| 2011 | "Low Level Virtual Machine" name officially retired (now just "LLVM") |
| 2014 | LLVM Foundation formed; Swift announced (LLVM-based) |
| 2019 | Relicensed to Apache 2.0 + LLVM exception; monorepo consolidation; MLIR upstreamed |
| 2020s | ~6-month release cadence; MLIR ecosystem grows; out-of-tree targets like llvm-mos mature |

---

## 5. Glossary (terms used elsewhere in this repo)

- **IR** — Intermediate Representation; LLVM's typed, SSA-form instruction set.
- **SSA** — Static Single Assignment; each variable assigned exactly once, simplifying
  dataflow analysis.
- **Front end / back end** — language parser (→ IR) / target code generator (IR → machine code).
- **ISel** — Instruction Selection; mapping IR operations to target instructions. LLVM has
  **SelectionDAG** (older) and **GlobalISel** (newer); #321 uses GlobalISel.
- **MC layer** — Machine Code layer: instruction encodings, relocations, asm/disasm.
- **TableGen (`.td`)** — LLVM's declarative DSL for describing targets; generates C++ at build.
- **regalloc** — Register allocation; assigning virtual registers to physical ones.
- **compiler-rt / libc++** — runtime builtins + sanitizers / the C++ standard library.

---

## References

- LLVM project site: <https://llvm.org>
- Chris Lattner & Vikram Adve, *"LLVM: A Compilation Framework for Lifelong Program Analysis &
  Transformation,"* CGO 2004: <https://llvm.org/pubs/2004-01-30-CGO-LLVM.html>
- *The Architecture of Open Source Applications* — LLVM chapter by Chris Lattner:
  <https://aosabook.org/en/v1/llvm.html>
- LLVM language reference: <https://llvm.org/docs/LangRef.html>
- llvm-mos: <https://github.com/llvm-mos/llvm-mos>

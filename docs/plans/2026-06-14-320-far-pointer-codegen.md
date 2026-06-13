# M1 / #320 — Increment 1: far-pointer codegen (32-bit far), non-breaking, disassembly-verified

**Date:** 2026-06-14 · **Status:** In progress — step 1 (far address space) done + verified.
· **Milestone:** M1 (ROADMAP steps 3–4), first real 65816 codegen.
**Builds on:** [M1 Phase 0](2026-06-14-m1-from-source-toolchain.md) (from-source editable toolchain + corpus).

## Progress (2026-06-14)

- **Reproducible-codegen workflow established.** `vendor/llvm-mos` is gitignored, so backend edits are
  captured as a tracked patch `patches/llvm-mos/0001-320-far-addrspace.patch` (verified it applies
  cleanly to a pristine clone) and `dev/toolchain.sh` applies all `patches/llvm-mos/*.patch` after a
  fresh clone. The patch *is* the eventual upstream PR diff. Dev loop: edit `vendor/llvm-mos` →
  `dev/run.sh toolchain` (incremental relink) → regenerate the patch.
- **Correction: 32-bit far, not 24-bit.** LLVM requires power-of-two pointer sizes (asiekierka's "lie
  and claim 32-bit"), so addrspace 2 is **32-bit** (`p2:32:8`); only the low 24 bits are emitted as
  65816 absolute-long. (The body below still says "24-bit" in places — read as 32-bit.)
- **Finding: the data-layout string is duplicated in THREE places** that must stay byte-identical, or
  the build dies with *"backend data layout … does not match expected target description"*:
  `llvm/lib/Target/MOS/MOSTargetMachine.cpp` (backend), `clang/lib/Basic/Targets/MOS.cpp` (frontend),
  and `llvm/lib/TargetParser/TargetDataLayout.cpp` (the centralized `Triple::mos` source the base
  `CodeGenTargetMachineImpl` checks against). Also: changing the layout invalidates all old-layout
  bitcode, so the toolchain runtimes must be rebuilt — a **clean** toolchain rebuild, not incremental.
- **Step 1 done + verified (non-breaking):** `AS_Far=2` enum + `p2:32:8` in all three layouts. Clean
  toolchain rebuild + `MOS_TOOLCHAIN=…self build && corpus` → **corpus 7/7**: the far address space is
  inert for 6502 codegen. Next: step 2 (legalize the 32-bit far pointer) → step 3 (`case 32` →
  `LDA/STA AbsoluteLong`).

## Context

[#320](https://github.com/llvm-mos/llvm-mos/issues/320) (24-bit address space / far pointers) is the
first *real* 65816 codegen — the part the design owner scoped but never implemented. Exploration of
the now-vendored backend (`vendor/llvm-mos/llvm/lib/Target/MOS`) found the decisive fact: **the entire
65816 instruction set + addressing modes already exist at the MC/assembler layer** —
`LDA_AbsoluteLong`/`STA_AbsoluteLong` (24-bit, `MOSInstrFormats.td:361-419` + `MOSInstrInfo.td:674-790`),
`JSL`/`RTL`, `IndirectLong` `[dp]`, `Addr24*` fixups, zero-bank relaxation — all gated on
`FeatureW65816`. **But no codegen uses any of it**: GlobalISel only emits 16-bit absolute, which the
assembler relaxes. So #320 is *wiring GISel to existing MC instructions for a new wide pointer type*,
not building instructions from scratch.

This increment lands the **smallest real far-pointer codegen**, **non-breaking** (6502 untouched,
gated on `W65816`), verified at the **disassembly level** (ROADMAP step 4: "near→`JSR`, far→`JSL`;
addrspace→addressing-mode"). Per the [roadmap](../ROADMAP.md)'s **code-first** strategy ("maintainers
bless ABI decisions only behind a running implementation"), this minimal running slice becomes the
artifact that anchors the upstream #320 design discussion — rather than designing in the abstract first.

## Key findings (from backend exploration)

- Data layout is **fixed** at module level (`MOSTargetMachine.cpp:75`): `…-p:16:8-p1:8:8-…` →
  addrspace 0 = 16-bit (absolute), addrspace 1 = 8-bit (zero/direct page). The TM ctor *does* receive
  `CPU`/`FS` (`:87-96`), so a feature-conditional layout is *possible* but a non-trivial change.
- `MOSLegalizerInfo.cpp:1670 selectAddressingMode` switches on pointer size: `case 8` (zp),
  `case 16` (abs/indirect), `default: llvm_unreachable`. **This is the linchpin** — far pointers add a
  `case 24`.
- Address spaces are an enum at `MOSInstrInfo.h:155` (`AS_Memory=0, AS_ZeroPage=1`). Section routing
  by addrspace at `MOSTargetObjectFile.cpp:31-52`. GISel load/store pseudos at `MOSInstrGISel.td`
  (`G_LOAD_ABS`, `G_LOAD_INDIR`, …; already `Predicates`-gated — e.g. `G_LOAD_INDIR` is `[Has65C02]`).
- 16-bit pointer width is hardcoded in several spots (`MOSCallLowering.cpp`, `MOSIndexIV.cpp:66`,
  `MOSInstructionSelector.cpp:1838`) — these must be *guarded*, not broken, so the far path is additive.
- All codegen is GlobalISel (`setGlobalISel(true)`, abort-on-fallback) — work lives in the Legalizer
  + InstructionSelector + `*GISel.td`, not SelectionDAG.

## Design decision — additive 24-bit far space (Option A), not asiekierka's default-far (Option B)

- **Option A (recommended, this increment):** keep addrspace 0 = 16-bit (6502 default *untouched*);
  **add addrspace 2 = 24-bit "far"**, reached only via an explicit far qualifier
  (`__attribute__((address_space(2)))`), legalized + selected **only under `W65816`**. Add `p2:24:8`
  to the fixed data-layout string (inert for 6502 — nothing creates addrspace-2 pointers). No TM
  redesign. Minimal, non-breaking, testable now.
- **Option B (deferred, upstream-gated):** asiekierka's full five-space model with addrspace 0 =
  **32-bit far as the default** for 65816 — requires a feature-conditional data layout (TM change) and
  is a module-wide ABI decision. That's exactly what needs maintainer blessing; Option A's running
  slice is the evidence that informs it.

Numbering note: asiekierka uses `2`=16-bit-absolute, `3`=24-bit-packed. We use `2`=24-bit far here for
the minimal slice; the final numbering is reconciled with upstream in the Option-B design. Flag this
in the upstream note so it's a conscious divergence, not an accident.

## Changes (additive, all gated on `W65816`)

| File | Change |
|------|--------|
| `MOSInstrInfo.h:155` | add `AS_Far24 = 2` to the AddressSpace enum |
| `MOSTargetMachine.cpp:75` | append `-p2:24:8` to the data-layout string (inert without addrspace-2 ptrs) |
| `MOSLegalizerInfo.cpp` | declare `LLT::pointer(2, 24)` legal; load/store legalization for 24-bit ptrs (lower to 8-bit ×3); **`case 24:` in `selectAddressingMode` (:1670)** → far addressing |
| `MOSInstrGISel.td` | new far pseudos `G_LOAD_FAR_ABS` / `G_STORE_FAR_ABS` (+ indirect-long variants), `Predicates=[HasW65816]` |
| `MOSInstructionSelector.cpp` | select the far pseudos → `MOS::LDA_AbsoluteLong` / `STA_AbsoluteLong` (and `*_IndirectLong`) — the MC instrs already exist |
| `MOSISelLowering.cpp:87` | `getRegisterTypeForCallingConv`: 24-bit far ptr → `MVT::i24`/3×i8 |
| `MOSTargetObjectFile.cpp:31` | route addrspace-2 globals to a `.far.*` section (later increment if not needed yet) |
| `MOSCallLowering.cpp`, `MOSIndexIV.cpp:66`, `MOSZeroPageAlloc.cpp` | **guard** the hardcoded 16-bit/zp assumptions so far ptrs are excluded (no 6502 behaviour change) |

## Implementation steps (iterate via the Phase-0 from-source toolchain: edit → `dev/run.sh toolchain` (incremental relink) → test)

1. **Enum + data layout** (`AS_Far24`, `p2:24:8`). Rebuild; confirm the 6502 corpus is still 7/7 (the
   added addrspace spec is inert) — regression guard.
2. **Legalizer**: make `LLT::pointer(2,24)` legal + load/store lowering for it.
3. **`selectAddressingMode` `case 24`** + far GISel pseudos + InstructionSelector patterns → the
   existing `*_AbsoluteLong` MC instrs.
4. **Calling-conv / guards** for the hardcoded-16-bit spots (additive, feature-gated).
5. **Test artifact**: a tiny C function dereferencing a `__attribute__((address_space(2)))` pointer
   (load + store), compiled `-mcpu=mosw65816`.

## Verification (compiler-only — no emulator/native-mode bench needed this increment)

1. **6502 unaffected** — full corpus still 7/7 on both prebuilt and from-source toolchains (the new
   addrspace is inert). (Evidence: corpus table.)
2. **Far load/store lowers correctly (the deliverable)** — compile the address-space-2 test
   `-mcpu=mosw65816`, then `llvm-objdump -d` the object shows **`lda $xxxxxx` / `sta $xxxxxx`
   (absolute-long, 4-byte)** — not 16-bit absolute — for the far accesses. (Evidence: disasm excerpt.)
   This is ROADMAP step 4 ("addrspace → addressing mode").
3. **Near vs far** — a 16-bit (addrspace 0) access in the same program still emits 16-bit absolute;
   only the addrspace-2 access goes long. (Evidence: side-by-side disasm.)
4. **`-verify-machineinstrs` / no GISel fallback abort** on the test. (Evidence: clean compile.)

## Risks

- **Large GISel surface, iterative.** Real backend work; expect several edit→rebuild→inspect cycles.
  The from-source toolchain makes each iteration an incremental relink (minutes via ccache), not a
  full build. Cap to disassembly-level correctness this increment.
- **Addrspace numbering diverges from asiekierka's #320.** Conscious, documented; reconciled in the
  upstream Option-B design note. The point of Option A is a running slice, not the final ABI.
- **No end-to-end emulator run yet.** A true run needs 65816 *native mode* (crt0 `XCE` + DBR setup,
  register widths) and a multi-bank ROM — both substantial bench changes. **Deferred to Increment 2.**
  Disassembly verification is the honest bar for Increment 1.
- **Upstream may want Option B numbering/shape.** That's why this stays minimal + feature-gated and we
  open the #320 discussion with the running slice in hand before building the full five-space model.

## Out of scope (later increments / milestones)

- 65816 **native-mode crt0** + multi-bank ROM + emulator end-to-end run of far pointers (Increment 2;
  ROADMAP step 3).
- The full **five-address-space** model / 32-bit-default (Option B), packed 24-bit, zero-bank, abs-16
  — after upstream ABI blessing.
- **16-bit registers / REP-SEP** ([#321](https://github.com/llvm-mos/llvm-mos/issues/321)) and the
  **hardware-stack ABI** — M2.
- Upstream PR — opens after the running slice + design note land and the maintainers weigh in.

# #321 native-width upstream PR blueprint

<!-- CURRENT DECISION (2026-08-03): LOCAL ONLY. Do not post without a new user instruction. -->

## Status

There is no upstream pull request for `patches/llvm-mos/0002-321-accum16.patch`. GitHub #321 is the
tracking issue. The open PRs #577, #578, #579, and #584 are independent focused changes; `0002` must
not be folded into any of them.

For now, keep developing and regenerating the complete native-width implementation as holistic
patch `0002`. The interrupt-width fix and its LLVM regression belong there. Do not update GitHub or
wald3n.com until the user explicitly chooses to post the draft PR.

## Proposed title

`[MOS][65816] Add opt-in native accumulator and index-register widths`

Avoid “first stage.” The current patch implements both accumulator and index-register modes,
cross-block M/X tracking, ABI boundaries, and asynchronous interrupt entry preservation.

## Proposed opening

> Implements the native 65816 register-width support tracked by #321, including opt-in accumulator
> and index-register modes, cross-block M/X state tracking, ABI boundaries, and interrupt-state
> preservation.

## Review structure

`0002` is the canonical local aggregate, not the desired review history. Before posting, reorganize
its current backend and test changes into a coherent commit series such as:

1. Model native accumulator/index registers and feature gates.
2. Add native-width instruction forms, legalization, and selection.
3. Add post-RA M/X state tracking and `REP`/`SEP` placement.
4. Define call, return, spill, and frame behavior.
5. Preserve unknown incoming M/X state across interrupt handlers.
6. Add focused LLVM coverage and native-width correctness tests.

The commits may be reviewed independently, but the intended upstream vehicle is one draft PR with
one complete feature narrative. Do not present the ISR fix as an unrelated standalone correction:
upstream main does not yet contain the native-width machinery that exposes it.

## Extraction audit: `0002` is not the PR diff

The current 6,154-line/34-file patch round-trips the live fork correctly, but it was generated from
a shared MOS backend tree and contains #320/far-pointer work in addition to #321 native-width work.
It must not be pushed verbatim or merely divided at file boundaries.

Explicit cross-series content appears in at least these files:

- `MCTargetDesc/MOSAsmBackend.cpp` — #320 bank relaxation;
- `MOSAsmPrinter.cpp` — packed-24 constants;
- `MOSCallLowering.cpp`, `MOSCallingConv.cpp`, `MOSCallingConv.h`, and `MOSCallingConv.td` — far-pointer
  calling conventions;
- `MOSFeatures.td` and `MOSSubtarget.h` — far-CC feature selection mixed with native-width features;
- `MOSISelLowering.cpp`, `MOSISelLowering.h`, `MOSInstrInfo.h`, and `MOSTargetMachine.cpp` — far/packed
  address-space representation;
- `MOSLegalizerInfo.cpp` and `MOSLegalizerInfo.h` — both native-width legalization and substantial
  far/packed-pointer legalization;
- `MOSRegisterBanks.td` and `MOSZeroPageAlloc.cpp` — Imag32 far-pointer register/allocation support.

Several of these are genuinely shared files, so extraction is hunk-level. Build the eventual PR
series from a fresh upstream worktree plus only explicitly accepted dependencies, then transplant
the #321 hunks commit by commit. Compare the reconstructed result against the native-width behavior
of the live fork; do not use equality with aggregate `0002` as the purity criterion because the
aggregate intentionally includes the cross-series material above.

The clean series should contain the native-width feature gates, register/instruction definitions,
legalization/selection, `MOSInsertREPSEP`, native ABI/frame behavior, accumulator residency, and
the ISR regression. It should exclude far address spaces, packed pointers, far calling conventions,
bank relaxation, and unrelated standalone bug fixes unless an upstream base dependency makes one
unavoidably explicit.

## Interrupt evidence

Round 7 ROM #123 exposed that a hardware interrupt inherits the interrupted M/X flags while the old
C ISR prologue assumed M8/X8. `MOSFrameLowering` now saves full A/X/Y at deterministic M16/X16,
establishes M8/X8 for the generated body, restores at M16/X16, and lets `RTI` restore stacked P.

- LLVM regression: `llvm/test/CodeGen/MOS/interrupt-width-65816.ll`
- Runtime: host == default == a16 == xy16 == `0xDA3B`
- Determinism: three repeated a16 runs agree
- Runnable ROM and explanation: <https://biohack.net/snes/nmitally/>

## Posting gates

Before creating the draft PR:

- regenerate `0002` and pass its round-trip verification;
- build the affected LLVM tools and run the focused/native-width test set;
- confirm default 8-bit behavior remains unchanged;
- prepare the review commit series without unrelated standalone patches;
- audit the reconstructed diff for `#320`, `AS_Far`, `AS_FarPacked`, and `FarCC` residue;
- rebase onto the chosen upstream base and record any dependency on #320 explicitly;
- ensure the PR body describes the complete implementation and links issue #321 and the demo.

After posting, record the PR URL and head SHA in `docs/upstream-contribution-status.md`, then refresh
wald3n.com's contributions snapshot. Until a real PR URL exists, wald3n.com remains intentionally
unchanged.

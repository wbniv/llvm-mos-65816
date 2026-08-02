# Compiler defects the SNES demo battery has exposed

**What this is.** The demo battery exists to find compiler bugs — the ROMs are the instrument, not
the product. This is the consolidated scoreboard: every backend/toolchain defect a demo or its gate
has surfaced, what it was, and where it ended up. Per-round narrative lives in
[the ideas doc](2026-06-27-compiler-stress-test-demo-ideas.md); the upstream paperwork and its
current state live in [upstream-contribution-status.md](../upstream-contribution-status.md) — this
page is the index that ties a *demo* to a *defect*.

**Last updated:** 2026-08-02.

## Scoreboard

| # | Defect | Found by | Class | Where it ended up |
|---|---|---|---|---|
| 1 | **`combineLdImm` null-pointer store** — `mos-late-opt` stores through a null `ImmLoad*` for any `LDImm` whose destination is not A/X/Y. Legal on SPC700 (`getRegClass` widens the def class to `Anyi8`), so 7 lines of ordinary C crash pristine upstream. | #138 LZSS-gallery far-decode investigation (reached it via a 32-bit imaginary destination) | hard crash, upstream | **[PR #584](https://github.com/llvm-mos/llvm-mos/pull/584)** — posted, CI green ×3, later hardened (aliasing-safe invalidation + sibling `TA` handler) |
| 2 | **`MOSZeroPageAlloc` non-determinism** — zero-page winners chosen in heap-address order (`DenseMap` iteration + `stable_sort` tie-break), so identical sources produced two different ROMs ~50/50. | lzss-gallery reproducible-build check | silent build non-determinism, upstream | fixed (`DenseMap`→`MapVector` ×2, `SmallSet`→`SmallSetVector`), verified 20/20 one hash; **package READY TO POST** (status row 17) |
| 3 | **`lowerCmpZeros` skips lowering after the block's first fold** — a surviving `CmpZero` pseudo is legal MIR, so the verifier is silent and the asm printer emits **nothing**: the flag test vanishes. | filed in passing by the #138 Phase-A read of `MOSLateOptimization`; repro built 2026-08-02 | silent dropped instruction, upstream | fixed (per-`CmpZero` `Folded` flag), reproduces on pristine upstream; **package READY TO POST** (status row 18, patch `0022`) |
| 4 | **`PH $p` reads an undefined physical register** — the fork's `saveScavengerRegister` decided the `undef` flag with a *reaching-definition* scan while the verifier tracks *forward availability*; dead-flagged `$c` defs opened the gap. | seamdemo P1's gate (it runs `-verify-machineinstrs`; `dev/seqvm.sh` never did, which is why it hid) | verifier reject, fork-only | fixed (`hasNoAvailableValue` on `LivePhysRegs`), folded into `0002` + the unposted `0011` package; 253/254 objects byte-identical, the one delta 4 B smaller |
| 5 | **`rc-undef` cause #2, second manifestation** — an `undef %N.sublo:imag16` chain's high lane is read after RA; the `undef` flag is lost when the pair-COPY's high-lane copy is elided. The new instance **feeds a store** rather than being a dead read. | `seqvm.c draw_frame` under `+mos-a16 -O1/-O2/-Os` | verifier reject, code-correct | evidence appended to the existing upstream issue (status row 13); toolchain-wide fix still filed, not attempted |
| 6 | **`$rl1 = LDImm` malformed producer** — an `Imag32` (far-pointer) destination on a GPR-only opcode, emitted into `@unpack_slide`. | lzss-gallery far decode (this is what crashed into defect #1) | malformed MIR, fork | fixed by `0018-320-imag32-spill` (far-pointer stack slots were split through a single GPR); a **standing gate** now asserts every `LDImm` destination is a GPR, because #1's guard would now skip a returning producer silently |
| 7 | **DEFAULT-8-bit matrix-fold miscompile** | Mandelbrot zoom-pyramid demo (since retired) | silent miscompile | fixed (patch `0010`); upstream repro is the self-contained `coalesce-rotate-ac.mir` lit test |
| 8 | **`+mos-xy16` in-place memmove miscompile** | demo #23 | silent miscompile | fixed in-flight during Round 2 |
| 9 | **`G_UNMERGE_VALUES` legalizer gap** (`+mos-a16`/`+mos-xy16`, s64 arithmetic) | Round-4 demo (#61 DH 64-bit modexp surfaced the s64↔s16 level) | compile abort | fixed; folded into the `0002` series (status row 14 — series content, not a standalone PR) |
| 10 | **Round-3 legalizer bug** | Round-3 demo | compile abort | fixed |
| 11 | **`setjmp`/`longjmp` scoped break** | the setjmp demo | broken runtime behaviour | fixed 2026-07-02 (`platforms/snes/setjmp.S`) |
| 12 | **`LDCImm` set-lowering assert** — `MOSMCInstLower` lowered only `0`/`-1`; a *set* i1 carry arrives as `1` from a 16-bit `SBC`. | surfaced while validating the scavenger fix (compilation reached MC lowering once the scavenger stopped crashing) | assert / release-mode UB | fixed (`0012`); status row 10 |
| 13 | **DP-pointer-argument CC crash** — `addrspace(1)` 8-bit pointer *argument* got a 16-bit register. | #320 far-value work | backend crash | **merged upstream** ([#563](https://github.com/llvm-mos/llvm-mos/pull/563), status row 8) |
| 14 | **`mos-late-opt` TYX/TXY dead-flag** | #321 F4 work | wrong flag state | **merged upstream** ([#562](https://github.com/llvm-mos/llvm-mos/pull/562), status row 1) |
| 15 | **`coalesce-rc-undef`** — call-clobbered `$rcN` coalesced into a pair across the clobber. | corpus under register pressure | verifier reject, latent hazard | fixed (`0015`); status row 12 |
| 16 | **`coalesce-rotate-Ac`** — rotate value coalesced into the A-only `Ac` class. | Round-6 re-stress | **silent miscompile** | fix posted ([#578](https://github.com/llvm-mos/llvm-mos/pull/578)); the underlying RA behaviour filed as a companion issue (row 16) |
| 17 | **`G_SCMP`/`G_UCMP` legalization** | corpus | compile gap | fix posted ([#577](https://github.com/llvm-mos/llvm-mos/pull/577)) |

## Non-defects worth remembering

Two loud scares that turned out **not** to be compiler bugs, both refuted by instrumented
experiment rather than argument — the discipline is the point:

- **The "LTO + `+mos-a16` bitmask-loop early exit" miscompile** (status row 11, RETRACTED): the
  suspicious `cmp #$10` was the loop's own `UPQ_MAX_JOBS` guard. Overriding the macro moved the
  constant, which settled it.
- **Demo #83's "ZP-allocation miscompile"**: refuted by a rebuilt debug toolchain; the fault was in
  the demo's own expectations.

Also from 2026-08-02, not a compiler defect but a real trap: **this assembler sizes immediates by
the literal's magnitude, not the `M` flag** — `and #$00ff` in 16-bit mode assembles as 2 bytes and
the CPU eats the following opcode as the operand's high byte. Caught by disassembly during the
keyframe specialization.

## What the pattern says

- **Gates only catch what they assert.** Four separate defects here were invisible to a passing
  gate: #3 and #6 because a legal-but-wrong MIR shape has no diagnostic, #4 because `dev/seqvm.sh`
  never ran `-verify-machineinstrs`, and the cartsize canary's entropy check because a stale
  `jgxcheck` gave it nothing to compare. Every fix in this table that could regress silently now
  has an assertion that would fail loudly.
- **The productive demos are the ones that hit untested corners** — far pointers, 64-bit libcalls,
  register pressure, indirect control flow — not the visually impressive ones.
- **Verifier-clean is not miscompile-free, and verifier-noisy is not always a miscompile.** Items
  #5 and #15 are code-correct; #7, #8 and #16 were silent wrong-code with green screens.

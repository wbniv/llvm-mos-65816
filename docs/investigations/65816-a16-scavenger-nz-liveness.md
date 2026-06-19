# `+mos-a16` register-scavenger crash: N/Z live at a frame-vreg spill point

**Status:** root-caused + asserts-confirmed; **XFAIL'd**, fix deferred (pristine-upstream bug).
**Date:** 2026-06-18 · **Issue:** #321, ROADMAP M2.
**Repro:** `examples/65816/a16scavnz.c` (delta-debugged from fuzz seed-306).
**Family:** 8/500 fuzz seeds — 169, 173, 196, 268, 271, 272, 306, 420.

## Symptom

`+mos-a16` at `-O1`/`-Os` crashes the compiler. Under `-verify-machineinstrs` (what the
differential fuzzer uses) the Release toolchain reports:

```
*** Bad machine code: Using an undefined physical register ***
- instruction: PH $p
*** Bad machine code: Illegal physical register for instruction ***
- instruction: $rc17 = STImag8 $p
$p is not a GPR register.
- instruction: $p = LDImag8 $rc17
$p is not a GPR register.
fatal error: error in backend: Found N machine code errors.
```

DEFAULT 8-bit `-Os` and `+mos-a16 -O0` both compile clean. The corpus never caught it because
the corpus is built default 8-bit (never `+mos-a16`), and the shape needs `-O1`/`-Os` pressure.

> **Superseded 2026-06-19:** a `+mos-a16` corpus now exists (the `corpus-a16` differential gate,
> [`c998d7f`](https://github.com/wbniv/llvm-mos-65816/commit/c998d7f)) — so the "corpus is 8-bit"
> reason is no longer the operative one. This crash is **fuzzer-only**: it is a fuzz-generated
> scavenge-under-live-N/Z shape (8/500 seeds), not a corpus program, so `corpus-a16` still doesn't
> exercise it. The corpus's one `+mos-a16` casualty is the *separate* `globals.c` RA failure
> ([`65816-a16-regalloc-pressure-failure.md`](65816-a16-regalloc-pressure-failure.md)).

## Root cause (asserts-confirmed)

The crash is in the **register scavenger**, when `scavengeFrameVirtualRegs` must spill a register
to materialize a frame index. `MOSRegisterInfo::saveScavengerRegister`
(`vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp`) opens with:

```cpp
// Note: NZ cannot be live at this point, since virtual registers are never
// inserted into CmpBr instructions.
assertNZDeadAt(MBB, I);
assertNZDeadAt(MBB, UseMI);
```

i.e. it **assumes the N/Z processor-status flags are dead** at every scavenging point (the spill
sequence — and the `P`-register save path below it — clobbers the flags). Under `+mos-a16` that
assumption is **false**: a 16-bit compare / ALU op holds **N (or Z) live** across a point where a
frame-index virtual register must be scavenged. Downstream, for `Reg == MOS::P` with an unbalanced
hard-stack range (`pushPullBalanced` false), the same function falls through to
`STImag8 {Save}, {P}` / `LDImag8 {P}, {Save}` — illegal, since `P` is not a GPR.

**Confirmed via an isolated asserts build** (`dev/run.sh asserts-build` →
`build/llvm-mos-asserts-install`; `Release + LLVM_ENABLE_ASSERTIONS=On`). Compiling
`a16scavnz.c` (or seed-306) `+mos-a16 -Os` with it aborts *earlier* than the verifier, at the
precondition itself:

```
MOSRegisterInfo.cpp:157: assertNZDeadAt(...): Assertion
  `!LiveRegs.contains(MOS::N) && "expected N to be free when saving scavenger register"' failed.
  #10 MOSRegisterInfo::saveScavengerRegister(...)
  #11 RegScavenger::spill(...)
  #12 RegScavenger::scavengeRegisterBackwards(...)
  #15 scavengeFrameVirtualRegs(...)
```

So the `$p is not a GPR register` verifier error in the Release build is the *downstream* symptom;
the *primary* invariant violated is **N/Z must be dead at the scavenging point**, broken by a16's
longer flag live ranges.

## It is pristine UPSTREAM llvm-mos, not #321 code

`saveScavengerRegister` / `assertNZDeadAt` / `pushPullBalanced` are **not** in
`patches/llvm-mos/0002-321-accum16.patch` (`grep -c` = 0). The `+mos-a16` work doesn't touch the
scavenger; it merely creates the flag-liveness + register pressure (16-bit ADC carry chains, 16-bit
compares) that violates the upstream precondition. In principle a sufficiently flag-heavy DEFAULT
8-bit program could hit it too.

## Why a16 triggers it

`+mos-a16` 16-bit compares/ALU produce N/Z results that live longer (a 16-bit `>=`/`!=`/`+` whose
flag result is consumed after intervening 16-bit work), and recursion + many 16-bit values live
across a self-call drive `scavengeFrameVirtualRegs` to spill exactly where a flag is still live.

## Fix options (deferred — mirrors the `globals.c` RA bug)

1. **a16-side:** ensure the 16-bit compare/ALU pseudos don't leave N/Z live across a frame-index
   materialization point (kill/recompute flags earlier). Narrow but needs care that it doesn't
   pessimize the common a16 path.
2. **Upstream-side (`saveScavengerRegister`):** save/restore N/Z (and P) around the scavenger spill
   via `PHP`/`PLP` instead of asserting them dead. The general fix; touches the upstream scavenger
   contract and is regression-sensitive across all MOS subtargets.

Both are deep and regression-sensitive — the same class as the deferred `globals.c` RA failure
([investigation](65816-a16-regalloc-pressure-failure.md)). The ZP-pressure baseline shows real code
is slack (no pool exhaustion in 13 real functions), so this is **pathological**. Holding state:
XFAIL + deterministic repro, like `globals.c`.

### Feasibility re-probe (2026-06-19) — why neither option is a drop-in

Re-confirmed live (host `+mos-a16 -Os -verify` still emits `PH $p` / `STImag8 $p`) and probed both
fixes against `saveScavengerRegister` (`MOSRegisterInfo.cpp`) + the repro's pre-PEI MIR:

- **Option 2 is *not* a simple `PHP`/`PLP` bracket.** `P` has **no GPR spill home** (`STImag8`/`LDImag8`
  are GPR-only; the illegal-`$p` symptom is exactly this fallthrough), so it can only be saved on the
  hard stack. But `PHP`@`I` … `PLP`@`UseMI` only restores correctly when the intervening range is
  **push/pull-balanced** (`pushPullBalanced`); under a16 the scavenge lands inside an *unbalanced* range
  (the soft-stack `STStk`/`LDStk` spill run around the self-call), so the `PLP` would pop the wrong byte.
  A correct upstream fix would need a **stack-relative restore** of the saved P (not a plain `PLP`), or
  to teach the scavenger to choose a flag-safe spill point — both touch the upstream scavenger contract
  across all MOS subtargets.
- **Option 1 bottoms out in the `globals.c` core.** The live N/Z is a genuine 16-bit-compare result
  consumed after intervening 16-bit work; the scavenge for the frame-index scratch (`$rs*`) falls in that
  gap. Removing the liveness-across-scavenge is a register-pressure/scheduling problem identical to the
  deferred `globals.c` RA failure — not a localized flag-kill.

**Verdict: no narrow, low-risk fork-side fix.** Deferral stands; the genuine unblock is the **upstream
issue** ([draft](../321-upstream-scavenger-nz-issue.md), user-triggered posting) — reevaluate alongside
`globals.c` at M2 wrap-up.

## Disposition

- **XFAIL'd:** `tools/a16_fuzz.py` `KNOWN_ISSUES` entry `scavenger-p-not-gpr` (matches
  `"$p is not a GPR register"`) — the 8 seeds now classify as known-issue, not raw crashes.
- **Repro:** `examples/65816/a16scavnz.c` (verify-crashes `+mos-a16 -Os`; clean default + `-O0`).
- **Asserts build:** `dev/asserts-build.sh` (reusable; the diagnostic that pinned this).
- **Upstream:** drafted in [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md)
  (user-triggered posting). When fixed upstream/locally: drop the `KNOWN_ISSUES` entry and promote
  `a16scavnz.c` to a positive gate.

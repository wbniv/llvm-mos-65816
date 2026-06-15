# #321 native s16 — fix the compare-result-as-value `SelectImm` crash (F3)

**Date:** 2026-06-16
**Status:** open (next pass)
**ROADMAP:** step 5 (M2) · **TODO:** M2 "16-bit comparison follow-ups" item (c)
**Predecessor:** [Tier-1 corpus plan](2026-06-15-321-tier1-broaden-corpus.md) (this is its finding **F3**)

## Goal

Make the Tier-1 differential fuzzer go **fully green** — `dev/run.sh fuzz 50 1` → **50/50 PASS, 0 xfail**
(today 42/50 PASS + **8 xfail**, all the `cmp-value-selectimm` known issue). Concretely: a 16-bit
compare whose boolean result is consumed as a **cross-block i1 value** (a stored bool / `G_SELECT` / PHI
under branchy control flow) must stop emitting invalid MIR, on both emulators, with correct values.

## The bug (root-caused in the Tier-1 pass)

Under `+mos-a16`, a 16-bit compare result used as a VALUE (not a branch) materializes via
`SelectImm $a16, -1, 0` (or `SelectImm $y, -1, 0`) — a GPR where the `SelectImm` pseudo requires a
**Flag** (`Cc`/`NZ`) register operand:

```
*** Bad machine code: Illegal physical register for instruction ***
- instruction: $x = SelectImm $a16, -1, 0
$a16 is not a Flag register.
fatal error: error in backend: Found 2 machine code errors.
```

`-verify-machineinstrs` reports it; a normal build **segfaults** in link-time codegen. The default
(non-`+mos-a16`) build of the same source is clean.

**Why:** in `MOSLegalizerInfo.cpp::legalizeICmp` the s16 **ordering** native gate has no guard on how
the result is used, unlike the s16 **equality** gate immediately above it:

- `MOSLegalizerInfo.cpp:1361` `NativeS16EqBranch` — keeps an s16 `ICMP_EQ` native **only when every use
  is `G_BRCOND_IMM`** (the Z flag must fuse into a terminator).
- `MOSLegalizerInfo.cpp:1366` `NativeS16` — keeps an s16 `ICMP_UGE` native **unconditionally** (the
  comment claims "ordering-as-value already goes native, as C is a plain i1" — that assumption is what
  the fuzzer disproved). `ICMP_SLT` reaches this via the `SLT → ULT` sign-flip rewrite at
  `MOSLegalizerInfo.cpp:1311`, and `ULT` canonicalizes to `UGE`.

So an ordering compare feeding a `G_SELECT`/PHI stays native, and the C-flag i1 is mis-selected into
`SelectImm <GPR>`. A prior attempt (2026-06-15, reverted; see the comment at `MOSLegalizerInfo.cpp:1357`)
tried to fold the s16 compare back to native through `buildNZSelect` (`:1267`) → `G_SELECT` and it did
**not** work — the value path narrows in the select lowering.

**Minimal repro (committed):** `examples/65816/known/a16-cmp-value-selectimm.c` (delta-reduced from
fuzz seed 1). Bare `r = (a == b)` does NOT trigger it; the branchy CFG that turns the result into a
cross-block value does. The 8 fuzz seeds that XFAIL today: **1, 7, 9, 11, 22, 35, 41, 44**.

## Approach (two candidates — try A first)

### A — conservative: narrow ordering-as-value to the 8-bit chain (correctness-first)

Mirror the equality guard onto the ordering path: keep an s16 `UGE` (and the `SLT → ULT` rewrite)
native **only when every use is `G_BRCOND_IMM`**; otherwise fall back to the existing 8-bit byte-compare
narrowing (the default path, which correctly produces an i1 in a GPR — no `SelectImm <GPR>`). Touch:

- `MOSLegalizerInfo.cpp:1366` — gate `NativeS16` for `UGE` on the same `all_of(use_instructions(Dst),
  … == G_BRCOND_IMM)` predicate used by `NativeS16EqBranch` (1361). Factor the predicate into a helper.
- `MOSLegalizerInfo.cpp:1311` — the `SLT → ULT` sign-flip rewrite: only fire it when all uses are
  branches too, so an `SLT`-as-value narrows directly via the default signed path instead of emitting
  the `eor #$8000` XORs and then narrowing the `ULT`. (If leaving it unguarded still produces correct
  code — XOR'd operands through the 8-bit chain — that's acceptable; verify either way.)

Trade-off: a compare whose result is a value (rare — the micro-tests all branch on their compares)
regresses to 8-bit. **Correctness over optimization** — this kills the crash and is the safe landing.
Watch the `SelectImm $y` variant in the repro: confirm it also comes from the s16 path (so the guard
fixes it) and not a separate 8-bit select issue; if separate, investigate that path too.

### B — optimal (harder, optional follow-up): materialize the flag into a value natively

Keep ordering/equality-as-value native by lowering the s16 compare's C/Z flag to a 0/1 value correctly
— either a `SelectImm` that reads the real **flag** register (not the accumulator), or a
compare→branch→`0/1` materialization at selection. This is what the reverted 2026-06-15 attempt was
reaching for; only pursue it after A lands green, and keep it gated/reversible.

## Verification

1. `examples/65816/known/a16-cmp-value-selectimm.c` compiles clean under
   `-mllvm -verify-machineinstrs` (was: 2 machine-code errors) and the default build stays clean.
2. **Promote it to a passing regression test:** compute its host-expected `corpus_result`, add
   `dev/a16cmpval.sh` (`diff_check a16cmpval 0x…`) + move the `.c` out of `examples/65816/known/` (or add
   a fresh compare-as-value test), asserting `host == default == +mos-a16` on MAME + bsnes-jg.
3. **De-XFAIL the fuzzer:** remove the `cmp-value-selectimm` entry from `KNOWN_ISSUES` in
   `tools/a16_fuzz.py` so a re-crash FAILS (not silently XFAILs). Then `dev/run.sh fuzz 50 1` →
   **50/50 PASS, 0 xfail, 0 mismatch/crash/error** (run on a quiet box — concurrent docker/MAME load
   flakes the settle window). Spot-check a couple of the formerly-XFAIL seeds (1, 7, …) individually.
4. **Non-breaking:** the full a16 suite + 6 kernels + 2 combinatorial = 40/40 (now 41/41 with the new
   regression) and `dev/run.sh corpus` → 7/7.
5. `dev/regen-patch.sh` round-trips (`0002`).

## Workflow notes for the next pass

- From-source toolchain + SDK + jgxcheck + BIOS are already built under `build/`. Rebuild after a
  `vendor/` edit: `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh toolchain` (~13 s incremental),
  then `MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build` (SDK) if needed.
- Fast inner loop: compile the repro with
  `mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm
  -verify-machineinstrs -c known/a16-cmp-value-selectimm.c` inside the dev container; clean exit = fixed.
- Use the fuzzer to find more value-compare shapes once A lands: the 8 seeds are reproducible
  (`dev/run.sh fuzz 1 <seed>`), and the delta reducer pattern from the Tier-1 pass
  (`build/min/reduce.py`) generalizes.
- Cap backend-fix hypotheses at ~3 attempts; if A doesn't converge, document and keep the XFAIL.

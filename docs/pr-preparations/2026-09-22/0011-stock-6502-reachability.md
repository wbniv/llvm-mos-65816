# Patch 0011: stock-6502 reachability of the scavenger live-`$p` failure

Found while reviewing patch 0030: the c-torture differential's one "fails on
both, differently" file, `strlen-4.c` at `-O0` on plain `mos6502`, is this bug.
The 0011 [PR draft](../../upstream-scavenger-live-p-pr.md) had been held as
"not ready to post" for lack of an upstream producer that does not need
`+mos-a16`; this is that producer.

- [x] Reproduce on the pinned upstream (`742d554bf080`) with stock `mos6502` at `-O0`.
- [x] Confirm 0011 fixes it on a controlled build (only 0011 differs).
- [x] Corpus differential for 0011 itself (verifier, assembly).
- [x] Reduce `strlen-4.c` to a small C reproducer.
- [x] Add a stock-6502 regression that runs on upstream; keep the `+mos-a16` MIR test as downstream-only; fix its pass name.
- [x] Update the PR draft, trackers, TODO; commit.

## Failure on pristine upstream

`build/upstream-reference/…/bin/clang --target=mos -mcpu=mos6502 -O0 -mllvm -verify-machineinstrs -c strlen-4.c`
(release build) fails after Prologue/Epilogue Insertion with
`Using an undefined physical register` on `PH $p` in `test_array_ptr`
(`%bb.314`, `%bb.351`). An assertion-enabled pristine `llc` aborts earlier in
the same pass at `assertNZDeadAt` ("expected N to be free when saving
scavenger register"). Both are the two halves 0011 addresses.

The pre-PEI shape (from `-stop-before=prolog-epilog`), in `%bb.314`:

```text
renamable $c = LDImm1 -1                                   ; sec
renamable $a = LDImm 0
renamable $rs1, dead early-clobber renamable $rs2 = LDStk %stack.6, 0   ; reload spilled pointer
renamable $y = LDImm 0
renamable $a, renamable $c, dead renamable $v = SBCIndirIdx killed renamable $a, renamable $rs1, killed renamable $y, killed renamable $c
```

`LDStk`'s frame-index expansion needs a scavenged carry register (class `Pc`,
whose only member is `$c`) while `$c` is live, so `$p` must be saved. The range
is push/pull-balanced, so the existing `PHP … PLP` path is taken, but at a
later scavenge in the same block `$p` has no available value (the preceding
`ADCImag8` dead-flagged `$c` and `$v`), so the `PHP` reads an undefined `$p`.
With 0011 that push is `PH undef $p` (8 sites in the function) and the sites
where `$c` is available keep a plain `PH $p` (16 sites), which is exactly the
distinction 0011's predicate was written for.

## Controlled fix check

`build/newton-postra-src` (pinned upstream + 0030 + 0031) with 0011 applied on
top, rebuilt as `build/0030-claude-review/llc-0031-plus-0011`; the reference is
the frozen `build/0031-review-audit/llc-0031`. Both assertion-enabled.

| Check | without 0011 | with 0011 |
|---|---|---|
| `strlen-4.c` IR at `-O0 -verify-machineinstrs` | `assertNZDeadAt` | clean |
| MOS CodeGen + MC suites, assertion build, with the guard and the new test | (existing `scavenger.mir` aborted before the guard) | 132 pass (86 CodeGen incl. the new test, 46 MC), 1 unsupported, 0 fail |
| c-torture `execute`, 1,390 files × `-O0/-O2/-Os`, 4,170 comparisons | | exactly one outcome changes: `strlen-4` at `-O0` now compiles; 0 new failures; every one of the 4,090 pairs that succeed on both sides has identical assembly |

So on stock 6502, 0011 is a pure fix: it touches no other compilation in the
corpus, and the `report_fatal_error` it adds for an unbalanced live-`$p` range
without index-register stack ops is never reached there.

## 0011's existing test cannot run upstream

`llvm/test/CodeGen/MOS/scavenger-p-undef.mir` uses `-mattr=+mos-a16` and the
`$a16` register, which do not exist upstream, and `-run-pass=prologepilog`,
which current LLVM no longer registers (it is `prolog-epilog` now; the
project's LLVM 23 tree still only accepts the old spelling). The patch now carries a second test,
`llvm/test/CodeGen/MOS/scavenger-p-undef-6502.ll`: the `strlen-4.c`
reproducer reduced with `llvm-reduce` (interestingness: the pinned release
backend fails the verifier with an undefined `PH $p` after PEI, and the 0011
backend verifies clean with both a `PH undef $p` and a plain `PH $p` after
PEI) to one 290-line `-O0` function. It runs as
`llc -mtriple=mos -mcpu=mos6502 -O0 -stop-after=prolog-epilog -verify-machineinstrs`
and pins both directions in order (`PH undef $p` … `PH $p`, no second undef).
It fails on the pristine release and assertion builds and on the 0030+0031
build, and passes with 0011. The `+mos-a16` MIR test stays in the patch,
marked `DOWNSTREAM-ONLY` and with the current pass spelling, for the project's
own regression coverage of the unbalanced arm; the upstream branch drops that
file (the minting recipe in the contribution status says so). The vendor
LLVM 23 copy keeps `prologepilog`.

## A second defect in 0011, found by the suite

With 0011 applied, the existing upstream test `CodeGen/MOS/scavenger.mir`
aborts in an assertion build: `MachineBasicBlock::livein_begin()` asserts
"Liveness information is accurate", reached from `hasNoAvailableValue`'s
`LivePhysRegs::addLiveIns` on the block being scavenged. That test's functions
carry no `tracksRegLiveness`, and 0011 computed liveness unconditionally (the
old `assertNZDeadAt` only walked successor live-ins, which those blocks do not
have, so it never tripped). Release builds hide it; upstream CI runs with
assertions and would have failed the PR on the spot. It passes on pristine and
on the 0030+0031 build, so it is 0011's own regression.

Fix: both helpers bail out when the function does not track liveness.
`hasNoAvailableValue` returns false (the operand stays unflagged; the verifier
only checks physical-register liveness when `MRI->tracksLiveness()`, and an
unflagged use is the side that can never miscompile), and `findDeadIndexReg`
returns no register, so `canSaveScavengerRegister(P)` falls back to the
balanced hard-stack path exactly as before 0011. `getProperties().hasTracksLiveness()`
exists in both the project's LLVM 23 tree and current upstream.

The `+mos-a16` MIR test is moved out of patch 0011 (it cannot parse upstream)
into the a16 feature patch 0002 via `dev/regen-patch.sh`'s test list; the
vendor tree keeps its copy, and it is folded into 0002 at the next regeneration.

## Reduced reproducer

`docs/investigations/repro/upstream-issues-2026-09-22/strlen-4-reduced.c`
(65 lines, from `strlen-4.c` by two line-level reducers, `reduce-strlen4.py`
and the chunk-wise `reduce-strlen4-dd.py`): `test_array_ptr` with its 34
`A(…)` checks and an emptied string table. No single check can be removed
because the failure needs the frame to exceed 255 bytes (the carry chain) and
enough pressure to spill the pointer between `sec` and `sbc`; hand-written
smaller candidates with a 300-byte local array did not reproduce, so the IR
test was taken from `llvm-reduce` instead of from a smaller C file.

Artifacts under `build/0030-claude-review/`: `diff4.py` / `diff4-results.json`
(the 0011 differential), `strlen4-reduce/` (reducers and outputs),
`llc-0031-plus-0011`.

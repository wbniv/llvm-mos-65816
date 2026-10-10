# Repair the SPC700 copy-hint allocation assertion

TODO item: *Repair the upstream SPC700 copy-hint allocation assertion* (M2 section, ranked T4 by the user on 2026‑10‑01). Defect record: [`mos-spc700-hint-outside-order`](../defects/mos-spc700-hint-outside-order.json). Evidence: [`2026-10-10-spc700-hint-repair/`](../defects/evidence/2026-10-10-spc700-hint-repair/README.md). Upstream packet (not posted): [`pr-preparations/2026-10-10/spc700-hint-order/`](../pr-preparations/2026-10-10/spc700-hint-order/README.md).

No visible surface: this is a register-allocator hint change plus a MIR test, so the plan has no mockups.

## Problem

On upstream llvm-mos `06bc967d2668` built with assertions, `llc -mtriple=mos -mcpu=mosspc700 -O2` aborts in the greedy allocator with `Target hint is outside allocation order` on 18 of the 52 default-mode corpus IRs (record baseline: `boids.ll`). The #320 split's commit 1c drops such a hint but keeps returning hard hints. The record describes that variant as failing with "ran out of registers" and then a rewriter abort.

## Root cause

1. On SPC700, `MOSCallLowering::lowerCall` lowers an indirect call as `$rs9 = COPY callee`, `$rc17 = COPY (G_CONSTANT 0x5F)`, `JSR __rc17`. `$5F` is the SPC700 `JMP !abs` opcode. The zero-page bytes RC17, RC18 and RC19 then form a jump to the callee. The CPU has no plain indirect jump that preserves X.
2. RC17 is the high byte of RS8. `MOSRegisterInfo` reserves RS8 on every CPU for the register scavenger. The register can still appear as a fixed physical operand, and the scavenger treats it as live between the copy and the call.
3. The constant becomes `%n:anyi8 = LDImm 95`. On SPC700, `MOV dp,#imm` exists, so the virtual register's class is `Anyi8`, and that class contains RC17. On the other CPUs the same constant would be `GPR`, which does not contain RC17.
4. MOS sets `shouldRematPhysRegCopy()` to false, so the coalescer does not fold the constant into the copy. MachineLICM or MachineCSE often hoists or shares the `LDImm` across a loop or across several calls.
5. In `MOSRegisterInfo::getRegAllocationHints`, `getStrongCopyHint` returns RC17. The value is rematerializable, its only uses are copies into RC17, and RC17 is in the class. `getRegAllocationHints` returns that register as a **hard** hint (`return true`). RC17 is reserved, so `RegisterClassInfo` leaves it out of the allocation order. `AllocationOrder::create` asserts that every hint is in the order.
6. Without assertions, greedy honours the hard hint and assigns the virtual register to the reserved RC17 (`renamable $rc17 = LDImm 95` after the rewriter, observed on the installed release pin compiler). The allocator never hands out a reserved register under its own contract. This output is wrong by contract, though the observed code happens to be harmless.

The 1c filter removes the out-of-order hint but still returns `true`. A hard-hint order with no hints is empty, so the value is spilled and rematerialized. The rematerialized value gets the same hint and an empty order again, and then "ran out of registers" follows in `@main`. The rewriter abort that the record lists afterwards is separate. It is in `@_title_emit`, it is the spill-hoist scratch-register defect that patch `0033` repairs, and the clang driver avoids it by always passing `-disable-spill-hoist`. The abort appears on unpatched `06bc967d` when `@_title_emit` is compiled first (`title-emit-first-*.log`). It persists with this repair, and it disappears with `-disable-spill-hoist`.

## Design

**Chosen (A):** take the strong-hint early return only when the hint is in `Order` (or is `NoRegister`, which means "spill instead"). Otherwise, fall through to the cost-based soft hints computed below. The value then lands in an allocatable register, the cheapest by copy cost into RC17. The check uses the allocator's own contract, which is membership in `Order`. It also covers the #320 series' empty alternative `Imag32` order without a separate filter.

**Rejected:**

- (B) Make `getStrongCopyHint` ignore reserved registers. That tests reservation, which only approximates membership in `Order`. An alternative allocation order can leave out an unreserved register. It also changes a helper that has its own `NoRegister` merging semantics.
- (1c) Filter the hint and keep returning `true`. The order is then empty and the rematerialized value can never be allocated.
- (C) Emit the thunk opcode straight into RC17 in SPC700 call lowering, with no virtual register. This would recover the best code: `mov __rc17,#95` at each call, as release builds produce today by assigning the reserved register. However, it only removes this trigger, the hint contract stays broken for any other copy into a reserved register, and the change is outside allocation-hint handling. It is listed as a follow-up below, not part of this patch.

**Optimization levels:** this is a correctness repair of an allocator contract. The changed path runs only when a strong hint falls outside the allocation order, and in an assertions build that path always aborted. It cannot be gated by `-O2`/`-O3` against `-Os`/`-Oz`: every level that runs greedy (`-O1` and above, including `optsize`/`minsize`) reaches it. `-O0` uses the fast allocator and is unaffected.

## Verification

1. MIR regression `regalloc-spc700.mir` fails on upstream `06bc967d` (and on `06bc967d` + #584) with the assertion, and passes with the repair.

    ```
    mir-up-06bc967d.log: exit_code=134 Target hint is outside allocation order
    mir-fix-06bc967d.log: exit_code=0
    mir-up584-06bc967d.log: exit_code=134 Target hint is outside allocation order
    mir-fix584-06bc967d.log: exit_code=0
    ```

    **PASS** (2026‑10‑10)

2. The reduced input `boids-reduced.ll` (from `boids.ll` with `llvm-reduce`) aborts with the assertion on `06bc967d` and on `06bc967d` + #584. It compiles with `-verify-machineinstrs` on `06bc967d` + #584 + repair. On `06bc967d` + repair alone it reaches the late-optimization crash that #584 fixed.

    ```
    reduced-up-06bc967d.log: exit_code=134 Target hint is outside allocation order
    reduced-up584-06bc967d.log: exit_code=134 Target hint is outside allocation order
    reduced-fix584-06bc967d.log: exit_code=0
    reduced-fix-06bc967d.log: exit_code=139 Running pass 'MOS Late Optimizations' on function '@main'
    ```

    **PASS** (2026‑10‑10)

3. The record baseline `boids.ll`: `06bc967d` + #584 aborts with the assertion. With the repair, `@main` allocates, and `@_title_emit` hits the separate spill-hoist abort. With `-disable-spill-hoist` (what clang passes), the repair compiles it cleanly with `-verify-machineinstrs`, and the unrepaired compiler still aborts with the assertion.

    ```
    boids-up584-06bc967d.log: exit_code=134 Target hint is outside allocation order
    boids-fix584-06bc967d.log: exit_code=134 Running pass 'Virtual Register Rewriter' on function '@_title_emit'
    boids-disable-spill-hoist-up584-06bc967d.log: exit_code=134 Target hint is outside allocation order
    boids-disable-spill-hoist-fix584-06bc967d.log: exit_code=0
    title-emit-first-up-06bc967d.log: exit_code=134 (Virtual Register Rewriter on @_title_emit)
    ```

    **PASS** (2026‑10‑10)

4. Rebuilt `06bc967d` and `06bc967d` + #584 are bit-identical to the preserved `p-321-00` and `r3-584-up` binaries.

    ```
    2f5c17683f93825767f9d4888ab6a15c929e9508ef2817c3267f9199e14d39a7  build/spc700-hint/llc/up-06bc967d
    2f5c17683f93825767f9d4888ab6a15c929e9508ef2817c3267f9199e14d39a7  build/split-320-321/llc/p-321-00
    c3878a98df57c15b15bdf0caf701216a5816683012a80e8b5c70653fadc50f03  build/spc700-hint/llc/up584-06bc967d
    c3878a98df57c15b15bdf0caf701216a5816683012a80e8b5c70653fadc50f03  build/split-320-321/llc/r3-584-up
    ```

    **PASS** (2026‑10‑10)

5. MOS lit (`CodeGen/MOS`, `MC/MOS`) passes on each repaired build. The new test is the only failure when the unrepaired `llc` is used.

    ```
    fix-06bc967d:    Total Discovered Tests: 134  Passed: 133  Unsupported: 1
    up-06bc967d llc: Passed: 132  Unsupported: 1  Failed: 1  (LLVM :: CodeGen/MOS/regalloc-spc700.mir)
    fix584-06bc967d: Total Discovered Tests: 135  Passed: 134  Unsupported: 1
    ```

    **PASS** (2026‑10‑10)

6. Corpus census (52 default-mode IRs, mosspc700, `-O0`–`-O3` plus `optsize`/`minsize` IR at `-O2`), `06bc967d` + #584 against the same plus the repair, with `-verify-machineinstrs`: every `hint-outside-order` abort goes away, no new failure appears, and every input that compiled before produces identical assembly.

    ```
    changed outcomes (-verify-machineinstrs -disable-spill-hoist):
      18 x O1/O2/O3/Os/Oz each: hint-outside-order -> ok
    inputs ok on both: 177 identical assembly, 0 different
    mos6502/mos65c02/mos65ce02/moshuc6280 (19 compile), mosw65816 (46): exit codes identical, 0 assembly differences
    ```

    **PASS** (2026‑10‑10)

7. Destination: on upstream main `0f031168a7cc` with assertions, the MIR test fails without the repair and passes with it. The MOS lit suites pass with the repair.

    ```
    mir-up-0f031168.log: exit_code=134 Target hint is outside allocation order
    mir-fix-0f031168.log: exit_code=0
    reduced-up-0f031168.log: exit_code=134 / reduced-fix-0f031168.log: exit_code=0
    lit up-0f031168: Passed: 138  Unsupported: 1  Failed: 1 (LLVM :: CodeGen/MOS/regalloc-spc700.mir)
    lit fix-0f031168: Total Discovered Tests: 140  Passed: 139  Unsupported: 1
    census on 0f031168: 90 outcomes hint-outside-order -> ok; 177 identical; other CPUs identical
    ```

    **PASS** (2026‑10‑10)

Results and raw output: [evidence README](../defects/evidence/2026-10-10-spc700-hint-repair/README.md).

## Follow-ups (not in this change)

- SPC700 call lowering could define RC17 with the opcode directly at each indirect call. That restores the one-instruction `mov __rc17,#95` that release builds emit today by assigning the reserved register. Measure the bytes and cycles before proposing it.
- Patch `0033` (spill-hoist scratch virtual registers) remains the repair for the `@_title_emit` abort.
- The #320 split's 1c strong-hint filter can be replaced by this change once it lands upstream.

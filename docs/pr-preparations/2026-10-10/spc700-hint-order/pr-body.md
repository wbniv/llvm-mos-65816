`getRegAllocationHints` returns the strong copy hint as a hard hint. `getStrongCopyHint` only checks that the hinted register is in the virtual register's class, but a class member can still be outside the allocation order, for example when it is reserved. `AllocationOrder::create` asserts that every hint is in the order.

SPC700 indirect calls reach this case. Call lowering copies the `JMP !abs` opcode (`$5F`) into the reserved `RC17` and calls `__rc17` ([#357](https://github.com/llvm-mos/llvm-mos/pull/357)). On SPC700, `LDImm` may define an imaginary register ([93d338b079d4](https://github.com/llvm-mos/llvm-mos/commit/93d338b079d4c158794a9a0e74b53bbe90721205), part of [#448](https://github.com/llvm-mos/llvm-mos/pull/448)), so the constant's class is `Anyi8`, which contains `RC17`. When MachineLICM or MachineCSE hoists or shares the constant, the coalescer leaves it alone (`shouldRematPhysRegCopy` is false). Its only use is then the copy into `RC17`, so the strong hint names `RC17`:

```cpp
  // On SPC700, LDImm can be used for imaginary registers.
  if (STI.hasSPC700() && MCID.getOpcode() == MOS::LDImm && OpNum == 0) {
    return &MOS::Anyi8RegClass;
  }
```

With assertions, `llc -mtriple=mos -mcpu=mosspc700 -O2` then fails with `Target hint is outside allocation order` on a function that calls through a pointer in a loop:

```llvm
define i16 @main(ptr %0) {
  br label %2

2:
  %3 = load ptr, ptr %0, align 1
  tail call void %3(ptr null, ptr null)
  br label %2
}
```

Without assertions, greedy follows the hard hint and assigns the virtual register to the reserved `RC17` (`renamable $rc17 = LDImm 95` after the rewriter).

This change uses the strong hint only when it is in the allocation order. Otherwise the cost-based hints apply, which put the value in an allocatable register that is cheap to copy into the destination. Filtering the hint while still returning `true` would leave a hard order with no registers. The rematerialized value would then get the same empty order and fail with "ran out of registers".

Effect by target: the code runs for every MOS CPU, but only SPC700 copies a value of a class that contains a reserved register, so generated code changes only for SPC700 functions with such a copy. With assertions those functions aborted, and without assertions they used a reserved register. Functions that compile today with assertions enabled are unchanged on every CPU, because the changed path always asserted. The corpus check below confirms this.

Test: `regalloc-spc700.mir` runs greedy and the rewriter on the opcode constant copied into `RC17`, with and without an intervening call. It aborts with the assertion before this change and passes after it.

Validation on `main` (`0f031168a7cc`), assertions enabled:

```sh
llc -mtriple=mos -mcpu=mosspc700 -run-pass=greedy,virtregrewriter -verify-machineinstrs llvm/test/CodeGen/MOS/regalloc-spc700.mir -o -
llvm-lit llvm/test/CodeGen/MOS llvm/test/MC/MOS
```

Without this change, the MIR test aborts with the assertion, and `llvm-lit` reports 138 passed, 1 unsupported, 1 failed (`regalloc-spc700.mir`). With it, `llvm-lit` reports 139 passed and 1 unsupported. The reduced loop above also compiles with `-verify-machineinstrs`.

On a 52-program SPC700 corpus (compiled as clang does, with `-disable-spill-hoist`), 18 programs aborted at each of `-O1`, `-O2`, `-O3`, `-Os` and `-Oz`, and all of them now compile with the verifier clean. The 177 program/level pairs that already compiled produce byte-identical assembly. The same holds for `mos6502`, `mos65c02`, `mos65ce02`, `moshuc6280` and `mosw65816` at `-O2`.

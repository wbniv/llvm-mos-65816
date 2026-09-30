# Repair the four far-prerequisite defects (B1–B4) downstream

Status: done (2026‑09‑30). All seven verification steps pass; the four records are `fixed`. Deviations and residual limits are listed under [Outcome](#outcome). The user approved the fixes on 2026‑09‑30 ("Fix B1–B4 now?" — "YES") with the ranks B1 T2, B2 T3, B3 T2, B4 T2. All four were found by the [independent review of the rebased far-word series](../pr-preparations/2026-09-30/far-word-rebase/independent-review.md), reproduce on the downstream release toolchain (`llc` `9031686c`), and have confirmed canonical records with frozen baselines. This plan repairs them in `vendor/llvm-mos` and the fork patch stack and closes each record with a same-input red/green. Carrying the repairs into the extracted #320 series is a later step: it waits for the [#320/#321 split](2026-09-30-split-320-321-series.md) and is not part of this plan.

Attribution: Claude Code 2.1.283, model Claude Opus 5.5 (`claude-opus-5-5`), `xhigh` reasoning effort; session `f79adc39-72b4-4dc5-abc1-849c14c5ce96`.

No visible surface: compiler and runtime repairs, no mockups.

## Shared contract

- **Baseline** for every record is the frozen `build/far-review-defects/downstream/llc` (`9031686c…`, a hard link of the 2026‑09‑30 05:29 `build/llvm-mos/bin/llc`). The captured baselines in the records are immutable.
- **One toolchain, sequential.** The four repairs touch the same files, `vendor/` is shared, and there is one downstream build. Do them in one pass, with one rebuild, and freeze the candidate tools under `build/far-review-defects/candidate/` with their hashes.
- **The bar** is the project differential ([`docs/agent-handoff.md`](../agent-handoff.md)): the MOS lit suites, `-verify-machineinstrs`, and the MAME and bsnes runs for any runtime-visible change. Report default-mode (`mos6502` and plain `mosw65816` without `+mos-a16`) codegen changes explicitly.
- **Patch discipline.** Regenerate `0002` with `dev/regen-patch.sh`. Check that it absorbed no foreign `vendor/` edits by comparing its diff against origin's `0002`. Also update any standalone patch that carries the same code (`dev/toolchain.sh` has the apply list; `0004`, `0013`, `0061` and `0070` are candidates).
- **Closure.** Each record moves to `fixed` with a `resolution` whose candidate run uses the same input and configuration as its baseline and exits 0. It must also give the causal change and a `trigger_check`; `dev/check-defect-evidence.py` enforces the schema.

## Repairs

1. **B1 — far-pointer argument exhaustion** ([record](../defects/mos-far-pointer-arg-exhaustion.json)). Add an ungated `CCIfPtrAddrSpace<2, CCAssignToStack<4, 1>>` to `CC_MOS` after the four `farPtrCC()`-gated far-pointer rules and before the direct-page and generic `CCIfPtr` rules. Every far-pointer convention then falls back to the soft stack when its registers are exhausted: Imag32 (the default), Split and AXY, whose custom assigners already return false when they run out. Tests: caller and callee with four far pointers, and a near/far interleaving that uses up the quads while leaving `RS1` free. Run in plain `mosw65816`, `+mos-a16` and `+mos-a16,+mos-xy16`.
2. **B2 — far memory lengths above 65535** ([record](../defects/mos-far-memop-length-truncation.json)). This one needs a design decision, recorded here:
    - **Provably ≤ 0xFFFF:** keep the current 16-bit `__memset_far`/`__memcpy_far`/`__memmove_far` call when the length is a constant ≤ 0xFFFF or its known-bits maximum (`GISelValueTracking` via `LegalizerHelper::getValueTracking()`) is ≤ 0xFFFF. Existing programs whose lengths are provable keep identical code.
    - **Otherwise:** call new 32-bit-length entries `__memset_far32`, `__memcpy_far32` and `__memmove_far32` with a `uint32_t` length. Add them as weak C functions next to the existing ones in [`platforms/snes/mem-far.c`](../../platforms/snes/mem-far.c), with the same direction rule for memmove. Loop-idiom memsets over far arrays produce unprovable lengths such as `zext(n) * 2`. Those lengths can exceed 0xFFFF in valid programs, so rejecting them would break compilation instead of fixing it.
    - **Mixed near/far lengths are not a defect.** For memcpy or memmove between a far and a near pointer, the generic IRTranslator narrows the length to the smaller pointer width. LangRef bounds every allocated object by the largest signed integer of its index type, which is 32767 bytes for the 16-bit near space. A near operand therefore cannot be valid for 65536 bytes, and that narrowing is sound. The `len64k` function in the record's input is undefined behaviour. Correct the record's summary to say so, citing LangRef "Allocated objects".
    - **Tests:** lit coverage for lengths 65535, 65536, 65537 and 70000, an unbounded runtime `i32`, and a provably bounded runtime length that must stay on the 16-bit entry. Also add a runtime fill and copy larger than 64 KiB, across the `$7E`/`$7F` WRAM banks, checked on MAME and bsnes. Extend `examples/65816/far_memops.c` or `dev/check-far-memset.py`, whichever fits.
3. **B3 — far accesses on non-65816 CPUs** ([record](../defects/mos-far-access-non-65816.json)). When the subtarget lacks `hasW65816()`, report a clear diagnostic, such as a `DiagnosticInfoUnsupported` stating that far (address space 2) memory needs 65816 long addressing, instead of selecting long-indirect opcodes. This covers every address-space-2 load, store, extending load and far memory intrinsic. Passing a far pointer as a value stays legal. Tests: a `mos6502` negative test for a runtime far load and a runtime far store, plus one other non-65816 CPU.
4. **B4 — undef debug value after the far index fold** ([record](../defects/mos-far-index-fold-dangling-dbg.json)). When a far index fold (byte, and the 0070 word fold) erases the pointer add, first drop the location of any debug use `salvageDebugInfo` could not rewrite: `MachineInstr::setDebugValueUndef()`, giving `$noreg`. A `DBG_VALUE_LIST` salvage is optional and out of scope. Tests: `-g` byte and word folds under `-verify-machineinstrs`, checking the `DBG_VALUE` operand.

## Out of scope

- The extracted #320 series, which waits for the split and is then applied per commit.
- B5, the far-quad DWARF numbering, and B7, reconciliation with #594.
- Speed or size tuning of the new 32-bit runtime entries.

## Verification

1. Each of the four baseline commands, rerun unchanged on the frozen baseline, still fails with its recorded signature.

    ```text
    BASELINE mos-far-pointer-arg-exhaustion: exit=-6 (recorded -6) signature_present=True
      *** Bad machine code: Copy Instruction is illegal with mismatching sizes ***
    BASELINE mos-far-memop-length-truncation: exit=1 (recorded 1) signature_present=True
      MISCOMPILE: 70000-byte far memset passes length 4464 (0x1170)
      MISCOMPILE: 65536-byte far memmove deleted
    BASELINE mos-far-access-non-65816: exit=1 (recorded 1) signature_present=True
      MISCOMPILE: mos6502 far byte load emitted 65816 opcode $A7
    BASELINE mos-far-index-fold-dangling-dbg: exit=-6 (recorded -6) signature_present=True
      *** Bad machine code: Generic virtual register use cannot be undef ***
    ```

    PASS

2. The candidate toolchain builds. The frozen candidate `llc`, `llvm-objdump` and runtime objects are hashed in an identity file.

    ```text
    $ dev/run.sh toolchain            -> rc=0 (clang-23 2026-09-30 08:41:55, llc 08:38:49)
    $ MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build -> SDK built; 296 programs built,
      3 failed (ascast, ascast_sim, lzss-gallery; all fail identically on the baseline llc, see step 6)
    f1fa50a225c3660715b16c44dd2dc65b98984549923e4a6bb994ed2867cedda1  build/far-review-defects/candidate/llc
    fba3e55229c58c9c2e0e7c730a47d6827d311d514c13ee5142b4afe367bc632a  build/far-review-defects/candidate/llvm-objdump
    856fd9e343be8ba90f5b732d613595dc4b15fcc46864479540e986434f4f05e9  build/far-review-defects/candidate/llvm-dwarfdump
    254624ba26462f49b4c875b16eda3a1d10d7b766dd80175ec69b64bc96485b0c  build/far-review-defects/candidate/clang-23
    0280822c13fbeb1bb1be1269ba448a0cf2b1876fb282004fa8599d5388d4bd52  build/far-review-defects/candidate/runtime/mem-far.c.obj
    78b6040a322cd0ab1d97782f9c84c2aeb94d4f2126cf3ddc48756bd8586ca91b  build/far-review-defects/candidate/runtime/libc-snes.a
    identity: docs/defects/evidence/2026-09-30-*/candidate-identity.json (one per record)
    $ llvm-nm mem-far.c.obj | grep far
    00000000 W __memcpy_far
    00000000 W __memcpy_far32
    00000000 W __memmove_far
    00000000 W __memmove_far32
    00000000 W __memset_far
    00000000 W __memset_far32
    ```

    PASS

3. Each record's same-input candidate run passes, and `dev/check-defect-evidence.py --worktree` accepts all four records as `fixed`.

    ```text
    CANDIDATE mos-far-pointer-arg-exhaustion: exit=0
    CANDIDATE mos-far-memop-length-truncation: exit=0
      big_const: ... jmp __memset_far32 ; big_var: jmp __memcpy_far32
      PASS: lengths above 0xFFFF reach the 32-bit-length far runtime
    CANDIDATE mos-far-access-non-65816: exit=0
      error: <unknown>:0:0: in function ld_rt i8 (ptr addrspace(2)): far (address space 2) memory access
      requires 65816 long addressing; the target CPU has none
      PASS: diagnosed; no object emitted
    CANDIDATE mos-far-index-fold-dangling-dbg: exit=0
    $ python3 dev/check-defect-evidence.py --worktree
    Defect evidence: PASS (30 records, worktree)
    ```

    PASS

4. The new lit tests fail on the baseline and pass on the candidate, and the full MOS CodeGen/MC suites pass on the candidate with no new failure.

    ```text
    # candidate llc f1fa50a2 (bind-mounted over build/llvm-mos/bin/llc), CodeGen/MOS + MC/MOS
      Unsupported:   3 (1.55%)
      Passed     : 190 (98.45%)
    # baseline llc 9031686c, same suites and tests
    FAIL: LLVM :: CodeGen/MOS/far-index-fold-debug.ll (7 of 193)
    FAIL: LLVM :: CodeGen/MOS/far-access-non-65816.ll (10 of 193)
    FAIL: LLVM :: CodeGen/MOS/far-ptr-arg-exhaustion.ll (17 of 193)
    FAIL: LLVM :: CodeGen/MOS/far-memop-length.ll (19 of 193)
      Unsupported:   3 (1.55%)
      Passed     : 186 (96.37%)
      Failed     :   4 (2.07%)
    ```

    PASS

5. The runtime fill and copy larger than 64 KiB pass on MAME and bsnes, and the existing far-memory gates still pass.

    ```text
    $ dev/run.sh far_memops32
      PASS: references __memset_far32 / __memcpy_far32 / __memmove_far32
    ==> [a16 -Os]  MAME SMOKE: PASS addr=0x7E0214 len=2 got=0xFFFF | bsnes-jg SMOKE: PASS off=0x214 len=2 got=0xFFFF
    ==> [a16 -O2]  MAME SMOKE: PASS got=0xFFFF | bsnes-jg SMOKE: PASS got=0xFFFF
    ==> [xy16 -Os] MAME SMOKE: PASS got=0xFFFF | bsnes-jg SMOKE: PASS got=0xFFFF
    ==> [xy16 -O2] MAME SMOKE: PASS got=0xFFFF | bsnes-jg SMOKE: PASS got=0xFFFF
    RESULT: PASS — far memset/memcpy/memmove above 64 KiB across $7E/$7F honour the full length on both emulators (a16, xy16; -Os, -O2)
    $ dev/run.sh far_memops
    RESULT: PASS — far memset (variable) + far aggregate memcpy land in bank $7E at -Os and -O2; read back == 0x74
    $ dev/run.sh xcheck        (13 far ROMs rebuilt from scratch)
    RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (16 of 16 PASS)
    $ python3 dev/check-far-memset.py --mode {a16,xy16} --opt {Os,O2}
    a16 Os rc=0 RESULT: PASS / a16 O2 rc=0 RESULT: PASS / xy16 Os rc=0 RESULT: PASS / xy16 O2 rc=0 RESULT: PASS
    ```

    PASS

6. The SNES corpus (`examples/snes/corpus/expected.tsv`) and the demo ROM builds have no unexplained change. Every changed object is attributed to one of the four repairs.

    ```text
    $ dev/run.sh corpus
    CORPUS run 100% 84/84 complete | PASS 84 FAIL 0
    $ dev/run.sh corpus-a16    (host == default == +mos-a16 == +mos-xy16, MAME + bsnes-jg)
    A16 100% 83/83 complete | PASS 83 FAIL 0 XFAIL 0
    # Same frontend IR (candidate clang, -Os) codegenned by baseline and candidate llc:
    # 277 sources (examples/snes/corpus/*.c + dev/build-determinism-demo-set.txt), 3 modes
        272 a16 identical     1 a16 llc-fail(base=1,cand=1)     4 a16 skip-frontend
        260 w65816 identical 13 w65816 llc-fail(base=1,cand=1)  4 w65816 skip-frontend
        272 xy16 identical    1 xy16 llc-fail(base=1,cand=1)    4 xy16 skip-frontend
    # SDK program build failures, each reproduced on the baseline llc:
    lzss-gallery: precodegen.bc -> baseline and candidate: "ran out of registers ... in function 'record_result'" rc=1
    ascast, ascast_sim: precodegen.bc -> baseline and candidate: "unable to legalize ... G_MERGE_VALUES ... (in function: ac_to_far)" rc=1
    ```

    PASS. No object changed, so none needs attribution. The 15 `llc-fail` pairs fail identically on both compilers (13 are `mos-a16-only` demos compiled in plain mode). `ascast.c` is untracked work of another agent in the main checkout.

7. `0002` and any affected standalone patches round-trip, and `grep` confirms that `0002` absorbed no foreign hunks.

    ```text
    $ dev/regen-patch.sh
        reversing 0070-mos-far-word-index-policy.patch out of the 0002 generation tree
        ...
        wrote patches/llvm-mos/0002-321-accum16.patch (9264 lines, 51 files)
    RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)
    # per-file post-image change of 0002 against origin/main:
    llvm/lib/Target/MOS/MOSCallingConv.td: +6 -0
    llvm/lib/Target/MOS/MOSLegalizerInfo.cpp: +80 -13
    llvm/test/CodeGen/MOS/far-access-non-65816.ll: +51 -0
    llvm/test/CodeGen/MOS/far-index-fold-debug.ll: +103 -0
    llvm/test/CodeGen/MOS/far-memop-length.ll: +105 -0
    llvm/test/CodeGen/MOS/far-ptr-arg-exhaustion.ll: +78 -0
    $ grep -c <symbol> patches/llvm-mos/0002-321-accum16.patch
    rejectFarAccessWithoutLong: 4   __memset_far32: 6   DeadAddrs: 6   CCIfPtrAddrSpace<2, CCAssignToStack<4, 1>>,: 1
    ```

    PASS. Every changed hunk is one of the four repairs or its test. The applied standalone patches, including 0069 and 0070, reapply unchanged in the round trip.

## Outcome

- **B1** closes for the recorded configuration (`+mos-a16`) and `+mos-a16,+mos-xy16`. In plain `mosw65816`, call lowering now stacks the fourth far pointer correctly, but reading the stacked 4-byte value fails loudly with "unable to legalize `G_MERGE_VALUES` s32". That is the existing plain-mode limit on any far-pointer value in memory; the baseline fails the same way on a far-pointer load from a near global. The plain-mode lit coverage therefore stops after the IRTranslator. The opt-in `+mos-farcc-split` and `+mos-farcc-axy` variants already abort on the baseline whenever a custom-assigned far pointer is followed by another argument, before any exhaustion, so no regression covers them. That is recorded separately as [mos-far-cc-split-axy-custom-args](../defects/mos-far-cc-split-axy-custom-args.json).
- **B2** runtime entries are plain byte loops over a `uint32_t` index, as the plan allows. The new gate is `dev/run.sh far_memops32` with `examples/65816/far_memops32.c`. The `len64k` record correction follows the plan.
- **Standalone patches.** `0004` (far CC) and `0013` (far memops) carry older copies of the B1 and B2 code but are not applied by `dev/toolchain.sh`, apart from 0013's `far-memset.ll`. They belong to the #320 series and are updated with the split, as scoped above.
- **Default-mode codegen.** Plain `mosw65816` objects are byte-identical across the 260 corpus and demo sources that compile (step 6). For `mos6502`, the only change is B3's: far loads, stores and far memory intrinsics are now diagnosed instead of emitting `$A7`-family opcodes. The MOS lit suites, including every `mos6502` test, pass unchanged.

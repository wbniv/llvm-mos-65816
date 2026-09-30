# Repair the four far-prerequisite defects (B1–B4) downstream

Status: planned. The user approved the fixes on 2026‑09‑30 ("Fix B1–B4 now?" — "YES") with the ranks B1 T2, B2 T3, B3 T2, B4 T2. All four were found by the [independent review of the rebased far-word series](../pr-preparations/2026-09-30/far-word-rebase/independent-review.md), reproduce on the downstream release toolchain (`llc` `9031686c`), and have confirmed canonical records with frozen baselines. This plan repairs them in `vendor/llvm-mos` and the fork patch stack and closes each record with a same-input red/green. Carrying the repairs into the extracted #320 series is a later step: it waits for the [#320/#321 split](2026-09-30-split-320-321-series.md) and is not part of this plan.

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
2. The candidate toolchain builds. The frozen candidate `llc`, `llvm-objdump` and runtime objects are hashed in an identity file.
3. Each record's same-input candidate run passes, and `dev/check-defect-evidence.py --worktree` accepts all four records as `fixed`.
4. The new lit tests fail on the baseline and pass on the candidate, and the full MOS CodeGen/MC suites pass on the candidate with no new failure.
5. The runtime fill and copy larger than 64 KiB pass on MAME and bsnes, and the existing far-memory gates still pass.
6. The SNES corpus (`examples/snes/corpus/expected.tsv`) and the demo ROM builds have no unexplained change. Every changed object is attributed to one of the four repairs.
7. `0002` and any affected standalone patches round-trip, and `grep` confirms that `0002` absorbed no foreign hunks.

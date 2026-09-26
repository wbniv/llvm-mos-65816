# 0044 validation — 24-bit address operands print an explicit `mos24(...)` width

**Patch:** [`patches/llvm-mos/0044-mos-asm-print-long-address.patch`](../../../patches/llvm-mos/0044-mos-asm-print-long-address.patch)
(3 files changed in `llvm/lib/Target/MOS/MCTargetDesc/MOSInstPrinter.{h,cpp}` and
`MOSInstrFormats.td`, 1 new test file `llvm/test/MC/MOS/long-address-roundtrip-65816.s`).
**PR draft:** [`docs/upstream-asm-print-long-address-pr.md`](../../upstream-asm-print-long-address-pr.md).
**Plan:** [`docs/plans/2026-09-24-asmprinter-long-address.md`](../../plans/2026-09-24-asmprinter-long-address.md).

**Status: prepared, not posted. Posting is user-triggered.**

This validation follows the `0043`/`0046` pinned-base pattern
([review](../2026-09-25/claude-batch-review.md) noted `0044` still needed its own
standalone PR body and validation bundle) and additionally answers the question the
plan itself raised but did not test in isolation: **does `0044`'s round-trip test need
`0039` (the parser-side width-modifier fix) to pass?**

## What was built, and where

| | |
|---|---|
| Worktree | `/home/will/llvm-mos-65816-0044prep` (branch `throwaway/0044-upstream-pr-2026-09-26`, off `main`) |
| Source tree | fresh `vendor/llvm-mos`, shallow-fetched (`git fetch --depth 1`) and checked out detached at `LLVM_MOS_PIN` = `8be0546128a55e78c63ca571d466aa72a782cd36` |
| Host build directory | `build/llvm-mos` inside the worktree (mounted at `/work/build/llvm-mos` by `dev/container.sh`'s bind mount, `llvm-mos-65816-dev` image) |
| Configuration | `Ninja`, `Release`, `LLVM_ENABLE_PROJECTS=clang;lld`, `LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=MOS`, `LLVM_TARGETS_TO_BUILD=""`, assertions off, `LLVM_TOOL_LLVM_DRIVER_BUILD=OFF` (required — CMake 4.2.3 in this container otherwise fails to generate), `LLVM_USE_LINKER=lld`, `LLVM_CCACHE_BUILD=ON` |
| Targets built | `llc opt llvm-mc llvm-objdump llvm-readobj split-file FileCheck not llvm-config count` (`llvm-lit` is a generated script, not a ninja target — already present after `cmake` configure) |

## 1. Apply-check against the pin — standalone, and the 0039 stacking question

```
$ git -C /home/will/llvm-mos-65816-0044prep/vendor/llvm-mos apply --check \
    /home/will/llvm-mos-65816/patches/llvm-mos/0044-mos-asm-print-long-address.patch
0044 CLEAN

$ git -C /home/will/llvm-mos-65816-0044prep/vendor/llvm-mos apply --check \
    /home/will/llvm-mos-65816/patches/llvm-mos/0039-mos-asm-modifier-width.patch
0039 CLEAN
```

Both apply standalone against the bare pin — expected, since they touch disjoint files
(`0044`: `MOSInstPrinter.{h,cpp}`, `MOSInstrFormats.td`; `0039`:
`AsmParser/MOSAsmParser.cpp`). Applying `0039` first and then checking/applying `0044`
on top also succeeds cleanly (no conflict either order):

```
$ git apply patches/llvm-mos/0039-mos-asm-modifier-width.patch
$ git apply --check patches/llvm-mos/0044-mos-asm-print-long-address.patch
0044 CLEAN ON TOP OF 0039
$ git apply patches/llvm-mos/0044-mos-asm-print-long-address.patch
BOTH APPLIED
```

**`0044` applies without `0039`.** There is no patch-apply-level stacked dependency.

## 2. Baseline build (pristine pin) and binary snapshots

Built `llc opt llvm-mc llvm-objdump llvm-readobj split-file FileCheck not llvm-config count`
from the bare pin (1861 ninja steps, cold ccache — the container competed for CPU with an
unrelated concurrent build on the same host, so this took materially longer than the
sibling validations' warm-cache runs). Snapshotted as `build/before-bin/`:

```
b1491614e051e414b49d3550bb0db2575fade4f8d673158b6c828d25a8b1e73b  count
08a28afd2e0b867db9713829710d171311e804f12468d19a5c1ed3b0260d429d  FileCheck
38ae28de9399d183b5e9aaf387d1edaa8ed30d830dd1ecac7d92855846f31414  llc
d45e86c4e17646d759b84e674411ab924944cfad6e09bbb1a71ee8de64d90ce5  llvm-config
fbec862455be680368ef8dc78d8343c23b8fca448178f3ca26fd3efd7854d644  llvm-mc
5c3b162290fc4bf5d00433cb2ecb61c68a1102233115a18764ff363d9f729d41  llvm-objdump
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readobj
e2be4772aeaafffb1b3ac8e3cea371458455408cd2dca8dbd5b093173b882db7  not
83e50e9363e43ba10bcfc4e3cb2554c51c2e72489199cf3c23b81767601ffdaf  opt
165a0a852117b57fbb0c1f796e14007143c136dde5e04fbc25b6b54aa8373f24  split-file
```

## 3. The new test at the pristine pin — FAILS, as expected

The test file doesn't exist at the pin (it ships with `0044`), so both its `RUN` lines
were run by hand against `before-bin`, exactly reproducing what `llvm-lit` would do:

```
$ before-bin/llvm-mc -triple mos -mcpu=mosw65816 -disassemble long-address-roundtrip-65816.s
	lda	240
	sta	240
	lda	43981,x
	jmp	240
	jsl	240
	lda	15395562
	jmp	15395562
$ before-bin/FileCheck long-address-roundtrip-65816.s < (above)
long-address-roundtrip-65816.s:14:10: error: CHECK: expected string not found in input
# CHECK: lda mos24(240)
```

**FAIL — RUN1_RC=1.** Confirms the plan's own recorded pre-fix output. The round-trip
(`--check-prefix=RT`) half also fails, with the exact byte narrowing the plan describes:

```
$ before-bin/llvm-mc -disassemble ... | before-bin/llvm-mc -show-encoding ...
	lda	240   ; encoding: [0xa5,0xf0]        (was: af f0 00 00 — DBR-relative, wrong bank)
	sta	240   ; encoding: [0x85,0xf0]        (was: 8f f0 00 00)
	lda	43981,x ; encoding: [0xbd,0xcd,0xab]  (was: bf cd ab 00)
	jmp	240   ; encoding: [0x4c,0xf0,0x00]    (was: 5c f0 00 00 — wrong ROM bank)
	jsl	240   ; encoding: [0x22,0xf0,0x00,0x00] (unaffected — no narrower form)
	lda	15395562 ; unaffected (already unambiguous)
	jmp	15395562 ; unaffected
```

**FAIL — RUN2_RC=1.**

## 4. `0044` applied ALONE (no `0039`) — the empirical answer to the stacked-dependency question

Applied `0044` to the pristine source, rebuilt incrementally (58 ninja steps — only the
MOS-target files recompile and four tools relink: `llc opt llvm-mc llvm-objdump`; `count
FileCheck llvm-config llvm-readobj not split-file` are byte-identical to `before-bin`, as
expected for a change confined to `LLVMMOSDesc`). Snapshotted as `build/0044only-bin/`.

**The print half (`CHECK`, RUN1) already PASSES with 0044 alone** — this is purely the
printer, and it works standalone:

```
$ 0044only-bin/llvm-mc -disassemble long-address-roundtrip-65816.s
	lda	mos24(240)
	sta	mos24(240)
	lda	mos24(43981),x
	jmp	mos24(240)
	jsl	mos24(240)
	lda	15395562
	jmp	15395562
$ 0044only-bin/FileCheck long-address-roundtrip-65816.s < (above)
RUN1_RC=0  PASS
```

**The round-trip half (`RT`, RUN2) still FAILS with 0044 alone** — and it fails *worse*
than the pre-fix narrowing, not just the same amount:

```
$ 0044only-bin/llvm-mc -disassemble ... | 0044only-bin/llvm-mc -show-encoding ...
	lda	mos24(240)         ; encoding: [0xa5,0xf0]         <- ZERO PAGE, not just absolute
	sta	mos24(240)         ; encoding: [0x85,0xf0]         <- ZERO PAGE
	lda	mos24(43981),x     ; encoding: [0xb5,0xcd]         <- zero page,X, address TRUNCATED
                                                                 to one byte (43981 -> 0xcd)
	jmp	mos24(240)         ; encoding: [0x4c,0xf0,0x00]     <- bank-local jump, wrong bank
	jsl	mos24(240)         ; encoding: [0x22,0xf0,0x00,0x00] <- unaffected (no narrower form)
	lda	15395562           ; unaffected (already unambiguous)
	jmp	15395562           ; unaffected
RUN2_RC=1  FAIL
```

**Exact recorded outcome: with `0044` alone, `lda`/`sta`/`lda ,x`/`jmp` on a `mos24(...)`
constant still re-parse to a narrower opcode — for `lda`/`sta` this is zero page, not
merely absolute, and the indexed form's address is truncated to 8 bits.** Only `jsl`
(no narrower encoding exists) and the two `> 0xFFFF` bare-constant cases round-trip
correctly without `0039`. This is because the pre-`0039` parser's width check for a
modified constant compares the value against the *modifier's own* width, not the
*candidate opcode's* width, so `mos24(240)` under 6502-legacy width selection still
matches zero page before it ever gets to compare against absolute-long. **`0044`'s test
does not pass without `0039` — confirmed by direct build, not inferred from source
reading.**

## 5. `0039` applied on top of `0044` — PASSES

Applied `0039`, rebuilt incrementally (5 ninja steps: `MOSAsmParser.cpp` recompiles,
`libLLVMMOSAsmParser.a` relinks into `llvm-mc`/`llc`/`opt`). Snapshotted as
`build/after-bin/`; confirmed the same four tools differ from `before-bin` and none of
the other six do (same set as the 0044-only step — no additional tool touched by 0039):

```
9a7cd72cec2442cd9a6470c5a6a45f39458e22be63c9eeaa788e0559288ed30a  llc
dd80af24f41677c939c7d024df290110e6fd8aea55d986c4b6b319088e3d59cb  llvm-mc
78d2698a090ffff7a75335d5a6296e862c577d70cd374a56931a2238e1e2e660  llvm-objdump
1f38dcd45dea00e423a119f307bbc32fd9fab45682c9410858bd1e8064c4e583  opt
```

```
$ after-bin/llvm-mc -disassemble ... | after-bin/llvm-mc -show-encoding ...
	lda	mos24(240)     ; encoding: [0xaf,0xf0,0x00,0x00]   CORRECT (was af, stayed af)
	sta	mos24(240)     ; encoding: [0x8f,0xf0,0x00,0x00]   CORRECT
	lda	mos24(43981),x ; encoding: [0xbf,0xcd,0xab,0x00]   CORRECT
	jmp	mos24(240)     ; encoding: [0x5c,0xf0,0x00,0x00]   CORRECT — right bank
	jsl	mos24(240)     ; encoding: [0x22,0xf0,0x00,0x00]   CORRECT
	lda	15395562       ; encoding: [0xaf,0xea,0xea,0xea]   unaffected
	jmp	15395562       ; encoding: [0x5c,0xea,0xea,0xea]   unaffected
RUN1_RC=0  RUN2_RC=0  BOTH PASS
```

Also confirmed via the real `llvm-lit` runner, not just the manual `RUN`-line replication:

```
$ llvm-lit -s -v llvm/test/MC/MOS/long-address-roundtrip-65816.s
Total Discovered Tests: 1
  Passed: 1 (100.00%)
```

**PASS.**

## 6. Full MOS lit suites at `pin + 0039 + 0044`

```
$ llvm-lit -s llvm/test/CodeGen/MOS llvm/test/MC/MOS
Total Discovered Tests: 122
  Unsupported:   1 (0.82%)
  Passed     : 121 (99.18%)
```

**0 failures.** One test (`MC/MOS/addr-asciz.s`) initially failed on both this state and
every other state in this validation with `llvm-readelf: command not found` — a
missing-tool artifact of the trimmed build target list (`llvm-readelf` is a symlink
target that building `llvm-readobj` alone does not create — the exact gap the
`claude-batch-review.md` review already flagged for `0043`/`0046`). Built it as a fourth
follow-up step (`cmake --build ... --target llvm-readelf`) and reran: 0 failures.

122 discovered vs. the `0043`/`0046` validations' 118/119 is **not** a discrepancy — this
tree carries 4 new test files (`0039`'s three: `modifier-width.s`,
`modifier-width-65816.s`, `modifier-width-errors.s`; `0044`'s one:
`long-address-roundtrip-65816.s`), 118 + 4 = 122. And the fork's usual "4 known failures"
showing up as **0** here is the same explained-not-discrepant pattern the siblings
recorded: of the four, `CodeGen/MOS/legalizer.mir`, `MC/MOS/addressing-modes-65816.s`,
and `CodeGen/MOS/shift-rotate.ll` exist as pristine-upstream files at this pin and are
discovered and pass cleanly; the fourth, `CodeGen/MOS/scavenger-p-undef-6502.ll`, does
not exist at this pin at all (added later by patch `0011`/`0042`, not applied here) —
confirmed directly:

```
EXISTS  CodeGen/MOS/legalizer.mir
ABSENT  CodeGen/MOS/scavenger-p-undef-6502.ll
EXISTS  CodeGen/MOS/shift-rotate.ll
EXISTS  MC/MOS/addressing-modes-65816.s
```

## 7. `0044` alone causes no suite regressions (bonus check)

Swapped `build/0044only-bin/{llc,opt,llvm-mc,llvm-objdump}` into the live build directory
(binaries only — the source tree still had both patches' test files present) and reran
the full suites:

```
Total Discovered Tests: 122
  Unsupported:   1 (0.82%)
  Passed     : 118 (96.72%)
  Failed     :   3 (2.46%)
    LLVM :: MC/MOS/long-address-roundtrip-65816.s   (its own RT half — §4, expected)
    LLVM :: MC/MOS/modifier-width-65816.s            (0039's new test — needs 0039's binary fix)
    LLVM :: MC/MOS/modifier-width.s                  (0039's new test — needs 0039's binary fix)
```

Exactly the three tests whose passing *depends on* code this binary doesn't have — no
other test regresses. Restored `after-bin` into the live build directory afterward and
reconfirmed 121/122 passed, 0 failed, before finishing.

## Summary

| Question | Answer |
|---|---|
| `0044` applies without `0039`? | **Yes** — clean, either order, no file overlap. |
| New test fails before `0044`? | **Yes** — both `CHECK` and `RT` halves fail, matching the plan's recorded bytes. |
| New test passes with `0044` alone (no `0039`)? | **No.** `CHECK` (print) half passes; `RT` (round-trip re-parse) half fails — `lda`/`sta` narrow to **zero page** (not just absolute), the indexed form's address **truncates to one byte**, and the long jump still lands in the wrong bank. Confirmed by direct build. |
| New test passes with `0039`+`0044`? | **Yes**, both halves, confirmed via manual `RUN`-line replication and the real `llvm-lit` runner. |
| Full MOS lit suites at `pin+0039+0044`? | **121/122 passed, 1 unsupported, 0 failed** (after building the `llvm-readelf` harness gap fix). |
| `0044` alone regress anything else? | **No** — swapping in 0044-only binaries only fails 0044's own RT half plus 0039's two not-yet-fixed tests; nothing else changes. |

**Conclusion: `0044` and `0039` fix opposite ends of the same round trip and must be
treated as a stacked pair for this specific defect (`0044`'s printer + `0039`'s parser),
even though `0044` applies and partially works standalone.** The PR body states this
explicitly.

## Not done

- No corpus / differential-gate run (`dev/run.sh corpus[-a16]`) in this isolated
  worktree — it has no SNES ROM toolchain wired beyond the lit suites. The plan's own
  verification record (`docs/plans/2026-09-24-asmprinter-long-address.md` §7 steps 5–6)
  already ran both corpus gates against this same patch on the main tree and both
  passed (80/80, and 79/79 with 0 xfail).
- `dev/regen-patch.sh` was not run live against the shared `vendor/` tree (other
  workers hold in-progress edits there); the plan's own verification record (§7 step 8)
  already confirmed `0044` reverse-applies cleanly out of a `0002` regeneration and does
  not leak into it.

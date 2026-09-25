# 0043 validation — inline-asm physreg constraints refuse an operand wider than the register

> **September 25 independent revision:** the evidence below describes the initial
> patch snapshot. The current artifact has additional review changes and validation
> in [the batch review](claude-batch-review.md). Earlier binary hashes identify only
> that earlier snapshot; they do not identify the revised patch.


**Patch:** [`patches/llvm-mos/0043-mos-inline-asm-physreg-width.patch`](../../../patches/llvm-mos/0043-mos-inline-asm-physreg-width.patch)
(1 file changed in `llvm/lib/Target/MOS/MOSISelLowering.cpp`, 1 new test file
`llvm/test/CodeGen/MOS/inline-asm-physreg-width.ll`).
**PR draft:** [`docs/upstream-inline-asm-physreg-width-pr.md`](../../upstream-inline-asm-physreg-width-pr.md).
**Plan:** [`docs/plans/2026-09-24-inline-asm-num-registers.md`](../../plans/2026-09-24-inline-asm-num-registers.md).

**Status: prepared, not posted. Posting is user-triggered.**

## What was built, and where

| | |
|---|---|
| Worktree | `/home/will/llvm-mos-65816-pr0043-pinval` (branch `throwaway/pr0043-pinval`, off `main`) |
| Source tree | fresh `vendor/llvm-mos`, shallow-cloned and pinned at `LLVM_MOS_PIN` = `8be0546128a55e78c63ca571d466aa72a782cd36`, edited in place |
| Host build directory | `build/llvm-mos` inside the worktree (mounted at `/work/build/llvm-mos` by `dev/container.sh`) |
| Configuration | Release, `MOS.cmake` cache trimmed to clang+lld, host clang-21 + lld, ccache |
| Pre-fix binaries | `build/before-bin/{llc,opt,llvm-mc,llvm-objdump,llvm-readobj,split-file,FileCheck,not}` |
| Post-fix binaries | `build/after-bin/{llc,opt,llvm-mc,llvm-objdump,llvm-readobj,split-file,FileCheck,not}` |

`git apply --check patches/llvm-mos/0043-mos-inline-asm-physreg-width.patch`
against the fresh pinned checkout: **clean** (no `-vendor` twin needed — the
patch is standalone, touches only `MOSISelLowering.cpp` plus one new test
file, and no other numbered patch in the stack touches that file).

sha256 of the built tool set (`llc` and `opt` are the only two that differ —
both statically link `LLVMMOSCodeGen`, which contains the patched
`MOSISelLowering.cpp`; every other tool is byte-identical before/after, as
expected for a change confined to one MOS-target source file):

```
BEFORE (build/before.sha256):
b1491614e051e414b49d3550bb0db2575fade4f8d673158b6c828d25a8b1e73b  count
08a28afd2e0b867db9713829710d171311e804f12468d19a5c1ed3b0260d429d  FileCheck
3d6b3f91996fc4a7f82807d355c69316ab9c5d9d2b773b3217540360c499c5c3  llc
00c91386374c13b3164ab8496b0fd2ebd3c500b7b68fea5a6e0724bf3abf65ac  llvm-config
a54056ed33e22fc883173f8c4c57eda9325d7b3bdb93e0f0fc6706f377480499  llvm-mc
d0dfcc82f0f6d7b0ad3db35b21de9ac8680cce726c34c99a30f10c4738497aa9  llvm-objdump
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readelf (-> llvm-readobj)
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readobj
e2be4772aeaafffb1b3ac8e3cea371458455408cd2dca8dbd5b093173b882db7  not
1642a7735bc4b2a02d9234959c4e36d18f8b0b7130da864757766ecd07d35309  opt
165a0a852117b57fbb0c1f796e14007143c136dde5e04fbc25b6b54aa8373f24  split-file

AFTER (build/after.sha256):
b1491614e051e414b49d3550bb0db2575fade4f8d673158b6c828d25a8b1e73b  count
08a28afd2e0b867db9713829710d171311e804f12468d19a5c1ed3b0260d429d  FileCheck
108ded5ef416a1b901978696ea4481331f04646d8e996b192bc6fb75bf4230cf  llc
00c91386374c13b3164ab8496b0fd2ebd3c500b7b68fea5a6e0724bf3abf65ac  llvm-config
a54056ed33e22fc883173f8c4c57eda9325d7b3bdb93e0f0fc6706f377480499  llvm-mc
d0dfcc82f0f6d7b0ad3db35b21de9ac8680cce726c34c99a30f10c4738497aa9  llvm-objdump
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readelf (-> llvm-readobj)
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readobj
e2be4772aeaafffb1b3ac8e3cea371458455408cd2dca8dbd5b093173b882db7  not
33ca81cb9dde504c3efacbec13f2504a8c6c2f203ac650895a8c5488e8e09296  opt
165a0a852117b57fbb0c1f796e14007143c136dde5e04fbc25b6b54aa8373f24  split-file
```

`count`, `llvm-config` and `llvm-readelf` (a symlink to `llvm-readobj`) were
not in the initial trimmed target list and were built as three small
follow-up `cmake --build` steps (each confirmed to leave `vendor/` in the
exact same patched/unpatched state it started in, immediately before and
after) — `llvm-lit`'s own config needs `llvm-config`, and `count` and
`llvm-readelf` are RUN-line tools the lit suites themselves invoke.

## 1. Before/after repro — the headline defect

`asm("" : "=a"(i16))` as an output: before this change it silently narrows
the 16-bit value into the 8-bit `$a` and invents a zero high byte; after, it
hard-rejects at instruction selection. `one.ll` is the plan's repro:

```llvm
define i16 @f() {
  %v = call i16 asm "lda #42", "=a"()
  ret i16 %v
}
```

```
$ build/before-bin/llc -mtriple=mos -mcpu=mosw65816 one.ll -o -
	...
f:                                      ; @f
; %bb.0:
	;APP
	lda	#42
	;NO_APP
	ldx	#0
	rts
...
rc=0

$ build/after-bin/llc -mtriple=mos -mcpu=mosw65816 one.ll -o -
LLVM ERROR: unable to translate instruction: call (in function: f)
PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/ ...
Stack dump:
0.	Program arguments: build/after-bin/llc -mtriple=mos -mcpu=mosw65816 one.ll -o -
1.	Running pass 'Function Pass Manager' on module 'one.ll'.
2.	Running pass 'IRTranslator' on function '@f'
...
rc=134
```

Confirmed deterministic and repeatable against the sha256-verified
`before-bin`/`after-bin` binaries above (re-run twice each, identical result
both times).

## 2. New test: fails before, passes after

```
=== BEFORE: new test (expect FAIL) ===
-- Testing: 1 tests, 1 workers --
FAIL: LLVM :: CodeGen/MOS/inline-asm-physreg-width.ll (1 of 1)
******************** TEST 'LLVM :: CodeGen/MOS/inline-asm-physreg-width.ll' FAILED ********************
...
# RUN: at line 3
not --crash .../llc -mtriple=mos -mcpu=mos6502 .../wide_a.ll -o /dev/null 2>&1 | FileCheck ... --check-prefix=REJECT-A
# executed command: not --crash .../llc -mtriple=mos -mcpu=mos6502 .../wide_a.ll -o /dev/null
# note: command had no output on stdout or stderr
# error: command failed with exit status: 1
# executed command: .../FileCheck ... --check-prefix=REJECT-A
# .---command stderr------------
# | FileCheck error: '<stdin>' is empty.
# `-----------------------------
# error: command failed with exit status: 2

Total Discovered Tests: 1
  Failed: 1 (100.00%)

=== AFTER: new test (expect PASS) ===
-- Testing: 1 tests, 1 workers --
Total Discovered Tests: 1
  Passed: 1 (100.00%)
```

`not --crash` on `before-bin` fails because `llc` exits **0** on `wide_a.ll`
pre-fix (no crash — it silently narrowed the value, exactly the defect this
patch closes), so the test correctly reports the pre-fix state as a failure.

## 3. Full MOS suites (after-bin)

```
-- Testing: 119 tests, 8 workers --
Testing:  0.. 10.. 20.. 30.. 40.. 50.. 60.. 70.. 80.. 90..

Testing Time: 2.50s

Total Discovered Tests: 119
  Unsupported:   1 (0.84%)
  Passed     : 118 (99.16%)
```

**0 failures, 118/119 pass, 1 unsupported.** This is a bare `pin + 0043`
tree (119 tests), not the fork's fuller 154-159-test stack, so the extra
tests other patches add are simply absent — but that's not why this run has
no failures where the full stack shows 4. Checked directly: three of the
four full-stack known-failing tests (`CodeGen/MOS/legalizer.mir`,
`MC/MOS/addressing-modes-65816.s`, `CodeGen/MOS/shift-rotate.ll`) exist as
pristine-upstream files at this pin and **are** discovered and counted in
the 119 here, passing cleanly. The fourth, `CodeGen/MOS/scavenger-p-undef-6502.ll`,
does not exist at the pin at all — it's added by patch `0011`/`0042`, not
applied in this validation. So those four failures are a property of the
rest of the fork's patch stack (chiefly `0002`'s 65816 accum16 codegen), not
reproducible or relevant at the `pin + 0043` level, and their absence here
is not a discrepancy to explain away. The relevant comparison stays
before-bin vs. after-bin on identical source, which is clean. One test,
`MC/MOS/addr-asciz.s`, initially failed on
**both** `before-bin` and `after-bin` with `llvm-readelf: command not found`
— a missing-tool artifact of this validation's trimmed build (`llvm-readelf`,
a symlink to `llvm-readobj`, was not in the original target list), unrelated
to the patch. Built it as a fourth small follow-up step and reran: passes on
both before-bin and after-bin, confirming it was purely a validation-harness
gap, not a codegen difference. The new `inline-asm-physreg-width.ll` test is
included in the 118 passes.

## 4. The breaking commit

The disagreement was created by
[`f7593f2a15e20243244b2f7fb6b19cebeb717618`](https://github.com/llvm-mos/llvm-mos/commit/f7593f2a15e20243244b2f7fb6b19cebeb717618)
— "Place 16-bit inline assembly values in Imag16." (2021-07-14). That commit
is what **added** `getNumRegistersForInlineAsm` (the VT-only hook, with the
unconditional `i16 → 1` special case). `getRegForInlineAsmConstraint`
already existed before it, from the original MOS backend bring-up
(`39e9974f67acc0d52297899edfd9994363649a82`, "Squashed commit of the MOS code
generator.", 2021-03-06), and its `'a'`/`'x'`/`'y'`/`'R'` cases already
returned a fixed 8-bit register regardless of VT at that point. The
2021-07-14 commit updated only the `'r'` case (to return `Imag16` for `i16`)
to keep it consistent with the new `getNumRegistersForInlineAsm` hook it was
introducing — it did not touch `'a'`/`'x'`/`'y'`/`'R'`/`'d'`, which is exactly
where the two hooks fell out of agreement. Diff of that commit's relevant
hunk:

```diff
+unsigned MOSTargetLowering::getNumRegistersForInlineAsm(LLVMContext &Context,
+                                                        EVT VT) const {
+  // 16-bit inputs and outputs must be passed in Imag16 registers to allow using
+  // pointer values in inline assembly.
+  if (VT == MVT::i16)
+    return 1;
+  return TargetLowering::getNumRegistersForInlineAsm(Context, VT);
+}
+
 TargetLowering::ConstraintType
 MOSTargetLowering::getConstraintType(StringRef Constraint) const {
   if (Constraint.size() == 1) {
@@ -76,6 +85,8 @@ MOSTargetLowering::getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
     default:
       break;
     case 'r':
+      if (VT == MVT::i16)
+        return std::make_pair(0U, &MOS::Imag16RegClass);
       return std::make_pair(0U, &MOS::Imag8RegClass);
     case 'R':
       return std::make_pair(0U, &MOS::GPRRegClass);
```

## 5. Patch-stack integration

- Standalone patch, not folded into `0002`. Confirmed no overlap with any
  other patch in the stack: `MOSISelLowering.cpp` carries no other numbered
  patch's hunks at this pin, and `git apply --check` at bare pin succeeded
  cleanly (§ "What was built, and where" above).
- `0002` was not regenerated from the shared `vendor/` (it is a hot tree
  other workers are actively editing); instead confirmed statically that the
  live `patches/llvm-mos/0002-321-accum16.patch` carries none of this
  change's symbols:

```
$ grep -c "isWiderThan\|inline-asm-physreg-width" patches/llvm-mos/0002-321-accum16.patch
0
```

## Not done

- `dev/regen-patch.sh` was not run live against the shared `vendor/` tree
  (other workers hold in-progress edits there); only the static check above
  was performed. A live round-trip remains unverified, matching the same
  caveat recorded in the plan's own verification record.
- No corpus / differential-gate run (`dev/run.sh corpus[-a16]`) — this
  worktree has no SNES ROM toolchain wired beyond the lit suites, and the
  defect and its fix are inline-asm/register-allocation-only; nothing in the
  SNES corpus exercises a physreg-constrained wide inline-asm operand. The
  plan's own verification record (§6, 2026-09-24) already ran both corpus
  gates against this same patch on the main tree and both passed.

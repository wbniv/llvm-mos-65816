# 0047 validation — `llvm-mc -show-encoding` crash on a symbolic `.mos_addr_asciz`

> **Worktree relocation, September 25:** this completed validation checkout was
> retired to recover disk space. Its compiler snapshots, reproducers, logs, and
> source changes remain under `build/retired-worktrees/2026-09-25/llvm-mos-65816-pr0047-pinval/`.
> Original paths below describe the captured run. See the
> [retirement and hash-verification record](../../investigations/2026-09-25-worktree-retirement.md).

> **September 25 independent revision:** the evidence below describes the initial
> patch snapshot. The current artifact has additional review changes and validation
> in [the batch review](claude-batch-review.md). Earlier binary hashes identify only
> that earlier snapshot; they do not identify the revised patch.


**Patch:** [`patches/llvm-mos/0047-mos-mc-addr-asciz-symbolic-crash.patch`](../../../patches/llvm-mos/0047-mos-mc-addr-asciz-symbolic-crash.patch)
(4 files: three source files, one test).
**PR draft:** [`docs/upstream-mc-addr-asciz-symbolic-crash-pr.md`](../../upstream-mc-addr-asciz-symbolic-crash-pr.md).
**Plan:** [`docs/plans/2026-09-24-mc-addr-asciz-symbolic-crash.md`](../../plans/2026-09-24-mc-addr-asciz-symbolic-crash.md).

**Status: prepared, not posted. Posting is user-triggered.**

## Patch-apply ordering — answered first

`0039-mos-asm-modifier-width.patch` and `0047` both touch `AsmParser/MOSAsmParser.cpp`,
in different functions (`0039`: `isImmInRange`'s constant exit; `0047`:
`parseDirectiveAddrAsciz`). Checked empirically against a fresh pinned checkout
(`LLVM_MOS_PIN` = `8be0546128a55e78c63ca571d466aa72a782cd36`), **without** `0039`
applied:

```
$ git -C vendor/llvm-mos apply --check patches/llvm-mos/0047-mos-mc-addr-asciz-symbolic-crash.patch
STANDALONE_OK
```

Confirmed with a real (non-`--check`) apply on the same bare-pin checkout — touches
exactly the four files below, no conflict, no fuzz:

```
 M llvm/lib/Target/MOS/AsmParser/MOSAsmParser.cpp
 M llvm/lib/Target/MOS/MCTargetDesc/MOSMCExpr.cpp
 M llvm/lib/Target/MOS/MCTargetDesc/MOSModifierNames.cpp
 M llvm/test/MC/MOS/addr-asciz.s
```

**`0047` is standalone — it has no patch-apply-ordering dependency on `0039`.** The
plan's phrasing ("sits in `dev/toolchain.sh`'s apply order after `0039`, since it
touches the same file") is conservative fork-bookkeeping ordering, not a genuine
hunk-context dependency; the fix itself (`parseDirectiveAddrAsciz`) doesn't depend on
`isImmInRange`'s behavior either.

Gotcha for anyone repeating this check: `git -C <dir> apply --check <relative-path>`
resolves the relative patch path against `<dir>`, not the caller's cwd — `-C` changes
directory for the whole command, argument resolution included. Pass an absolute patch
path, or the check spuriously fails with "No such file or directory" that looks like a
missing patch rather than a path bug.

## What was built, and where

| | |
|---|---|
| Worktree | `/home/will/llvm-mos-65816-pr0047-pinval` (branch `throwaway/pr0047-pinval`) |
| Source tree | fresh `git init` + `fetch --depth 1` + `checkout --detach` of `vendor/llvm-mos` at the pin |
| Configuration | Release, `MOS.cmake` cache, assertions off, `-DLLVM_CCACHE_BUILD=On` |
| Build targets | `llc opt llvm-mc llvm-objdump llvm-readobj split-file FileCheck not`, plus `llvm-readelf` (added mid-run — see note below) |

**Note on a build-target gap and a concurrent-worktree hazard, found and worked around
during this validation:**

- The initial build target list (`llc opt llvm-mc llvm-objdump llvm-readobj split-file
  FileCheck not`) omits `llvm-readelf`, which `addr-asciz.s`'s *existing*
  `--filetype=obj` `RUN` line needs. First lit attempt against it failed with `command
  not found`, exit 127 — a build-target gap in the validation harness, not a code
  regression. Fixed by building the `llvm-readelf` target (a symlink to
  `llvm-readobj`) before re-running lit.
- Mid-session, a second agent operating on this same task began running its own
  build/apply/revert cycles **in this same worktree** concurrently with this one
  (visible via `ps aux`: overlapping `flock`/`cmake --build`/`git checkout`/`git apply`
  invocations against the identical paths). This produced real, observed corruption —
  `build/before-bin` and `build/after-bin` were each overwritten out from under one
  agent by the other mid-sequence, to the point that a naive read of
  `build/before.sha256`/`build/after.sha256` at one point showed **both** labeled sets
  crashing on the repro (i.e. neither was a valid post-fix build) because the
  directories had been clobbered between build and read. This was caught by testing
  the actual binaries against the crash repro rather than trusting the sha256 file
  labels, and resolved by rebuilding into uniquely-named directories
  (`build/w47-before-bin`, `build/s017after-bin`) and copying the result out to a
  private scratch directory immediately after each build, before anything else could
  touch it. All numbers below are from binaries verified intact (re-hashed and
  re-tested) at the moment they were used. **Net effect on the result: none** — three
  independent pristine builds agreed on one behavior (crash) and two independent
  patched builds agreed on the other (no crash), so the corruption was caught, not
  silently absorbed into a wrong number. Flagged here so a reviewer doesn't mistake the
  odd-looking intermediate directory names for a methodology error.

## 1. The crash, reproduced pre-fix

```
$ llvm-mc -triple mos -motorola-integers -show-encoding
	.section	.header,"a",@progbits
	.mos_addr_asciz	_start, 5
LLVM ERROR: Don't know how to emit this value.
PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/ and include the crash backtrace and instructions to reproduce the bug.
Stack dump:
...
 #10 llvm::MOSAsmParser::parseDirectiveAddrAsciz(llvm::SMLoc) MOSAsmParser.cpp:0:0
 #11 llvm::MCTargetAsmParser::parseDirective(llvm::AsmToken)
 #12 (anonymous namespace)::AsmParser::parseStatement(...)
 #13 (anonymous namespace)::AsmParser::Run(bool, bool)
 #14 AssembleInput(...)
 #15 main
bash: Aborted (core dumped)
```

Reproduced identically across three independent from-scratch builds of the bare pin
(no patches). All three agree byte-for-byte on the crash stack and on two of three
`sha256` values that matter for this fix (`llc`, `llvm-mc`, `llvm-objdump`, `opt` — the
four tools that statically link `libLLVMMOSAsmParser.a`/`libLLVMMOSDesc.a`; the
non-deterministic third-run hash differences on `llc`/`llvm-mc`/`llvm-objdump`/`opt`
are expected — LLVM Release builds are not byte-reproducible run-to-run even from
identical source — but all three runs agree on the crash).

## 2. Post-fix — same repro, clean

```
$ llvm-mc -triple mos -motorola-integers -show-encoding
	.section	.header,"a",@progbits
	.mos_addr_asciz	_start, 5
EXIT=0
```

Also checked a genuinely-symbolic (not parse-time-foldable) operand:

```
$ cat repro2.s
.section .header,"a",@progbits
label_a:
  .space 1
label_b:
  .mos_addr_asciz label_b-label_a, 5
$ llvm-mc -triple mos -motorola-integers -show-encoding repro2.s
	.section	.header,"a",@progbits
label_a:
	.zero	1
label_b:
	.mos_addr_asciz	label_b-label_a, 5
EXIT=0
```

Confirmed via two independent builds from the 0047-patched source (one via the normal
target list, one via a from-scratch rebuild after re-applying `0047` to a freshly
reverted pristine tree); both agree on `sha256` for `llc`/`llvm-mc`/`llvm-objdump`/`opt`
and both produce this exact clean output.

## 3. `--filetype=obj` regression check — unaffected

```
$ cat addr-asciz-obj.s
.section .header,"a",@progbits
  .mos_addr_asciz _start, 5
  .mos_addr_asciz 42, 5
$ llvm-mc -triple mos -motorola-integers --filetype=obj -o=t.obj addr-asciz-obj.s
$ llvm-readobj --relocs -x .header t.obj
File: t.obj
Format: elf32-mos
Relocations [
  Section (4) .rela.header {
    0x0 R_MOS_ADDR_ASCIZ _start 0x0
  }
]
Hex dump of section '.header':
0x00000000 30000000 00003432 00000000          0.....42....
```

Matches the existing test's `CHECK`/`CHECK-NEXT` expectations exactly (also covered by
the lit run below). The fix only adds a new branch guarded by `hasRawTextSupport()`,
which is `false` on the object-file (ELF) streamer, so this path is provably untouched
by the change — confirmed, not just argued.

## 4. New test and full suites

```
$ llvm-lit -s -v llvm/test/MC/MOS/addr-asciz.s
-- Testing: 1 tests, 1 workers --
Total Discovered Tests: 1
  Passed: 1 (100.00%)
```

Both `RUN` lines pass: the pre-existing `--filetype=obj` line and the new
`-show-encoding` line with its `# ASM: .mos_addr_asciz _start, 5` `CHECK`.

```
$ llvm-lit -s llvm/test/CodeGen/MOS llvm/test/MC/MOS
-- Testing: 118 tests, 8 workers --
Total Discovered Tests: 118
  Unsupported:   1 (0.85%)
  Passed     : 117 (99.15%)
```

**0 failed.** This build is the bare pin plus `0047` only (no other fork patch, per
this task's isolation requirement) — of the fork's four usually-tracked known-failing
tests, only three (`legalizer.mir`, `addressing-modes-65816.s`, `shift-rotate.ll`) even
exist as files at this pin (`scavenger-p-undef-6502.ll` does not), and none of the
three fail here. That is expected, not a discrepancy: those failures are a property of
the fork's full patch stack (chiefly `0002`'s 65816 accum16 codegen changes), which
this isolated pin+`0047` build does not include. The 159/118 test-count difference from
other validation docs in this repo (which run against the live, fully-patched
`vendor/llvm-mos`) is the same cause — more MOS test files exist once the rest of the
patch stack's own test additions are layered in.

## 5. `sha256` — final, verified-intact values

Pristine pin (before), three independent builds agreed on behavior; representative
hashes from the last one, re-verified immediately before use:

```
08a28afd2e0b867db9713829710d171311e804f12468d19a5c1ed3b0260d429d  FileCheck
3d6b3f91996fc4a7f82807d355c69316ab9c5d9d2b773b3217540360c499c5c3  llc
a54056ed33e22fc883173f8c4c57eda9325d7b3bdb93e0f0fc6706f377480499  llvm-mc
d0dfcc82f0f6d7b0ad3db35b21de9ac8680cce726c34c99a30f10c4738497aa9  llvm-objdump
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readobj
e2be4772aeaafffb1b3ac8e3cea371458455408cd2dca8dbd5b093173b882db7  not
1642a7735bc4b2a02d9234959c4e36d18f8b0b7130da864757766ecd07d35309  opt
165a0a852117b57fbb0c1f796e14007143c136dde5e04fbc25b6b54aa8373f24  split-file
```

Pin + `0047` (after):

```
08a28afd2e0b867db9713829710d171311e804f12468d19a5c1ed3b0260d429d  FileCheck
97693e5aa2179c25928fd53fa93483ae8f3f20e5728feb8e76d02d5ebfb4e5c4  llc
1dcce0e3940b1fa77b1e4dc94dfb1320466ba0bf3632bf5fd957152eb812c0b9  llvm-mc
968791f95b3a3b29f7075ab08d0819446dc21c7239f41c3215fcb2856963d017  llvm-objdump
6958f18390b05c36508862f376e06debb4ca260dc7c1f46ed201ac2256c93630  llvm-readobj
e2be4772aeaafffb1b3ac8e3cea371458455408cd2dca8dbd5b093173b882db7  not
39ac9cee4928ca77eedac494e07e32175339c829c969ba58d20cf01eb2f23670  opt
165a0a852117b57fbb0c1f796e14007143c136dde5e04fbc25b6b54aa8373f24  split-file
```

Exactly the tools that statically link `libLLVMMOSAsmParser.a`/`libLLVMMOSDesc.a`
(`llc`, `llvm-mc`, `llvm-objdump`, `opt`) change hash; `FileCheck`, `llvm-readobj`,
`not`, `split-file` (no MOS target dependency) are byte-identical before and after, as
expected for a change confined to the MOS AsmParser/MCTargetDesc.

## 6. Breaking commit

[`6cbcc49db9b2903bf78d78d207da150d53e8cf39`](https://github.com/llvm-mos/llvm-mos/commit/6cbcc49db9b2903bf78d78d207da150d53e8cf39)
— "`.mos_addr_asciz` target directive with `R_MOS_ADDR_ASCIZ`" (2022-01-17). Added
`parseAddrAsciz` (now `parseDirectiveAddrAsciz`) calling `getStreamer().emitValue(...)`
unconditionally on the symbolic branch (no `hasRawTextSupport()` guard), and added
`VK_MOS_ADDR_ASCIZ`'s (now `VK_ADDR_ASCIZ`) `evaluateAsInt64` case as
`llvm_unreachable`. The same commit never added a `MOSModifierNames.cpp` entry for the
new `VariantKind` either. All three root causes trace to this one commit. Confirmed via
`gh api repos/llvm-mos/llvm-mos/commits/<sha>` — file list and patch hunks for both
`MOSAsmParser.cpp` and `MOSMCExpr.cpp` inspected directly; `MOSModifierNames.cpp` is
absent from that commit's file list, confirming the omission.

Hexagon precedent for the `hasRawTextSupport()` discriminator, verified directly
against `llvm/llvm-project` (not assumed from the plan):
`llvm/lib/Target/Hexagon/AsmParser/HexagonAsmParser.cpp`, lines 102 (`getAssembler()`),
791 (`ParseDirectiveComm`: `if (getStreamer().hasRawTextSupport()) return true; // Only
object file output requires special treatment.`), and 1517.

## 7. Patch-stack integration

Registered in `dev/toolchain.sh` (applied after `0046`) and in `dev/regen-patch.sh`'s
`STANDALONE_MOSDIR` list, per the plan. Not exercised via a live `dev/regen-patch.sh`
run in this validation (the plan's own note on `0002`/`dev/regen-patch.sh` carrying
other workers' uncommitted state applies here too); the plan's own manual
pristine-worktree apply-and-diff round-trip (recorded in the plan's Results §5) is the
authoritative round-trip check for this patch.

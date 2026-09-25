# 0046 validation — `MOSFixupKinds.cpp` missing `AddrAsciz` row

> **September 25 independent revision:** the evidence below describes the initial
> patch snapshot. The current artifact has additional review changes and validation
> in [the batch review](claude-batch-review.md). Earlier binary hashes identify only
> that earlier snapshot; they do not identify the revised patch.


**Patch:** [`patches/llvm-mos/0046-mos-fixupkinds-addrasciz-row.patch`](../../../patches/llvm-mos/0046-mos-fixupkinds-addrasciz-row.patch)
(19 lines, 1 file).
**PR draft:** [`docs/upstream-fixupkinds-addrasciz-row-pr.md`](../../upstream-fixupkinds-addrasciz-row-pr.md).
**Plan:** [`docs/plans/2026-09-24-fixupkinds-addrasciz-row.md`](../../plans/2026-09-24-fixupkinds-addrasciz-row.md).

**Status: prepared, not posted. Posting is user-triggered.**

## No new lit test — stated up front

This patch adds no regression test. `Info.Name`/table-completeness is an
internal `MCFixupKindInfo` property with no lit-level observation point (no
`llvm-mc`/`llc` flag prints a fixup kind's name or table row for a data
directive fixup). The validation below is therefore *not* a fail-before/
pass-after test; it is (a) a clean apply against the pin, (b) the one
existing test that exercises this fixup kind passing identically before and
after, (c) the full MOS lit suites being byte-identical in pass/fail count
before and after, and (d) the source diff itself, checked against the enum.

## What was built, and where

| | |
|---|---|
| Host build directory | `/home/will/llvm-mos-65816-pr0046-pinval/build/llvm-mos` (mounted at `/work/build/llvm-mos`) |
| Source tree | `vendor/llvm-mos` at `LLVM_MOS_PIN` = `8be0546128a55e78c63ca571d466aa72a782cd36`, fresh shallow checkout in an isolated worktree |
| Configuration | Release, `MOS.cmake` cache (clang;lld only), assertions off, `LLVM_CCACHE_BUILD=On` |
| Targets built | `llc opt llvm-mc llvm-objdump llvm-readobj split-file FileCheck not` |

## 1. Apply-check against the pin

```
$ git -C vendor/llvm-mos apply --check patches/llvm-mos/0046-mos-fixupkinds-addrasciz-row.patch
APPLY-CHECK OK
```

## 2. Row-count / enum confirmation, pre-patch

```
$ grep -n "AddrAsciz\|NumTargetFixupKinds" vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.h
43:  AddrAsciz,           // Address encoded as a decimal ASCII string.
45:  NumTargetFixupKinds = LastTargetFixupKind - FirstTargetFixupKind
$ grep -c '^\s*{"' vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.cpp
14
```

15 fixup kinds declared in the enum (`Imm8` … `PCRel16`, `AddrAsciz`), 14
`Infos[]` initialisers before the patch — confirms the plan's claim exactly.
After the patch, `Infos[]` has 15 rows, matching `NumTargetFixupKinds`.

## 3. Two binary snapshots, full suite both times

Built twice from the same configured tree: once at the pristine pin, once
with `0046` applied on top (only `MOSFixupKinds.cpp` recompiles — the rebuild
relinked exactly `llc`, `llvm-mc`, `llvm-objdump`, `opt`, which are the
binaries statically linking `libLLVMMOSDesc.a`; `FileCheck`, `llvm-readobj`/
`llvm-readelf`, `not`, `split-file` came back byte-identical, confirming the
patch touches nothing outside that one file).

| | before (pristine pin) | after (pin + 0046) |
|---|---|---|
| `llc` sha256 (first 24 hex) | `3d6b3f91996fc4a7f82807d3` | `495b379f5e5ea5bd91ae512a` |
| `llvm-mc` sha256 (first 24 hex) | `a54056ed33e22fc883173f8c` | `f1dc2d72206eb0f8f5df694d` |
| `llvm-objdump` sha256 (first 24 hex) | `d0dfcc82f0f6d7b0ad3db35b` | `2ed6249411ec308cb48a9ba7` |
| `opt` sha256 (first 24 hex) | `1642a7735bc4b2a02d923495` | `148084a86b668522e0e2db36` |
| `llvm-readobj`/`llvm-readelf` sha256 | `6958f18390b05c36508862f3` | `6958f18390b05c36508862f3` (identical) |

## 4. `MC/MOS/addr-asciz.s`

```
$ llvm-lit -s -v llvm/test/MC/MOS/addr-asciz.s      # before
Total Discovered Tests: 1
  Passed: 1 (100.00%)

$ llvm-lit -s -v llvm/test/MC/MOS/addr-asciz.s      # after
Total Discovered Tests: 1
  Passed: 1 (100.00%)
```

PASS, identically, on both sides.

## 5. Full MOS lit suites, before vs after

```
$ llvm-lit -s llvm/test/CodeGen/MOS llvm/test/MC/MOS      # before
-- Testing: 118 tests, 8 workers --
Total Discovered Tests: 118
  Unsupported:   1 (0.85%)
  Passed     : 117 (99.15%)

$ llvm-lit -s llvm/test/CodeGen/MOS llvm/test/MC/MOS      # after
-- Testing: 118 tests, 8 workers --
Total Discovered Tests: 118
  Unsupported:   1 (0.85%)
  Passed     : 117 (99.15%)
```

**Byte-identical counts before and after: 118 discovered, 117 passed, 1
unsupported, 0 failed, both runs.** Zero failures in either run and zero
change in outcome for any test.

118 vs. the fuller project tree's 157-159 is **not** a build-target gap —
`llc`/`llvm-mc`/etc. are exactly the tools `CodeGen/MOS` and `MC/MOS` RUN
lines need, no `clang`/`lli` required. It is a **test-file-count** gap: this
is a bare `pin + 0046` checkout, so it lacks the test files other patches in
the fork's stack add. Checked directly against this worktree's `vendor/`:
of the four tests the full-stack project docs track as known-and-unrelated
failures, three exist here as files (`CodeGen/MOS/legalizer.mir`,
`MC/MOS/addressing-modes-65816.s`, `CodeGen/MOS/shift-rotate.ll` — all
pristine-upstream, present at the bare pin) and **are counted in the 118**,
passing cleanly both before and after; only the fourth,
`CodeGen/MOS/scavenger-p-undef-6502.ll`, is absent from this tree (it does
not exist at the pin — it is added by patch `0011`/`0042`, neither of which
this validation applies). So this is not "those tests weren't discovered
here" — three of the four *are* discovered and pass; they simply don't fail
at the `pin + 0046` level. Their known failure in the full project tree is a
property of the rest of the patch stack (chiefly `0002`'s 65816 accum16
codegen changes interacting with those tests), not of this patch, and not
reproducible in isolation — which is itself confirmation that `0046` doesn't
cause or interact with them. What matters for this validation is that the
*set* of 118 and its pass/fail split are identical before and after — this
change adds no new failure and fixes no test, as expected for a latent-only
defect.

## 6. Source diff (the actual evidence)

```diff
--- a/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.cpp
+++ b/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.cpp
@@ -37,7 +37,13 @@ MOSFixupKinds::getFixupKindInfo(const MOS::Fixups Kind,
        0},                  // The high byte of the segment of a 24-bit addr
       {"Addr13", 0, 13, 0}, // A 13-bit address.
       {"PCRel8", 0, 8, 0},
-      {"PCRel16", 0, 16, 0}};
+      {"PCRel16", 0, 16, 0},
+      {"AddrAsciz", 0, 0,
+       0}, // Address encoded as a variable-width decimal ASCII string; the
+           // width is supplied per-call-site (emitMosAddrAsciz), so this
+           // fixup has no fixed TargetSize and must never be relaxed (see
+           // fixupNeedsRelaxationAdvanced's Info.TargetSize > N check).
+  };
```

## 7. Breaking commit

[`6cbcc49db9b2903bf78d78d207da150d53e8cf39`](https://github.com/llvm-mos/llvm-mos/commit/6cbcc49db9b2903bf78d78d207da150d53e8cf39)
("`.mos_addr_asciz` target directive with `R_MOS_ADDR_ASCIZ`", 2022-01-17)
added `AddrAsciz` to the `Fixups` enum in `MOSFixupKinds.h` but its file list
does not include `MOSFixupKinds.cpp` — the `Infos[]` array was never updated
to match.

## Upstream

Pristine-upstream, one-file, one-row fix. Queued as a TODO item ("Draft the
`0046` upstream PR"), mirroring the `0043`/`0044` queued-draft pattern.

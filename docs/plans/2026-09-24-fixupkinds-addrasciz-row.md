# `MOSFixupKinds.cpp` `Infos[]` missing the `AddrAsciz` row

**Date:** 2026-09-24 · **TODO:** M2 item "`MOSFixupKinds.cpp` `Infos[]` has 14 initialisers for
15 fixup kinds — add the `AddrAsciz` row." · **Branch:** `main` (one-line pristine-upstream fix,
not an investigation/spike; no worktree needed).

No visible surface (compiler backend table), so no mockups.

## The bug

`vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.h` declares 15 target fixup
kinds (`Imm8` … `PCRel16`, then `AddrAsciz`). `MOSFixupKinds.cpp`'s `Infos[MOS::NumTargetFixupKinds]`
array — documented as "must be in the same order as ... `MOSFixupKinds.h`" — has only 14
initialisers; the `AddrAsciz` row is missing entirely. `getFixupKindInfo` indexes this array
directly by `Kind - FirstTargetFixupKind`, so a lookup for `MOS::AddrAsciz` reads past the
written initialisers into the array's value-initialised tail: `MCFixupKindInfo{nullptr, 0, 0, 0}`.

Confirmed pristine-upstream (not caused by any fork patch):
`grep -l MOSFixupKinds.cpp patches/llvm-mos/*.patch` → no match.

Diagnosed in the 2026-09-24 #320 completeness audit,
[§1](../investigations/2026-09-24-mos24-far-addressing-completeness-audit.md#1-assembler--parser--mostly-done-one-real-gap-already-tracked),
via an AST-walk script that counted `Infos[]` elements against the enum.

## Why it's harmless today, and why the fix still matters

`AddrAsciz` fixups are only ever read through two paths:

- `MOSAsmBackend::fixupNeedsRelaxationAdvanced` (`MOSAsmBackend.cpp`): for a target-specific
  expression (`MOSMCExpr`, which is exactly how `.mos_addr_asciz` fixups are created —
  `MOSMCExpr.cpp:154` sets `Kind = MOS::AddrAsciz`), the relax decision is
  `Info.TargetSize > (BankRelax ? 16 : 8)`. With the missing row read as `TargetSize == 0`,
  this is always `false` — i.e. "never relax" — which is the *correct* answer: `AddrAsciz` is a
  variable-width decimal-ASCII data directive (`.mos_addr_asciz sym, N` — width `N` is supplied
  per-instance at the call site, see `MOSMCELFStreamer::emitMosAddrAsciz`), not a fixed-width
  instruction operand, so relaxation does not apply to it at all.
- `MOSAsmBackend::applyFixup`'s `case MOS::AddrAsciz:` branch writes the ASCII bytes directly and
  never touches `Info` at all.

So `Info.Name == nullptr` and `Info.TargetOffset == 0`/`Info.Flags == 0` are read by nothing
today, and `MC/MOS/addr-asciz.s` (the one existing lit test for this directive) already passes.
The defect is real but latent: the array's own documented invariant (14 rows for 15 kinds) is
silently violated, `Info.Name` is `nullptr` for any future diagnostic/debug path that prints it,
and the *next* fixup kind appended after `AddrAsciz` inherits the same off-by-one silently.

## The fix

Add the missing row to `Infos[]`, matching the existing rows' `{"Name", offset, bits, flags}`
convention (name = the bare enum-case string, as every other row already does — `"Imm8"` for
`Imm8`, `"Addr24_Segment_High"` for `Addr24_Segment_High`, etc.):

```cpp
{"AddrAsciz", 0, 0, 0}, // Address encoded as a variable-width decimal ASCII string; the
                        // width is supplied per-call-site (emitMosAddrAsciz), so this fixup
                        // has no fixed TargetSize and must never be relaxed (see
                        // fixupNeedsRelaxationAdvanced's Info.TargetSize > N check).
```

`TargetOffset = 0`, `TargetSize = 0`, `Flags = 0` are chosen deliberately (matching today's
accidental behaviour, but now documented and intentional): `TargetSize == 0` is what keeps
`fixupNeedsRelaxationAdvanced` from ever relaxing this fixup, which is correct since the
directive's width is caller-supplied, not something the assembler can widen.

## Regression guard

`Info.Name`/table-completeness is an internal `MCFixupKindInfo` property with no direct lit-level
observation point (`-show-encoding` etc. don't print fixup-kind names for a data directive fixup).
Rather than contort a lit test around an internal structure, add a `static_assert` immediately
above the `Infos[]` array in `MOSFixupKinds.cpp` pinning `sizeof(Infos) / sizeof(Infos[0]) ==
MOS::NumTargetFixupKinds` (or equivalently `std::size(Infos)`  — `NumTargetFixupKinds` is a
compile-time enum value, and the array bound is already declared as
`Infos[MOS::NumTargetFixupKinds]`, so this doesn't catch a *short* initializer list today — C++
zero-initializes the remaining elements rather than erroring. A `static_assert` on the bound
doesn't help either, since the array is already sized to the enum by construction.

So the actual guard that catches "too few initialisers" is a brace-count check, which isn't
expressible as a `static_assert` in C++17 without reflection. Instead: keep the array declaration
as-is (still enum-sized, so out-of-bounds reads can't happen), fix the row so the semantic value
read for `AddrAsciz` is no longer an accidental default, and add a comment cross-reference from
`MOSFixupKinds.h`'s enum to the `.cpp` array noting the row count must match by inspection — this
mirrors the existing "must be in the same order" comment already there. This is a documentation
strengthening, not a new mechanism, because C++ does not offer a compile-time way to assert an
aggregate initializer supplied *all* of an array's elements (only that it supplied no more than
the bound). Escalation note: if a stronger static guard is wanted later (e.g. converting `Infos`
to be built via a `constexpr` helper that fails to compile on a short list), that is a design
change beyond this T1 mechanical fix's remit.

## Verification

1. `dev/run.sh lit` — expect the same known-failing baseline (unaffected by this change; the
   change is a data-table completeness fix with no semantic effect on any currently-tested path).

```text
$ dev/run.sh lit vendor/llvm-mos/llvm/test/MC/MOS vendor/llvm-mos/llvm/test/CodeGen/MOS
-- Testing: 159 tests, 8 workers --
FAIL: LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll
FAIL: LLVM :: CodeGen/MOS/legalizer.mir
FAIL: LLVM :: MC/MOS/addressing-modes-65816.s
FAIL: LLVM :: CodeGen/MOS/shift-rotate.ll
Total Discovered Tests: 159
  Failed: 4
```

   Same 4 known-failing baseline named in the M2 TODO item "Vendor MOS lit suite has four
   failing tests" — unaffected by this change. Confirmed `MC/MOS/addressing-modes-65816.s` is a
   pre-existing failure unrelated to `MOSFixupKinds.cpp` by reverting the fix (`git stash push`
   on the one file inside `vendor/llvm-mos`) and re-running just that test in isolation — it
   still failed identically with the fix absent, and the test file does not reference `asciz`/
   `Asciz` at all. PASS (baseline unchanged; the one failure in the file's own suite is
   pre-existing and unrelated).

2. `MC/MOS/addr-asciz.s` still passes (already covers the only observable behaviour of this
   fixup kind — emission of the ASCII bytes and the ELF relocation).

   Included in the 159-test run above (`MC/MOS` suite); not in the failed list. PASS.

3. `dev/regen-patch.sh` round-trip check for the new standalone patch
   `0046-mos-fixupkinds-addrasciz-row.patch`.

```text
$ git -C vendor/llvm-mos worktree add --detach <scratch-wt> <pristine-HEAD>
$ git -C <scratch-wt> apply --check patches/llvm-mos/0046-mos-fixupkinds-addrasciz-row.patch
APPLY-CHECK OK
$ git -C <scratch-wt> apply patches/llvm-mos/0046-mos-fixupkinds-addrasciz-row.patch
$ diff -u <scratch-wt>/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.cpp \
          vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSFixupKinds.cpp
ROUNDTRIP IDENTICAL
```

   Done via a manual worktree apply-and-diff (not a live `dev/regen-patch.sh` run) because that
   script's own `STANDALONE_MOSDIR`/`TESTRELS` lists were mid-edit by other workers this session;
   `MOSFixupKinds.cpp` is confirmed untouched by `patches/llvm-mos/0002-321-accum16.patch`
   (`grep -l MOSFixupKinds.cpp patches/llvm-mos/*.patch` → no match), so there is no absorption
   risk from skipping a live regen. PASS.

No corpus/full-toolchain rebuild needed: this is a static-only fix (a data table read by the
assembler backend at MC-layer fixup resolution) fully exercised by the standalone lit build that
`dev/run.sh lit` already performs.

## Upstream

Pristine-upstream, one-file, one-row fix — a clean standalone upstream-postable artifact.
Queued as a TODO item ("Draft the `0046` upstream PR") mirroring the existing `0043`/`0044`
queued-draft pattern, rather than written inline here: the PR-prep doc template those two use
(`docs/pr-preparations/`) needs its own validation record against the pinned base and a
`docs/upstream-contribution-status.md` entry, which is its own unit of work, not a T1 mechanical
step. The item is left **unranked** in TODO.md (`- [ ]`) because assigning a delegation tier is
not something a T1 dispatch does — ranking is reserved to the orchestrator per
`~/CLAUDE.md` "Delegation" (enforced by a `PreToolUse[Write|Edit]` guard hook that denies a
non-Fable model adding a tier marker). Suggested tier: T2, matching its `0043`/`0044` twins.

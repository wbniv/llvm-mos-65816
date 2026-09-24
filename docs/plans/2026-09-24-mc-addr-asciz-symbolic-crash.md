# `llvm-mc -show-encoding` crashes on a symbolic `.mos_addr_asciz`

**Date:** 2026-09-24 · **TODO:** M2 item "`llvm-mc -show-encoding` crashes on a symbolic
`.mos_addr_asciz`" · **Branch:** `main` (small, contained fix; no worktree needed — pristine
codepath in `vendor/llvm-mos/llvm/lib/Target/MOS`, no other worker touching the exact same lines
per the pre-flight `git diff`/patch-ownership check below).

No visible surface (compiler assembler/MC-layer bug), so no mockups.

## The bug

`llvm-mc -show-encoding` (any invocation **without** `--filetype=obj`, i.e. text/asm output)
crashes on a `.mos_addr_asciz <symbol>, N` directive whose operand is a symbolic expression that
cannot be resolved at parse time:

```
$ llvm-mc -triple mos -motorola-integers -show-encoding addr-asciz.s
LLVM ERROR: Don't know how to emit this value.
```

Reproduced against the current `build/llvm-mos-install/bin/llvm-mc` with:

```
.section .header,"a",@progbits
  .mos_addr_asciz _start, 5
```

(the exact first line of the existing `MC/MOS/addr-asciz.s` test, which only exercises
`--filetype=obj` and therefore never hits this).

### Root cause (two independent gaps, one crash)

`.mos_addr_asciz` is parsed by `MOSAsmParser::parseDirectiveAddrAsciz`
(`AsmParser/MOSAsmParser.cpp`). For a **constant** operand it emits a decimal-ASCII string
directly (`getStreamer().emitBytes(...)`) — no `MCExpr` machinery involved, never crashes. For a
**symbolic** operand it wraps the symbol in a `MOSMCExpr::VK_ADDR_ASCIZ` and calls the generic
`getStreamer().emitValue(Expr, CharCount + 1, Loc)`.

1. **`MCAsmStreamer::emitValueImpl`'s generic fallback can't emit an unresolved symbolic value at
   an odd size.** `CharCount` ranges `[1,8]`, so `Size = CharCount + 1` ranges `[2,9]`. When
   `Size` is one of `{1,2,4,8}` there is a `.byte`/`.short`/`.long`/`.quad` directive to reach for;
   otherwise (5 of the 8 possible widths, including the test's `CharCount=4` → `Size=5`) the
   fallback tries `Value->evaluateAsAbsolute(IntValue)`, which fails for a not-yet-resolved
   symbol, and hits `report_fatal_error("Don't know how to emit this value.")`. This is the
   *actual* crash observed — general `llvm/lib/MC` code, not MOS-specific: there is no generic way
   to print "N raw bytes of an unresolved value" as text for a non-power-of-two width. `.mos_addr_asciz`'s
   own object-file emission (`MOSMCELFStreamer::emitMosAddrAsciz`) sidesteps this entirely by
   writing zero-bytes plus a deferred `MOS::AddrAsciz` fixup — but that override only exists on
   the **ELF** streamer, not the plain-text `MCAsmStreamer` used for `-show-encoding`.

2. **`VK_ADDR_ASCIZ` has no textual spelling and `evaluateAsInt64` is `llvm_unreachable`.**
   `MOSModifierNames.cpp`'s table (consulted by `MOSMCExpr::getName()`/`printImpl`) has no entry
   for `VK_ADDR_ASCIZ`, so `getName()` returns `nullptr` — this happens to be silently swallowed
   as an empty string by `StringRef`'s `const char*` constructor rather than crashing, but the
   printed form (`(sym)`, no modifier keyword) is wrong. Separately,
   `MOSMCExpr::evaluateAsInt64`'s `VK_ADDR_ASCIZ` case is `llvm_unreachable`, reached whenever the
   wrapped sub-expression *does* fold to an absolute constant (e.g. `.mos_addr_asciz 5+3, 5` — a
   computed, not literal, constant, so it skips the parser's `dyn_cast<MCConstantExpr>` fast path
   and takes the symbolic branch). Reproduced: in this project's no-asserts release build,
   `llvm_unreachable` is UB rather than a trap (`LLVM_UNREACHABLE_OPTIMIZE`), so this doesn't even
   crash cleanly — it silently produces garbage output (`.byte 56` from an `8` for one manual
   repro), which is worse than a crash.

Not 24-bit-specific — general MC-layer/MOS-modifier gap. Found incidentally during the
2026-09-24 #320 far-addressing completeness audit
([§1](../investigations/2026-09-24-mos24-far-addressing-completeness-audit.md#1-assembler--parser--mostly-done-one-real-gap-already-tracked)).

## The fix

Three small, independent changes, all inside `vendor/llvm-mos/llvm/lib/Target/MOS`:

1. **`MOSAsmParser.cpp::parseDirectiveAddrAsciz`** (the actual crash fix): for the symbolic
   branch, check `getStreamer().hasRawTextSupport()` (true only for the plain-text
   `MCAsmStreamer`, false for `MOSMCELFStreamer` — the same discriminator the Hexagon target's
   `AsmParser` already uses for directives the generic streamer API can't represent). When true,
   round-trip the original directive source (`\t.mos_addr_asciz\t<expr>, <N>`) via
   `getStreamer().emitRawText(...)` instead of ever constructing a `MOSMCExpr`/calling
   `emitValue` — there is no generic way to print an unresolved, non-power-of-two-width symbolic
   value, so don't try. Object-file emission is untouched: `hasRawTextSupport()` is `false` there,
   so it falls through to the existing `MOSMCExpr::create(VK_ADDR_ASCIZ, ...)` +
   `emitValue(..., CharCount + 1, ...)` path unchanged, still routing through
   `MOSMCELFStreamer::emitMosAddrAsciz`'s dedicated fixup.
2. **`MOSModifierNames.cpp`**: add `{"addrasciz", MOSMCExpr::VK_ADDR_ASCIZ, false}` so
   `getName()`/`printImpl` have a real spelling (defense in depth — after (1), `printImpl` should
   no longer be reached for this Kind from `.mos_addr_asciz`, since `VK_ADDR_ASCIZ` is now only
   ever constructed on the object-file path, but a real name is still strictly better than a
   silently-swallowed empty one for any other caller that prints an `MOSMCExpr`).
3. **`MOSMCExpr.cpp::evaluateAsInt64`**: change the `VK_ADDR_ASCIZ` case from `llvm_unreachable`
   to a `break` (identity pass-through, no mask/shift). This is not just "don't crash" — it's the
   *correct* semantics: `VK_ADDR_ASCIZ` has no fixed width to mask/shift (its width is supplied
   per-call-site, not baked into the `VariantKind`), and if the wrapped sub-expression does fold
   to an absolute constant, that constant *is* the value to be stringified, so returning it
   unchanged is right.

## Pristine-upstream check (before editing)

```
$ grep -l MOSMCExpr.cpp patches/llvm-mos/*.patch          # (none)
$ grep -l MOSModifierNames.cpp patches/llvm-mos/*.patch   # (none)
$ grep -l MOSAsmParser.cpp patches/llvm-mos/*.patch
patches/llvm-mos/0039-mos-asm-modifier-width.patch
```

`MOSMCExpr.cpp`/`.h` and `MOSModifierNames.cpp` are pristine upstream, untouched by any existing
fork patch. `MOSAsmParser.cpp` is touched by `0039` (a different area of the file —
`isImmInRange`'s constant-exit fix, not `parseDirectiveAddrAsciz`). Because this bug is a single
coherent fix spanning three files with mixed patch history, and the two never-touched files can't
"fold into" a patch that doesn't cover them, this becomes a **new standalone patch**,
`0047-mos-mc-addr-asciz-symbolic-crash.patch` — the next free number after today's `0046`. It sits
in `dev/toolchain.sh`'s apply order **after** `0039` (since it touches the same file) and is added
to `dev/regen-patch.sh`'s `STANDALONE_MOSDIR` list so a future `0002` regen doesn't absorb it.
Upstream-postable (pristine-upstream defect, self-contained, no fork-specific concepts involved).

**Note on `dev/regen-patch.sh`'s current state**: it carries a foreign uncommitted edit
(`TESTRELS` gained an unrelated `insert-rep-sep-cloned-kills.mir` line, plus a chmod, from another
worker's in-flight task) at the time of this fix. The new `STANDALONE_MOSDIR` entry is added
without touching that foreign hunk. Per this session's standing caution about a hot shared
`dev/regen-patch.sh` and an already-dirty `patches/llvm-mos/0002-321-accum16.patch`, the new
`0047` patch and its round-trip check are verified via a **manual pristine-worktree apply-and-diff**
(same method `0046`'s plan used), not a live `dev/regen-patch.sh` run — that would overwrite
`0002` with a freshly regenerated version and discard whatever uncommitted work other agents have
in it today.

## Regression guard

Add a `-show-encoding` RUN line to `MC/MOS/addr-asciz.s` covering the symbolic-operand,
non-power-of-two-width case that crashed (`.mos_addr_asciz _start, 5`, the exact line from the
existing `--filetype=obj` RUN line, so the same directive is now exercised both ways in one file),
plus a `CHECK` on the round-tripped directive text. This is the regression guard the audit
flagged was missing (the file only ever ran `--filetype=obj`).

## Verification

1. Reproduce pre-fix (done above): `LLVM ERROR: Don't know how to emit this value.`, confirmed
   against the current `build/llvm-mos-install/bin/llvm-mc`.
2. Rebuild (`dev/run.sh toolchain`) and re-run the same repro — expect success, no crash.
3. `dev/run.sh lit vendor/llvm-mos/llvm/test/MC/MOS vendor/llvm-mos/llvm/test/CodeGen/MOS` —
   expect the same 4 known-failing baseline (`scavenger-p-undef-6502.ll`, `legalizer.mir`,
   `addressing-modes-65816.s`, `shift-rotate.ll`) plus the updated `addr-asciz.s` passing with its
   new RUN line.
4. `--filetype=obj` regression check: the existing object-file RUN line in `addr-asciz.s` (and the
   constant-operand cases) still pass unchanged — the fix only touches the plain-text-streamer
   branch.
5. New standalone patch `0047-mos-mc-addr-asciz-symbolic-crash.patch` round-trips cleanly via a
   manual pristine-worktree apply-and-diff (see note above) against the live `vendor/llvm-mos`
   state.

### Results

1. Pre-fix repro (`build/llvm-mos-install/bin/llvm-mc` before the fix):
```
$ llvm-mc -triple mos -motorola-integers -show-encoding addr-asciz-repro.s
LLVM ERROR: Don't know how to emit this value.
... Stack dump ...
 #10 llvm::MOSAsmParser::parseDirectiveAddrAsciz(llvm::SMLoc) MOSAsmParser.cpp:0:0
Aborted (core dumped)
```
PASS (crash reproduced and matches the diagnosis).

2. Post-fix (`dev/run.sh toolchain`, "done in 1m 6s"), same repro:
```
$ llvm-mc -triple mos -motorola-integers -show-encoding addr-asciz-repro.s
	.section	.header,"a",@progbits
	.mos_addr_asciz	_start, 5
EXIT=0
```
Also checked a genuinely-symbolic (not parse-time-foldable) case, `label_b-label_a`:
```
	.mos_addr_asciz	label_b-label_a, 5
EXIT=0
```
PASS.

3. `dev/run.sh lit vendor/llvm-mos/llvm/test/MC/MOS vendor/llvm-mos/llvm/test/CodeGen/MOS`:
```
Total Discovered Tests: 159
  Unsupported:   2 (1.26%)
  Passed     : 153 (96.23%)
  Failed     :   4 (2.52%)
FAIL: LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll (1 of 159)
FAIL: LLVM :: CodeGen/MOS/legalizer.mir (2 of 159)
FAIL: LLVM :: MC/MOS/addressing-modes-65816.s (3 of 159)
FAIL: LLVM :: CodeGen/MOS/shift-rotate.ll (4 of 159)
```
Same 4 known-failing baseline, unchanged. `MC/MOS/addr-asciz.s` (with the new `-show-encoding` RUN
line) is not in the failure list — it passed. PASS.

4. `--filetype=obj` regression check — `addr-asciz.s`'s existing object-file RUN line, byte-identical
   to its pre-fix expectation:
```
$ llvm-mc -triple mos -motorola-integers --filetype=obj -o=t.obj addr-asciz.s
$ llvm-readelf --relocs -x .header t.obj
Relocation section '.rela.header' ... R_MOS_ADDR_ASCIZ 00000000 _start + 0
0x00000000 30000000 00003432 00000000 39393939 0.....42....9999
0x00000010 39393939 00                         9999.
```
Matches the test's own `CHECK`/`CHECK-NEXT` lines exactly (also covered by the lit run in step 3).
PASS.

5. New standalone patch `0047-mos-mc-addr-asciz-symbolic-crash.patch` round-trip (manual
   pristine-worktree apply-and-diff, per the note above):
```
$ git -C vendor/llvm-mos worktree add --detach <scratch-wt> 8be0546128a5
$ git -C <scratch-wt> apply patches/llvm-mos/0039-mos-asm-modifier-width.patch
$ git -C <scratch-wt> apply --check patches/llvm-mos/0047-mos-mc-addr-asciz-symbolic-crash.patch
APPLY-CHECK OK
$ git -C <scratch-wt> apply patches/llvm-mos/0047-mos-mc-addr-asciz-symbolic-crash.patch
$ diff -u <scratch-wt>/llvm/lib/Target/MOS/AsmParser/MOSAsmParser.cpp vendor/llvm-mos/llvm/lib/Target/MOS/AsmParser/MOSAsmParser.cpp
IDENTICAL
$ diff -u <scratch-wt>/llvm/lib/Target/MOS/MCTargetDesc/MOSMCExpr.cpp vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSMCExpr.cpp
IDENTICAL
$ diff -u <scratch-wt>/llvm/lib/Target/MOS/MCTargetDesc/MOSModifierNames.cpp vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSModifierNames.cpp
IDENTICAL
$ diff -u <scratch-wt>/llvm/test/MC/MOS/addr-asciz.s vendor/llvm-mos/llvm/test/MC/MOS/addr-asciz.s
IDENTICAL
```
PASS. `0047` applied after `0039` (same file, `MOSAsmParser.cpp`); registered in
`dev/toolchain.sh` (new `apply_patch 0047-mos-mc-addr-asciz-symbolic-crash` after `0046`) and in
`dev/regen-patch.sh`'s `STANDALONE_MOSDIR` (new entry after `0046`'s), without touching that
file's pre-existing foreign uncommitted hunk (`TESTRELS` + a chmod, unrelated, left exactly as
found). Scratch worktree removed afterward (`git -C vendor/llvm-mos worktree remove <scratch-wt>`).

## Upstream

Pristine-upstream, self-contained, three-file MC-layer fix — a clean upstream-postable artifact,
same shape as `0043`/`0044`/`0046`. Left **unranked** (`- [ ]`) for a follow-up "draft the `0047`
upstream PR" item — ranking is reserved to the Fable orchestrator (`rank-requires-fable.sh`
blocks a non-Fable model from adding a tier marker), not something a T2 dispatch does.

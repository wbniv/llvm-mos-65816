# #321 xy16 fp compare-as-select ("cmove") — XFAIL was STALE, resolved to positive gates

**Outcome: NO compiler defect. The three `ieee/` XFAIL rows are stale; de-XFAIL'd to positive
gates. No `vendor/`/`0002` change.** This is the [`pr15296`](2026-06-26-pr15296-mos-a16-link-time-zp-overflow-gated-narrow.md)
stale-XFAIL pattern (a shared-hot-tree `build/` that didn't match the tracked patches).

Supersedes the fix-hypothesis plan [`2026-06-26-full-xy16-backend-fix-close-the-last-mos-xy16-defe.md`](2026-06-26-full-xy16-backend-fix-close-the-last-mos-xy16-defe.md):
its Step 3 ("the MIR diff is the arbiter; it may redirect") redirected the conclusion from
"fix a defect" to "the defect does not exist on the shipping compiler."

## Context

The `ieee/` full-vendoring sweep (`5f3b316`, 2026-06-26 12:02) recorded three `+mos-xy16`
XFAILs sharing one body — the gcc "cmove patterns are correct" test
(`__builtin_isunordered/isless(x,y) ? a : b`): `ieee/fp-cmp-8.c` + its long-double
(`fp-cmp-8l.c`) and double (`pr38016.c`) `#include`-wrappers. The finding claimed
`+mos-xy16` reads sentinel `0xDEAD` while default and `+mos-a16` PASS, reproducible isolated
on MAME at `-Os` and `-O1`.

The hypothesis (sibling of the `requiredXWidth` index-width family / seed-445 fix): a non-index
16-bit value parked in `X16`/`Y16` across the `MOSLowerSelect` diamond, where a sibling block's
narrowing `sep #$10` zeroes the high byte.

## Investigation (measurement-led; the worktree compiler == the committed stack)

Worktree `wt/321-xy16cmove`, off `main` HEAD, `vendor/llvm-mos` real-copied + `build/` warm-copied;
`clang-23` freshly rebuilt. Verified the worktree compiler **is** the shipping committed stack:
every `vendor/` edit beyond a pristine tree maps to a committed patch (`0001..0012`) — `regen-patch.sh`
attributes later-patch hunks (`0004/0006/0007/0008/0012`) to `0002`, but **zero** hunks are
uncommitted. So measurements here are measurements of the tracked compiler.

### 1. Reproduce — the defect does NOT reproduce (both opt levels, both emulators)

```
$ dev/run.sh torture --tests ieee/fp-cmp-8.c ieee/fp-cmp-8l.c ieee/pr38016.c
==> torture-run: 3 test(s), -Os, explicit, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
  XP ieee/fp-cmp-8.c        XPASS listed in xfails.tsv but now PASSes — remove the row
  XP ieee/fp-cmp-8l.c       XPASS listed in xfails.tsv but now PASSes — remove the row
  XP ieee/pr38016.c         XPASS listed in xfails.tsv but now PASSes — remove the row
==> torture-run: 0 PASS, 0 FAIL, 0 SKIP, 0 XFAIL, 3 XPASS (of 3)

$ dev/run.sh torture --tests ieee/fp-cmp-8.c ieee/fp-cmp-8l.c ieee/pr38016.c --opt -O1
==> torture-run: 3 test(s), -O1, explicit, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
  XP ieee/fp-cmp-8.c   …  XP ieee/fp-cmp-8l.c   …  XP ieee/pr38016.c
==> torture-run: 0 PASS, 0 FAIL, 0 SKIP, 0 XFAIL, 3 XPASS (of 3)
```
**PASS** (i.e. defect absent) — all three XPASS at `-Os` and `-O1`. The harness runs the full
4-way differential `host==default@MAME==+mos-a16@MAME==+mos-xy16@MAME==+mos-a16@bsnes-jg`.

### 2. `+mos-xy16` is genuinely live (not silently ignored → not a false "agree")

```
$ … -c  (default / +mos-a16 / +mos-xy16) fp-cmp-8.c
5092 d_def.o   3b20eb4f…   # default
5204 d_a16.o   e226d04b…   # +mos-a16   (distinct)
5208 d_xy16.o  63dac70b…   # +mos-xy16  (distinct from both)
```
Three distinct objects → the xy16 path is exercised; the XPASS is real, not a no-op.

### 3. Localize (the arbiter) — the bug class cannot manifest in this codegen

```
$ … -S  +mos-xy16  fp-cmp-8.c   → grep 'rep #$10|sep #$10|LDXAbs16|LDYAbs16'  → (none)
```
The xy16 codegen for this body uses **no 16-bit index register at all** — no `rep/sep #$10`
bracket, no `LDXAbs16`/`LDYAbs16`. `data[i]` (stride 28: `double` ×2 + `int[6]`) is reached via
computed-pointer arithmetic + 8-bit `(zp),Y`, not a 16-bit absolute-indexed load; the `test_*`
selectors take their float args off the soft stack via 8-bit `(sp),Y`. With no 16-bit index live,
the hypothesized "value parked in `X16` across the select diamond, narrowed by a sibling `sep`"
cannot occur. **The recommended H1 fix would have been a fix for a non-bug.**

### 4. Concrete cause of the 12:02 finding

```
$ git log --oneline 5f3b316..HEAD -- patches/llvm-mos/     → (empty)
$ git log -1 --format='%ci' -- …0006-320-packed24.patch    → 2026-06-22   (predates finding)
$ git log -1 --format='%ci' -- …0007-…bank-relax.patch      → 2026-06-22   (predates finding)
```
The committed patch stack is **byte-identical at the finding commit `5f3b316` and at HEAD**, and
every compiler-affecting patch predates the finding. A clean build of those patches — then or now —
produces the compiler measured above, which **passes**. Therefore the 12:02 sweep did not measure
the committed stack: it measured `main`'s shared `build/` in a state that did not match the tracked
patches (stale install, or transiently dirty from a concurrent worker's `vendor/` edit since
reverted/committed). The source of truth is the patches, not the shared `build/`; the XFAIL was
never valid for the shipping compiler.

## Resolution

- Removed the 3 rows + the stale "FOUND 2026-06-26" comment block from
  `examples/65816/torture/xfails.tsv`; left a breadcrumb pointing here so they are not re-added.
- The 3 tests are now **in-scope positive gates** — a recurrence hard-FAILs the suite.
- No `vendor/`/`0002`/tooling change (codegen-inert) → the xy16 suite, corpus, csmith fuzz, and
  the rest of c-torture are byte-for-byte unaffected and were not re-run (shared-box courtesy).

### Verification

```
$ dev/run.sh torture --tests ieee/fp-cmp-8.c ieee/fp-cmp-8l.c ieee/pr38016.c   # after removal
==> torture-run: 3 test(s), -Os, explicit, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     ieee/fp-cmp-8.c        PASS  all variants PASS (0x600D)
     ieee/fp-cmp-8l.c       PASS  all variants PASS (0x600D)
     ieee/pr38016.c         PASS  all variants PASS (0x600D)
==> torture-run: 3 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 3)
```
**PASS** — the rows now report PASS (positive gates), sentinel `0x600D`, 4-way agreement on
MAME + bsnes-jg.

## Lesson reinforced

Measure against the **tracked patches**, not the shared `build/`. On this hot multi-agent `main`
working copy a stale/dirty `build/` produces phantom XFAILs; the same root for `pr15296`'s
`a16-zp-pressure-overflow`. A full-suite sweep that records new XFAILs should rebuild the toolchain
from the committed patches first (the `dev/run.sh toolchain` stale-`clang-23` gate), or its findings
can be artifacts of another worker's in-flight `vendor/` edits.

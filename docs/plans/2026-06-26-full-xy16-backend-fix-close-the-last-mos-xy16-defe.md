# Full xy16 backend fix — close the last `+mos-xy16` defect (fp compare-as-select)

## Context

The 65816 `+mos-xy16` (16-bit X/Y index register) backend is **fully implemented and
verified except for exactly one open defect** (TODO.md:398). The `ieee/` full-vendoring
sweep (2026-06-26) found a single `+mos-xy16` miscompile: a floating-point
**compare-as-select ("cmove")** pattern — `__builtin_isunordered/isless(x,y) ? a : b`
with `a,b,x,y` = float/double/long-double. Three c-torture rows share **one body, one
root cause**: `ieee/fp-cmp-8.c`, `ieee/fp-cmp-8l.c`, `ieee/pr38016.c`
(`xfails.tsv:62-64`). Under `+mos-xy16` the test self-check reads sentinel `0xDEAD`
(FAIL); **default (non-a16) and `+mos-a16` both PASS**. Reproducible in isolation on
MAME at both `-Os` and `-O1` (opt-independent).

"Full xy16 backend fix" = root-cause and close this last defect so the differential
gate is fully green for `+mos-xy16` (the three rows de-XFAIL to GREEN), completing the
xy16 backend. This is the **sibling of the already-fixed `requiredXWidth` index-width
family**: on the 65816 the X and Y index registers share **one** index-width status
flag, and narrowing it (`sep #$10`) forces the high bytes `XH`/`YH` to **zero** — so a
16-bit index value must never be live across an 8-bit-index op. Three prior bugs of this
exact family were root-caused and fixed (value-ops `55ec505`, transfers/push `4d8a2bd`,
seed-445 selection-steering "approach B" `2d8ab51`, Track A indexed-family catch-all
2026-06-21). This is the same shape applied to the select-diamond.

The fix is **measurement-led, not assumed** (project lesson #1). The plan reproduces,
cvise-reduces, root-causes via MIR/asm diff, fixes at the originating phase, and
verifies 4-way. The recommended root cause and fix site are stated decisively; the
measurement step (Step 3) is the arbiter and may redirect to the fallback site.

## How the failing pattern lowers (established from the source)

1. `G_FCMP` (`__builtin_isunordered`/`isless`/…) → soft-float **libcall** returning i32 →
   `ICmp(NE,…,0)` → i1 (`MOSLegalizerInfo.cpp:~3189-3261`).
2. `G_SELECT cond, a, b` → **control-flow diamond** in `MOSLowerSelect.cpp:~104-330`:
   creates TrueMBB/FalseMBB/SinkMBB + `G_BRCOND_IMM`/`G_BR`, sinks the value defs into
   the branches, merges via **`G_PHI`** in SinkMBB.
3. `selectXY16` runs first under `STI.hasIndex16() && selectXY16(MI)`
   (`MOSInstructionSelector.cpp:286`); its `G_LOAD16_ABS` case decides "genuine index"
   and may load a 16-bit value straight into **X16/Y16** (lines 2752-2763).
4. Post-RA, `MOSInsertREPSEP::requiredXWidth` + the X-flag lattice place `rep/sep #$10`.

The `test_*` select functions are called **indirectly** (function pointers) so they are
**not inlined** into `main`; their float args `a,b` come off the soft stack via 8-bit
`(sp),Y` (already `XW_X8`). `main` is where the only *genuine* 16-bit index lives
(`data[i]`, struct stride 28 for double → byte offset > 255 → real `LDAbsXIdx16`). **The
MIR diff in Step 3 determines which function carries the anomaly** — that one fact picks
the fix site.

## Root-cause hypothesis (recommended) and fallback

**H1 (most likely) — `selectXY16` over-classifies a non-index 16-bit value as a "genuine
index", parking it in X16 across the select-diamond, where a sibling block's 8-bit op
narrows X and zeroes the high byte.** This is the *select-diamond sibling of the seed-445
fix*. The current `GenuineIndex` test (`MOSInstructionSelector.cpp:2752-2763`) is "any
non-COPY use ⇒ genuine index." After `MOSLowerSelect` has split the value across the
diamond, a 16-bit chunk's sole non-COPY use can be the **`G_PHI`** merge (or a use in a
*different* block) — not a COPY, so it loads straight into X16 and is **live across the
diamond**, where a sibling block's now-`XW_X8` 8-bit stack op emits the narrowing
`sep #$10` that zeroes its high byte → wrong float bytes → `0xDEAD`.

**Recommended fix (if Step 3 confirms H1):** generalize the `GenuineIndex` predicate so a
value is loaded directly into X16/Y16 **only when genuinely consumed as an index within
its own block** — treat any use that is a `G_PHI`, or any use in a *different*
`MachineBasicBlock` than the def (i.e. live across a diamond edge / the merge), as
**non-genuine**: `MRI.setRegClass(Dst, &MOS::Imag16RegClass); return false;` (the existing
accumulator fall-through). This extends "all uses are COPYs ⇒ not an index" to "no use
keeps the value live in X16 across a block boundary."

Why this site over the alternatives:
- **Gating is automatic & structural** — `selectXY16` is reached only via the
  `STI.hasIndex16()` gate at line 286, so default/a16 codegen is byte-identical *by
  construction*. (`selectXY16` lives in `0002-321-accum16.patch` — confirmed.)
- It fixes the **origin** (a 16-bit value should never be parked in X16 across the
  diamond), not the symptom (the narrowing sep) — project doctrine "fix at the
  originating phase."
- It is the same shape as the proven approach-B fix (`2d8ab51`), so review/verify is known.

**Fallback sites (choose only if the MIR shows a different signal):**
- **H2 — X-lattice placement gap** at a diamond passthrough/critical edge truncating a
  *correctly*-X16 value → `MOSInsertREPSEP.cpp:460-600` (meet/placement; confirm the
  diamond does not trip the `Bail`→`placeLegacy` path at line 568/602).
- **H3 — a `requiredXWidth` classification gap** Track A missed: an X/Y-reading op that is
  neither `mayLoad/mayStore` nor a branch, running in a stray X=16 ambient →
  `MOSInsertREPSEP.cpp:164-278` (add the op class → `XW_X8`, **memory/operand-gated**).

## Plan

### Worktree (compiler-changing variant; off `main` HEAD — never on the hot shared tree)
Per `docs/howto-feature-worktree.md`: `git worktree add -b wt/321-xy16cmove
../llvm-mos-65816-xy16cmove main`, then **real-copy** `vendor/llvm-mos` +
`vendor/llvm-mos-sdk` + `build/` (a compiler change rebuilds in place — never hardlink
`vendor/llvm-mos`), and `cp -al` `vendor/bsnes-jg` + `dev/roms`. Dead-end teardown:
`dev/worktree-teardown.sh throwaway/... --yes`; keep → merge durable artifacts back.

### Step 1 — Reproduce (durable signal)
`dev/run.sh torture --tests ieee/fp-cmp-8.c ieee/fp-cmp-8l.c ieee/pr38016.c` → expect
`0 PASS / 3 FAIL` (xy16@MAME=0xDEAD); repeat `--opt -O1`. Confirm `xy16@bsnes-jg` also
reads wrong (build the xy16 ROM, `build/jgxcheck out.sfc vendor/bsnes-jg/Database …`) —
two independent emulators ⇒ genuine codegen bug, not an emulation artifact.

### Step 2 — Reduce (cvise, the seed-445 method)
`cvise --n $(nproc) dev/reduce-xy16.sh cand.c` (interestingness already encodes
`default-Os == default-O0 == a16-Os` AND `xy16-Os ≠ default-Os`, read via bsnes-jg —
strong UB filter). Reduce to a sub-50-line UB-free TU. (If LTO narrows away the standalone
repro — the documented caveat — skip to Step 3 on the c-torture body directly; the
`-stop-after` MIR is pre-link and authoritative.)

### Step 3 — Localize (the arbiter): per-function MIR diff, xy16 vs a16
Dump MIR after the X-flag pass for both features with the real torture flags and diff:
```
COMMON="--config build/install/bin/mos-snes.cfg -mcpu=mosw65816 -Os \
  -Dmain=torture_test_main -Dabort=__torture_abort -Dexit=__torture_exit \
  -mllvm -stop-after=mos-insert-rep-sep -o -"
mos-clang $COMMON $T -Xclang -target-feature -Xclang +mos-a16  > a16.mir
mos-clang $COMMON $T -Xclang -target-feature -Xclang +mos-xy16 > xy16.mir
diff a16.mir xy16.mir       # + llvm-objdump -d the xy16 .o for the on-silicon view
```
**Decision rule:**
- **Signal A** — an `LDX/LDYAbs16`/`*Idx16` value **read after** an intervening
  `SEP_Immediate #$10` (16-bit index live across a narrowing): in `test_*` with the
  consumer a `G_PHI`/cross-block use ⇒ **H1** (recommended fix); a *correctly*-X16 value
  truncated by a mis-placed lattice sep ⇒ **H2**.
- **Signal B** — an X/Y-reading op in an X=16 ambient with no live 16-bit value and no
  surrounding sep (it *wants* X8) ⇒ **H3**.
- **Which function** (test_* vs main) carries the anomaly picks the locus.

### Step 4 — Fix at the originating phase
Apply the H1 fix (recommended) or the fallback the MIR dictates. Keep it **HasIndex16-gated**
so default/a16 are byte-identical. Scope narrowly — a genuine in-block index use (e.g.
`main`'s `data[i]` `LDAbsXIdx16`) must still take the direct X16 path; re-confirm in the MIR.

### Step 5 — De-XFAIL + regression guard
Remove the 3 rows from `examples/65816/torture/xfails.tsv`. Attempt a RED micro-test
`examples/65816/xy16cmove.c` + `dev/xy16cmove.sh` (4-way differential, modeled on the
float-select body + `examples/65816/xy16spillr.c`, with a genuinely-16-bit index kept live
across the select). **Per the documented LTO-narrowing caveat** (both prior `requiredXWidth`
fixes shipped without a standalone micro-test because a small index narrows back to X8
through the `--config` link), if a minimal RED case is not constructible, land the fix with
the **3 de-XFAIL'd torture rows as the durable regression guard** + the structural-safety
argument + the byte-identical proof, and document the test-gap explicitly — do **not**
fabricate a test that asserts nothing.

## Critical files
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp` — `selectXY16`
  `GenuineIndex` predicate, **lines 2752-2763** (recommended H1 fix).
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` — `requiredXWidth` (164-278) +
  X-flag lattice/placement (460-600) (fallback H2/H3).
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLowerSelect.cpp` — diamond construction
  (104-330) (structure under test; read-only unless H2 demands it).
- `examples/65816/torture/xfails.tsv` — de-XFAIL the 3 rows.
- `patches/llvm-mos/0002-321-accum16.patch` — regen via `dev/regen-patch.sh` (owns both
  `selectXY16` and `requiredXWidth`).
- New on implement: `docs/plans/2026-06-26-321-xy16-cmove-fix.md` (durable project plan,
  per convention) + a `TODO.md` entry; optional `examples/65816/xy16cmove.c` +
  `dev/xy16cmove.sh`.

## Verification (mirror the sibling fixes — write raw output back into the project plan)
1. **Rebuild took:** `dev/run.sh toolchain`; confirm `build/llvm-mos-install/bin/clang-23`
   mtime advanced (the stale-`clang`-symlink trap — else you measure old codegen).
2. **RED→GREEN:** the 3 torture rows PASS at both `--opt -Os` and `--opt -O1` (0xDEAD→0x600D).
3. **Two oracles:** `host == default@MAME == a16@MAME == xy16@MAME == xy16@bsnes-jg`.
4. **a16/default byte-identical** (the gating proof): disasm a16 suite + `default` build of
   `examples/65816/*.c` pre/post — byte-identical; `dev/run.sh corpus` → 7/7.
5. **No xy16 regression:** `xy16basic/xy16ops/xy16indiry/xy16spill/xy16spillr` all PASS;
   `k_isort` xy16 leg agrees; **re-verify csmith seeds 247 + 445 still agree** (don't
   regress approach-B).
6. **Full suites:** `dev/run.sh torture 60` (+ larger N) clean, no new FAIL/XPASS surprises;
   `dev/run.sh fuzz --gen csmith 200 101` and `… 200 301` → 0 mismatch / 0 crash.
7. **MIR-verify clean** (`-verify-machineinstrs`); regen `0002`, confirm it round-trips with
   **no foreign hunks** (grep for concurrent far-cc/frameabi symbols).
8. **Commit hygiene:** stage only your files (regen'd `0002`, `xfails.tsv`, plan/TODO, optional
   micro-test) — never `vendor/`, a foreign patch, or `docs/transcripts/`. Triage the
   audit-deferrals Inbox. Update `TODO.md:398` to `[x]` (move to done, one line). Don't push
   without coordinating.

## Risks / gotchas
- **Stale clang-23** — verify mtime advanced after every `vendor/llvm-mos` edit.
- **LTO-narrowing** — the linked ROM can mask/refuse a minimal repro; the pre-link
  `-stop-after=mos-insert-rep-sep` MIR is authoritative; the c-torture rows are the guard.
- **`requiredXWidth` additions (if H3)** must be memory/operand-gated — never force `sep #$10`
  before a `T_A` (TXA/TYA) reading X/Y *as a value*; that itself zeroes the high byte (a
  regression). Track A's `(mayLoad||mayStore)` gate is the precedent.
- **`selectXY16` fix (if H1) must not over-route** a legitimate in-block 16-bit index
  through the accumulator — scope to "live across a block boundary / feeds a `G_PHI`".
- **Worktree:** real-copy `vendor/llvm-mos` (never hardlink — in-place rebuild would corrupt
  `main`); stage only your files.

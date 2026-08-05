# Third-party validation of llvm-mos PR #585 (`G_ASHRE` ASR legalization)

**TODO entry:** upstream-contribution-status row 22 — *"#585 watch — `G_ASHRE` ASR legalization (mlund)"*,
validation pass approved 2026-08-05.

**Deliverables:** `docs/investigations/2026-08-05-585-gashre-validation.md` (full record) and
`docs/upstream-585-validation-comment.md` (DRAFT review comment — **not** posted).

**No visible surface.** This is a compiler-validation pass; its output is two markdown documents and a
draft review comment. No UI, rendered page, CLI screen, or generated document with a layout — so no
mockup bundle.

## What #585 is

[PR #585](https://github.com/llvm-mos/llvm-mos/pull/585) (mlund) introduces a generic opcode `G_ASHRE`
(8-bit arithmetic-shift-right-with-carry) so that a one-bit arithmetic right shift is *represented* during
legalization rather than recovered as a sign-carry idiom during instruction selection. On 65CE02 a live
result then selects the native `ASR`; everywhere else selection falls back to the pre-existing `LSR`/`ROR`
path, so the PR claims **inertness for every non-65CE02 CPU**.

Eight source files change. Seven of them are inside `0002`'s territory
(`MOSLegalizerInfo.cpp`, `MOSInstructionSelector.cpp`, `MOSInstrLogical.td`, `MOSInstrGISel.td`,
`MOSCombiner.cpp`, `MOSMCInstLower.cpp`, `MOSTargetMachine.cpp`); only `MOSCombine.td` is untouched by the
fork.

## What we can and cannot validate

We have no 65CE02 emulator, so the **65CE02-specific half** (native `ASR` selection, the new
`asr-65ce02.ll` expectations) is out of reach for execution testing.

What *is* in reach is the **CPU-independent half**, which is the larger share of the diff and the part that
carries the inertness claim:

- `legalizeShiftRotate` — `G_ASHR` now lowers to `G_ASHRE` instead of `G_LSHRE`.
- `legalizeLshrEShlE` — the multi-byte split now gives the **most-significant** byte `G_ASHRE` and the rest
  `G_LSHRE`.
- `matchFoldShift` / `matchShiftUnusedCarryIn` — constant folding and carry-in elision for the new opcode.
- `MOSCSEConfigFull::shouldCSEOpc` — `G_ASHRE` becomes CSE-able.

All four run for `mos6502`/`mosw65816`, so our differential battery genuinely exercises them.

## Approach

1. **Throwaway worktree** `throwaway/585-validation` at `/home/will/llvm-mos-65816-585val`, compiler-changing
   variant (real-copied `vendor/llvm-mos` + warm `build/`) per
   [`howto-feature-worktree.md`](../howto-feature-worktree.md). `main` and the shared `vendor/` are not touched.
2. **Apply #585 on top of the fork patch stack**, recording every conflict and its resolution. Resolve only
   what is mechanical (context drift / adjacent hunks). Anything needing a design decision **stops that path**
   and is recorded instead — a partial, honestly-scoped validation beats a hand-waved full one.
3. **Byte-identity sweep** (the sharpest test of the inertness claim). Compile a broad C body — the 132
   `examples/65816` programs, the `examples/snes/corpus` slices, and the in-scope gcc c-torture rows — across
   five target/feature combos (`mosw65816` default / `+mos-a16` / `+mos-a16 +mos-xy16`, `mos6502`, `mos65c02`)
   with the **pre-#585** toolchain and again with the **post-#585** toolchain, and diff per-object hashes.
   Byte-identity is a far stronger statement than "the battery still passes"; a diff is a lead to chase.
   Script: `dev/sweep-585.sh`.
4. **Differential battery** on the post-#585 build: `dev/run.sh corpus` (baseline 7/7), `dev/run.sh torture`
   (baseline 30/30 on the sampled selector). Csmith only if the budget allows — it needs `vendor/csmith` built
   from source, which is not vendored in `main`.
5. **lit** — `llvm/test/CodeGen/MOS`, including the PR's three new/changed test files, noting known fork
   divergences.

## Attribution is clean

PR #585's base is `1f334fe`; our vendor pin is `8be0546` (#563). The three commits between them are
`Use action token for releasing`, `Update packaging action permissions`, and `lld/ELF .debug_frame GC (#567)`
— **none touches `llvm/lib/Target/MOS/` or `llvm/test/CodeGen/MOS/`**. Confirmed:

```
git diff --stat 8be0546128a5 1f334fef02b5 -- llvm/lib/Target/MOS/ llvm/test/CodeGen/MOS/   # empty
```

So every conflict encountered is **fork-vs-PR**, never upstream drift. That makes the conflict log directly
useful to mlund as rebase intel.

## Timebox

If the toolchain build plus corpus plus torture completes but Csmith would push past ~4 h total, skip Csmith
and say so. If the apply is so conflicted that a meaningful merged build needs design decisions, the conflict
analysis becomes the deliverable and the validation is marked **NOT RUN**.

## Verification

1. Worktree builds a toolchain with #585 applied; `clang-23` mtime advances (the stale-build gotcha).

    ```
    BASE: 2026-08-04 22:11:33.000000000
    NEW : 2026-08-05 00:06:33.000000000

    --- NEW toolchain, mos65ce02 ---     --- BASE toolchain, mos65ce02 ---
    f:                                   f:
    	asr                              	cmp	#128
    	rts                              	ror
                                         	rts
    ```

    **PASS** — mtime advanced *and* the behaviour changed, which is the stronger check.

2. `dev/sweep-585.sh` baseline vs post — report the number of differing (file, combo) pairs.

    ```
    === #585 as submitted  (vs pre-#585 baseline) ===
    combo             compared  identical  DIFFER
    45gs02                1250       1234      16
    6502                  1250       1250       0
    65c02                 1250       1250       0
    65ce02                1250       1234      16
    w65816-a16            1468       1468       0
    w65816-a16-xy16       1468       1468       0
    w65816-default        1442       1441       1

    === #585 + getDemandedBits fix  (vs pre-#585 baseline) ===
    w65816-default        1442       1442       0
    (all other rows unchanged from above)
    ```

    **PASS (with a finding)** — 1 unexpected `mosw65816` difference, root-caused to the missing `G_ASHRE`
    arm in `getDemandedBits` and eliminated by the fix. See the investigation §2.

3. `dev/run.sh corpus` — expect `7/7`.

    ```
    =================== TOOLCHAIN BASE585 ===================
    corpus exit=1 : corpus: 42/63 passed
    =================== TOOLCHAIN 585ONLY ===================
    corpus exit=1 : corpus: 42/63 passed
    === PASS-set diff (baseline vs 585) ===
    IDENTICAL PASS SETS
    ```

    **PASS** — the "7/7" expectation in this step was stale when written (the corpus is now 63 entries).
    The measurement that matters is the paired one: identical PASS sets. The 21 non-passing rows fail
    identically in both legs from missing generated assets in a fresh worktree, not from #585.

4. `dev/run.sh torture --sample N` — compare against the recorded baseline.

    ```
    BASE585  ==> torture-run: 40 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 40)
    585ONLY  ==> torture-run: 40 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 40)
    === per-test status diff ===
    IDENTICAL PER-TEST STATUS
    ```

    **PASS** — `--sample 40 --sample-seed 585`, clean on both legs.

5. lit `llvm/test/CodeGen/MOS` — compare pass/fail set against a pre-#585 run of the same suite.

    ```
    585only: 7 failing |  Passed : 78 (90.70%)
    base:    7 failing |  Passed : 77 (90.59%)
    585fix:  7 failing |  Passed : 78 (90.70%)
    === failing-set deltas ===
    --- introduced by #585 (in 585only, not in base) ---
    --- fixed by #585 (in base, not in 585only) ---
    --- changed by my getDemandedBits fix (585only vs 585fix) ---
    (no change)
    ```

    **PASS** — failing set identical across all three states; all 7 are pre-existing fork divergences. The
    PR's `asr-65ce02.ll` and `combiner.mir` pass; its `legalizer.mir` additions are unverifiable here
    because that file already fails at baseline.

**Not run:** Csmith (`vendor/csmith` absent from `main`; skipped per the timebox — the 1288 c-torture rows
in the sweep give comparable breadth at compile level).

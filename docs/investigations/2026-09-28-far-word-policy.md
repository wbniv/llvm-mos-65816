# Native far-word indexing: speed and size policy

**Status: patch 0070 is integrated and installed locally, September 28, 2026.** Native word indexing is enabled at `-O2` and `-O3` in functions without size or `optnone` attributes. `-Os`, `-Oz`, `-O0`, and `-O1` retain the existing policy. The measurements support accepting a size increase when the build requests speed. Independent upstream review and validation against the destination revision remain separate work.

Attribution: OpenAI Codex CLI 0.157.1 (session source: `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e67f-298f-7a21-80af-06f867085f84`. Earlier investigations retain their recorded attribution.

## Policy and prior work

The [prior-work audit](../defects/evidence/2026-09-28-far-word-policy/prior-work.json) reconciles the existing Farblit defect, original experiment, installed 0069 proof, patch stack, Git history, and live legalizer. The existing legalization defect remains fixed by 0066; this is an optimization policy, with no new defect or defect-status change.

The baseline legalizer is byte-identical to the captured [0069 integration](2026-09-28-farblit-range-integration.md). An isolated build adds word admission to both the entry guard and the all-users walk, using the native M16/Y8 pseudo already supplied by 0062. Only plain two-byte loads qualify. Atomic, escaping, call-separated, unsupported-loop, and out-of-range uses retain the existing fallbacks. Every sibling's final byte must fit Y8 when the group contains a word, even when a byte use is visited first. The offset expression and its narrow arithmetic remain intact.

[Patch 0070](../../patches/llvm-mos/0070-mos-far-word-index-policy.patch) provides `-mos-far-word-index=speed` by default. It requires code-generation optimization level at least `Default` and rejects function `optsize`, `minsize`, and `optnone` attributes. `off` restores the baseline; `all` explicitly permits the measured size tradeoff in size-optimized functions. With Clang, pass `-mllvm -mos-far-word-index=off`; with LTO, also pass `-Wl,--mllvm=-mos-far-word-index=off`. The same forwarding applies to `all`.

## Full-LTO Farblit measurements

The baseline includes 0069. “All” enables word folding regardless of size attributes. The installed default chooses baseline behavior for `-Os`/`-Oz` and the word fold for `-O2`/`-O3`. The table measures complete `main`, including the code outside `rdw`.

| Mode | Option | Baseline bytes → all | Baseline master clocks → all | Installed default |
| --- | --- | ---: | ---: | --- |
| A16 | `-Os` | 1,949 → 2,011 | 308,814 → 289,658 | Baseline |
| XY16 | `-Os` | 1,921 → 1,893 | 284,774 → 262,336 | Baseline |
| A16 | `-Oz` | 2,085 → 2,085 | 355,972 → 355,972 | Baseline |
| XY16 | `-Oz` | 1,942 → 1,942 | 311,650 → 311,650 | Baseline |
| A16 | `-O2` | 3,279 → 3,266 | 311,266 → 289,102 | Word fold |
| XY16 | `-O2` | 3,235 → 3,197 | 292,108 → 269,494 | Word fold |
| A16 | `-O3` | 14,662 → 14,708 | 376,006 → 348,590 | Word fold |
| XY16 | `-O3` | 14,016 → 13,920 | 361,030 → 337,664 | Word fold |

At `-O2`, A16 is **7.12% faster and 13 bytes smaller**; XY16 is **7.74% faster and 38 bytes smaller**. The additional `-O3` check accepts 46 more A16 bytes for **7.29% faster execution**. These are fixture-specific results, not a universal speed guarantee. The padded cartridge lengths do not change.

The [results](../defects/evidence/2026-09-28-far-word-policy/results.json), [identities](../defects/evidence/2026-09-28-far-word-policy/identity.json), commands, ROMs, and raw instruction profiles are retained. Timing uses the calibrated bsnes master-clock probe, including memory waits and refresh; repeated independent runs agree exactly. Bounds and pressure profiles exclude called functions and are correctness controls rather than full-work speed comparisons.

## Where the 62 A16 bytes come from

Replaying identical captured pre-legalizer MIR on the rebased compiler reproduces the earlier `-Os` result. `rdw` shrinks from 103 to 76 bytes, saving 27; the rest of `main` grows by 89, giving the net **+62**.

Register allocation changes the placement of values live across the probes. The soft-stack frame grows from 10 to 17 bytes. Assembly annotations identify 10 → 18 folded spill instructions and 10 → 18 folded reload instructions. The copy-setup region alone grows by 54 bytes, with extra pointer saves/reloads and Y preservation. Both alternatives have 36 `REP` and 36 `SEP` instructions. The growth is therefore attributable primarily to changed allocation and spills, rather than additional M/X transitions.

[Region sizes and instruction counts](../defects/evidence/2026-09-28-far-word-policy/trace.json), the assembly diff, and post-allocation MIR are retained in the trace archive. A local access-size heuristic would miss this whole-function effect. The function's speed/size attributes provide a direct policy without trying to predict later allocation.

## Validation and installation

- Sixteen fixtures × two modes × three optimization levels give **96 verified object builds per policy**. They cover Farblit, boundary and pressure inputs, far indexing/banks/loops/memory operations/casts/arithmetic, near wrapping, and three far kernels. Five variants were built: baseline, all, explicit speed, off, and final default.
- With the final default, aggregate object code at `-O2` falls from **14,131 to 14,080 bytes in A16** and **13,842 to 13,766 in XY16**. `-Os`/`-Oz` output is byte-identical to the baseline across all 16 fixtures. Only Farblit and the boundary fixture change code in this sample. Both modes use the same policy; this sample does not justify a special size-mode exception for XY16.
- **54 primary ROM/configuration pairs pass MAME and bsnes**, covering three fixtures, two modes, three optimization levels, and baseline/all/speed. Four additional Farblit `-O3` pairs also pass both emulators. Bounds inputs execute word loads across `$xxFFFF`, copy stores across `$7EFFFF`, the scaled 255/256 boundary, wrapping induction/expressions, full-byte cycles, non-unit steps, and call/register pressure.
- [Shape checks](../defects/evidence/2026-09-28-far-word-policy/shape-checks.json) confirm M16/Y8 word folding where expected and preserve the negative cases. At `-O2`, the wrapping fixture is partly unrolled; its existing constant-displacement accesses are compared with baseline shapes rather than misclassified as runtime folds.
- The new **12-case MIR regression** covers size/no-opt attributes, default and explicit policies, `-O0`/`-O1`/`-O3`, boundary/wrapping recurrences, and mixed word/byte groups in both visitation orders. It passes with the existing range, native-word, and far-indexed regressions. The assertion-only legalizer observer test is unsupported by this Release build; its separate status is retained in the initial lit log.
- Disabled output reproduces **96 baseline objects and 18 ROMs** exactly. The final default reproduces the explicit speed results exactly. The [installed compiler](../defects/evidence/2026-09-28-far-word-policy/installed-control.json) then reproduces all **96 default objects and 18 ROMs** exactly. Patch-stack reconstruction passes; the original 0002 bytes are preserved after verifying that regeneration only changes diff metadata and file ordering.

The initial packaging attempt filled `/tmp` and interrupted an installed-control run. Both checks passed when rerun with temporary files on the workspace disk. Failed setup logs are retained; they are not compiler defects.

## Reproduction and remaining work

The preserved workspace is `.scratch/far-word-policy`. It contains baseline, explicit-policy, and final-policy compiler binaries, an isolated build tree, source overlays, and runners. [The evidence directory](../defects/evidence/2026-09-28-far-word-policy/) retains the source and run archives, scripts, commands, hashes, and logs. The source archive includes the final vendor diff/untracked overlay and the baseline legalizer override. Binaries remain local.

The local speed/size decision is complete. Before upstream submission, obtain independent review, inspect the exact destination's guards/callers/tests/history, and reconcile the #320/#321 and 0069 prerequisites. Broader application speed measurements can refine the policy; these measurements do not establish profitability for every program.

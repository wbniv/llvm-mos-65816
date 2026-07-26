# Plan: oop-in-c.md refresh + all-virtual snesgfx dispatch benchmark

**Date:** 2026-07-26 · **Status:** DONE (experiment on `throwaway/snesgfx-virt-bench` `8ad0f28`,
fate pending user decision) · **Results:**
[investigation](../investigations/2026-07-26-snesgfx-static-vs-virtual-dispatch.md) ·
[charts](../investigations/2026-07-26-snesgfx-dispatch-charts.html) ·
[patch](../investigations/2026-07-26-snesgfx-all-virtual.patch) · `docs/oop-in-c.md` §8

## Context

`docs/oop-in-c.md` had drifted (claimed 12 headers / 29 demos; reality: 13 / 113) and carried two
unsound claims: unsourced "~8 cycles" dispatch estimates (plus a selector-table row for a table
that never existed), and a "0 indirect JMPs / LTO devirtualized" §4 claim produced by
`grep -c 'jmp (' || true` over a possibly-missing ELF. The user then asked to **benchmark a design
change: make ALL statically-dispatched member functions virtual and measure the difference.**
Adoption decision deferred until numbers exist → experiment runs throwaway-first.

## Design (as executed)

- **Three-mode `SNESGFX_DISPATCH`** switch in new `snesgfx/dispatch.h`: 0 = static inline
  (byte-identical to production), 1 = out-of-line direct (`noinline` impls — isolates
  loss-of-inlining), 2 = per-type vtables (`self->vt->verb(...)` — adds indirection). Forwarder +
  `_impl` split; ~40 members, 11 headers; constructors/HScrollN/free-functions excluded (see doc §8).
- **Vehicles:** `mandel-oop.c` (correctness `0x204F`, `.text`, indirect-site count via hardened
  `dev/mandel-oop.sh`) + new `snesgfx_bench.c` throughput ROM (canvas star; volatile `iters` at a
  fixed bsnes-jg frame; host oracle CRC `0x26EC`) via new `dev/measure-snesgfx-dispatch.sh`.
  **bsnes-jg-only** (no SPC700 IPL on this machine → MAME leg SKIP, the repo's JG_ONLY posture);
  `dev/probe-cycles.lua`/MAME plan-variant not usable here.
- **Worktree:** `throwaway/snesgfx-virt-bench` off main `9bddc38`, hardlinked build assets per
  `docs/howto-feature-worktree.md`.
- **Landed on main:** `docs/oop-in-c.md` refresh + §8; `TODO.md:371` dated correction;
  `dev/mandel-oop.sh` hardening (ELF assert, `$TOOL/llvm-objdump`, full indirect pattern,
  `SNESGFX_CFLAGS`); `dev/run.sh` env forwarding (`SNESGFX_CFLAGS`, `BENCH_FRAMES`); investigation
  doc + charts + archived patch + this plan. **Stayed on throwaway:** the header conversion, bench,
  oracle, measure script (re-appliable from the patch).

## Headline results

| | mode 0 inline | mode 1 out-of-line | mode 2 all-virtual |
|---|---|---|---|
| bench redraws / 2400 f | 175 | **201 (15% faster)** | 149 (1.35× vs m1) |
| bench `.text` | 1,918 B | 1,934 B | 2,199 B (+15%) |
| mandel-oop `.text` | 3,660 B | 3,537 B (−3.4%) | 5,470 B (+49%) |
| mandel-oop indirect sites | 1 | 2 | 15 (LTO devirtualizes 0) |
| invaders `.text` | 12,972 B | **11,571 B (−10.8%)** | 15,647 B (+20.6%) |
| invaders indirect sites / gate | 1 / PASS | 2 / PASS | 57 / PASS (`0x9D57`) |

## Verification

1. **Counts** — `ls examples/snes/snesgfx/*.h | wc -l` → 13; snesgfx-including demos → 113; no
   stale numbers outside the intentionally-preserved struck-through TODO history line.

    ```
    $ ls examples/snes/snesgfx/*.h | wc -l
    13
    $ grep -l '#include *"snesgfx/' examples/snes/*.c | wc -l
    113
    $ grep -nE '\b(29 demos|12-header|12 headers)\b' docs/oop-in-c.md TODO.md
    TODO.md:371: ... ~~... 12 committed headers, 29 demos ...~~ *(2026-07-26 refresh: now 13 headers / 113 demos; ...)*
    ```

    **PASS** — docs/oop-in-c.md clean; the TODO hit is the struck-through historical record with
    the dated correction appended in the same line (plan chose preserve-history over rewrite).

2. **Mode-0 neutrality** — post-conversion worktree `dev/run.sh mandel-oop`:

    ```
    SMOKE: PASS off=0x447 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
        indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1
        mandel-oop  .text: 3660 bytes
    RESULT: PASS
    ```

    **PASS** — `.text` 3660 B and 1 indirect site, both identical to the pre-conversion baseline run.

3. **Mode-1/2 correctness** — `SNESGFX_CFLAGS=-DSNESGFX_DISPATCH=N dev/run.sh mandel-oop`:

    ```
    [mode 1] SMOKE: PASS off=0x447 len=2 got=0x204F ... .text: 3537 bytes ... call sites: 2
    [mode 2] SMOKE: PASS off=0x512 len=2 got=0x204F ... .text: 5470 bytes ... call sites: 15
    ```

    **PASS** — CRC `0x204F` both modes, `-verify-machineinstrs` clean.

4. **Dispatch reality** — mode-2 counts > 0 (15 mandel-oop / 5 bench, above); mode-0 count == 1 ==
   pre-refactor baseline. **PASS** (no devirtualization-laundering barrier needed).

5. **Throughput** — `BENCH_FRAMES=2400 dev/run.sh measure-snesgfx-dispatch`:

    ```
      mode                            .text B  ind.calls      iters
      0 static inline (today)            1918          0        175
      1 out-of-line direct               1934          0        201
      2 all-virtual (vtables)            2199          5        149
      inlining-loss cost   (iters0/iters1): 0.87x
      indirection cost     (iters1/iters2): 1.35x
      total virtual cost   (iters0/iters2): 1.17x
    RESULT: PASS — all 3 modes correct; see table
    ```

    **PASS** — all 3 corpus CRCs == host oracle `0x26EC`; iters₁ ≥ iters₂ holds (iters₀ < iters₁
    is the genuine mode-1 finding, not an artifact — identical ratios at 600 frames: 40/46/34).

6. **ELF-missing guard** — the hardened counting stanza against a nonexistent ELF path:

    ```
        FAIL: build/definitely-missing.elf missing — cannot count indirect dispatch
    stanza rc=1 (1 = guard fired, correct)
    ```

    **PASS** — explicit FAIL, no silent 0.

7. **Main regression** — on main with cherry-picked hardening, `dev/run.sh mandel-shot &&
   dev/run.sh mandel-oop`:

    ```
    SMOKE: PASS off=0x52A len=2 got=0x204F (ran 5800 frames, bsnes-jg)
        indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1
        mandel-oop  .text: 3682 bytes
    RESULT: PASS — mandel-oop OOP gate GREEN
    ```

    **PASS** — note: main measured 3,682 B vs the worktree's 3,660 B because another worker has
    uncommitted `snesgfx/display.h`/`upload.h` edits in main's working tree (left untouched per
    the shared-tree rule); the experiment's quotable numbers are the clean-worktree ones.

8. **Teardown** — RESOLVED 2026-07-26: user decided to **keep** `throwaway/snesgfx-virt-bench`
   for follow-on experiments ("more things to consider"). No teardown; branch is live.

9. **invaders.c measurements** (user-requested follow-up, same session) —
   `BENCH_FRAMES=2400 dev/run.sh measure-snesgfx-dispatch` with the invaders Part-2 extension:

    ```
    ==> Part 2: invaders.c (attract gate, +mos-a16)
        host oracle attract CRC16=0x9D57; settle=1400 frames
      mode 0 gate:    SMOKE: PASS off=0x25 len=2 got=0x9D57 (ran 1400 frames, bsnes-jg)
      mode 1 gate:    SMOKE: PASS off=0x25 len=2 got=0x9D57 (ran 1400 frames, bsnes-jg)
      mode 2 gate:    SMOKE: PASS off=0xB6 len=2 got=0x9D57 (ran 1400 frames, bsnes-jg)
    ==> RESULTS invaders.c (attract gate @1400 frames, oracle 0x9D57)
      mode                            .text B  ind.calls   gate
      0 static inline (today)           12972          1   PASS
      1 out-of-line direct              11571          2   PASS
      2 all-virtual (vtables)           15647         57   PASS
    RESULT: PASS — all 3 modes correct; see table
    ```

    **PASS** — all 3 modes reproduce the canonical attract CRC (also proving mode 2 still fits
    the frame budget); out-of-line direct is −10.8% `.text` on the real game, all-virtual +20.6%
    with 57 surviving indirect sites. Bench + mandel-oop numbers unchanged (175/201/149).

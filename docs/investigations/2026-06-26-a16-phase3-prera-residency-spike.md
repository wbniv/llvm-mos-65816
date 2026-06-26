# #321 A16-threading Phase 3 — trigger-check + pre-RA `Ac16`-residency spike (CLOSE: measured net-negative)

**Date:** 2026-06-26 · **Status:** DONE — verdict recorded · **Branch:** `throwaway/a16-phase3-spike`
(torn down; durable artifacts merged to `main`). **Plan:**
[`docs/plans/2026-06-26-321-a16-threading-phase-3-trigger-check-pass-re-op.md`](../plans/2026-06-26-321-a16-threading-phase-3-trigger-check-pass-re-op.md).

## TL;DR

The Phase-3 re-open trigger **(b) fired** — real heavy-16-bit-math kernels now use most/all of the `Imag16`
pool — so we ran the gated **B0→B1** spike to answer *"is pre-RA `Ac16` residency worth landing?"*. Answer,
**measured end-to-end: NO.** Pre-RA residency works and fires heavily, but delivers **zero peak-ZP-pressure
relief** and a **net +24 B code-size regression** across the real a16 kernel set. The high pressure is
*genuinely-simultaneous* live 16-bit values that the single 65816 accumulator cannot thread away — exactly
the deferral's stated cap, now **proven, not assumed**. Phase 3 is therefore **closed as net-negative**, not
left open: the trigger is re-framed (a proxy FIRE is necessary but not sufficient; the *fix* is what's
net-negative).

## What prompted it

The 2026-06-18 ZP-pressure baseline had the busiest real function at ~5/14 pairs → DEFER. By 2026-06-26 the
project had added heavy-16-bit math kernels (the trig **CORDIC** library `k_trig16`/`k_trig32`, **Mandelbrot**
`k_mandel`, **Hopalong** `k_hopalong`). Re-running `dev/measure-zp-pressure.sh` (now with an explicit
Phase-3 trigger line):

```
A16-threading Phase-3 trigger (b): real fns >= 20 B (~10/14 pairs) = 6 (max 28 B ~14 pairs, k_trig16:cordic16_atan2) => FIRE
```

`k_trig16:cordic16_atan2` sits at the **full 14/14 pool**; `k_hopalong:main`, `k_trig16:main`,
`k_trig32:main` at ~10/14. All compile **clean** — tight, not broken.

## Phase A — triggers

- **(b) FIRED** — 6 real functions ≥ ~10/14 pairs (above). Realistic code (CORDIC/Mandelbrot/Hopalong), not
  hand-reduced.
- **(a) NOT fired** — full kernel+corpus sweep `-verify-machineinstrs` clean at `-O1`/`-Os`; **csmith
  fuzz 200** = 180 PASS / 20 skip / **0 mismatch / 0 crash / 0 error**. No realistic
  `regalloc-out-of-registers` / `a16-zp-pressure-overflow`.

## Phase B0 — `shouldCoalesce` Ac16 barrier: GO (proven inert)

Added the `{Anyi1,Anyi8,GPR} → Ac16RegClass` coalescer barrier (`MOSRegisterInfo::shouldCoalesce`). Isolated
*within one build environment* (same vendor snapshot, with-vs-without the one rule), it is **byte-for-byte
inert across all 190 example+corpus compilations** at `-O1`/`-Os` → confirms the model **"no 8-bit↔Ac16
coalesce happens in today's codegen"**. (A first diff *against main's installed clang* showed a false
`far_near_call.c` delta — that was **hot-shared-tree vendor drift**, main's installed clang predating the
cp'd vendor; isolating within one build env removed it. Lesson: compare with-vs-without **in the same
build**, never against a separately-built toolchain.)

## Phase B1 — pre-RA `Ac16` residency (flag `-mos-a16-prera-residency`, off by default): **NO-GO**

A flag-gated pre-RA `MachineFunctionPass` (`MOSPreRAAccum16`, added beside `threadAccum16`) that mirrors the
post-RA round-trip collapse on still-SSA virtual regs: for `%lo = LDAImag16 %home` whose single-def is
`%home = STAImag16 %src` in-block, RAUW `%lo→%src` and drop the reload (+ the now-dead store). B0's barrier is
its mandatory safety companion. Measured (flag ON vs OFF):

| Evidence | Result |
|---|---|
| Pass fires? | **Yes, heavily** — `k_trig16` 551→448 STA/LDA (**−103**), `k_hopalong` 41→24, `k_mandel` 35→23, `k_isort` 21→16, `k_bits` 17→13, `k_crc16` 10→8 |
| Correctness | **All 190** examples/corpus `-verify-machineinstrs` **clean** flag-ON (B0 barrier holds) |
| **Peak ZP pressure** | **Zero relief** — `cordic16_atan2` **14/14 → 14/14**; *every* kernel's distinct `__rc` unchanged |
| **Code size** | **+24 B WORSE** across all `k_*.c` (7798→7822 B); `k_trig16` **+26 B**; `k_hopalong` −2 B; neutral elsewhere |
| Default build (flag OFF) | **Byte-identical** to the no-spike baseline across all 190 → inert, lands nothing |

**Root cause (measured).** The single 65816 accumulator. The pool-filling values in these kernels are
*genuinely simultaneously live* (CORDIC state x/y/z + table pointer; Mandelbrot z_re/z_im/c_re/c_im) — they
**must** occupy distinct `Imag16` pairs no matter how single-use transits are threaded. The post-RA
`threadAccum16` already collapses the *transit* round-trips for free; doing it pre-RA adds nothing for peak
pressure and, by *widening* `Ac16` ranges that the lone accumulator can't hold, forces slightly worse spill
placement → the mild regression. This is precisely the deferral's "realizable gain capped by the single
accumulator / reopens regression risk on the common path", now **empirically confirmed**.

Per the B1 gate ("NO-GO if any win regresses"): **NO-GO**. Per project lesson #2/#3 (a blanket change that
regresses common shapes is wrong) and "close net-negative findings, don't defer": **close Phase 3**.

## Verdict & disposition

- **Phase 3 (pre-RA `Ac16` residency) is CLOSED as measured net-negative** — not "deferred pending trigger."
  The trigger fired; the spike answered.
- **Trigger re-framed.** A `dev/measure-zp-pressure.sh` FIRE (≥10/14 pairs) is **necessary but not
  sufficient** — the *fix* is net-negative, so a FIRE alone does not justify building Phase 3. The only thing
  that could re-open is a **genuinely different remedy** for an *actual* realistic `Imag16` overflow
  (`pr15296`-class), e.g. better `Imag16` spill packing — **not** accumulator residency.
- **Nothing landed.** B0 is proven-inert but only matters *with* B1, so it is **not** landed (per "don't add
  defensive code for a feature we're not building"). The full B0+B1 spike is preserved for reproducibility:
  [`2026-06-26-a16-phase3-prera-residency-spike.diff`](2026-06-26-a16-phase3-prera-residency-spike.diff)
  (`+115` lines: the `shouldCoalesce` barrier, the `MOSPreRAAccum16` pass + flag, and the pipeline wiring).

## Reproduce

```bash
# trigger (b): the explicit FIRE/defer-stands line
dev/measure-zp-pressure.sh | tail -1

# the spike (compiler-editing worktree; flag is off by default → measurement only)
#   apply docs/investigations/2026-06-26-a16-phase3-prera-residency-spike.diff to vendor/llvm-mos, rebuild, then:
CF="--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os"
F="-mllvm -mos-a16-prera-residency"
# fires (round-trips collapse) but pressure unchanged + bytes worse:
mos-clang $CF      -c examples/65816/k_trig16.c -o off.o   # .text 4355 B
mos-clang $CF $F   -c examples/65816/k_trig16.c -o on.o    # .text 4381 B (+26), cordic16_atan2 still 14/14
```

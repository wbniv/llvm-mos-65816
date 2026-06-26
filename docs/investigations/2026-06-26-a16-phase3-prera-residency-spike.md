# #321 A16-threading Phase 3 — trigger-check + pre-RA `Ac16`-residency spike (CLOSE: measured net-negative)

**Date:** 2026-06-26 · **Status:** DONE — verdict recorded · **Branch:** `throwaway/a16-phase3-spike`
(torn down; durable artifacts merged to `main`). **Plan:**
[`docs/plans/2026-06-26-321-a16-threading-phase-3-trigger-check-pass-re-op.md`](../plans/2026-06-26-321-a16-threading-phase-3-trigger-check-pass-re-op.md).

## TL;DR

The Phase-3 re-open trigger **(b) fired** — real heavy-16-bit-math kernels now use most/all of the `Imag16`
pool — so we ran the gated **B0→B1** spike to answer *"is pre-RA `Ac16` residency worth landing?"*. Answer,
**measured end-to-end: NO.** Pre-RA residency works and fires heavily, but delivers **zero peak-ZP-pressure
relief** and a code-size **regression** (B1: +24 B over the kernels; **B2: +530 B over the whole example+corpus
set, 41 files worse / 6 better**), while being fully correct (corpus 7/7, a16/k_ suite 66/66, csmith 200
0-mismatch, 196/196 `-verify`-clean). The high pressure is *genuinely-simultaneous* live 16-bit values that the
single 65816 accumulator cannot thread away — exactly the deferral's stated cap, now **proven, not assumed**.
A follow-up probe (below) confirmed there is **no pressure-neutral post-RA win** to salvage from the 6
winners either. Phase 3 is therefore **closed as net-negative**, not left open: the trigger is re-framed (a
proxy FIRE is necessary but not sufficient; the *fix* is what's net-negative).

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

## Phase B2 — broad differential correctness + net size (residency ON): **NO-GO**

Rebuilt the spike with the flag **defaulted on** so the differential harness (which can't inject `-mllvm`)
exercises residency, then ran the full B2 gate:

| B2 check | Result |
|---|---|
| Whole-set net `.text` (OFF vs ON, all examples+corpus, `-O1`+`-Os`) | **65580 → 66110 B = +530 B WORSE** (196 pairs; **41 worse, 6 better**) |
| Emulator differential | **corpus 7/7** (host==default==`+mos-a16` on MAME+bsnes-jg), **a16/k_ suite 66/66**, **csmith 200: 0 mismatch / 0 crash / 0 error** |
| `-verify-machineinstrs` (residency ON) | **196/196 clean** |

Residency is **correct** (runs identically on both emulators) but the B2 "net-neutral-or-better across the
whole set → land" criterion **fails hard** (+530 B). The regression is broad, not a tail artifact.

## Post-RA extension probe — can the 6 winners be salvaged pressure-neutrally? **NO.**

The 6 winning `(file,opt)` pairs are 3 files — `a16cmpaudit.c` −82 B (a *synthetic* harness exercising every
16-bit compare form), `a16loadcall.c` −10 B (micro-test), `k_hopalong.c` −2 B (the only real kernel). They
win because they are **low register pressure** (threading removes round-trips without forcing spills); the
losers are high-pressure (`a16s32` +88, CORDIC `k_trig16x`/`k_trig16` +58/+26, the `*spillr` spill tests +34).
Two facts kill any "just the winners" gate:

1. **Consumer kind does not separate win from loss** — `a16cmpaudit` *wins* with ~90% ALU/shift consumers;
   `k_trig16` *loses* with 82 compare consumers. The discriminator is **register pressure**, which a pre-RA
   pass cannot reliably predict (RA decides it later) — i.e. a conservative "never-regress" gate *is* the
   deferred RA-integration, not a cheap heuristic.
2. **There is no pressure-neutral post-RA win left.** In `a16cmpaudit`'s post-`threadAccum16` MIR (flag off),
   **0** A-clean `STAImag16`→`LDAImag16` pairs survive — the post-RA peephole has already removed every
   *resident* round-trip. The 220 surviving reloads are all **A-dirty**: the single `$a16` was reused by an
   intervening 16-bit op (`$rs4 = STAImag16 $a16` … `$a16 = LDAImag16 $rs13` — a *different* value cycling
   through the one accumulator), so the value genuinely lives in `Imag16` and the reload is *necessary*.
   Threading those post-RA would be incorrect (the value isn't in `$a16`); making it correct = keeping it
   resident across the reuse = the pre-RA residency that just measured net-negative.

So the residency benefit is **intrinsically RA-level** (keep a value live across the single accumulator's
reuse). There is nothing to extract at the pressure-safe post-RA layer.

## Verdict & disposition

- **Phase 3 (pre-RA `Ac16` residency) is CLOSED as measured net-negative** — not "deferred pending trigger."
  The trigger fired; the spike answered.
- **Trigger re-framed.** A `dev/measure-zp-pressure.sh` FIRE (≥10/14 pairs) is **necessary but not
  sufficient** — the *fix* is net-negative, so a FIRE alone does not justify building Phase 3. The only thing
  that could re-open is a **genuinely different remedy** for an *actual* realistic `Imag16` overflow
  (`pr15296`-class), e.g. better `Imag16` spill packing — **not** accumulator residency.
- **Nothing landed.** B0 is proven-inert but only matters *with* B1, so it is **not** landed (per "don't add
  defensive code for a feature we're not building"). The raw spike `.diff` was **not retained** (Phase 3 is
  closed, nothing to land); the implementation is fully described in §Phase B0/B1 above — the
  `shouldCoalesce` `{Anyi1,Anyi8,GPR}→Ac16` barrier, the pre-RA `MOSPreRAAccum16` SSA-threading pass + the
  `-mos-a16-prera-residency` flag, and the `addMachineSSAOptimization` pipeline wiring — and is
  reconstructible from that if ever revisited.

## Reproduce

```bash
# trigger (b): the explicit FIRE/defer-stands line
dev/measure-zp-pressure.sh | tail -1

# the spike (compiler-editing worktree; flag is off by default → measurement only)
#   re-create the B0 barrier + MOSPreRAAccum16 pass per §Phase B0/B1 above, rebuild, then:
CF="--target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os"
F="-mllvm -mos-a16-prera-residency"
# fires (round-trips collapse) but pressure unchanged + bytes worse:
mos-clang $CF      -c examples/65816/k_trig16.c -o off.o   # .text 4355 B
mos-clang $CF $F   -c examples/65816/k_trig16.c -o on.o    # .text 4381 B (+26), cordic16_atan2 still 14/14
```

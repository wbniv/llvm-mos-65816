# #321 — zero-page-pressure measurement (CC-frame revival trigger + multi-value Phase 0)

**Date:** 2026-06-18 · **Status:** **DONE — baseline captured (on throwaway branch `throwaway/321-zp-pressure`).**
**Issue:** #321, ROADMAP M2.
**Required reading:**
[CC frame decision — phased (this is its named revival trigger)](2026-06-18-321-cc-frame-phased-decision.md) ·
[multi-value register pressure (this is its Phase 0 scan)](2026-06-18-321-16bit-alu-multivalue-register-pressure.md).

## Context

The CC frame decision (`e30f01c`) **phased it** — keep the soft static stack; **defer the TCD DP-window
behind a zero-page-pressure measurement.** This builds that measurement (`dev/measure-zp-pressure.sh`,
standalone, host-only) and captures a baseline, turning the deferred trigger into data. It double-serves as
the **Phase 0 trigger scan** for the multi-value-register-pressure item. Run on a **throwaway worktree**
(investigation hygiene — `main` stays clean, doubly so on a hot multi-agent tree).

## Metric

Per-function **distinct allocatable `__rc<N>`** in `+mos-a16 -Os -S` output (live-range reuse ⇒
distinct-names ≈ peak imaginary-register pressure); reserved `__rc0/1` (soft-SP), `__rc16/17` (scavenger)
excluded. Usable 16-bit pool = **14 pairs = 28 bytes**. Synthetic `rep+sep` bracket count is the
fragmentation cross-check.

## Results (baseline, 2026-06-18)

**Synthetic ladder (metric validated — monotonic + fragmentation cross-check):**

| shape | live s16 | distinct_rc | rep+sep |
|---|---|---|---|
| syn1 | 1 | **0** (threads through A16) | 2 (1 bracket) |
| syn2 | 2 | 2 (~1 pair) | 2 |
| syn3 | 8 | 8 (~4 pairs) | 2 (still 1 bracket) |
| syn4 | ~20 | 22 (~11 pairs; overflow spills to stack) | **26 (13 brackets)** |

syn4's 13 brackets exactly reproduce the prior session's fragmentation observation — metric is sound.

**Real code (the verdict sample):**

```
kernels:  k_bits:main=10  k_isort:main=8  k_fxmul:main=6  k_prng:{main=3,xs16=4}  k_crc16:main=4  k_satadd:main=4
corpus:   arith:main=9  structs:main=7  control:main=6  funcs:{main=2,fib=6}  arrays:main=4   [globals: SEE FINDING]
SUMMARY:  real-code fns n=13  max=10 bytes (~5 pairs, k_bits:main)  mean=5.6   #(>=24B)=0   #(>28B)=0
a16 micro-tests: n=54  max=12  mean=2.7 (leaf floor)
```

## Verdicts

- **CC-frame DP-window (a): SHELVE with evidence.** The ZP is **slack** — the busiest real function uses
  **10 / 28 bytes (~5 of 14 pairs)**, mean ~2.8 pairs. Nothing approaches the budget, so moving locals to a
  DP frame would relieve pressure that **isn't there**. (c) the soft static stack stands for the first-pass
  ABI. Revisit only if future code (or a stabilized-xy16 re-run) pushes real functions toward the ceiling.
- **Multi-value fragmentation Phase 0: DEFER confirmed.** No real function exhausts the pool or fragments;
  the spill-fusion peephole has no real-world trigger. (The 20-live *synthetic* `syn4` does fragment — the
  pathological-only case the plan already identified.)

## FINDING (new defect, surfaced by this measurement)

**`examples/snes/corpus/globals.c:main` fails register allocation under `+mos-a16 -Os`** — *"ran out of
registers during register allocation in function 'main'."* Triage (minimal, conclusive):

| invocation | result |
|---|---|
| DEFAULT 8-bit (any `-O`) | ✅ |
| `+mos-a16 -O0` / `-O2` | ✅ |
| **`+mos-a16 -O1` / `-Os`** | ❌ ran out of registers |

So it is **`+mos-a16`-specific and confined to `-O1`/`-Os`** (`-O0` and `-O2` are clean). **Root-caused
2026-06-18 — full record:
[a16-regalloc-pressure-failure](../investigations/65816-a16-regalloc-pressure-failure.md).** NOT raw value
count — it's `-Os` **over-coalescing**: pre-RA MIR shows `-Os` produces **fewer but longer-lived** `Ac16`
ranges (8 distinct vregs) than `-O2` (14), yet only `-Os` crashes — the coalesced long ranges all need the
*single* `A16` at once and can't be split/spilled apart, so the allocator gives up; `-O2` keeps the values in
more, shorter vregs it *can* satisfy. **The regression corpus is built default 8-bit, so this was never
exercised under `+mos-a16`**, and the fuzzer doesn't generate the shape — hence undiscovered. (**Gap now
closed:** `dev/run.sh corpus-a16` builds the corpus `+mos-a16`/`+mos-xy16` differentially —
[corpus-a16 plan](2026-06-19-321-corpus-a16-differential-mode.md); `globals` stays XFAIL'd until the Phase-3
fix.) A *hard crash*,
more severe than the fragmentation the multi-value plan modeled; it is the
[A16-threading Phase 3](2026-06-17-321-a16-threading.md) hard core (single-`Ac16` residency).

**Follow-up status (2026-06-18):** (1) TODO defect filed ✓; (2) deterministic repro
`examples/65816/a16regpress.c` ✓ (`cca1694`); (3) fuzzer `KNOWN_ISSUES` XFAIL `regalloc-out-of-registers` ✓
(generator-shape extension still optional); (4) **root-caused ✓ via an isolated asserts build (`50a59b5`)** —
pinpointed it (hard-register A/X/Y exhaustion + unspillable INF `Ac16` transits; **coalescing ruled out**) and
proved there is **no targeted fix**, only the general Phase-3 `Ac16`-residency rework (high-risk to the common
a16 path / low-reward). **DECISION 2026-06-18: keep the XFAIL** for this *pathological* bug (real code is
slack); **reevaluate at M2 wrap-up** (TODO Watch) — [A16-threading Phase 3](2026-06-17-321-a16-threading.md)
is the fix home, `a16regpress.c` the acceptance case.

## Verification

1. **`dev/measure-zp-pressure.sh` runs clean** (exit 0) over synthetic + kernels + 5/6 corpus + 54 a16
   micro-test functions; `-h` exits 0. **PASS** (raw output above; `globals` is the FINDING, not a script
   bug — it's a real compile failure).
2. **Metric sanity: PASS** — ladder monotonic (0 < 2 < 8 < 22); syn4 (~20 live) = 26 rep+sep (13 brackets),
   matching the prior-session fragmentation.
3. Verdicts recorded above; cross-reference into the CC record + multi-value plan + TODO is the merge-back
   follow-up.
4. **No codegen change** — script + docs only; `vendor/` untouched, `0002` not regenerated.
5. Done on the **throwaway branch**; merge the script + this plan to `main` (keepers), then `worktree remove`.

## Disposition

**KEEP** — the script (reusable), this baseline, and the `globals.c` finding are all durable. Merge to `main`.
The DP-window (a) and the fragmentation peephole both stay shelved **with measured evidence**. The
`globals.c` `+mos-a16 -Os` RA failure is promoted to its own follow-up.

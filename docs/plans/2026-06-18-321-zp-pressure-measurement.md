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
| DEFAULT 8-bit `-Os` | ✅ |
| `+mos-a16 -O0` | ✅ |
| **`+mos-a16 -Os`** | ❌ ran out of registers |

So it is **`+mos-a16` + `-Os`-specific**. `globals.c:main` sums ~12 live `u16` globals (`data_vals[4]` +
`bss_vals[8]` + bytes); at `-Os` the optimizer's register pressure exhausts the a16 allocator (at `-O0`,
heavier spilling survives). **The regression corpus is built default 8-bit, so this was never exercised
under `+mos-a16`**, and the differential fuzzer doesn't generate this shape — hence undiscovered. This is a
*hard crash*, a more severe class than the fragmentation the multi-value plan modeled (which produces
correct-but-bloated code). It belongs with the F3 / soft-stack spill-coverage line of robustness work.

**Recommended follow-up (separate from this measurement):** (1) file/track a `#321` defect; (2) reduce to a
hermetic `.ll` / minimal-C repro; (3) extend `tools/a16_fuzz.py` to generate many-live-`u16`-global shapes so
the fuzzer catches this class; (4) root-cause + fix (likely allocator/spill-path, the F3 family). **Not
fixed here** — out of scope for the measurement.

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

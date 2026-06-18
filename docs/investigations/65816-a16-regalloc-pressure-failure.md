# `+mos-a16` register-allocation failure under `-O1`/`-Os` (the `globals.c` crash) — root cause

*Deep root-cause record for the `+mos-a16` "ran out of registers" compile failure surfaced by the
[ZP-pressure measurement](../plans/2026-06-18-321-zp-pressure-measurement.md). The fix is the
[A16-threading Phase 3](../plans/2026-06-17-321-a16-threading.md) hard core; this note pins down **why**,
**how risky**, and **what a correct fix requires** so it can be done deliberately rather than guessed.*

## Symptom

`examples/snes/corpus/globals.c:main` (and the reduced repro `examples/65816/a16regpress.c`) aborts
compilation: **`error: ran out of registers during register allocation in function 'main'`**. The shape: a
`u16` accumulator held live across a *second* accumulation loop, alongside two `u16*u8` multiplies.

## Triage — optimization-level-specific, not value/codegen

| invocation | result |
|---|---|
| DEFAULT 8-bit `-O0`/`-Os`/`-O2` | ✅ compiles |
| `+mos-a16 -O0` | ✅ |
| `+mos-a16 -O1` | ❌ ran out of registers |
| **`+mos-a16 -Os`** | ❌ ran out of registers |
| `+mos-a16 -O2` | ✅ |

**Crashes at `-O1`/`-Os`; safe at `-O0` and `-O2`.** Only `+mos-a16` is affected. So the *code is
allocatable in principle* (`-O2` proves it) — this is not a missing lowering; it is a register-pressure /
allocation-schedule failure.

## Root cause — `-Os` over-coalesces into unallocatable long `Ac16` live ranges

The 65816 has **one** physical 16-bit accumulator (`Ac16` = `A16`). Every native-s16 value that wants to be
"in the accumulator" is an `Ac16` vreg; with more than one live at a time they must round-trip through the
zero-page `Imag16` pool (≈14 usable pairs) or spill. The counterintuitive evidence (pre-RA MIR,
`-mllvm -stop-before=greedy`):

| build | distinct `Ac16` vregs | MIR instrs | result |
|---|---|---|---|
| `-Os` | **8** | 83 | ❌ crash |
| `-O2` | **14** | 123 | ✅ ok |

`-Os` has **fewer** `Ac16` vregs than `-O2` yet crashes. The reason: `-Os` **coalesces aggressively for
size**, producing fewer but **longer-lived** `Ac16` ranges that overlap and *all* demand the single `A16`
simultaneously — and the allocator cannot split/spill them apart, so it gives up. `-O2` keeps the values in
**more, shorter-lived** vregs the allocator *can* satisfy by spilling/reloading; `-O0` has low pressure.
(`-O1` patterns like `-Os` here.) So the trigger is the **interaction of `-Os` coalescing with the
single-accumulator constraint**, not raw value count.

## Why it went undiscovered

The M0/M1 regression **corpus is built DEFAULT 8-bit** (`globals.c` only ever saw the 8-bit path), and the
differential fuzzer's generator never emits this two-loop / cross-loop-live-accumulator / two-multiply shape.
So no existing gate exercised `globals.c` under `+mos-a16 -Os`. Surfaced only because
`dev/measure-zp-pressure.sh` compiled the corpus `+mos-a16 -Os`.

## The fix locus — and why it is hard and risky

This is the **single-accumulator residency problem**, i.e. the
[A16-threading **Phase 3** hard core](../plans/2026-06-17-321-a16-threading.md) the team deliberately
deferred. The lever is `MOSRegisterInfo::shouldCoalesce` (currently `MOSRegisterInfo.cpp` ~line 731;
the plan cites `:669` — line numbers drift) and/or `Ac16` live-range splitting / spill robustness. The
candidate is the plan's Phase-3 idea: a `shouldCoalesce` rule that prevents the over-coalescing that creates
unallocatable long `Ac16` ranges (or forces splits), relying on the F3 / soft-stack `Ac16` spill path
(`STAImag16`/`LDAImag16`, `STAbs16`/`STAIndir16`) when RA must spill.

**Two real regression risks make a blind change worse than the current XFAIL (governing lesson: a wrong
answer is 3× worse than "I don't know"):**

1. **Regress A16-threading's wins.** A blanket anti-coalesce barrier would reintroduce exactly the
   `STAImag16`→`LDAImag16` round-trips that A16-threading Phases 1/1.5 eliminated (−31/−36 % on dependent
   chains). The fix must relieve *this* pressure case without un-threading the common case.
2. **Reopen the 1d coalescer crash.** Coalescing an 8-bit class into `Ac16`/`A16` is the `$a16 = LDImm`
   corruption that crashed the 1d prototype. A `shouldCoalesce` change in this area must keep the
   `A16 = B:A` aliasing intact and not perturb that path.

**A correct fix needs an asserts build.** The release toolchain (`-DCMAKE_BUILD_TYPE=Release`, no
assertions) reports only the bare "ran out of registers"; `-mllvm -debug-only=regalloc` is unavailable.
Pinpointing the *exact* culprit coalesce / failing vreg — required to target the `shouldCoalesce` rule
without guessing — needs a `RelWithDebInfo + LLVM_ENABLE_ASSERTIONS=On` build (a long compile; build into a
separate dir reusing `$ROOT/build/.ccache` per the [handoff](../agent-handoff.md) isolation technique).
Acceptance must include: `a16regpress.c` compiles clean, `a16localx.c` (the coalescer-crash guard) stays
verify-clean, **no A16-threading size regression** (re-run `dev/measure-a16-threading.sh`), and `fuzz 200+`.

## Cost/benefit & recommendation

The bug is **pathological**: the ZP-pressure baseline showed real code is *slack* (busiest real function
≈5 of 14 pairs); this is an `-Os` over-coalescing edge on an unusual two-accumulator shape. It is already
contained — deterministic repro `examples/65816/a16regpress.c`, fuzzer `KNOWN_ISSUES` XFAIL
(`regalloc-out-of-registers`), and a TODO entry.

**Recommendation: fold the fix into A16-threading Phase 3** rather than a one-off patch — it is the same
`shouldCoalesce`/`Ac16`-residency territory and needs the same asserts build + no-regression measurement.
`a16regpress.c` becomes a concrete Phase-3 acceptance case (a function that *crashes* today, not merely
suboptimal). When fixed: drop the fuzzer XFAIL and convert `a16regpress.c` to a positive differential gate.

## Tracking

- Repro: `examples/65816/a16regpress.c` · fuzzer XFAIL: `tools/a16_fuzz.py` `KNOWN_ISSUES["regalloc-out-of-registers"]`.
- TODO: M2 "#321 `+mos-a16 -O1/-Os` register-allocation FAILURE on real code (`globals.c`)".
- Plans: [ZP-pressure measurement](../plans/2026-06-18-321-zp-pressure-measurement.md) (the surfacing) ·
  [A16-threading](../plans/2026-06-17-321-a16-threading.md) (Phase 3, the fix home).

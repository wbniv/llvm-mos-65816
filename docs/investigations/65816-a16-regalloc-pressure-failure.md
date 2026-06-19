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

## Pinpointed via an asserts build (2026-06-18) — and it is NOT a coalescing fix

An isolated `Release + LLVM_ENABLE_ASSERTIONS=On` build (22 min, reusing the shared ccache; the shared
toolchain untouched) + `-debug-only=regalloc` pinned the exact failure:

- **The unspillable vregs are the `Ac16` *transits*.** E.g. `%122:ac16 = LDAbsIdx16 @B,%123` immediately
  consumed by `%27:imag16 = STAImag16 %122`. A 1-instruction load→store range has **`weight:INF`** — you
  can't spill it (nothing lives between def and use), so it *must* hold `$a16` for that instant. Same for the
  `LDAImag16→ADCImag16→STAImag16` accumulation transits (%101/%106/%119 — two-segment INF ranges).
- **The deadlock is hard-register (A/X/Y) exhaustion in the indexed-accumulation loop.** `LDAbsIdx16` needs
  `A16` (=`A:B`) for the 16-bit result *and* `X` for the index; the other 16-bit accumulator cycles through
  `A16` too; the 8-bit loop machinery then has nowhere but `$a` (A16's low-byte alias). The allocator evicts
  and even live-range-splits the 8-bit squatter (`%157`), but every split piece returns to **`$a`** (X/Y are
  taken), so `A16` is never freed for the unspillable `Ac16` transit → *"ran out of registers."*
- **Coalescing is RULED OUT** — `-debug-only=...coalescing` shows zero 8-bit↔`A16`/`Ac16` joins. So the
  plan's named Phase-3 candidate (reject 8-bit→`Ac16` coalescing — which fixes the *1d `LDImm`* crash) does
  **not** apply to this crash.

**Implication: there is no clean targeted one-liner.** Fusing `LD…16→STAImag16` (a selection-time change)
removes the *load* transits but not the `ADCImag16`-chain transits, so it likely won't resolve the loop;
lowering the transits' spill weight fights generic `CalcSpillWeights` (single-instruction ranges are INF by
design). The real fix is the **general Phase-3 work — reduce the number of simultaneous `Ac16` transits the
allocator must place** (pre-RA `Ac16` residency/threading: keep the running value in `A16` across ops so
fewer load/store transits compete), with the soft-stack spill path as fallback. A substantial,
regression-sensitive change (must not un-thread the Phase-1 wins or perturb the common a16 path) — hence a
deliberate Phase-3 project, not a patch.

## Cost/benefit & recommendation

The bug is **pathological**: the ZP-pressure baseline showed real code is *slack* (busiest real function
≈5 of 14 pairs); this is an `-Os` over-coalescing edge on an unusual two-accumulator shape. It is already
contained — deterministic repro `examples/65816/a16regpress.c`, fuzzer `KNOWN_ISSUES` XFAIL
(`regalloc-out-of-registers`), and a TODO entry.

**Recommendation: fold the fix into A16-threading Phase 3** rather than a one-off patch — it is the same
`shouldCoalesce`/`Ac16`-residency territory and needs the same asserts build + no-regression measurement.
`a16regpress.c` becomes a concrete Phase-3 acceptance case (a function that *crashes* today, not merely
suboptimal). When fixed: drop the fuzzer XFAIL and convert `a16regpress.c` to a positive differential gate.

## Related manifestation — link-time ZP overflow (c-torture `pr15296.c`, 2026-06-19)

The c-torture differential gate (Phase 1) surfaced a **second symptom of the same root cause**. On
`gcc.c-torture/execute/pr15296.c` (pointer/union/`intptr_t` games, register-heavy), `+mos-a16` at
`-O1`/`-Os` allocates so many `Imag16` zero-page pairs that the `.zp` section grows **past 256 bytes**, so
an 8-bit zero-page relocation can no longer reach it:

```
ld.lld: error: relocation R_MOS_ADDR8 out of range: 1043 is not in [-128, 255]; references section '.zp.noinit'
```

Same fingerprint as the RA crash — **DEFAULT 8-bit and `+mos-a16 -O0` link clean; `-O1`/`-Os` fail** — but
the over-allocation overflows the ZP *addressing budget* at link instead of exhausting the allocator at
compile. Same `Ac16`/ZP-residency root cause, same fix home (A16-threading Phase 3). Classified
`a16-zp-pressure-overflow` in `KNOWN_ISSUES` so the c-torture gate XFAILs it (the fuzzer never feeds link
errors to `classify_known`, so its behavior is unchanged).

## Tracking

- Repro: `examples/65816/a16regpress.c` · fuzzer XFAIL: `tools/a16_fuzz.py` `KNOWN_ISSUES["regalloc-out-of-registers"]`.
- Sibling (ZP overflow): `vendor/c-torture/execute/pr15296.c` (gitignored) · XFAIL `KNOWN_ISSUES["a16-zp-pressure-overflow"]`.
- TODO: M2 "#321 `+mos-a16 -O1/-Os` register-allocation FAILURE on real code (`globals.c`)".
- Plans: [ZP-pressure measurement](../plans/2026-06-18-321-zp-pressure-measurement.md) (the surfacing) ·
  [A16-threading](../plans/2026-06-17-321-a16-threading.md) (Phase 3, the fix home).

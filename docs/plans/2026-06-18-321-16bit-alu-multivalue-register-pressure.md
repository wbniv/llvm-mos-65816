# #321 — 16-bit ALU chains: multi-value register pressure & spilling

**Date:** 2026-06-18 · **Status:** **CHARACTERIZED (measured) — implementation gated on a Phase 0 trigger scan.**
**Issue:** #321, ROADMAP M2 (step 5 frontier) · **TODO:** M2 "#321 16-bit ALU chain extensions →
*Remaining: spilling when >1 16-bit value is live at once*".
**Predecessors / required reading:**
[1d-retry — the Imag16-resident invariant](2026-06-14-321-increment-1d-retry-imag16-native-s16.md) ·
[1c chains — the single-pseudo threading mechanism](2026-06-14-321-increment-1c-chained-16bit-alu.md) ·
[A16-threading — redundant-reload elimination, Phase 3 deferral](2026-06-17-321-a16-threading.md) ·
[soft-stack spill coverage / SPILL CONTRACT](2026-06-16-321-soft-stack-spill-coverage.md).

---

## TL;DR (the measured bottom line)

The backlog item's premise — *"what happens when register pressure exceeds one 16-bit slot"* — rests on
the A16-threading note that "two live 16-bit values must spill to `Imag16`." **Measurement on the built
toolchain (2026-06-18) shows that premise is mostly already solved, and the framing is misleading:**

1. There is **not one 16-bit slot — there are ~14.** `Ac16` (the hardware accumulator, `A`) is the
   *transient* compute register; the 16-bit *register file* is the `Imag16` zero-page pool (`RS1`–`RS7`,
   `RS9`–`RS15` usable = **14 sixteen-bit pairs**; `RS0` = soft-stack ptr, `RS8` = scavenger temp,
   `RS16`–`RS127` reserved — `MOSRegisterInfo.cpp` `getReservedRegs`).
2. For **2–9 simultaneously-live s16 values** (the realistic multi-value case) the codegen is **already
   tight**: distinct `Imag16` pairs, **one `rep`/`sep` bracket** for the whole body, and the *second* live
   value is read as a **folded memory operand** (`and __rc2`, `adc __rc4`, `eor __rc2`) — never round-tripped
   through a register. The only reloads present are **fundamentally necessary** (a value consumed twice
   after `A` was overwritten — irreducible on a one-accumulator machine). Measured **−58 % … −65 %** vs the
   default 8-bit build.
3. **Correctness holds even at pool exhaustion** (`-verify-machineinstrs` clean, no crash) — the F3 /
   soft-stack / SPILL-CONTRACT work already covers `Ac16` *and* `Imag16` spills.

The **one genuine residual**, measured: when the `Imag16` pool is *exhausted* (**>14 live s16 values**), the
register spills fragment the single M=16 region into **many `rep`/`sep` brackets** (13 on a 20-live probe)
because each spill is emitted **byte-wise through `X` in 8-bit mode**. This is real but **pathological-only**
— no kernel, corpus program, or fuzzer-generated program hits it, and even there the output still beats
default by 45 %. **Recommendation: Phase 0 scans real code for an actual trigger; absent one, this is
DEFER-with-evidence (documented frontier), not active work.** Phase 1 (a gated, conservative spill-fusion
peephole) is fully specified below so it is ready if a trigger appears or the user wants it regardless.

---

## The problem, measured (not assumed)

Probes (`/tmp/mv_probes.c`, `/tmp/mv_spill.c` — `volatile` in/out to keep bodies intact, mirroring the
fuzzer), compiled `+mos-a16 -Os` on the built `mos-clang` (`clang-23`, 2026-06-18 17:37):

### Common multi-value case — already tight

`p1`: two independent add-chains, **both** results reused (`t` and `u` live together):

```c
void p1(void){ u16 t=a+b+c; u16 u=d+e+f; r0=t&u; r1=t|u; }
```
```asm
rep #32
lda b; clc; adc a; clc; adc c; sta __rc2      ; t -> Imag16 pair __rc2
lda e; clc; adc d; clc; adc f; sta __rc4      ; u -> Imag16 pair __rc4   (t still live in __rc2)
and __rc2; sta r0                             ; r0 = u & t   <- t FOLDED as memory operand, no reload
lda __rc4; ora __rc2; sta r1                  ; r1 = u | t   <- one reload of u (irreducible: A held u&t)
sep #32 ; rts                                 ; ONE bracket for the whole body
```

| probe | shape | `+mos-a16` | default | Δ |
|---|---|---|---|---|
| `p1` | 2 chains, both reused | **51 B** | 147 B | −65 % |
| `p2` | dependent value live across a 2nd chain | **47 B** | 134 B | −65 % |
| `p3` | **8** live temps, tree reduction | **136 B** | 334 B | −59 % |
| `p4` | 2 live bitwise-chain results | **48 B** | 114 B | −58 % |
| `p5` | single chain (control, the "done" case) | **28 B** | 79 B | −65 % |

`p3` (8 live) keeps **one** `rep`/`sep` bracket and lives entirely in `Imag16` (`__rc2`…`__rc18`) — no stack
spill. Its only inefficiency is a couple of **tree-shaped reduction** reloads (`sta __rcN … lda __rcN`): a
balanced `(a^b)+(c^d)+…` is *not* a homogeneous linear chain, so a running sub-result is stored and reloaded.
This is exactly the non-adjacent-reload residue the [A16-threading](2026-06-17-321-a16-threading.md) Phase 1.5
scan already measured at **~1 per program** — effectively closed; **no separate work warranted.**

### Pool-exhaustion case — correct but mode-fragmented

`hp` (`/tmp/mv_spill.c`): 20 s16 temps live simultaneously, then reduced. Exceeds the 14-pair pool →
allocator must spill to the static stack slot. **Compiles `-verify-machineinstrs` clean, no crash.**
`+mos-a16` = **618 B** vs default **1116 B** (still −45 %). But **13 `rep`/`sep` brackets** (vs 1 in the
well-behaved cases). The spill pattern, repeated at every spill point:

```asm
            sta __rc2          ; value computed into Imag16 pair (M=16)
            sep #32            ; <- forced 8-bit
            ldx __rc2; stx .Lhp_sstk        ; 1-byte Folded Spill (low)
            ldx __rc3; stx .Lhp_sstk+1      ; 1-byte Folded Spill (high)
            rep #32            ; <- forced back to 16-bit
            lda in+4; clc; adc in+2; sta __rc24   ; next 16-bit compute
```

**Root cause:** the spiller lowers an `Imag16` spill to **two 8-bit `Imag8` spills through `X`** (`ldx lo;
stx slot; ldx hi; stx slot+1`). `X` is 8-bit, so `MOSInsertREPSEP` must bracket the spill `sep … rep`,
splitting the surrounding M=16 region. **Cost per spill point ≈ 4 B of mode switches + byte-wise (4 ops) vs
a 16-bit `lda __rc2; sta slot` (2 ops).** On this 20-live / 13-spill probe that is ~50–70 B (~10 %); on
realistic code it is **zero** (nothing exhausts the pool).

### Why `X`, not `A`?

The spiller picks `X` because a 16-bit spill through `A` (`lda __rc2; sta slot`) **clobbers `A`**, which may
hold the chain's running value. In the observed code `A` happens to be dead across each spill (the next op
is a fresh `lda in+N`), so a 16-bit spill *would* be safe there — but the generic spiller cannot prove that
and conservatively avoids `A`. A fix must re-establish that safety locally (A-liveness + ambient M=16).

---

## Scope

| Item | Disposition |
|---|---|
| Multi-value (2–9 live) correctness | **Done** — verify-clean, −58..−65 % vs default; nothing to do |
| Folded-memory-operand reads of the 2nd live value | **Done** — already emitted (`and/adc/eor __rcN`) |
| Tree-shaped reduction reloads | **Done** — covered by A16-threading Phase 1.5 (residue ~1/prog) |
| Irreducible reloads (value used twice, one accumulator) | **Architectural** — not removable; not in scope |
| **Mode-fragmented spill under pool exhaustion (>14 live)** | **THIS PLAN** — Phase 0 trigger scan → Phase 1 gated fix (only if triggered) |
| RA-level `Ac16` residency (keep value in `A` across ops) | **Deferred** → A16-threading Phase 3 (separate item; capped + coalescer-crash risk) |

This plan is **strictly additive and `+mos-a16`-gated** (governing-lesson #2 + the handoff's gating
discipline): it must not alter default-build codegen, and a misclassification must only *miss a win*, never
add a `rep`/`sep` or miscompile.

---

## Phase 0 — does any real code trigger this? (measure before building)

**RESULT — RAN 2026-06-18 (`dev/measure-zp-pressure.sh`): DEFER confirmed.** Across 6 kernels + 5/6 corpus
(13 real functions) the imaginary-register high-water mark maxes at ~5 of 14 pairs; **zero** real functions
exhaust the pool or fragment. The ~20-live *synthetic* shape does fragment (13 `rep/sep` brackets) — the
pathological-only case below — so Phase 1 has **no real-world trigger → not built.** (The scan also surfaced
a separate, more severe `+mos-a16 -Os` RA *crash* on `globals.c` — a different failure mode, tracked
independently.) Full baseline: [ZP-pressure plan](2026-06-18-321-zp-pressure-measurement.md).

The entire justification for Phase 1 is whether real-world `+mos-a16` code ever exhausts the 14-pair pool.
**Build nothing yet.** Scan for the trigger:

1. **Kernels + corpus + examples.** Compile every `examples/65816/*.c` and `examples/snes/corpus/*.c`
   `+mos-a16 -Os -S`; flag any function with a `.L*_sstk` *Folded Spill* of an `Imag16` value **and** a
   `rep`/`sep` count > (number of genuine 8-bit ABI boundaries — entry/calls/return). Record per-function
   bracket counts.
2. **Fuzzer at scale.** `tools/a16_fuzz.py gen` a large sample (≥1000 programs, varied seeds), compile each
   `+mos-a16 -Os -S`, and count functions that (a) spill an `Imag16` value to the stack and (b) fragment
   (>1 bracket per straight-line M=16 region). Report the distribution of live-s16-value counts — confirm
   how far the realistic tail reaches below/above 14.
3. **Optionally extend the generator** (`gen_funcs`) with a wide-live-set shape (the `hp` probe pattern) so
   the fuzzer *can* manufacture the trigger — useful both to confirm the fragmentation differentially and
   to guard a future fix.

**Decision gate:**
- **If essentially no real/fuzzed function triggers** (the expected outcome from the probes above):
  **DEFER.** Record the evidence here, mark the TODO item *measured-deferred* with the trigger condition
  (">14 live s16 values in one function") for revival, and stop. This matches the project's measure-first
  WON'T-DO/DEFER precedent (variable shifts, `inc abs`, indir-dst).
- **If a non-trivial fraction triggers:** proceed to Phase 1.

---

## Phase 1 — gated 16-bit spill fusion (only if Phase 0 triggers)

Collapse the byte-wise-in-8-bit `Imag16` spill into a single 16-bit move **inside the ambient M=16 bracket**,
eliminating both the mode-switch pair and the byte decomposition — **without ever regressing the
8-bit-ambient or A-live case.**

**Where (the layer decision).** The spill is chosen by register allocation, which runs *before*
`MOSInsertREPSEP` decides the M-mode — so the spiller cannot know the ambient width. Two candidate layers;
prefer (A):

- **(A) A post-RA peephole in `MOSInsertREPSEP` (recommended).** The pass already computes the M-width
  lattice per program point, so it *knows* a spill sits inside an M=16 region. Recognize the exact
  byte-spill idiom — `ldx <imagLo>; stx <slot>; ldx <imagHi>; stx <slot+1>` (and the symmetric reload
  `ldx <slot>; stx <imagLo>; …`) — where `<imagLo>/<imagHi>` are the two `Imag8` subregs of one `Imag16`
  pair and `<slot>/<slot+1>` are adjacent stack-slot bytes, **and** the surrounding lattice width is M=16,
  **and** `A` is dead across the idiom (use the pass's liveness). Rewrite to a single `lda <imag>; sta
  <slot>` (spill) / `lda <slot>; sta <imag>` (reload) at 16-bit width, and **drop the bracketing `sep`/`rep`
  this spill alone forced** (do not drop a `sep`/`rep` that any other instruction needs). This keeps all
  knowledge in one pass and naturally composes with the existing bracket-minimization.

- **(B) Mode-aware spill in `loadStoreRegStackSlot` / `expandLDSTStk`.** Emit the 16-bit `Imag16` spill
  directly. Rejected as primary: the spiller does not yet know the ambient mode, so it would have to emit
  *unconditional* 16-bit spills + rely on `MOSInsertREPSEP` to bracket them — which **adds** a `rep`/`sep`
  in 8-bit-ambient functions (a regression, violating lesson #3). Only viable if paired with (A)'s gating.

**Gating (conservative — a miss only misses a win):**
- Fire **only** under `hasAccum16()`.
- Fire **only** when the pass's M-lattice width at the spill is **M16** on both sides (so no mode switch is
  introduced — it is *removed*).
- Fire **only** when `A` (`Ac16`/`A16`) is **dead** across the rewritten idiom (else the 16-bit move would
  clobber a live running value — the exact reason the spiller chose `X`). If `A` is live, **leave the
  byte-through-`X` spill untouched** (correct, just unfused).
- Match the **full** idiom (both bytes, adjacent slot, same `Imag16` pair) or bail. Never partial-rewrite.

**Why this cannot reintroduce the 1d coalescer crash:** it runs **post-RA** (RA has already assigned
physical regs); it only *rewrites already-chosen spill code* and never creates an `Ac16` vreg that lives
across ops nor any `COPY` bridging `Ac16` and an 8-bit class. (Same safety argument as `threadAccum16`.)

---

## Measurement methodology

- Compare `+mos-a16 -Os` **with vs. without** the Phase-1 peephole on the *same* high-pressure C shape
  (toggle the peephole) — never `+mos-a16` vs default (conflates the spill change with the whole native
  path). Decide on **bytes** (`-Os`), cycles as tiebreaker.
- Confirm the peephole **only removes** `rep`/`sep` brackets and spill ops inside an existing M=16 region —
  **never adds** a switch and never fires when `A` is live or the ambient mode is M8 (the regression guards).
- Re-measure the `hp` probe (expect ~13 brackets → far fewer; ~50–70 B saved on that pathological case) and
  **every kernel + the full a16 suite** (expect byte-identical — they don't trigger, proving non-regression).

---

## Micro-test (the correctness gate)

`examples/65816/a16pressure.c` + `dev/a16pressure.sh` (add only if Phase 1 proceeds): a function holding
>14 s16 values live then reducing them (the `hp` shape, sized to force ≥1 `Imag16` stack spill), producing a
`corpus_result` asserted **host == default == `+mos-a16`** on **MAME + bsnes-jg**, with a disasm gate: the
`Imag16` spill is a 16-bit `lda/sta` to the slot (no `ldx slot; stx …` byte pair) and the spill does **not**
sit in its own `sep`/`rep` bracket. The fuzzer (`tools/a16_fuzz.py`, optionally extended in Phase 0 step 3)
differentially exercises the high-pressure path.

---

## Verification steps (fill with raw output + PASS/FAIL on completion)

1. **Phase 0 — trigger scan.** Paste the kernel/corpus/example scan table (per-function bracket counts +
   `Imag16` stack spills) and the fuzzer distribution of live-s16-value counts. State the decision:
   **DEFER** (no real trigger) or **PROCEED**.
2. **Phase 1 (if PROCEED) — fusion correctness.** `dev/run.sh a16pressure` → `corpus_result` agrees
   host == default == `+mos-a16` on MAME + bsnes-jg; disasm gate (16-bit spill, no per-spill bracket) passes.
3. **Non-regression.** Full a16 suite + kernels (`for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh …; done`)
   **byte-identical** to pre-change for every non-triggering function; `dev/run.sh corpus` 7/7;
   `dev/run.sh fuzz 50 1` → 50/50, 0 mismatch/0 new-crash. `-verify-machineinstrs` clean over examples +
   the fuzz sample (incl. `a16localx`, the coalescer-crash guard).
4. **Size delta.** `hp` probe and any Phase-0-identified real triggers: bytes before → after (expect a
   net reduction with **zero** functions regressed).
5. **Patch.** `dev/regen-patch.sh` → `0002` round-trips; the new hunk is confined to `MOSInsertREPSEP.cpp`
   (+ the test); no foreign hunks absorbed (`grep -c` the usual anchors).

---

## Risks

- **Peephole unsound (rewrites a spill where `A` is live, or in an M8 region)** → miscompile or an added
  switch. Mitigation: the three hard gates (M16-both-sides, `A`-dead, full-idiom-match); the fuzzer +
  both-emulator differential is the guard. The realized peephole is post-RA → cannot hit the 1d crash class.
- **Pathological-only gain** → effort/benefit mismatch. Mitigation: **Phase 0 is the gate** — do not build
  Phase 1 unless real code triggers. This is the plan's central honesty check (governing lesson #3: a few-byte
  win is worth doing *because it is a compiler*, but only a *genuine* win, never a blanket change that risks
  the common path). The expected outcome is a documented DEFER.
- **Layer coupling (spiller ↔ REP/SEP pass)** → fragility. Mitigation: keep all logic in `MOSInsertREPSEP`
  (option A); the spiller is unchanged, the peephole only rewrites already-emitted, fully-matched idioms.

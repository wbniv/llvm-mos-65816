# #320 — zero-bank (AS4): measure-and-close the LAST address space

**Date:** 2026-06-22 · **Status:** **DONE — CONFIRMED measured-null** (de-lumped census run 2026-06-22;
nothing built; five-space model now complete). GO contingency did not fire. · **Milestone:** M1 (#320) —
the address-space-layout consolidation
**Closes:** [five-address-space model](2026-06-21-320-five-address-space-model.md) §Phase 2 (whose current
"NO-GO (closed null)" rests on a *circular, lumped* census — see *Why re-open a closed null*).
**Templates it mirrors:** [frame-ABI build-all-three-and-measure](2026-06-20-321-frame-abi-build-all-three-and-measure.md)
(the measured-*null* close) · [packed-24 Increment B](2026-06-21-320-five-address-space-model.md)
(the measured-*win* build) — this plan keeps **both** paths and lets the measurement pick.
**Upstream:** feeds the queued #320 design note ([320-upstream-far-pointer-note.md](../320-upstream-far-pointer-note.md),
[upstream-contribution-status](../upstream-contribution-status.md) #3) — posting is user-triggered.

---

## TL;DR

Zero-bank (**`addrspace 4` = `AS_FarZeroBank`**) is the **fifth and last** of asiekierka's #320 address
spaces and the only one this fork has not formally measured-and-closed. AS0/1/2 ship; **AS3 packed-24** was
*built* because measurement found a real win (−25 % on stored far-pointer tables); **AS4 zero-bank** is
currently marked NO-GO — but on a **circular, lumped** census ("zero-bank likewise has 0 users") that never
directly probed it. The five-space model is therefore **not formally complete**: four spaces are
evidence-closed, the fifth is asserted-closed.

This plan closes AS4 with the **same rigor** as the other four. A premise-check (4 readers + 3 adversarial
skeptics, 2026-06-22) already establishes the expected result with high confidence: **zero-bank is a genuine,
*structural* measured-null** — dominated by the already-available incumbent **"a plain near pointer cast to
`AS_Far` on demand,"** for the same kind of structural reason frame-ABI's DP/SR frames were dominated by the
soft static stack. The deliverable is the **de-lumped, reproducible census + the recorded verdict** that
makes the close *measured* rather than asserted, which **completes the five-space model** and hands the
upstream note a clean "all five spaces measured" story. The GO contingency (build it) is kept and
pre-registered, but is not expected to fire.

---

## What zero-bank (AS4) is — and the one insight that decides everything

From the five-space plan §Phase 2: `AS_FarZeroBank` is a **far-*typed*** pointer the compiler **knows lives
in bank `$00`**. Datalayout `-p4:16:8` (**16-bit storage**), accessed via 16-bit absolute (`ad`/`8d`,
DBR-relative — the cheap form, not absolute-long `af`/`8f`), but type-compatible with `AS_Far` so it widens
to `AS_Far` at **zero cost** (bank byte = `$00`) and is a legal far-call / far-arg target. Stated purpose:
**interop** — let bank-0 data flow through far-pointer APIs without the absolute-long tax per access.

**The insight:** at the representation level, a zero-bank pointer is **bit-identical to a near pointer** —
both `…:16:8` (2 bytes), both accessed via the same 16-bit absolute path. The *only* thing AS4 adds over a
near pointer (AS0) is **far type-identity** (free widening to `AS_Far`, far-ABI legality). So the question is
**not** "is zero-bank cheaper than far?" (trivially yes — 2 bytes vs 4, `ad` vs `af`). It is:

> **Is zero-bank cheaper than the incumbent it actually competes with — a plain near pointer (AS0) cast to
> `AS_Far` on demand at the far-API boundary?**

That incumbent already exists and works (`near→far` `addrspacecast` is a no-bias zero-extend of the `$00`
bank byte, OK under `+mos-a16`; see `far_cast.c`, the Phase-3 cast matrix). Measured against *it* (not
against far), the premise-check found zero-bank wins **nothing**:

| axis | zero-bank (AS4) | incumbent (near AS0 + lazy `→far` cast) | delta |
|---|---|---|---|
| **storage** | 2 B (`p4:16:8`) | 2 B (`p0:16:8`) | **0** |
| **per-access (global, provable bank-0)** | `ad`/`8d` (16-bit abs) | `ad`/`8d` — *already*, via the existing **`ZeroBank` instruction relaxation** | **0** |
| **per-access (runtime pointer)** | `lda (dp)` ($B2) — no far *indexed*-long mode exists | `lda (dp)` ($B2) for a near runtime ptr | **0** |
| **boundary** | none | one transient `near→far` zero-extend (≈ 2 stores of `$00`, cold) | AS4 saves ~2 stores, once, off the hot path |

### The two facts that make this a *structural* null (not a circular one)

1. **AS4's cheap access is *already delivered on AS0*.** llvm-mos's assembler has a **`ZeroBank` relaxation**
   (`ZeroBankInstructionRelaxationEntry`, applied in `MCTargetDesc/MOSAsmBackend.cpp`
   `fixupNeedsRelaxationAdvanced`/`relaxInstructionTo`): a near (AS0) access **starts narrow (16-bit
   `Absolute` `ad`/`8d`)** and only **widens to `AbsoluteLong` (`af`/`8f`) when bank-0 is *not* provable**
   (unresolved/extern/cross-bank symbol). So a *near* pointer to a resolved bank-0 global already emits the
   exact `ad`/`8d` AS4 was invented to produce. **AS4 has no access advantage to add** — the optimization is
   pre-delivered one address space down. (This is the same ground the unlanded `0007` near-abs
   bank-relaxation works.)
2. **The far machinery has no indexed-long mode**, and AS4's cheap `ad`/`8d` is **globals-only**
   (`tryFarAbsoluteAddressing` fires on `matchAbsoluteAddressing` = constant/global). A runtime AS4 *argument*
   (the hot-loop case) is a runtime value → it can only use an indirect form (`lda (dp)`, $B2) — **identical**
   to a near runtime pointer's deref, and a near callee is strictly cheaper than a far one (no `Imag32` quad,
   no `[dp]`). "Monomorphize the far callee on AS4" reduces to "write a near callee," which the incumbent
   already permits.

So the null is not "0 because the type doesn't exist" (the circular trap, below). It is "**0 because
bank-0 data is strictly cheaper as a near pointer — 2 B storage + `ad`/`8d` access via the existing relaxation
— than as any far-typed pointer, so no rational shape forces it far.**" Same shape as frame-ABI: the cheaper
incumbent already owns the win.

---

## Why re-open a "closed" null (the circularity the templates demand we fix)

The five-space plan §Phase 2 already says **NO-GO (closed null, 2026-06-21)**. We re-open it because that
close is **not measured to the project's own bar** — it is a **lumped assertion**. The census script
(`dev/measure-five-space-census.sh:92-97`) states *"zero-bank (AS4) likewise has 0 users (a bank-0 far
pointer is just a near pointer)"* — **no AS4-specific probe, no cost model, no size/access measurement**. It
rides on the packed-24 finding in the same breath.

That matters because **packed-24's twin finding in that exact census was later corrected as circular**
(five-space plan lines 243-270): *"No code stores far pointers is circular — nothing stores them because
storing them is broken, not because there's no use."* The zero-bank line has the **identical structural
risk**: "0 users because a bank-0 far pointer is just a near pointer" conflates *"is it functionally a near
pointer?"* (yes) with *"would code adopt a far-typed bank-0 pointer for API interop if the type+free-cast
existed?"* (never measured). Until that second question is **directly** answered, "closed" is asserted, not
earned — and the five-space model is not complete.

**The good news from the premise-check:** when you *do* de-lump it and build the cost model the bar demands,
the answer is **still empty — but now for a demonstrable structural reason** (the two facts above), exactly as
frame-ABI's A0 census was a *stronger* null than the ZP-pressure proxy it replaced. This plan produces that
stronger close.

---

## Honest expectation (pre-registered)

**Most likely: CONFIRMED measured-null**, the frame-ABI outcome — durable census artifact merged to `main`, no
compiler code landed, an upstream evidence paragraph that *completes* the five-space model. The premise-check
puts this at high confidence (3/3 adversarial skeptics across storage / hot-loop / SNES-platform lenses found
no realistic shape where AS4 beats near+lazy-cast).

**Contingency: GO (build it)** — kept and pre-registered (Phase 1) in case the de-lumped census surprises with
a real, repeated bank-0-far shape that beats the incumbent. Feasibility is *higher* than packed-24
(~30 LoC, reuses the near load/store path + 0006's cast template, **no `MVT` workaround, no byte-merge
bridge**), so a GO would be cheap — but the evidence says it will not fire. Either outcome **formally
completes the model**; that completion is the actual deliverable.

---

## Where it runs (host-only measurement; worktree only if anything is built)

Per CLAUDE.md "Investigations on throwaway worktrees" and mirroring the five-space Phase-0 census itself:
**Phase 0 is pure measurement — prebuilt `mos-clang`, zero `vendor/` edits — so it needs no worktree** (run
on `main`'s host toolchain, like `dev/measure-five-space-census.sh` did). A worktree
(`wt/320-zerobank` off `main` HEAD) is created **only** if the optional type-only feasibility spike (§0a) or
a Phase-1 GO build is undertaken; that worktree is torn down on a null (keeping the recorded verdict), or
**RETAINED until upstream merge** per project policy if anything lands. Commit discipline: stage only this
plan + the census script + the recorded verdict; never `vendor/`, never a foreign patch.

---

## Phase 0 — the de-lumped close (the actual work)

No compiler code shipped in Phase 0. It replaces the circular one-liner with a direct, reproducible
measurement, mirroring `dev/frameabi-census.sh` (per-site cost model + profiting-site count). Deliverable: a
new census block (extend `dev/measure-five-space-census.sh` or a sibling `dev/measure-zerobank-census.sh`) +
the recorded verdict written back into this file and the five-space plan.

### 0a — feasibility confirmation (cheap; demonstrates "null by *worth*, not infeasibility")

State, with evidence, that AS4 is *implementable* (so the close is a worth-decision, the honest frame-ABI
framing — A0 cleared feasibility, the census settled worth). The premise-check already source-grounds this:

- Type (Increment A) = 3 lines: `AS_FarZeroBank=4` in the `MOS::AddressSpace` enum (`MOSInstrInfo.h`),
  `-p4:16:8` in both datalayout strings (`MOSTargetMachine.cpp` + clang `MOS.cpp`), `case 4: return 16` in
  `getPointerWidthV`.
- Codegen (Increment B) = reuse the near 16-bit-absolute load/store path (no custom legalizer — AS4 storage
  is transparent to `selectAddressingMode` at 16-bit width) **+** one `legalizeAddrSpaceCast` arm modeled on
  0006's `p2↔p3` block (AS4→far = zero-extend pad `$00`, always legal; far→AS4 = conditional truncate, legal
  only when bank provably `$00`, else fail loudly).

**Optional (recommended SKIP):** a *type-only* Increment-A spike on `wt/320-zerobank` to put `sizeof(__zerobank
*)==2` and a `zerobank→far` cast compile in-hand. Recommended skip — feasibility is already source-evidenced
from the 0006 template + datalayout parity, and frame-ABI did not build codegen for its null. Do it only if
the user wants concrete feasibility evidence before the close.

### 0b — the de-lumped opportunity census (the durable artifact, mirrors `frameabi-census.sh`)

Directly answer the question the lumped census skipped: **does realistic code ever hold provably-bank-0 data
that is forced through a far-*typed* pointer, where AS4 would beat near+lazy-cast?** Concretely:

1. **Enumerate** every far-call / far-argument / stored-far-pointer site across the corpus
   (`examples/snes/corpus/*.c`), the kernels (`examples/65816/k_*.c`), the far suite
   (`examples/65816/far_*.c`), and a **deliberately bank-0-far-heavy probe** built for this study
   (`examples/65816/zerobank_probe.c`: a heterogeneous far-pointer table mixing bank-0 and bank-1 targets, a
   far-typed API fed bank-0 args in a loop — the adversarial "best case" shapes).
2. For each site, classify the pointer's provable bank. **Count the sites where the target is provably bank-0
   AND it is carried by a far-typed pointer** (the only sites AS4 could serve).
3. Apply a cost model **generous to AS4** (mirroring frameabi-census.sh's SAVE/TAX/OVERHEAD): per qualifying
   site, AS4's win = (boundary zero-extend avoided) − 0 storage − 0 access. Sum, and compare to a profitability
   threshold.
4. **Record the count + the verdict.** Expected: **0 qualifying sites** (premise-check: corpus/far suite show
   zero bank-0-far carriage; all far usage is transient or targets high banks), → CONFIRMED-null.

**Non-circularity check (the crux, write it into the verdict):** unlike packed-24's blocked store, the
incumbent here **works today** — a near pointer + on-demand `near→far` cast is fully available and is what
realistic code already uses for bank-0 data. So a "0" is **not** "0 because AS4 is inexpressible"; it is "0
because the working, cheaper near path already covers every such site." That is a genuine empty opportunity,
not a circular one.

### 0c — quantify the incumbent (so the go/no-go bar names the *right* baseline)

Record, with disassembly, the incumbent's cost so the bar is honest:

- **Storage:** near = 2 B = AS4 (`llvm-objdump --section-headers` on a near vs an (Increment-A) AS4 table — or
  argue from datalayout parity if the spike is skipped).
- **Access (the centerpiece):** compile a near pointer to a **resolved** bank-0 global at `-Os` and disasm —
  show it emits `ad`/`8d` (16-bit absolute) via the `ZeroBank` relaxation, **not** `af`/`8f`; show the long
  form appears only for an unresolved/extern (cross-bank-possible) symbol. **This is the empirical proof that
  AS4's access advantage is already delivered on AS0.** (`dev/measure-zerobank-census.sh`, host-only.)
- **Boundary:** disasm `t2_near_to_far.c` (`+mos-a16`) — the `near→far` cast is a handful of `ldx/stx` writing
  the 16-bit address + the `$00` bank pad, then `lda [dp]`; the only thing AS4 removes is the `$00` pad stores,
  once, off any hot path.

---

## Pre-registered go/no-go (decide the bar *before* the census)

- **Zero-bank is WORTH building (GO → Phase 1)** iff 0b finds a **realistic, repeated** shape (≥ a few
  qualifying sites on real corpus/kernel code, not only the synthetic probe) where an AS4-typed pointer is
  **measurably smaller or faster than near+lazy-cast** (bytes first, cycles as tiebreaker, in 16-bit-ambient
  context), AND it is differential-clean. The bar names the **near+lazy-cast incumbent** as the baseline — a
  win "vs far" does **not** count (near already beats far for bank-0 data).
- **Zero-bank is CONFIRMED-null (close, nothing lands)** if 0b finds 0 qualifying sites on realistic code, or
  the only "wins" are the cold boundary `$00`-pad stores / the synthetic probe — i.e. AS4 ties near on
  storage and access and offers no realistic, repeated advantage. **This is the expected, publishable
  result** and it *completes* the five-space model.

---

## Phase 1 — build AS4 (GO contingency ONLY; not expected to fire)

Kept as the revival recipe. Cheaper than packed-24 (no `MVT::i24`, no byte-merge bridge). Build on
`wt/320-zerobank` (compiler-changing → own `vendor/` + warm `build/` per
[howto-feature-worktree.md](../howto-feature-worktree.md)), land in a stacked `0007-320-zerobank.patch` only
if it clears the go/no-go bar.

- **Increment A — type:** `AS_FarZeroBank=4` (enum, bump `NumAddrSpaces`); `-p4:16:8` in both datalayouts;
  `case 4: return 16` in `getPointerWidthV`. Verify `sizeof(__zerobank*)==2`; corpus 7/7 (AS4 inert unless
  code makes an addrspace-4 pointer).
- **Increment B — codegen:** load/store reuse the near 16-bit-absolute path (gate any new behavior on AS4 so
  the default + non-AS4 build is byte-identical — the fuzzer is the real guard). Add the
  `legalizeAddrSpaceCast` AS4↔`AS_Far` arm (AS4→far always-legal zero-extend; far→AS4 conditional-truncate,
  fail loudly when bank not provably `$00`). Reuse `tryFarAbsoluteAddressing` for AS4 globals (already emits
  `ad`/`8d`).
- **Micro-test + gate:** `examples/65816/far_zerobank.c` + `dev/far_zerobank.sh` (a bank-0 datum accessed via
  an AS4 pointer, cast to `AS_Far` for a far call, round-tripped on **MAME + bsnes-jg**; disasm asserting
  `ad`/`8d` not `af`/`8f`). Differential clean; `-verify-machineinstrs` clean; corpus 7/7; `fuzz 50 1`
  0-mismatch. Land via `dev/regen-patch-0007.sh`, round-trip-verified.

---

## Disposition

- **Null (expected):** durable artifacts merge to `main` — the de-lumped census script + this plan's recorded
  verdict + the corrected (non-lumped) census block. **No compiler code lands.** The optional type-only spike
  worktree (if created) is `git worktree remove`d + `git branch -D`'d, keeping only the verdict. Update the
  five-space plan §Phase 2 ("closed null — now *measured*, non-circular"), the TODO M1 item, and queue the
  upstream paragraph.
- **GO (not expected):** `0007-320-zerobank.patch` lands; `wt/320-zerobank` RETAINED until upstream merge
  (project policy); micro-test wired into `dev/run.sh` + `dev/xcheck.sh`.

---

## Upstream — the paragraph that completes the five-space model (user-triggered to post)

Fold into [320-upstream-far-pointer-note.md](../320-upstream-far-pointer-note.md) and mirror a pointer in
[upstream-contribution-status](../upstream-contribution-status.md) #3. Draft:

> **All five of asiekierka's #320 address spaces are now measured.** AS0 (near), AS1 (direct-page) and AS2
> (32-bit far) ship. **AS3 (packed-24 far)** was *built*: measurement found a real 25 % storage win on tables
> of far pointers (4 B → 3 B/entry, break-even N ≥ 1, differential-clean on two emulators). **AS4 (zero-bank
> far)** is a *measured null*: a zero-bank pointer is bit-identical to a near pointer (both 16-bit, both
> 16-bit-absolute), so its only value over the incumbent — a near pointer widened to far on demand by a
> zero-cost `$00`-bank zero-extend — is the type tag itself. It saves **0 bytes of storage and 0 per access**,
> because (a) provably-bank-0 *near* accesses already relax to the cheap 16-bit `ad`/`8d` absolute form
> (the assembler's ZeroBank relaxation), and (b) the far machinery has no indexed-long mode, so a runtime
> zero-bank pointer derefs no more cheaply than a near one. On a corpus + kernels + a bank-0-far-heavy probe,
> **0 sites** carry provably-bank-0 data through a far-typed pointer — bank $00 is WRAM/ZP/MMIO/local ROM while
> far data lives in high banks, so no realistic shape forces bank-0 data to be far-typed. Zero-bank is
> therefore retained as a *non-goal* — not by assertion, but by measurement, like the soft-static-stack frame
> ABI before it.

---

## Verification (acceptance steps — raw evidence under each)

> Measured 2026-06-22 via **`dev/measure-zerobank-census.sh`** (host-only). The decisive ACCESS demo + the
> opportunity census run on **main's installed toolchain** (reproducible-on-main); the far-VALUE probes
> (`sizeof(far*)==4`, the stored `far_tbl`) were run on the **post-F2 `wt/320-near-abs` toolchain** because
> main's installed `clang-23` (06-20) is **stale pre-F2** at measurement time (`CLANG=…/near-abs/… `
> env-override, the documented pattern). Two toolchains are shown for the access axis because it is gated by
> the in-flight **`0007`** near-abs relaxation (see step 3).

1. **0a feasibility.** AS4 implementability stated with file:line evidence (enum/datalayout/`getPointerWidthV`
   + the near-path reuse + the 0006 cast template). *(Optional spike, if run: `sizeof(__zerobank*)==2` and a
   `zerobank→far` cast compile.)* PASS = "feasible; close is a worth-decision."

   **PASS.** Source-grounded by the premise-check (workflow `wf_2fdcaeb8-b44`, 4 readers): AS4 = Increment-A
   (3 lines: `AS_FarZeroBank=4` enum + `-p4:16:8` datalayout + `getPointerWidthV case 4: return 16`) + an
   Increment-B `legalizeAddrSpaceCast` arm modeled on `0006`'s `p2↔p3` block, with **load/store reusing the
   near 16-bit-absolute path** (`MOSLegalizerInfo.cpp:2293-2322` `selectAddressingMode` routes by pointer
   size; AS4 is 16-bit → transparent). **~30 LoC, no `MVT::i24`, no byte-merge bridge — strictly less than
   packed-24.** The close is therefore a *worth* decision, not infeasibility. (Type-only spike skipped — not
   needed, per frame-ABI precedent.)

2. **0b de-lumped census.** `dev/measure-zerobank-census.sh` runs host-only and reports the count of
   provably-bank-0-via-far-typed-pointer sites across corpus + kernels + far suite + `zerobank_probe.c`, under
   the AS4-generous cost model, with the non-circularity note. PASS = a direct number replaces the lumped
   assertion. *(Expected: 0 qualifying sites.)*

   **PASS — 0 qualifying sites** (replaces the lumped one-liner with a direct count):
   ```
   TOTAL realistic (corpus+kernels)   Nfar=0   Nstore=0   Nopp=0   (12 files)
   TOTAL far suite                    Nfar=9   Nstore=0   Nopp=0   ( 9 files)
   ```
   Corpus/kernels use no far pointers (far is opt-in); the far suite's 9 far accesses target high-bank far
   data and **store 0 far pointers** (all transient cast→deref→discard). **Non-circular:** unlike packed-24's
   once-broken store, the near + lazy `near→far` cast incumbent *works today*, so `Nopp=0` is "covered by the
   cheaper near path," not "inexpressible."

3. **0c incumbent quantification.** Disasm shows (i) a near pointer to a *resolved* bank-0 global emits
   `ad`/`8d` (ZeroBank relaxation), widening to `af`/`8f` only for unresolved/cross-bank; (ii) `near→far` cast
   cost; (iii) storage parity near == AS4. PASS = the bar names the right incumbent.

   **PASS — with a refinement the measurement forced (lesson #1).** The plan *assumed* near already stays
   `ad` via the ZeroBank relaxation; measurement shows that relaxation suppression is the **in-flight `0007`**
   work (`wt/320-near-abs`, commit `ff02726` — *"near-global abs stays 16-bit, suppress abs→long
   bank-relax"*), **not yet on main**. So the access axis is toolchain-gated:
   ```
   # post-F2 + 0007 toolchain (the fixed world):
   near_global → 0: ad 00 00      lda $0        [AD abs, 16-bit]   ⇐ identical to far_global... no:
   far_global  → 0: af 00 00 00   lda $0        [AF abs-long, 24-bit]
   #   ⇒ near already emits AD; a zero-bank global emits the SAME AD. AS4 access advantage over near = 0.

   # current main (pre-0007):
   near_global → 0: af 00 00 00   lda $0        [AF — main bank-relaxes a NEAR bank-0 access ad→af, wasteful]
   far_global  → 0: af 00 00 00   lda $0        [AF — far, same long form]
   #   ⇒ AS4's one possible access win (forcing AD) is exactly 0007's near-pointer fix, MORE general than AS4.
   ```
   Storage (sizeof, datalayout): `near*=2 B`, `far*=4 B` (measured post-F2); `zero-bank* = 2 B`
   (`p4:16:8` == near's `p0:16:8`) ⇒ **storage win over near = 0.** Runtime deref (probe Shape 1):
   `far_first → a7 lda [dp]` (6 cyc) vs `near_first → b2 lda (dp)` (5 cyc) — there is **no far indexed-long
   mode** and AS4's cheap abs is globals-only, so a runtime AS4 pointer ties near's `(dp)` at best. Table
   storage (probe Shape 2): `far_tbl = 16 B`, `near_tbl = 8 B`, zero-bank `= 8 B (= near)`. **The bar's
   incumbent is near + lazy cast, and zero-bank ties it on every axis.**

4. **Go/no-go applied.** The pre-registered bar is evaluated against 0b/0c. Record GO or CONFIRMED-null with
   the evidence. *(Expected: CONFIRMED-null.)*

   **CONFIRMED-null.** 0 realistic opportunity sites (0b); and at any site, zero-bank ties near on storage
   (2 B), global access (`ad`, which is `0007`'s near-path win), and runtime deref (`(dp)`), and never beats
   it — dominated by "near pointer (+ lazy `near→far` cast)," exactly as frame-ABI's DP/SR frames were
   dominated by the soft static stack. The GO bar (a realistic, repeated win *over near+lazy-cast*) is not
   met. **Nothing is built.**

5. **Phase 1 (only if GO):** `far_zerobank.c` round-trips a bank-0 datum via an AS4 pointer cast to `AS_Far`
   on MAME + bsnes-jg; disasm shows `ad`/`8d`; corpus 7/7; `fuzz 50 1` 0-mismatch; `-verify-machineinstrs`
   clean; `0007` round-trips.

   **N/A — GO did not fire** (step 4 CONFIRMED-null). No compiler code built; no `0007`/`far_zerobank` patch.

6. **Model completion + docs.** Five-space plan §Phase 2 updated (measured, non-circular close); TODO M1 item
   updated; upstream paragraph queued in `upstream-contribution-status` (posting user-triggered);
   `dev/measure-five-space-census.sh`'s circular zero-bank line corrected to point at the de-lumped census.
   PASS = "five-address-space model formally complete — all five spaces measured."

   **PASS** — see the doc cascade landed alongside this verdict (five-space §Phase 2, TODO M1, the upstream
   note paragraph + status pointer, and the corrected circular line in `dev/measure-five-space-census.sh`).

---

## Risks / non-goals

- **Risk: the census surprises (GO).** Low (3/3 adversarial null, structural reason). If it fires, Phase 1 is
  cheap and gated; build it.
- **Risk: re-deriving the circular close.** Mitigated by the explicit non-circularity check in 0b (the
  incumbent *works today*, so "0" is genuine) + the 0c demonstration that AS4's access win is pre-delivered on
  AS0.
- **Non-goal:** building AS4 speculatively. A measured null with no realistic use and zero advantage over the
  incumbent is **closed, not deferred** (per `close-net-negative-findings-not-defer`); nothing lands unless the
  bar fires.
- **Non-goal:** any AS2/far rename or AS3/packed-24 change; any 6502 ABI change; flipping the default pointer
  (C1-foreclosed, see five-space plan). This plan touches *only* the AS4 decision.

## Critical files

- `dev/measure-five-space-census.sh` (the circular zero-bank block to de-lump) · `dev/frameabi-census.sh` (the
  methodology template) · new `dev/measure-zerobank-census.sh`.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSAsmBackend.cpp` (the `ZeroBank` relaxation —
  `fixupNeedsRelaxationAdvanced`/`relaxInstructionTo`) + `…/MOSInstrInfoTables.td`
  (`ZeroBankInstructionRelaxationEntry`) — the proof AS4's access win is pre-delivered on AS0.
- `MOSInstrInfo.h` (`AddressSpace` enum) · `MOSTargetMachine.cpp` + `clang/lib/Basic/Targets/MOS.cpp`
  (datalayout, `getPointerWidthV`) · `MOSLegalizerInfo.cpp` (`legalizeAddrSpaceCast`, near load/store path) —
  the Increment-A/B surface (GO only).
- `patches/llvm-mos/0006-320-packed24.patch` (the cast-arm template) · `examples/65816/far-value-evidence/`
  (the cast-matrix evidence) · `examples/65816/far_*.c` (the far suite census inputs).
- Read-only context: `platforms/snes/link.ld`, `platforms/snes-far/link.ld`, `docs/snes-bootup-sequence.md`
  (the SNES memory map = the structural reason bank-0 data is never far-typed).

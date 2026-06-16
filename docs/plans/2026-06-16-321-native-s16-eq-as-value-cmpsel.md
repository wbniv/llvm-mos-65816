# #321 — native s16 equality-as-value (`b = (a == c)`): the fused compare-select

**Date:** 2026-06-16
**Status:** **spiked (2026-06-16) → blanket REJECTED (a net regression); the GATED version is the planned
path — worth doing.** Approach A is feasible and cheap (verify-clean, **no new pseudo needed** — Approach
B is unnecessary). But *blanket* native EQ is **operand-residency-dependent**: it wins only when the LHS
is already in `Imag16` (local/computed −3 B, indirect `*p==c` −4 B) and **regresses** register/param EQ
(+8 B), globals (+4 B), global-vs-immediate (+12 B). So **gate** it to fire only where it wins — a
no-regression modest win, and on a compiler that is worth shipping (every win is amplified across all
compiled programs; "high-effort" is a scheduling input, not a veto). See "Spike results" + "Recommendation".
**ROADMAP:** step 5 (M2) · **TODO:** M2 "native s16 equality-as-value — the full native compare"
**Predecessors:**
[equality compares — the branch path](2026-06-15-321-native-16bit-equality-compares.md) (commit landed
`CmpBrImag16`/`CmpBrImm16` + `selectBrCondImm`) ·
[s16-load-unmerge byte-wise fix](2026-06-16-321-s16-load-unmerge-bytewise.md) (item (c) prologue
regression fix; the "Deferred" section sketched this) ·
[indirect s16 load (won't-implement)](2026-06-16-321-indirect-s16-load-bytewise.md) (the follow-up this
**subsumes** — see Context).

## Context — the problem

`b = (a == c)` for `short`/`unsigned short` (equality **as a value**, e.g. stored to a bool, returned,
or fed into further arithmetic) compiles to the **8-bit two-byte equality chain** even under `+mos-a16`:
compare the low bytes, compare the high bytes, AND the results, materialize 0/1. After the byte-wise-load
fix (`7c0fe56`) this is at **parity** with the default (non-a16) build — but it is **not native**. A
native version is one 16-bit compare — `rep; lda; cmp; sep` — then materialize **Z**→0/1.

Two reasons it's still 8-bit:

1. **Z can't be a plain value.** Every flag-as-value path on the 6502/65816 is **carry**-based (you can
   roll C into a register bit). N/Z are *only* ever fused into a terminator — `selectSbc` asserts this,
   and the only 16-bit Z consumer that exists is the fused compare-**branch** `CmpBrImag16`/`CmpBrImm16`
   (`selectBrCondImm`, `MOSInstructionSelector.cpp:1141`). So **ordering**-as-value (`b = (a < c)`)
   *already* goes native (C is a plain i1), but **equality**-as-value is the holdout.

2. **The legalizer gate only fires for branches.** `legalizeICmp` keeps an s16 `ICMP_EQ` un-narrowed
   *only* when **every use is `G_BRCOND_IMM`** (`NativeS16EqBranch`, `MOSLegalizerInfo.cpp:1361`). A
   value use isn't a branch at legalize time, so the gate fails and the compare narrows to the 8-bit
   chain before anything else runs.

**Why this matters / what it subsumes.** This is the principled fix for the just-closed indirect-s16-load
follow-up. That investigation found byte-wise indirect loads regress 16-bit-ambient code (+2 B) because
EQ-as-value forces a `G_UNMERGE` of the loaded operands into bytes, creating a spill-vs-byte-spill
dilemma on *both* the native and byte-wise paths. A **native 16-bit equality keeps the operands 16-bit
end-to-end** — no `G_UNMERGE`, no 8-bit island, no dilemma — so the load stays one native 16-bit op and
the whole indirect question evaporates.

## How it works today (grounded)

**Branch path — already native** (`b` used only in `if (a == c) …`):
- `legalizeICmp`: `NativeS16EqBranch` true → keeps the s16 compare, builds a **16-bit `G_SBC`** whose Z
  is the live flag (`MOSLegalizerInfo.cpp:1450`).
- `selectBrCondImm` matches `m_CmpNZImag16`/`m_CmpNZImm16` (the 16-bit-`G_SBC`-with-Z matchers,
  `MOSInstructionSelector.cpp:903–960`) → emits `CmpBrImag16`/`CmpBrImm16` (`MOSInstrPseudos.td:370`).
- `expandCmpBr16` (`MOSInstrInfo.cpp:1387`) lowers post-RA to `LDAImag16 A16,$l; CMPImag16/Imm16
  (defs C dead, Z); BR(Z)` — i.e. `rep; lda; cmp; sep; beq/bne`.

**Value path — 8-bit today** (`b` stored / returned / used in arithmetic):
- `NativeS16EqBranch` false → narrows to the 8-bit byte-equality chain (`MOSLegalizerInfo.cpp:1383–1406`).
- The bool is materialized by `buildNZSelect` (`:1267`) → `G_SELECT(Z, -1, 0)`, gated by `isNZUseLegal`
  (`:1246`), then a diamond (`emitSelectImm` / `MOSLowerSelect`) ending in `ldx #1` / `stz`.

**The pivotal fact (new observation):** `MOSLowerSelect` lowers a value-`G_SELECT` to a **`G_BRCOND_IMM
%cond`** + `G_BR` diamond (`MOSLowerSelect.cpp:173`). I.e. a value-select is *reduced to a terminator
that reads the condition* — and a terminator is exactly the one context in which Z is legal. So the
machinery to consume a native 16-bit Z **as a value** may already exist: route the value through a
select, let `MOSLowerSelect` turn it into a `G_BRCOND_IMM`, and let the existing `selectBrCondImm` →
`CmpBrImag16` path fire.

## Design

### Approach A — minimal (preferred; **spike this first**)

Hypothesis: the existing `CmpBr` machinery already materializes a native 16-bit Z as a value once it
reaches a `G_BRCOND_IMM`, so only the **legalizer** needs to change:

1. **Relax the gate.** `NativeS16EqBranch` → `NativeS16Eq`: keep an s16 `ICMP_EQ` (`!RHSIsZero`) native
   under `+mos-a16` for **value** uses too, not just all-`G_BRCOND_IMM`. (Leave the `RHSIsZero` EQ on the
   existing `G_CMPZ` zero-compare path — a separate follow-up.)
2. **Let `buildNZSelect` run for value uses even when native.** Today `MOSLegalizerInfo.cpp:1454` is
   `if (!NativeS16 && !isNZUseLegal(Dst, MRI)) Z = buildNZSelect(Z, …);`. Drop the `!NativeS16 &&` so a
   **value** use of a native 16-bit Z gets wrapped in `G_SELECT(Z16, -1, 0)`.

Then the flow is: 16-bit `G_SBC` (Z) → `buildNZSelect` `G_SELECT` → `MOSLowerSelect` `G_BRCOND_IMM(Z16)`
→ `selectBrCondImm` `m_CmpNZImag16` → `CmpBrImag16` → `rep; lda; cmp; sep; beq/bne` in the head block,
with the diamond's `ldx #1` / `stz` doing the 0/1 materialization. **No new pseudo, no new inserter.**

**Spike (step 1, throwaway build):** make changes (1)+(2), compile `b = (a == c)` (returned, stored, and
fed into arithmetic), inspect the disasm. Success = one native 16-bit `cmp` + the 0/1 diamond, **no**
8-bit `cpx/cmp` two-byte chain, `-verify-machineinstrs` clean. The current code comment claims a value
use "narrows in the select lowering" (`:1357`) — the spike confirms whether that was just the unrelaxed
gate (expected) or a real downstream narrowing (→ Approach B).

### Approach B — fallback (only if the spike shows the value path still narrows)

The original sketch's heavier path: a dedicated fused compare-**select** pseudo, mirroring `CmpBr`.
- New `CmpSelImag16`/`CmpSelImm16` (`MOSInstrPseudos.td`, beside `CmpBrImag16`): `Defs = [C, A16, NZ]`,
  operands `(outs GPR:$dst)` + `(ins Flag:$flag, i1imm:$flag_val, Imag16:$l, Imag16/i16imm:$r,
  i8imm:$true, i8imm:$false)`.
- A **custom inserter** `emitCmpSel16` (`MOSISelLowering.cpp`, mirror `emitSelectImm` at `:266`,
  `usesCustomInserter`): emit `LDAImag16 A16,$l; CMPImag16/Imm16 (defs Z)` in the head block (so Z is
  live with nothing between compare and branch — the reason `CmpBr` bundles them), then the **N/Z
  diamond** `emitSelectImm` already uses for N/Z flags (`:279–288`) to load `$true`/`$false`.
- Selection hook: at the `G_SELECT`→`SelectImm` site, match `m_CmpNZImag16`/`m_CmpNZImm16` on the select
  condition and emit `CmpSelImag16`/`CmpSelImm16` (mirror `selectBrCondImm`).

Heavier (new pseudo + inserter + selection rule); only if Approach A can't reach `G_BRCOND_IMM` natively.

### Why a spike gate

Two reasons, both recent: (a) the [indirect-load measurement](2026-06-16-321-indirect-s16-load-bytewise.md)
showed assuming codegen cost/shape is unsafe; and (b) the original sketch predates the
`MOSLowerSelect`→`G_BRCOND_IMM` observation, so it may over-build. Confirm the cheap path empirically
before writing the expensive one.

## Spike results (2026-06-16)

Ran Approach A (the two-line gate relaxation) in a throwaway build and diffed `eqval.c`/`eqval2.c`
against the native baseline (`-Os`, byte sizes from section headers). **The spike answered both
questions — and the answer is: don't ship the blanket version.**

**1. Approach A is feasible; Approach B is unnecessary.** `-verify-machineinstrs` is clean, and the value
cases emit a real native 16-bit `rep; lda; cmp; sep; beq/bne` via the existing
`buildNZSelect → MOSLowerSelect → G_BRCOND_IMM → selectBrCondImm → CmpBrImag16` chain. **No new
`CmpSelImag16`/`CmpSelImm16` pseudo or custom inserter is needed** — the comment at
`MOSLegalizerInfo.cpp:1357` ("narrows in the select lowering") was describing the *unrelaxed gate*, not a
real downstream narrowing.

**2. But it is operand-residency-dependent — a net regression on the common cases.** Bytes, native
EQ-as-value vs today's 8-bit chain:

| operand residency | shape | native B | spike B | Δ |
|---|---|--:|--:|--:|
| register / param | `eq_ret` (`a==c` ret) | 22 | 30 | **+8** |
| register / param | `eq_store` / `eq_arith` | 17 / 40 | 25 / 48 | **+8** |
| global (abs) | `eq_glob` (`g1==g2`) | 34 | 38 | **+4** |
| global vs immediate | `eq_globimm` (`g1==0x1234`) | 28 | 40 | **+12** |
| **`Imag16` (local/computed)** | `eq_local` (`(a+b)==c`) | 46 | 43 | **−3** ✓ |
| **`Imag16`, combined** | `eq_local2` | 64 | 61 | **−3** ✓ |
| **indirect deref (memory)** | `eq_deref` (`*p==c`) | 38 | 34 | **−4** ✓ |
| branch (control) | `eq_branch` (`if(a==c)`) | 31 | 31 | 0 |

**Mechanism (the indirect-load lesson again).** The native compare reads its LHS from `Imag16`
(`LDAImag16; CMPImag16/Imm16`) inside a `rep`/`sep` bracket. So:
- **Register/param operand** → must **spill** to `Imag16` first (`sta; stx`) + `rep`/`sep`; the 8-bit
  path compares the register directly (`cpx; cmp`, no spill, no mode switch). → **+8 B**.
- **Global operand** → the EQ-native path has **no abs-operand fold** (unlike the *ordering* path's
  `CMPAbs16` / `a16abscmp`), so globals get materialized into `Imag16`, vs the 8-bit path's tight
  `lda g; cmp #imm` byte compares. → **+4 to +12 B**.
- **`Imag16`-resident** (local/computed) or **indirect deref** (already loaded to `Imag16`) → the value
  is *already in memory*, so the native compare just avoids the byte unmerge / second 8-bit compare and
  the `rep`/`sep` amortizes with adjacent 16-bit work. → **−3 to −4 B** (the only wins).

The blanket `AllUsesUnmerge`-style gate (what the spike is) can't see residency, so it ships the
regressions together with the wins.

## Recommendation: blanket REJECTED; build the GATED version (worth doing)

- **Don't ship Approach A as-is** — *blanket* native EQ regresses the common register/param and global
  EQ-as-value (+4 to +12 B) to win a narrow `Imag16`/deref sub-case (−3 to −4 B). A blanket regression is
  not a "modest gain"; it's a loss.
- **The "subsumes the indirect-load case" claim is downgraded.** Native EQ helps `*p==c` (−4 B) but does
  **not** dominate — ungated it regresses most other EQ-as-value shapes. A different, also-operand-
  dependent trade-off, not a free win that absorbs the indirect-load follow-up.
- **Build the GATED version — it is worth doing.** Fire native EQ only when the LHS is already
  `Imag16`-resident (a local/computed value or a foldable memory load) → a **no-regression** −3/−4 B win;
  then add an abs-operand fold to the EQ path for globals (mirror `a16abscmp` / `CMPAbs16`) to capture the
  global win too. Yes it's real work (residency gating + a new abs compare-fold), but this is a compiler:
  a no-regression modest win is amplified across every program built with the toolchain, so the effort is
  justified — **"high-effort" is a scheduling input, not a veto.** Best sequenced with A16-threading,
  which changes operand residency (re-measure then — it likely *widens* where the gated native EQ wins).

**Net spike value:** cheaply proved (a) no heavy pseudo is needed (Approach A reaches native via the
existing `CmpBr` path) and (b) the *blanket* form is a regression — so the work is specifically to **gate**
it. The Measurement / Verification / Risks sections below are the contract for that gated implementation.

## Measurement (the win is not assumed)

Per the indirect-load lesson, **measure the win in 16-bit-ambient code** (where `+mos-a16` actually runs —
it holds 16-bit/M=0 mode across compute, dropping to 8-bit mainly for hardware), bytes-first under `-Os`,
not in isolated leaf functions. Compare
native EQ-as-value vs today's 8-bit chain for three shapes: `b = (a == c)` (i) returned, (ii) stored to a
bool, (iii) combined into further 16-bit math. Expected win — one 16-bit `cmp` replaces two 8-bit `cmp` +
the AND-combine, and operands stay 16-bit (no load round-trips) — but **confirm it, and confirm it is not
worse in any ambient/schedule** before landing. If a shape regresses, gate the native path accordingly.

## Verification (when implemented)

1. **Disasm gate.** `b = (a == c)` under `+mos-a16`: one 16-bit `rep; lda; cmp; sep; beq/bne` + an
   `ldx #1` / `stz` (0/1) materialization; **no** 8-bit `cpx`/`cmp` two-byte chain; `-verify-machineinstrs`
   clean; **byte count ≤ the 8-bit form** (the gating measurement, captured in this plan).
2. **Value test.** Extend `examples/65816/a16eqval.c` (or add `a16eqvalv.c`) + `dev/…sh`:
   `host == default == +mos-a16` on MAME + bsnes-jg, covering `==`, `!=`, a stored bool, and the result
   fed into arithmetic.
3. **Subsumption check.** `b = (*p == c)` (the closed indirect-load case) now keeps the operand a single
   native 16-bit load — no `G_UNMERGE`, no byte-pair lowering.
4. **Non-breaking.** Full a16 suite + corpus 7/7 + `fuzz 50 1` 50/50 (this touches **every** s16 `==`/`!=`
   used as a value — broad blast radius; the Tier-1 differential fuzzer is the safety net).
5. `dev/regen-patch.sh` round-trips (`0002`).

## Risks

- **Z liveness.** The whole reason N/Z only fuse into terminators. Mitigated: Approach A routes Z through
  a terminator (`G_BRCOND_IMM`) and reuses `CmpBr`, which already bundles compare+branch; Approach B
  bundles them in the inserter's head block.
- **Downstream narrowing.** The current comment says value uses "narrow in the select lowering" — the
  spike determines whether that's just the unrelaxed gate (→ A works) or a real narrowing (→ B).
- **Blast radius.** Changes equality codegen for all s16 `==`-as-value. Lean on the fuzzer + a quiet box.
- **`RHSIsZero` (`b = (a == 0)`).** Left on the `G_CMPZ` path for now (keep `!RHSIsZero`); native
  zero-equality-as-value is a separate, smaller follow-up.

## Priority

The **blanket** version is a net regression — not worth doing. The **gated** version (fire only where the
LHS is `Imag16`-resident; add an abs-operand fold for globals) is a genuine, no-regression −3/−4 B win,
and on a compiler that is **worth shipping despite the effort** — every win is amplified across all
programs built with the toolchain. Keep it a real, planned follow-up (not shelved). **Sequencing:** best
done after / as part of A16-threading (ROADMAP step 5), which keeps s16 values in the accumulator and so
**changes operand residency** — re-measure then, as it likely widens where the gated native EQ wins.

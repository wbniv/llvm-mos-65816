# #320 Inc 4 Phase 2 — far-pointer calling convention: build all ABI variants and measure

**Date:** 2026-06-20 · **Status:** IN PROGRESS — **P0 + A0 (variant a Imag32) DONE & two-emulator
verified** on `wt/320-far-cc` (`10a5fc0`); A1–A3 / M / D pending. · **Scope:** `vendor/llvm-mos/` codegen (the CC) +
a far-pointer-passing workload + the reused measurement harness. Runs on a feature worktree, not `main`.
**Builds on:** [Inc 4 Ph1 far calls](2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md) (JSL/RTL landed —
the prerequisite: you can't pass a far pointer across a call you can't make). **Methodology template:**
[the 321 frame-ABI three-way study](2026-06-20-321-frame-abi-build-all-three-and-measure.md).

## Context — why, and how this differs from the frame-ABI study

A 32-bit far pointer (`p2`) **cannot cross a function boundary today** — passing or returning one
crashes in call lowering:

```
%6:_(s16) = G_UNMERGE_VALUES %5:_(p2)
*** Bad machine code: G_UNMERGE_VALUES scalar source does not match destination ***
```

**Root cause (verified):** `CC_MOS` (`MOSCallingConv.td:65`) assigns **every** pointer to a 16-bit
imaginary pair — `CCIfPtr<CCAssignToReg<[RS1..RS7]>>` — with no size discrimination. A 32-bit `p2`
gets force-split to fit a 16-bit `RS#`, and the value/register sizes disagree. There is **no i32 / 4-byte
/ far-pointer rule** in the CC at all.

**The mandate (user, 2026-06-20): no longer upstream-gated — implement every ABI variant and let the
byte/cycle counts pick the winner.** This is the project's "measure, don't assume" methodology, the same
one the frame-ABI study used.

**Crucial difference from the frame-ABI study — this one MUST ship.** The frame study compared three
ways to do something that *already worked* (the soft static stack), so a NULL result ("change nothing")
was a valid, publishable outcome. Here the thing **does not work at all** — passing a `p2` across a call
is a real correctness/capability gap. So Phase 2 is **"pick the best convention,"** not "is it worth
doing." A tie therefore resolves to *ship the simplest variant*, never *ship nothing*. The default-winner
prior is **(a) Imag32** — the literal width-extension of how near pointers already pass.

## The break and the fix point

`CC_MOS` is a single table-driven convention shared by every call. The far-pointer rule must:

1. Fire **only** for a 32-bit far pointer (`p2`), leaving p0/p1 pointers, scalars, and all existing
   codegen **byte-identical** — gate it with a size/addrspace predicate placed **before** the generic
   `CCIfPtr` rule (a `CCIf<"…32-bit far ptr…">`), so existing code never matches it.
2. Assign the 24-bit value to the variant's storage (below), and teach `MOSCallLowering` to
   (dis)assemble the 4 bytes / 2 words on both sides (the `splitToValueTypes` / `MOSValueAssigner` /
   `MOSOutgoingReturnHandler` path).

The **return** ABI extends too: the A/X return convention (i16 → A:X, **LOCKED**) has no room for 24
bits, so each variant also picks how a far-pointer *return* lands (the natural mirror of its arg layout).

## Variant matrix (the head-to-head)

| | Pass / return layout of the 24-bit far pointer | Extension of | Cost intuition |
|---|---|---|---|
| **(a) Imag32 quad** *(default-winner prior)* | one `RL#` (4 contiguous `__rc` ZP bytes); return in `RL` | near-ptr → `RS#` (Imag16), just wider | consistent with the whole CC; 4 ZP bytes/arg; no HW-reg pressure |
| **(b) Imag16 + bank byte** | low-16 in an `RS#` pair + bank in a separate `RC#` | decomposed {near ptr, bank} | cheaper when the bank is constant/shared; more CC bookkeeping |
| **(c) A:X + Y** | low-16 in `A`:`X`, bank in `Y`; return same | the A/X return convention | fast for the 1st far-ptr arg; pins A/X/Y, doesn't scale past one |
| **(d) hardware stack** | pushed (reverse) on the 65816 stack | WDC816CC / ORCA-C prior art | scales to many args; per-access cost; needs `,S` addressing |

**(a) and (c) are the primary poles** (all-ZP-register-file vs hardware-register) — the most informative
head-to-head. **(b) and (d) are controls** (the decomposed and the prior-art conventions). Mirrors how
the frame study ran (a)/(b) against the (c) incumbent.

## Selection mechanism (keeps near-call codegen byte-identical)

Add one off-by-default subtarget feature **per variant**, mirroring `FeatureAccum16`
(`MOSFeatures.td:30-37`) — **not** attached to any `Family` in `MOSDevices.td`, so default codegen is
provably untouched:

```
FeatureFarCCImag32  (+mos-farcc-imag32)   // variant (a)  [also the eventual default-on for p2]
FeatureFarCCSplit   (+mos-farcc-split)    // variant (b)
FeatureFarCCAXY     (+mos-farcc-axy)      // variant (c)
FeatureFarCCStack   (+mos-farcc-stack)    // variant (d)
```

`MOSSubtarget` getters + a `farPtrCC()` query (default = the chosen winner once measured; until then,
no feature ⇒ the far-ptr rule is absent ⇒ behaviour identical to today, i.e. p2-across-call still
errors — which is correct: nothing selected, nothing changes). The A-B harness selects a variant via the
existing `-Xclang -target-feature -Xclang +mos-farcc-XXX` path (as `+mos-a16` is selected). **Default
byte-identical** is the P0 gate (no `+mos-farcc-*` ⇒ identical disasm over corpus+kernels).

## Where it runs — feature worktree

Per CLAUDE.md ("Investigations go on throwaway worktrees") and mirroring `wt/321-frame-abi` /
`wt/321-xy16`: a dedicated **`wt/320-far-cc`** off `main` HEAD, own real `vendor/` + warm-copied `build/`
(the `cp -a` recipe in [howto-feature-worktree.md](../howto-feature-worktree.md) §compiler-changing).
Register it in the agent-handoff Active-worktrees table while live. **Durable artifacts merge back
regardless** (the workload, the measurement driver, the decision record). **Only the WINNER's CC code
lands**; the losing variants stay an inert measured spike on the worktree (retained until notified, like
`wt/321-frame-abi`).

**Patch home (settled in A0):** the far-CC delta lives in a **new stacked `0004-320-far-cc.patch`** (regen via
`dev/regen-patch-0004.sh`; `dev/toolchain.sh` auto-applies `patches/llvm-mos/*.patch` in glob order), **not**
folded into `0001` as originally anticipated. Reason: the A0 fix needs `Imag32` added to the **`AnyRegBank`
line that `0002` also edits** (`Ac16`, Increment 1b) — a single shared line can't be split between `0001`/`0002`
by the diff-reapply that `regen-patch-0001.sh` uses, so stacking after `0002` is the clean home. It stays
behaviourally a16-INDEPENDENT (every rule gated on an off-by-default `+mos-farcc-*` feature; default proven
byte-identical) — only the patch *context* references a16 lines. `0001` is left untouched + a16-free. At phase D
the maintainer may fold `0004` into `0001` when landing on `main` (regenerating `0001`+`0002` together as a
deliberate, reviewed action).

## Phased, gated sequence

| Phase | Deliverable | Gate to proceed |
|---|---|---|
| ~~**P0**~~ **DONE** | The 4 features (off by default) + `farPtrCC()` plumbing + the **shared** call-lowering plumbing that lets a `p2` be assembled/disassembled as 4 bytes / 2 words (the part every variant needs). | ✅ **Byte-identical default** — corpus+kernels default & `+mos-a16` disasm identical across the feature add (`dev/frameabi-byte-identical.sh`, empty diff); `+mos-farcc-imag32` recognized + inert; corpus 7/7. wt `10a5fc0`. |
| ~~**A0**~~ **DONE — GO** | **Variant (a) Imag32** end-to-end: the far-ptr CC rule + `RL#` assignment + a `p2`-across-`noinline` gate that PASSES. | ✅ A far pointer **returned** from `make_far_ptr()` AND **passed** into `deref_far()` across real noinline calls round-trips == `0xF3` on **MAME + bsnes-jg** (`dev/run.sh farcc_imag32` / `xcheck`); `-verify-machineinstrs` clean; negative control proves it does NOT compile without the flag. Needed a 2nd fix beyond the CC rule: **`Imag32` was missing from `AnyRegBank`**, so a far ptr only COPY'd through a fn (never deref'd locally) couldn't be class-constrained → `constrainGenericOp` left a generic vreg. wt `10a5fc0`. |
| **A1–A3** | Variants (b), (c), (d) to the same correctness bar (each behind its flag). | Each passes the same `p2`-across-call gate on both emulators. A variant that proves materially harder than (a) for no plausible win may be **recorded-and-dropped** (note why) rather than fully built — measure the opportunity first (census-style), per the frame-ABI lesson. |
| **M** | The measurement: bytes (`text_bytes`) + cycles on the far-ptr-passing workload, every cell differentially verified. | The N-way table (`prog \| a \| b \| c \| d \| Δ`) for bytes and cycles, inner-loop + whole-call brackets. |
| **D** | Decision: apply the go/no-go; land the winner in `0001`; make it the default-on far-ptr CC; record the rest. | Winner is differential-clean, `0001` round-trips (`dev/regen-patch-0001.sh`), no foreign hunks. |

**Cycle harness (build it here — the frame study specced but never built it):** `dev/probe-cycles.lua`
(MAME `totalcycles` via the sentinel protocol at `$7E00F0`/`$7E00F2`, greppable `CYCLES:` line) +
`dev/measure-far-cc.sh` (models on `dev/measure-zp-pressure.sh` per-program table +
`dev/measure-a16-threading.sh:33` `text_bytes`). If `total_cycles()` is unreachable, fall back to the
fixed-frame iteration-count proxy (deterministic on both emulators).

## Pre-registered go/no-go (decide the bar BEFORE measuring)

Unlike the frame study, **one variant ships** — the bar picks *which*, it cannot pick *none*:

- **Ship the variant that is smallest on the realistic far-ptr-passing corpus AND not materially slower
  in cycles**, with ties broken toward **(a) Imag32** (simplest, most consistent, scales).
- A variant wins outright only if it beats (a) on **both** bytes and cycles on **multiple** realistic
  programs (not isolated leaves — the handoff's leaf-misweights-rep/sep caveat applies). A marginal or
  single-program win does **not** displace (a)'s simplicity.
- Capture the *frequency* too: if far pointers rarely cross calls in realistic SNES code (a census on the
  workload + any sample programs), the choice matters little → default to (a) and stop. That census is
  itself the deliverable (it bounds how much the decision is worth), exactly as the frame study's census
  short-circuited its build.

## Workload

- **Micro-gates** (`examples/65816/farcc_*.c` + `dev/farcc_*.sh`): pass a `p2` as the only arg; pass a
  `p2` among other args (forces the spill rule); **return** a `p2`; a `make_far_ptr()`/`deref_far()`
  round-trip across `noinline`. Each host==variant on both emulators.
- **Realistic kernel**: a small routine that threads a far pointer through ≥2 call layers (e.g. a far
  "buffer walk" — pass a far buffer ptr + len to a leaf that reads/sums across a bank boundary), so the
  measurement reflects real call traffic, not just a leaf signature.
- Reuse: `tools/a16_fuzz.py evaluate()` (extend with the `+mos-farcc-*` flags), `dev/_emu.sh run_assert`,
  the corpus as the byte-identical-default reference.

## Critical files

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSCallingConv.td` — `CC_MOS` (`:58-75`); add the gated far-ptr
  rule(s) before `CCIfPtr`.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSCallLowering.cpp` — `splitToValueTypes` (`:462`),
  `lowerCall`/`lowerReturn`/`lowerFormalArguments`, the `MOSValueAssigner` / `MOSOutgoing*Handler` 4-byte
  (dis)assembly.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.td` — `Imag32`/`RL#` (added in Inc 3) for (a);
  any new CC-visible regclass for (b)/(c).
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSFeatures.td` + `MOSSubtarget.h` — the 4 features + `farPtrCC()`.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrInfo.td`/`MOSInstrFormats.td` — 65816 `,S` defs for (d)
  (the `StackRelative` modes exist but are wired only for 65CE02 — see the frame plan `:160-164`).
- Harness: `tools/a16_fuzz.py` (`evaluate`), `dev/smoke.lua` (sentinel→cycles), new `dev/probe-cycles.lua`
  + `dev/measure-far-cc.sh`; reuse `dev/frameabi-byte-identical.sh`, `dev/measure-zp-pressure.sh`.

## Verification

The bar is the project **differential** (host == default == variant on MAME + bsnes-jg, plus
`-verify-machineinstrs`):

1. **Byte-identical default (P0).** Pre- vs post-scaffolding disasm over corpus+kernels at `-Os` default
   and `+mos-a16` → identical (no `+mos-farcc-*`). PASS = no default regression.
2. **Per-variant correctness (A0–A3).** Each `farcc_*` gate + `a16_fuzz.evaluate` under each
   `+mos-farcc-XXX` → host==variant on both emulators; verify-machineinstrs clean. Includes a
   pass-among-other-args case (spill rule) and a return case.
3. **The measurement (M).** `dev/measure-far-cc.sh` emits the N-way bytes+cycles table, every cell
   differentially verified; inner-loop + whole-call brackets reported separately.
4. **Fuzz + torture non-regression.** `dev/run.sh fuzz 200+` and a torture pass under the winner → 0
   mismatch / 0 new-crash.
5. **Patch hygiene (winner only).** `dev/regen-patch-0001.sh` → `0001` round-trips; staged set is exactly
   the authored CC files; `0001` stays a16-free; `0002`/`0003` untouched.
6. **Docs + decision record.** Update this plan with the measured table + verdict; TODO + implementation-
   status point to the shipped variant; draft the upstream #320 CC evidence paragraph (posting is
   user-triggered) and queue it in `docs/upstream-contribution-status.md`.

## Out of scope / non-goals

- **Not** changing near-pointer or scalar passing, or the A/X scalar return convention (LOCKED) — this
  adds only the **far-pointer** (p2) case.
- **Not** far function pointers / indirect far calls (separate Inc 4 follow-up) — this is far *data*
  pointers crossing a call.
- **Not** auto-merging all variants: only the winner lands; the rest are a measured spike.
- **Not** posting upstream from this plan — the evidence paragraph is prepared; posting is user-triggered.

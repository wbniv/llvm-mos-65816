# #320 — the full five-address-space model (Option A → Option B)

**Date:** 2026-06-21 · **Status:** PHASE 0 DONE (2026-06-21) — **Phases 1–2 closed as measured nulls**
(packed-24 is *representable* but the opportunity is empty AND blocked; the real next work is
front-end far-pointer value completeness, not new spaces). See *Phase 0 — results* below.
**Milestone:** M1 (#320) — the address-space layout consolidation
**Builds on:** the shipped 3-space additive slice —
[far codegen](2026-06-14-320-far-pointer-codegen.md) ·
[runtime far pointers](2026-06-20-320-far-pointer-runtime.md) ·
[far calls + far-fn-ptr](2026-06-21-320-far-calls-followups.md) ·
[far-pointer CC](2026-06-20-320-far-pointer-cc-build-all-variants.md) ·
upstream note: [320-upstream-far-pointer-note.md](../320-upstream-far-pointer-note.md)

---

## What this is

[asiekierka's 2024-03-14 #320 proposal](https://github.com/llvm-mos/llvm-mos/issues/320)
maps the 65816 pointer zoo onto the 8086 near/far model with **five LLVM address spaces**:

| addrspace | proposed meaning | width |
|-----------|------------------|-------|
| `0` | **32-bit far** (the new *default*) | 32-bit (24 used) |
| `1` | 8-bit direct page | 8-bit |
| `2` | 16-bit absolute (near) | 16-bit |
| `3` | 24-bit **packed** far | 24-bit |
| `4` | 16-bit zero-bank | 16-bit |

This repo currently ships a **subset**, renumbered to stay non-breaking (the upstream note calls
this *Option A → Option B*):

| addrspace | **shipped today (Option A)** | width |
|-----------|------------------------------|-------|
| `0` = `AS_Memory` | 16-bit absolute — **6502 default, untouched** | 16-bit |
| `1` = `AS_ZeroPage` | 8-bit direct page | 8-bit |
| `2` = `AS_Far` | 32-bit far (24-bit addr in low 3 bytes) | 32-bit |
| `3` | — | — |
| `4` | — | — |

This plan grows Option A → the full model and, more importantly, **resolves the numbering/default
divergence consciously** rather than letting it drift.

## Honest scope — read this first

The far-pointer **capabilities** are already done: static far load/store, runtime deref (`lda [dp]`),
near→far `addrspacecast`, far-pointer arithmetic, far calls (`JSL`/`RTL` + far→near + far fn-ptrs),
and the far-pointer calling convention (`p2` → `Imag32`, in `0004`). The five-address-space model is
therefore **not new capability** — it is three things, in descending value:

1. **Upstream reconciliation (highest value, lowest effort, maintainer-gated).** Decide, with the
   maintainers, the final addrspace *numbering* and the *default-pointer-width* question. We must not
   renumber unilaterally — the number is upstream's call. The deliverable here is a refreshed design
   note + a posted decision, not code.
2. **`addrspace 3` packed-24 far — a size optimization** (3-byte stored far pointer vs the current
   4-byte). Real, but modest, and gated by an unproven LLVM-representability question (below). Per
   governing lesson #2, it must clear a measured go/no-go or close as a documented null.
3. **`addrspace 4` zero-bank far — an interop convenience** (a far-typed pointer the compiler knows
   lives in bank 0, accessed via 16-bit absolute, zero-cost cast to/from far). Marginal; same
   go/no-go discipline.

The plan is structured so the cheap, decision-shaped work happens first and the speculative code is
**gated behind a census + a representability experiment**, mirroring the frame-ABI study (which
measured an *empty* opportunity and correctly shipped only the measurement).

---

## The two hard constraints that shape every choice

**C1 — there is ONE MOS datalayout, shared by the 6502 and all 65816 subtargets.**
`MOSTargetMachine.cpp` defines a single static string
(`"e-m:e-p:16:8-p1:8:8-p2:32:8-i16:8-i32:8-i64:8-f32:8-f64:8-a:8-Fi8-n8"`, mirrored in
`clang/lib/Basic/Targets/MOS.cpp`). It is **not** subtarget-conditional. Therefore **redefining
`addrspace 0` to 32-bit far (the proposal's headline) is foreclosed**: it would make *every 6502
pointer* 32-bit and detonate the entire non-65816 backend + every existing program. The proposal's
`0 = far default` cannot be taken literally under llvm-mos's architecture.

The realistic reading of "far by default" is therefore **a clang memory-model flag** (à la
`-mcmodel=` / a `-mfar-pointers`) that makes *clang emit user pointers into the far address space by
default* — addrspace 0 keeps its 16-bit meaning; the front-end chooses which space plain `T*` lands
in. That decouples "what's the default pointer" from "what does addrspace 0 mean," and keeps the
6502 safe. (Phase 3, measure-only.)

**C2 — `addrspace 2` is load-bearing across the whole tree.** `__attribute__((address_space(2)))`
is the far spelling used by every far test (`examples/65816/far_*.c`), the SNES `snes-far` platform,
the far-call/fn-ptr work, and the far CC. The proposal puts **16-bit absolute** at `2` and **far** at
`0`/`3`. Adopting the proposal's numbers is a **tree-wide rename in one commit** (sources, linker
scripts, `0001`/`0004`, docs) — mechanically doable, but it touches everyone's in-flight far work
and must be coordinated. Default posture: **keep the additive numbers, add the missing spaces at new
free numbers, and document the divergence**; only renumber if/when upstream rules on it.

---

## Decision (default posture, revisable on upstream input)

1. **Keep `0 = AS_Memory` (16-bit near) as the default.** Forced by C1; non-breaking.
2. **Keep `2 = AS_Far` (32-bit far)** where it is. Renumbering to the proposal is deferred to upstream
   (C2).
3. **Add the two missing spaces at the next free numbers** (additive, opt-in):
   `3 = AS_FarPacked` (24-bit packed far), `4 = AS_FarZeroBank` (16-bit zero-bank far).
4. **"Far by default" = a clang flag** emitting plain pointers into `AS_Far`, never a datalayout-0
   change. Built measure-only, behind a flag, default off.
5. Each new space **must clear a measured go/no-go** (a real byte win on realistic code) or be closed
   as a documented null, like the frame-ABI study.

This is the conscious form of the upstream note's "Option A → Option B": we ship the *full set of
spaces* (Option B's capability surface) while leaving the *numbering + default flip* (Option B's ABI
commitment) as an explicit, maintainer-gated decision rather than smuggling it in.

---

## Phase 0 — gating experiments + decisions (cheap, do first)

No new codegen ships in Phase 0; it decides whether Phases 1–2 are worth building.

- **0a — representability experiment (HARD GATE for Phase 1).** Does LLVM's `DataLayout` accept a
  **non-power-of-two 24-bit pointer** (`p3:24:8`), and does GISel carry a genuine 3-byte pointer
  value through legalization? The current far is 32-bit precisely to dodge odd-size handling ("claim
  32, use 24"). Packed-24's *entire* value is a 3-byte *stored* pointer, which is impossible if LLVM
  forces the pointer size to 32. **Experiment:** in the container (`/opt/llvm-mos` has `llvm-as`/`opt`;
  or build them host-side), parse a module with `target datalayout = "...-p3:24:8-..."` and a
  `{ ptr addrspace(3), i8 }` struct; confirm (i) the parser accepts it and (ii) `DataLayout`
  reports the struct field at offset 3, not 4. **GO** → Phase 1 builds a true 24-bit space.
  **NO-GO** (size forced to 32) → packed-24 buys nothing distinct from `AS_Far`; **close it as a
  measured null** and skip Phase 1. (Per lesson #1 — the upstream note *asserts* power-of-two is
  required; this experiment is exactly the "measure, don't assume" check on that assertion.)
- **0b — usage census (HARD GATE for Phases 1 & 2).** Reuse the frame-ABI census methodology
  (`dev/frameabi-census.sh` as the template). Across the corpus + kernels + a far-heavy probe:
  how many far pointers are **stored in memory / struct fields / arrays** (where a 3-byte vs 4-byte
  pointer actually saves bytes)? How many far accesses are **provably bank-0** (where zero-bank wins)?
  If the answer is ~0 on realistic code (as frame-ABI found for frames), **close both as measured
  nulls** and stop — the opportunity is empty regardless of how clean the code is.
- **0c — numbering posture decision.** Confirm the default posture above (additive + defer renumber)
  vs. a coordinated tree-wide rename. Default = additive. This is the one item that may warrant a
  Discord ping to @asiekierka/@mysterymath *before* code, since the number is theirs to bless.

**Phase-0 exit:** a GO/NO-GO for each of Phase 1 (packed-24) and Phase 2 (zero-bank), each backed by
0a + 0b evidence, written back into this file.

---

## Phase 0 — results (2026-06-21)

Run on `main`, host tools only, **zero `vendor/` edits** (pure measurement — so no worktree was
needed; the worktree is reserved for Phase 1+ which would edit the compiler). Reproducible via
**`dev/measure-five-space-census.sh`**.

### 0a — representability: **GO** (but moot — see 0b)

- **IR layer (source of truth, `llvm/lib/IR/DataLayout.cpp`):** `parseSize` requires only a *non-zero
  24-bit integer* for a pointer size — **no power-of-two restriction** (the `isPowerOf2_32` check at
  ~line 357 is on *alignment*). `getPointerSize = divideCeil(BitWidth,8)` ⇒ a 24-bit pointer occupies
  **exactly 3 bytes**. **The upstream note's premise — "LLVM requires power-of-two pointer sizes" — is
  factually wrong.** The current 32-bit "claim 32, use 24" far pointer was *not* forced by
  representability; it stays on a simple type (no `MVT::i24`), which is a backend-convenience choice,
  not a hard limit.
- **Backend layer (empirical):** the MOS GISel pipeline carries a genuine 24-bit value —
  `unsigned _BitInt(24)` arithmetic that touches the 3rd/bank byte compiles clean **both default and
  `+mos-a16`**, `-verify-machineinstrs` clean, decomposed into a real 3-byte path
  (`lda/ldx/ldy … adc #$1` on the high byte). So a 24-bit pointer is *buildable*, not just parseable.

### 0b — usage census: **EMPTY and BLOCKED** → Phase 1 + Phase 2 NO-GO

| probe | result |
|-------|--------|
| far pointers **stored in memory** across corpus + far tests | **0** (all far usage is transient: cast addr → deref → discard) |
| `sizeof(unsigned char FAR *)` in C | **2**, not 4 — clang sizes the far pointer as **16-bit** |
| store a far pointer to a global (`G_STORE p2`) on `main` | **legalizer crash** — `unable to legalize instruction: G_STORE %0:_(p2)` |

Root cause of the size gap: `clang/lib/Basic/Targets/MOS.cpp::getPointerWidthV` returns **16 for
addrspace 2** (only `case 1` → 8; everything else → 16; **no `case 2: return 32`**). So the C
front-end and the IR datalayout (`p2:32:8`) **disagree** — the far *value* works in registers / across
calls (the backend reads the datalayout → `Imag32`), but the far pointer **cannot be correctly stored
in C memory**: `sizeof` is wrong *and* `G_STORE p2` isn't legalized on `main` (the p2-value store/load
support is unmerged — it lives in `0004` on `wt/320-far-cc`).

**Verdict.** Packed-24 is a *3-byte stored* far pointer — but **storing far pointers in memory doesn't
work at all yet** (backend store unmerged + clang `sizeof` wrong), and **no realistic code stores far
pointers** regardless. So the opportunity is both empty (frame-ABI-style: measured, not assumed) and
two prerequisites away from mattering. Zero-bank (AS4) is worse off — **0 users** (a bank-0 far
pointer is just a near pointer; an interop-only convenience nobody calls for).

**Both Phase 1 (packed-24) and Phase 2 (zero-bank) are closed as measured nulls.** The genuinely
valuable next far-pointer work that this census surfaced is **front-end value completeness** — fix
`getPointerWidthV` (`sizeof(far*)==4`), add aggregate/static-init support for far pointers, and merge
`0004`'s `G_STORE`/`G_LOAD p2` — *then* far pointers can be stored at all. A 3-byte packing is only
worth revisiting if/when real code accumulates tables of stored far pointers (the SNES banked-asset
idiom) and the byte pressure is measured, not assumed.

### 0c — numbering posture: confirmed

Default posture stands (additive numbers; `0`=far-default is foreclosed by the single shared
datalayout; defer any renumber to upstream). Nothing in Phase 0 changes it. The high-value upstream
deliverable is the design note carrying the C1 finding + the corrected pow2 fact (0a) + this census.

---

## Phase 1 — `addrspace 3` = packed-24 far (gated by 0a + 0b) — **NO-GO (closed null, 2026-06-21)**

_Not built. 0a says it is representable; 0b says the opportunity is empty and the prerequisite
(storing far pointers in memory) is incomplete. Kept below as the recipe to revive **iff** the 0b
census later shows real stored-far-pointer pressure._

Add `AS_FarPacked` as a genuine 3-byte far pointer: same 24-bit addressing as `AS_Far`
(absolute-long `af`/`8f`, indirect-long `[dp]`), but **3-byte storage** so far pointers in structs
/arrays/globals cost 3 bytes, not 4.

- **Enum + datalayout:** extend `MOS::AddressSpace` (`MOSInstrInfo.h`) with `AS_FarPacked = 3`;
  add `-p3:24:8` to both datalayout strings; bump `NumAddrSpaces`. Mirror the comment block.
- **Legalizer (`MOSLegalizerInfo.cpp`):** make `LLT::pointer(3, 24)` legal for
  `G_GLOBAL_VALUE`/`G_LOAD`/`G_STORE`/`G_PTR_ADD`/`G_INTTOPTR`/`G_PTRTOINT`; reuse
  `tryFarAbsoluteAddressing` (it keys on the 24-bit address, not the storage width). Wire
  `G_ADDRSPACE_CAST` between `AS_Far`(32) ↔ `AS_FarPacked`(24): a pure truncate/extend of the pad
  byte (the address bits are identical), so the cast is free in both directions.
- **Register class:** a 3-byte ZP class `Imag24` (mirror of `Imag32`/`Imag16`) so the allocator
  places the three address bytes consecutively; `[dp]` references the first. (Confirm the
  spill/`expandLDSTStk` path handles it — the spill-contract assert at `MOSRegisterInfo.cpp` lists
  every ≥16-bit class.)
- **Selector:** `selectUnMergeValues`/merge paths for the 24-bit value (3×s8 ↔ s24); reuse
  `G_LOAD_FAR_ABS`/`G_STORE_FAR_ABS` for the deref.
- **Go/no-go bar (pre-registered):** packed-24 ships **iff** a realistic far-pointer-in-memory shape
  (from the 0b census, e.g. an array of far pointers walked at runtime) is **measurably smaller**
  (bytes, `-Os`) than the same shape with `AS_Far`, with no cycle regression on the hot path, AND it
  is differential-clean. A tie or a leaf-only win that vanishes in 16-bit-ambient context (lesson
  #2) → close as null.
- **Regression gate:** corpus 7/7; far suite green; differential (host == default == a16@MAME ==
  a16@bsnes-jg); `-verify-machineinstrs` clean; `0001` round-trips.
- **Micro-test:** `examples/65816/far_packed.c` + `dev/far_packed.sh` (a packed-24 far load/store
  round-trip across a bank boundary; a `sizeof(struct{far_ptr; char})` static-assert proving 4 bytes,
  not 5), wired into `dev/run.sh` + `dev/xcheck.sh`.

---

## Phase 2 — `addrspace 4` = zero-bank far (gated by 0b) — **NO-GO (closed null, 2026-06-21)**

_Not built. 0b census: 0 users (a bank-0 far pointer is just a near pointer). Recipe kept for revival._

Add `AS_FarZeroBank`: a **far-typed** pointer the compiler **knows is in bank `$00`**. Accessed via
16-bit absolute (`ad`/`8d`, DBR-relative — cheaper than absolute-long), but type-compatible with far
so it can be widened to `AS_Far` at zero cost (bank byte = `$00`) and is a legal far-call/far-arg
target. Purpose: interop — let bank-0 data participate in far-pointer APIs without paying the
absolute-long tax on every access.

- **Enum + datalayout:** `AS_FarZeroBank = 4`, `-p4:16:8`; bump `NumAddrSpaces`.
- **Legalizer/selector:** 16-bit-absolute load/store (reuse the near path), but tag the pointer as
  far for cast/ABI purposes. `addrspacecast` `AS_FarZeroBank`(16) → `AS_Far`(32) = zero-extend
  bank=`$00`; the reverse (`AS_Far` → `AS_FarZeroBank`) is **only legal when the bank is provably
  `$00`** — otherwise it must trap/fail-to-legalize (loud, not silent — the established far rule).
- **Go/no-go bar:** ships **iff** the 0b census finds real bank-0 far traffic AND the 16-bit-absolute
  access measurably beats the absolute-long form for it. Otherwise close as null (a near pointer
  `addrspacecast`-ed to far on demand already covers the rare case).
- **Regression + micro-test:** same discipline; `examples/65816/far_zerobank.c` + `dev/far_zerobank.sh`.

---

## Phase 3 — cast matrix + the "far by default" clang flag (measure-only)

- **3a — the 5×5 `addrspacecast` semantics, defined and tested.** One table, one test
  (`examples/65816/far_castmatrix.c`), covering every legal pair: near↔far (exists: 3b), far↔packed
  (Phase 1, free), zerobank↔far (Phase 2), DP↔others (existing), and the **illegal/lossy** pairs
  (far→near narrowing, far→zerobank when bank≠0) which must fail-to-legalize loudly. This is the
  durable spec of the model.
- **3b — `-mfar-pointers` clang flag (default OFF, measure-only).** Per C1, this is the *only*
  faithful way to express the proposal's "far default": clang emits plain `T*` into `AS_Far` under
  the flag; addrspace 0 is untouched. Build it, measure a whole-program corpus build far-default vs
  near-default (bytes + cycles), and **record the number** — this is the evidence the
  default-pointer-width decision needs. We do **not** flip the default; we hand the maintainers data.

---

## Phase 4 — docs + upstream reconciliation

- Refresh [320-upstream-far-pointer-note.md](../320-upstream-far-pointer-note.md): the full shipped
  model, the conscious numbering divergence (C2), the C1 finding that `0 = far default` is
  architecturally foreclosed under llvm-mos's single datalayout (a substantive contribution to the
  design — it reframes the proposal), the 0a representability result, and the 3b far-default
  measurement.
- Queue the post in [upstream-contribution-status.md](../upstream-contribution-status.md) (posting is
  user-triggered). Mirror the one-liner in TODO's *Upstream / Contribution* section.
- Update [docs/agent-handoff.md](../agent-handoff.md) "Navigating the backend" with the final
  addrspace map.

---

## Correctness gate + methodology (unchanged house rules)

- **Differential bar:** host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
  `+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean. Far is `HasW65816`-gated and a16-independent
  — gate accordingly (a far change must not perturb the default 6502 build; the fuzzer guards that).
- **Measure in realistic 16-bit-ambient context, not isolated leaves** (lesson #1/#3). A 3-byte
  pointer that wins in a leaf but loses to `rep`/`sep` churn or extra casts in real code is a no-go.
- **Investigations on a throwaway worktree.** The census (0b), the representability experiment (0a),
  and any net-negative space (a NO-GO Phase 1/2) run on `wt/320-five-space` off `main` HEAD — keep the
  durable artifacts (census script, recorded verdict), `git worktree remove` the dead ends.
- **Commit discipline:** stage only your files; `0001` is the far patch; never absorb `0002`/`0004`
  hunks (`grep -c` foreign symbols after `dev/regen-patch.sh`).

---

## Risks / non-goals

- **Risk: packed-24 is not representable** (0a NO-GO) → Phase 1 closes as a null. *Likely the single
  biggest unknown; that's why 0a is first.*
- **Risk: empty opportunity** (0b finds no far-pointers-in-memory / no bank-0 far traffic on realistic
  code) → Phases 1–2 close as measured nulls, like frame-ABI. This is a *success* (the opportunity was
  measured, not assumed), not a failure.
- **Risk: renumbering churn** if upstream insists on the proposal's numbers → a single coordinated
  rename commit; deferred until they rule (C2).
- **Non-goal:** flipping the default pointer to far (C1 foreclosed for addrspace 0; the clang flag is
  measure-only). **Non-goal:** any 6502 ABI change. **Non-goal:** new far *capability* (all shipped).

---

## Verification (acceptance steps — paste raw evidence under each as met)

1. **0a representability.** **PASS — GO** (2026-06-21). Source-verified the IR layer
   (`parseSize` has no pow2 restriction; `getPointerSize=divideCeil(24,8)`=3 bytes) + empirically
   confirmed the backend carries a 24-bit value (`_BitInt(24)` compiles clean default + `+mos-a16`,
   verify-clean). `dev/measure-five-space-census.sh` 0a block. The note's pow2 premise is disproven.
2. **0b census.** **PASS — NO-GO for both new spaces** (2026-06-21). Census: 0 far pointers stored in
   memory; `sizeof(far*)==2` (clang gap); `G_STORE p2` crashes the legalizer on `main`. Opportunity
   empty + blocked. `dev/measure-five-space-census.sh` 0b block. Phases 1–2 closed as measured nulls.
3. **Phase 1 (if GO):** `far_packed.c` round-trips a packed-24 far load/store across a bank boundary
   on MAME **and** bsnes-jg; the `sizeof` static-assert shows 3-byte storage; the census shape is
   measurably smaller than `AS_Far`. Corpus 7/7; differential clean; `-verify-machineinstrs` clean.
   (Evidence: emulator value dump + `llvm-size` diff + corpus run.)
4. **Phase 2 (if GO):** `far_zerobank.c` accesses bank-0 data via 16-bit absolute, casts to `AS_Far`
   for a far call, round-trips on both emulators; measurably beats absolute-long for the census shape.
   Corpus 7/7; differential clean. (Evidence: disasm showing `ad`/`8d` not `af`/`8f` + emulator dump.)
5. **Phase 3a cast matrix:** every legal `addrspacecast` pair compiles + runs correct; every illegal
   pair fails-to-legalize loudly (no silent miscompile). (Evidence: `far_castmatrix` run + the
   negative cases' diagnostics.)
6. **Phase 3b far-default flag:** `-mfar-pointers` builds the corpus far-default; bytes/cycles vs
   near-default recorded. (Evidence: `llvm-size` table.) *No default flipped.*
7. **Phase 4:** upstream note refreshed with the model + C1 finding + measurements; queued in
   `upstream-contribution-status.md`. (Evidence: doc diff.)

---

## Open decisions (maintainer-gated — do NOT decide unilaterally)

- **Final addrspace numbering.** Keep additive (`2 = far`, `3/4` new) vs. adopt the proposal
  (`0/3 = far`, `2 = absolute`) → tree-wide rename. *Our recommendation, with C1/C2 evidence:
  additive; the proposal's `0 = far default` is architecturally infeasible under llvm-mos's single
  shared datalayout — surface this in #320.*
- **Default pointer width.** Per C1, only expressible as a clang memory-model flag, never as
  addrspace 0. We provide the measurement (3b); upstream/the user picks the default.

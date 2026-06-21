# #320 — the full five-address-space model (Option A → Option B)

**Date:** 2026-06-21 · **Status:** PHASE 0 + 3 DONE; **re-evaluated** (2026-06-21, later). **packed-24
(#3) BUILT + verified — Increment A (type) + Increment B (codegen) both DONE** (2026-06-21, on post-F2
`main`; see *Build packed-24*); zero-bank (#4) still DEFERRED as premature. The desirable work Phase 0 surfaced —
**completing the far-pointer VALUE type** (storable + `sizeof==4`) — was **built by the F2 agent**
(`wt/320-far-followups`, verified, ABI-gated, not on `main`), so it's **done, not ours to re-implement**.
`dp→near` cast = pre-existing **upstream** bug. **No clean in-scope codegen remains for us here** — see
*Re-evaluation (2026-06-21, later)*.
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

### 0a — representability: **GO** — and *the reason we skipped packed-24 was wrong* (win still moot — see 0b)

**What 0a settles.** asiekierka's #320 proposal carries a fifth space, **`3` = 24-bit "packed" far** — a
far pointer that occupies **3 bytes** in memory instead of 4. Our shipped slice omits it, and our own
upstream note ([320-upstream-far-pointer-note.md](../320-upstream-far-pointer-note.md)) justifies the
32-bit "claim 32-bit, use 24" pointer on **representability** grounds, in two places (lines 47–48, 41):

> _… the "claim 32-bit, use 24" approach — **LLVM requires power-of-two pointer sizes**._
> _AS_Far (2): … top byte unused (**LLVM wants power-of-two pointer sizes**)._

0a tests that claim against the source of truth and against the live backend. **It is false.**

**IR layer — there is no power-of-two rule on pointer size (`llvm/lib/IR/DataLayout.cpp`).**

- `parseSize` (the `<size>` field of a `p<n>:<size>:…` spec) accepts **any non-zero value that fits in
  24 bits** — the guard is literally `!to_integer(...) || BitWidth == 0 || !isUInt<24>(BitWidth)`. **No
  `isPowerOf2` on the size.** So `p3:24:8` parses clean.
- The *only* power-of-two check in the spec parser is in **`parseAlignment`** (~line 357,
  `isPowerOf2_32(Value / ByteWidth)`) and it gates the **alignment** field, not the size. `p3:24:8` has
  ABI alignment 8 bits = 1 byte (a power of two) → fine.
- `getPointerSize(AS) = divideCeil(getPointerSpec(AS).BitWidth, 8)` ⇒ `divideCeil(24,8) = 3`. LLVM lays a
  24-bit pointer out in **exactly 3 bytes**, and `getIntPtrType` for it is **`i24`**. Fully representable.

So the note's parenthetical is a **misconception to retract** — 32-bit was never *forced* by the IR.

**Backend layer — 24-bit values are buildable, with one decisive caveat.** llvm-mos is **GlobalISel-only**,
and GISel's `LLT` represents arbitrary widths (`LLT::scalar(24)`, `LLT::pointer(3, 24)`). Empirically
(`dev/measure-five-space-census.sh` 0a): an `unsigned _BitInt(24)` kernel whose add carries into the
3rd/bank byte compiles clean **both default and `+mos-a16`**, `-verify-machineinstrs` clean, lowering to a
real 3-byte path (a 3-byte load `lda/ldx/ldy`, a byte-wise add chain, `adc #$1` on the high byte). So
**intra-function** 24-bit codegen already works.

**The caveat — and the *real* reason the far pointer is 32-bit. It is not pow2; it is `MVT`.** The
machine-value-type system (`MVT`/`SimpleValueType`) has only power-of-two simple integers — `i8`, `i16`,
`i32`, … **there is no `MVT::i24`.** GISel's `LLT` dodges this *inside* a function, but the interfaces that
still speak `MVT` — register-class value-type lists (`addRegisterClass`) and especially the **calling
convention** (`CC_MOS` / `CCValAssign`, which assign in `MVT`) — cannot directly carry a 24-bit value.
That is precisely why the shipped far CC passes a far pointer **across function boundaries as `Imag32`**
(32-bit), not 24. Our `_BitInt(24)` probe only exercises the intra-function path; a 24-bit pointer that is
*passed/returned/stored* hits the `MVT::i24` gap. So **"claim 32, use 24" is a backend-plumbing
convenience (stay on a simple type that register classes + the CC accept), not an IR limit** — that is the
accurate statement, and the one to put upstream.

### What 0a means for the upstream #320 response

The packed-24 question on #320 has **three independent axes** that our note currently collapses into one
"pow2" hand-wave. Separated, they give a precise, defensible position:

| axis | the note's current basis | 0a verdict |
|------|--------------------------|------------|
| **Representable?** | "LLVM needs pow2 pointer sizes" | **FALSE** — `p3:24:8` parses, a 24-bit pointer is 3 bytes (`i24`), and `_BitInt(24)` builds. **Retract.** |
| **Cheaper at runtime?** | "32-bit is *cheaper* than 24-bit … 24-bit arithmetic forces a 16+8 access pair and a mode switch" (line 130) | **Still TRUE in the +mos-a16 regime far code targets** — a 24-bit add splits 16+8 with an `M`-width switch where 32-bit stays a clean 16+16; in pure 8-bit mode the two are within a byte-op. Either way packed-24's upside is **storage, never arithmetic**. This becomes the *load-bearing* argument once pow2 is gone. |
| **Cheap to implement?** | (unstated) | **No** — a 24-bit pointer needs the `MVT::i24` workaround in register classes + the CC (`CCValAssign`). Real effort, for a 1-byte-per-stored-pointer payoff. |

**So our #320 response is a *strengthening* of the design discussion, not a reversal.** Keep the 32-bit far
pointer as the default far representation — but on a **corrected** basis: packed-24 is *representable*; we
were simply wrong about *why* we skipped it. We **recommend deferring the `3` = packed-24 space**, with
data: (a) its 1-byte/pointer win lands **only on far pointers stored in memory**, and 0b measured **zero**
such pointers in realistic code (and storing them doesn't even work yet — see 0b); (b) the cost is the
`MVT::i24` plumbing, not free; ⇒ packed-24 is **net-negative until measured storage pressure exists** — the
standard project posture for a real-but-unrealized modest gain (schedule behind a trigger, don't build
speculatively). This same finding also settles the note's *other* open question, "default pointer width":
with pow2 removed, the runtime-cost argument (axis 2) is what actually carries it, so the note should lead
with that.

**Edits to fold into the upstream note _before_ it is posted (do not post — just stage the corrections):**

1. **Strike both "LLVM requires/wants power-of-two pointer sizes" parentheticals** (note lines 47–48 and
   41; mirror the same comment in `MOSInstrInfo.h` `AS_Far`). Replace with: _"stored as a 32-bit value to
   stay on a simple `MVT` type (there is no `MVT::i24`) — a backend-plumbing convenience for register
   classes + the calling convention, **not** an IR-representability limit; `p:24` parses and a 24-bit
   pointer is 3 bytes."_
2. **Answer the proposal's space `3` explicitly:** packed-24 is representable but **deferred on
   measurement** — empty opportunity (0b) + `MVT::i24` cost; revive on real stored-far-pointer pressure.
3. **Lead the "default pointer width" discussion with the runtime-cost (axis-2) argument**, now that the
   representability prop is removed.

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

#### 0b verdict (corrected, 2026-06-21 — after user pushback)

My first pass called this "an empty opportunity, close as a null." That conflated two different things
and the reasoning was partly **circular**. Corrected:

- **The new SPACES (packed-24 #3, zero-bank #4) defer — yes, but not because "nobody wants them."**
  Packed-24 is a 3-byte *size-optimization of a far pointer stored in memory*, and **a far pointer
  cannot be stored in memory at all yet** (the value-state matrix in *Phase 3 — results* confirms
  store/load/array/struct all fail, under default *and* `+mos-a16`). You can't shave a byte off a
  capability that doesn't exist. Zero-bank (#4) is functionally a near pointer. So the new *address
  spaces* are premature/marginal — **sequenced behind the capability, not built speculatively.**
- **The capability they presuppose is itself DESIRABLE, OPEN work — not a null.** The census's real
  output is the discovery that the far pointer is a complete **address mechanism** (deref / load / store
  / arithmetic / calls all work, `+mos-a16`-gated) but an **incomplete value type**: you cannot store it
  in a global / array / struct, cannot take a correct `sizeof` (it reports 2, not 4), and pass/return
  only works on the `0004` worktree. **"No code stores far pointers" is circular** — nothing stores them
  because storing them is *broken*, not because there's no use for tables of banked-asset far pointers.
  (Contrast the frame-ABI study, which was genuinely empty for a *structural* reason: locals live in
  `__rc`, so there is no frame traffic to optimize. Here there is a real, wanted capability behind a
  bug.)

**So:** Phase 1 (packed-24) + Phase 2 (zero-bank) stay **deferred** (premature/marginal — not built),
but the **far-pointer value-type completion** they exposed is **promoted to its own desirable M1 item**:
fix `getPointerWidthV` (`sizeof(far*)==4`), legalize `G_STORE`/`G_LOAD p2` in memory + aggregate/
static-init, the narrowing/cross-space casts (far→near, dp→near currently fail/segfault), and merge
`0004`'s pass/return half. A 3-byte packing is revisited only **after** the 4-byte stored far pointer
works and real banked-asset-table byte-pressure is measured — at which point it's a clean size-opt, not
a speculative space.

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

## Phase 2 — `addrspace 4` = zero-bank far (gated by 0b) — **CONFIRMED measured-null (2026-06-22)**

_Not built. The 2026-06-21 "NO-GO" rested on a **circular, lumped** 0b census ("zero-bank likewise has 0
users"). [The 2026-06-22 measure-and-close](2026-06-22-320-zerobank-as4-measure-and-close.md) **de-lumped it
to the project bar** (`dev/measure-zerobank-census.sh`): 0 realistic sites carry bank-0 data as a far-typed
pointer, and at any site zero-bank is bit-identical to a near pointer (`p4:16:8`==`p0:16:8`) and ties the
"near + lazy `near→far` cast" incumbent on storage (2 B), `ad` access (which is the in-flight `0007` near-abs
relaxation's win for ALL near pointers, not AS4's), and runtime `(dp)` deref — never beats it. Non-circular
(the near+cast incumbent works today). **This completes the five-space model: all five spaces measured.**
Recipe kept below for revival._

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

### Phase 3 — results (2026-06-21)

Characterized on the current `main` toolchain (clang-23 @ `c798c31`, pre-F2 — F2 landed only in
`wt/320-far-followups`), host-side, no vendor edits. Reproducible: **`dev/measure-far-ptr-value-state.sh`**
(every probe run *both* default and `+mos-a16`, since the far value machinery is `+mos-a16`-gated). The
probes are committed, inspectable sample programs in **`examples/65816/far-value-evidence/`** (its
`README.md` maps each program to its compile result, with verbatim errors + the `MVT::i24` analysis).

**3a — the cast / value-state matrix.** The 5×5 collapses to the implemented spaces (0 near, 1 DP, 2
far; 3/4 don't exist). The matrix is **not "cleanly gated"** — several cells are broken, which is the
*value-type* gap, not a clean spec:

| operation | default | +mos-a16 |
|-----------|---------|----------|
| deref a constant far addr | OK | OK |
| near→far cast + deref (transient) | no-legalize | **OK** (a16-gated) |
| **store** far ptr → global | verify-FAIL | verify-FAIL |
| **load** far ptr ← global | no-legalize | no-legalize |
| **array** of far ptrs | no-legalize | no-legalize |
| **struct** field far ptr | no-legalize | no-legalize |
| far→near cast + deref | verify-FAIL | verify-FAIL |
| dp→near cast + deref | SEGFAULT / verify-FAIL | verify-FAIL |
| `sizeof(far*)` | **2** (want 4) | **2** (want 4) |

So a far pointer is a **complete address mechanism** (transient deref/load/store/arith/calls work,
`+mos-a16`-gated) but an **incomplete value type** (can't be stored, sized, or narrowed). The "illegal
casts fail loudly" property the plan wanted is *partly* true (most fail to legalize — loud) but
dp→near can **segfault** without `-verify-machineinstrs` — a real robustness bug, not a graceful
diagnostic.

**3b — far-default flag: BLOCKED, not built.** `-mfar-pointers` would make plain `T*` a far pointer
module-wide — but the matrix shows a far pointer **can't yet be stored in memory or sized correctly**,
so making it the default pointer would break every program that puts a pointer in a struct/array. 3b is
therefore **gated on the far-pointer value-type completion** (below) and, being a clang change, must
also coordinate with the in-flight `far`-attribute (F2) work. Deferred with that explicit dependency;
no speculative build.

**Phase 3 net:** the cast matrix is the durable spec, and it *confirms* the 0b reframe — the work worth
doing is **completing the far-pointer value type**, after which 3a's broken cells close and 3b becomes
measurable.

---

## Re-evaluation (2026-06-21, later) — the far-data value type LANDED (built by the F2 agent)

The desirable work this plan surfaced ("complete the far-pointer data-value type") turned out to be
**built by the far-fn-ptr (F2) agent**, not just unblocked. Verified by compiling the
`examples/65816/far-value-evidence/` fixtures against their rebuilt toolchain (`wt/320-far-followups`,
clang-23 @ 2026-06-21 19:36):

| fixture | `main` (pre-F2) | `wt/320-far-followups`, `+mos-a16` |
|---|---|---|
| store far ptr → global (`s1`) | FAIL | **OK** |
| load far ptr ← global (`s2`) | FAIL | **OK** |
| array of far ptrs (`s3`) | FAIL | **OK** |
| struct far-ptr field (`s4`) | FAIL | **OK** |
| `sizeof(far*)` (`z1`) | 2 | **4** |
| far→near cast (`c1`) | FAIL | **OK** |
| dp→near cast (`c2`) | FAIL | FAIL (pre-existing upstream) |

So the far-pointer **value type is complete** under `+mos-a16`: `getPointerWidthV` gained `case 2: return
32`, and `PF` is a storable *value* type (the s32 merge narrows to bytes). **This satisfies the
"complete the far-data value type" item — done by the other agent**, in `wt/320-far-followups` (pushed
`origin/wt/320-far-followups`), **ABI-gated, not on `main`** (main's toolchain + `0001` unchanged; the
work lives in `0004` + recipes). Re-implementing it on `main` would duplicate/conflict — so we don't.

**`c2_dp_to_near` is a pre-existing UPSTREAM bug, not ours.** It fails identically on plain `mos6502`
("Bad machine code: Copy Instruction is illegal with mismatching sizes"; crashes without `-verify`) — a
generic DP(addrspace 1)→near(0) addrspacecast defect, unrelated to #320/#321. → an **upstream issue to
report** (maintainer territory, like the scavenger-N/Z and `reentrant` issues), not a fork fix.

**Net remaining in this plan:**
1. **packed-24 (space 3)** is now technically *unblocked* (far pointers are storable) but still a
   **deferred size-opt** — build only on measured byte-pressure, via `LLT` + a 3-byte ZP class (never
   `MVT::i24`; see 0a).
2. **zero-bank (4)** still marginal (≈ a near pointer).
3. The far-data value type, though done, is **not on `main`** — landing it is an ABI-blessing-gated
   decision, deliberately deferred per `upstream-contribution-status.md`.

So there is **no clean, in-scope codegen left for *us* to implement here**: the value type is done
(theirs), `dp→near` is upstream, packed-24/zero-bank are deferred-by-agreement.

---

## Build packed-24 (user-directed 2026-06-21) — Increment A DONE; Increment B blocked on 24-bit width

User directed building packed-24 ("measure first"). Measurement + feasibility (above): feasible without
`MVT::i24`, 25% storage win, ×3-index cost, opt-in. Built on **`wt/320-five-space`** (off `main`).

### Increment A — the 3-byte packed-far TYPE: **DONE + verified + non-breaking**

Recipe (gitignored `vendor/` edits on `wt/320-five-space`):
1. `MOSInstrInfo.h` — `enum AddressSpace { …, AS_Far, AS_FarPacked, NumAddrSpaces }` (AS3).
2. `MOSTargetMachine.cpp` + `clang/lib/Basic/Targets/MOS.cpp` — datalayout `+p3:24:8`.
3. `clang …/MOS.cpp::getPointerWidthV` — `case 3: return 24;`.

Verified (worktree toolchain, rebuilt clang-23 @ 20:26): `sizeof(__packed_far*)==3`, `table[16]==48 B`
(vs 64 for 32-bit far) — the storage win is realized at the type level; a packed global emits 3 bytes,
a 16-table 48. **Non-breaking: corpus 7/7** (AS3 is inert unless code creates an addrspace-3 pointer).

### Increment B — codegen to *use* packed pointers: **DONE + verified, 2026-06-21** (built on post-F2 `main`)

> **Follow-up 2026-06-22 — static-init table reloc fix (`a76bf18`).** Increment B (below) covered the
> *runtime* store/load/deref path; the realistic shape — a *statically-initialized* table of packed far
> pointers — did NOT link (each 3-byte entry emitted one `R_MOS_ADDR8`; no 3-byte data fixup). Fixed via a
> generic `AsmPrinter::emitNonStandardSizedConstant` hook + a MOS override emitting the `ADDR24
> SEGMENT_LO/HI/BANK` triple; landed in the updated `0006`. Also Task A measured the win (break-even N≥1).
> Full record: [2026-06-22-320-packed24-static-init-reloc-fix.md](2026-06-22-320-packed24-static-init-reloc-fix.md).

Built on `wt/320-packed24-incB` (compiler-changing worktree off post-F2 `main`; F2 precondition gate
PASS — `sizeof(far*)==4`, far store/load/array/struct legalize clean). The original "BLOCKED on s24"
diagnosis was *half right* — the dead-end was specifically the **`inttoptr/ptrtoint`-roundtrip-through-s24**
shape (which `legalizeAddrSpaceCast` would have used). The fix sidesteps `s24` entirely.

**Two findings reframed the approach (measure, don't assume):**
1. **An IR-level crash before any GISel s24 work even runs.** `deref_g` (load p3 + cast + far-deref)
   segfaulted in **`CodeGenPrepare::optimizeLoadExt`** → `EVT::getExtendedSizeInBits` on the 24-bit
   pointer load: `getValueType(p3)` → `getPointerTy(DL,3)` → `MVT::getIntegerVT(24)` = the invalid
   `MVT::i24`. "Memory-only" doesn't shield IR passes that query the type's MVT. **Fix:** override
   `MOSTargetLowering::getPointerTy(AS_FarPacked)` → `MVT::i32` (a packed pointer's register/value form
   IS the 32-bit far form; only its memory footprint is 3 bytes, from the datalayout). One target-local
   hook fixes every generic-pass site at once.
2. **The artifact combiner only looks through `G_TRUNC/SEXT/ZEXT/ANYEXT`, NOT `inttoptr/ptrtoint`**
   (`isArtifactCast`). So an `s24` formed by `ptrtoint p3 → s24` would never fold and would crash
   selection (no `MVT::i24`, no 24-bit register class). **Fix:** bridge `p3 ↔ 3×s8` with
   `G_MERGE_VALUES{PFP,S8}` / `G_UNMERGE_VALUES{S8,PFP}` directly (no `s24`, no `inttoptr` roundtrip). In
   every shape clang emits (cast→store, load→cast, packed→packed copy) the bridge merge **directly feeds**
   the consuming unmerge, so the basic `unmerge(merge)` artifact fold removes it — no 24-bit value or
   pointer ever reaches the selector.

**The implementation (all `0006-320-packed24.patch`, stacked after 0001-0005):**
- `getPointerTy(AS_FarPacked)→i32` (MOSISelLowering) — the CGP fix.
- `PFP = LLT::pointer(3,24)`; `PFP` added to `G_ADDRSPACE_CAST` + the `G_LOAD/G_STORE` *value*-type sets.
- `legalizeAddrSpaceCast`: a `PFP` arm — `p2→p3` keeps the 3 low bytes (`ptrtoint; unmerge s32; merge 3→p3`),
  `p3→p2` zero-extends the pad (`unmerge p3; merge 3+0→s32; inttoptr`). Other packed casts fail loudly.
- `legalizePackedPtrAccess`: a `PFP` load = 3 byte-loads merged to p3; a `PFP` store = p3 unmerged to 3
  byte-stores. Both bridge via `{PFP,S8}` merge/unmerge, which folds.

**Codegen achieved** (`packed24_e2e.c`, snes-far, bank $01): `set` → `stx slot; sty slot+1; sta slot+2`
(3-byte store, bank byte preserved); deref → `ldx/ldy/lda slot{,+1,+2}; stx __rc4; sty __rc5; stz __rc7`
(zero-extend pad) `; sta __rc6; lda [__rc4]` (far indirect-long deref). The `cp` (packed→packed copy)
shows the predicted **×3 indexing** (`asl; clc; adc` = i×2+i).

**Verification (the bar) — all PASS** (full evidence in the handoff plan's §3):
- **Differential, both emulators:** `dev/run.sh packed24` (MAME) `corpus_result==0xF3`; bsnes-jg
  (`jgxcheck`) `got=0xF3`. The far pointer targets **bank $01**, so 0xF3 *proves the bank byte survives
  the 3-byte packing*.
- **`-verify-machineinstrs` clean** on `incB_use.c`, the 4-shape table program, and `packed24_e2e.c`.
- **Non-breaking:** `dev/run.sh corpus` **7/7**; far suite (far-bank1/cast/arith/store/call) all PASS;
  `dev/run.sh fuzz 50 1` 0-mismatch (every new hook is `AS_FarPacked`-gated → default + non-AS3 codegen
  byte-unchanged).
- **Measured win:** a 16-entry table is **48 B vs 64 B = −16 B (−25%)**; access cost ≈ neutral (×3 index
  math offset by one fewer pointer byte loaded). The win is realized exactly as predicted.

Worktree `wt/320-packed24-incB` torn down 2026-06-22 (`f168003`, 12 G reclaimed); all work on `main`. Durable artifacts on `main`:
`0006-320-packed24.patch`, `dev/regen-patch-0006.sh`, the runnable e2e (`packed24_e2e.c` + `dev/packed24.sh`,
wired into `dev/xcheck.sh`), and this record. (Increment A's recipe + the original blocker are preserved
above and in `docs/plans/spikes/2026-06-21-320-packed24-incrementA.patch`.)

**Follow-ups — ALL RESOLVED; productionization thread CLOSED 2026-06-22**
([close-out](2026-06-22-320-packed24-residuals-close.md) · superseding the
[handoff](2026-06-21-320-packed24-productionization-handoff.md)): ~~(A) realistic-context measurement~~
**DONE + verified** (packed wins at every N, break-even N≥1; static-init reloc bug surfaced + FIXED in
`0006`). ~~(B) byte-2 absolute-long access cost~~ **= `0007`** — the cost is general, not packed-specific
(only the A-register byte 2 bloated; STX/STY have no long form so bytes 0,1 were already `abs`), built as
the near-abs bank-relaxation `0007` (`8f/af→8d/ad` for all near pointers, −2 B on packed byte-2). ~~(C)
`__far_packed` spelling~~ **closed** — no AS2 spelling to mirror ⇒ forbidden one-off; revive only via a
shared `<mos.h>`. Worktree `wt/320-packed24-incB` torn down (`f168003`). zero-bank (AS4) **measured-null**
(model complete); folding `0007` onto `main` + the upstream-note posting remain separate threads.

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
2. **0b census.** **PASS — new spaces DEFERRED (premature), value-type completion OPENED** (2026-06-21).
   Census: 0 far pointers stored in memory (circular — storing is broken); `sizeof(far*)==2` (clang gap);
   `G_STORE p2` fails. `dev/measure-five-space-census.sh` 0b block. Packed-24/zero-bank deferred behind
   the desirable far-pointer-value-completion work this surfaced (see *0b verdict (corrected)*).
3. **Phase 1 / packed-24:** **PASS — BUILT + verified** (2026-06-21, on `wt/320-packed24-incB`; user
   directed building it — see *Build packed-24 → Increment B*). `packed24_e2e.c` round-trips a 3-byte
   packed far pointer **across a bank boundary** (target in bank $01) on MAME **and** bsnes-jg:
   ```
   dev/run.sh packed24:  SMOKE: PASS addr=0x7E0203 len=1 got=0xF3 (ran 60 ticks)   [MAME]
   jgxcheck:             SMOKE: PASS off=0x203 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
   ```
   `sizeof` static-asserts show 3-byte storage (`incA_sizeof.c` compiles); the census shape is measurably
   smaller — a 16-entry table is **48 B vs 64 B (−16 B, −25%)** (`llvm-objdump --section-headers`). Corpus
   **7/7**; `dev/run.sh fuzz 50 1` → `45/50 PASS, 0 mismatch, 0 crash`; far suite (far-bank1/cast/arith/
   store/call) all PASS; `-verify-machineinstrs` clean. Shipped as `0006-320-packed24.patch` (round-trips
   via `dev/regen-patch-0006.sh`). The ×3-index cost is recorded (vs `AS_Far` ×4) and is ~neutral.
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

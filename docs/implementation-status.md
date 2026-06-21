# #320 / #321 implementation status — 2026-06-21

Quick-reference for "what's built, what's deferred, and where the ABI comparison landed."
For the full execution record see [ROADMAP.md](ROADMAP.md) and [TODO.md](../TODO.md).

---

## TL;DR

**#320 (far pointers / M1):** the slice that proves the concept is working — far load/store across
bank boundaries, **runtime far-pointer deref/cast/arithmetic (Inc 3 = 3a+3b+3c)**, **direct far
CALLS (JSL/RTL, Inc 4 Phase 1)**, and **mixed-banking far→near calls (via the `__call_near_from_far`
thunk, shipped to `main` 2026-06-21)**, all on two emulators. The far-pointer calling convention is
next — to be settled by **building every ABI variant and measuring** (no longer upstream-gated; ships
as `0004`). The five-address-space model and **far function pointers** (front-end **LOCKED = F2** MOS
`far` attribute; backend gated on `0004` reaching `main`) remain.

**#321 (16-bit accumulator / M2):** the core codegen is complete. Every planned per-op optimization
is either shipped, measured-and-rejected (WON'T-DO), or deferred with a concrete re-open trigger. The
ABI comparison (three frame strategies) ran to completion — it was **not** interrupted by crashes; the
census short-circuited the build at the measurement step.

---

## #320 — far pointers (M1)

| Item | Status |
|---|---|
| Far load/store (absolute-long `lda $018000`) | ✅ Done — `dev/run.sh far-run far-bank1`, MAME+bsnes-jg PASS |
| Second emulator cross-check (bsnes-jg) | ✅ Done — bank-$01 read agrees on both |
| SNES SDK platform (`mos-platform/snes`, `snes-far`) | ✅ Done |
| Design note for #320 (near→far ABI discussion) | ⬜ Drafted; **user-triggered** to post ([docs/320-upstream-far-pointer-note.md](320-upstream-far-pointer-note.md)) |
| Five-address-space model + full PR | ⬜ Upstream-gated on design-note posting; not started |
| Far calls (JSL / RTL) — direct call to a `.far_*` leaf in another bank | ✅ **Done (Inc 4 Ph1, 2026-06-20)** — `dev/run.sh far_call` + `xcheck`, MAME+bsnes-jg PASS; in `0001`. (far → far also already works — non-leaf JSL/RTL chains.) [plan](plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md) |
| Mixed-banking — a far function calling a **near** function (`__call_near_from_far` thunk) | ✅ **Done + shipped to `main` (Inc 4 follow-up b, 2026-06-21, `5717f6b`)** — `lowerCall` routes far→near through the generic bank-0 thunk (`pea .Lback-1; jmp (__rc18); rtl`) reached by `JSL` (`0001`, HasW65816-gated, a16-free). `far_near_call == 0xE0` MAME+bsnes-jg, corpus 7/7, thunk `--gc-sections`'d from near ROMs (byte-identical). Lifts the "far must be leaf-or-far-only" constraint. [plan](plans/2026-06-21-320-far-calls-followups.md) |
| Far function pointers — indirect call through a far code pointer (`__call_indir_far` / `jml [__rc18]`) | ⬜ **Inc 4 follow-up (a) — front-end LOCKED = F2** (MOS `far` attribute; clang forbids `address_space(2)` on fn types, `((far))` is MIPS-only). **Backend gated on `0004`** — forming/storing/returning a `p2` value crashes today (`G_TRUNC`/`G_UNMERGE`/`G_STORE` p2), the same p2-VALUE class the far-CC study ships as Imag32 in `0004-320-far-cc.patch` (not on `main` yet). Resumes on `wt/320-far-followups`. [plan](plans/2026-06-21-320-far-calls-followups.md) |
| Far tail calls | ⬜ Separate follow-up — already conservative-safe (tail peephole keys on `JSR`, so a `JSL` is never tail-converted) |
| Far-pointer calling convention (pass/return `p2`) | ⬜ **Inc 4 Phase 2 — build all ABI variants & measure** ([plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md); no longer upstream-gated; must ship one — tie → Imag32; reuses the frame-ABI harness) |
| Runtime far-pointer deref (`lda [dp]`/`sta [dp]`) + near→far cast (AS0→AS2) | ✅ **Done (Inc 3, 2026-06-20)** — `dev/run.sh far_indir`/`far_cast` + `xcheck`, MAME+bsnes-jg PASS. Added the backend's first 32-bit ZP register (`Imag32`); in `0001`. [plan](plans/2026-06-20-320-far-pointer-runtime.md) |
| Runtime far-pointer arithmetic (`G_PTR_ADD` on AS2) | ✅ **Done (Inc 3c, 2026-06-20)** — `fp++` via the symmetric `s32→4×s8 G_UNMERGE_VALUES` mirror (`legalizeUnmergeS32ToBytes`, a16/`0002`; also closes a latent `uint32_t` shift-≥8 gap); `dev/run.sh far_arith` + `xcheck`, MAME+bsnes-jg PASS. [plan](plans/2026-06-20-320-far-pointer-runtime.md) |
| Far data > 2 banks | ⬜ Deferred past Inc 3 (far load/store proven for ≤2 banks; multi-bank data placement not yet exercised) |
| Formal #320/#321 psABI document | ⬜ Premature — upstream won't bless ahead of a live implementation |

**M1 verdict:** load/store, runtime deref/cast/arithmetic, direct far calls, and mixed-banking far→near
are all built and two-emulator verified. The far-pointer calling convention is **no longer
upstream-gated** — it's a build-all-variants-and-measure task that ships as `0004`. Far function pointers
(a) and the five-address-space model are the remaining frontier; (a)'s backend is gated on `0004`
reaching `main`, and the five-address-space PR still waits on the design-note posting.

---

## #321 — 16-bit accumulator (M2)

### Codegen — per-op wins (all landed)

| Feature | Gate / test | Status |
|---|---|---|
| Basic ALU — add/sub/and/or/xor (globals + locals + immediates) | `a16add` `a16sub` `a16bit` `a16imm` `a16local*` | ✅ |
| ALU chains — add (multi-use, immediate terms), bitwise AND/OR/XOR | `a16chain` `a16chainld` `a16chainimm` `a16bitchain` | ✅ |
| Load-fold — mixed operands (global+register), across-clobber guard | `a16loadfold` `a16mixfold` `a16loadcall` | ✅ |
| Constant shifts ×1–7 (left, right, signed >>) | `a16shift` `a16ashift` | ✅ |
| Signed >> by ≥8 (byte-relabel; compile-hang bug fixed) | `a16ashift8` | ✅ |
| Variable shifts | WON'T-DO — inline loop costs more than `__ashlhi3` libcall at −Os |
| `inc a` / `dec a` — register ±1 and global `g ± 1` | `a16incdec` `a16incabs` | ✅ |
| `inc abs` / `dec abs` memory-RMW | WON'T-DO — no `inc long` on 65816; `inc abs` is DBR-relative (unsafe) |
| Indirect 16-bit load/store `(zp)` | `a16ptr` | ✅ |
| Absolute 16-bit load/store `abs` | `a16abs` | ✅ |
| Indexed load/store `abs,x` and `(zp),y` | `a16absidx` `a16indiry` | ✅ |
| Indexed compare fold `cmp (zp)` (CMPIndir16) | `a16cmpidx` | ✅ |
| Compare-operand fold `cmp abs` (CMPAbs16) | `a16abscmp` | ✅ |
| 16-bit comparisons — unsigned ordering (branch) | `a16cmp` | ✅ |
| 16-bit equality `== !=` (branch) | `a16eq` | ✅ |
| 16-bit signed ordering `slt/sle/sgt/sge` (branch) | `a16scmp` | ✅ |
| Equality as a value `b = (a == c)` — 4 gated variants | `a16eqvalp` `a16eqvalg` `a16eqvalc` | ✅ |
| Full native materialize for eq-as-value | WON'T-DO — measured +14 B (Option A) / +16–28 B (Option B) worse |
| Ordering as a value `b = (a < c)` — branchless carry-tail | WON'T-DO — both 8-bit (`adc`) and 16-bit (`rol`) forms BUILT + measured net-negative (a16cmpaudit +262 B / +654 B; corpus +340 B, **0** programs improve). Select-diamond is the ambient-16-bit optimum (folds inversion free, M8 tail matches mode, keeps the bool in X not an Imag16 slot). Compare track CLOSED |
| REP/SEP mode-tracking — M-flag, cross-block | `a16loop` `a16call` | ✅ |
| s32 legalizer (unmerge s32↔s16, 4×s8→s32 merge) | Csmith seed-50 / seed-113 gates | ✅ |
| A16 spill crash (F3) — static + soft-stack (reentrant) | `a16spill` `a16spillr` `a16spillir` | ✅ |

### A16-threading

| Phase | Status |
|---|---|
| Phase 0 — measure (20 redundant round-trips) | ✅ Done |
| Phase 1 — adjacent `STAImag16 R; LDAImag16 R` peephole | ✅ Done — `a16thread`, −31/−36 % on chains |
| Phase 1.5 — non-adjacent (across volatile stores, multi-reload) | ✅ Done — 1 genuine remainder in 300-program scan |
| Phase 2 — fold-while-threaded | Retired — already optimal (immediates + abs globals fold into chain today) |
| Phase 3 — RA-level `Ac16` residency | ⬜ **Deferred** — re-open trigger: 2nd independent regalloc crash from realistic code, or ZP pressure baseline crossing ~10/14 pairs |

### XY16 (X/Y permanently 16-bit)

| Item | Status |
|---|---|
| Feature flag `+mos-xy16`, Xc16/Yc16 register classes, pseudos | ✅ Done (Layers 1–2) |
| Parallel X-flag lattice in `MOSInsertREPSEP` | ✅ Done (Layer 3) |
| Static + soft-stack spills | ✅ Done (Layer 4) |
| `selectXY16` — direct + indexed (`abs,X16` / `(zp),Y16`) handlers | ✅ Done (Layer 5) |
| X-flag `requiredXWidth` gap fix (CPX/CPY/INC/DEC value ops) | ✅ Done — cleared all 5 xy16 torture miscompiles + `k_isort` |
| Frame-index elimination scramble (CmpBrAbsImm16) | ✅ Done — cleared 13 c-torture miscompiles |
| `xy16basic` / `xy16ops` / `xy16indiry` / `xy16spill` gates | ✅ All PASS on MAME + bsnes-jg |
| Csmith seed-247 + seed-445 runtime miscompiles | ✅ **FIXED 2026-06-20 (`2d8ab51`, approach B)** — cvise-reduced to an 8-line UB-free repro: a non-index s16 value classed `Xc16`, loaded into X16, left live across an 8-bit-index op whose `sep #$10` zeroes the high byte. `selectXY16` now emits `LDXAbs16`/`LDYAbs16` only when the value is genuinely an index, else reclasses to `Imag16`. 4-way both emulators + csmith 101–500 (0/400 mismatch) + c-torture 60/60; smaller code (61→54 B) |
| `requiredXWidth` 8-bit-indexed-family hardening (Track A) | ✅ **Done 2026-06-21** — structural memory-gated catch-all closes the last index-width omission (the load/store/branch siblings of the value-compare bug); byte-identical 75/75, hardening not a live bug |
| Hardware-stack ABI / 16-bit calling convention | ⬜ Pending (see ABI section) |

### Infrastructure + correctness corpus

| Item | Status |
|---|---|
| Tier-1 differential fuzzer (`a16_fuzz.py`, builtin generator) | ✅ Standing capability |
| Csmith differential fuzzer (phases 0–5; 1–500 seeds) | ✅ **Phases 0–5 done (2026-06-21)** — sampled CI wired (`fuzz-csmith` job, host-side, 4-way, secret-gated, `mode` sampled/full) |
| GCC c-torture suite (-O1 pass: 1098 PASS; -Os pass: 1114 PASS; bsnes-jg 4-way) | ✅ **Done; Phase 3 sampled CI wired (2026-06-21)** — `torture` job (in-container, 4-way, seeded `--sample`, secret-gated, `mode` sampled/full) |
| `corpus-a16` differential gate (+a16/+xy16 on both emus) | ✅ Standing capability + in CI |
| bsnes-jg `xcheck` in CI | ✅ Verified green (run 27823207476) |
| Native-mode crt0 (DBR=0 via `phk;plb`, explicit contract) | ✅ Done |
| Register-scavenger crash (`$p is not a GPR`) | ⬜ **Upstream bug** — XFAIL'd (8/500 seeds), now under **both** `+mos-a16` and `+mos-xy16`; XPASS-guarded; fix deferred |
| `+mos-a16 -Os` RA failure (`globals.c`) | ⬜ XFAIL'd — coalescing ruled out; only Phase-3 residency rework could fix; re-open trigger defined; XPASS-guarded |
| KNOWN_ISSUES XFAIL handling — `evaluate()` classifies under `+mos-xy16` too + both-legs hardening | ✅ **Done (2026-06-21)** — a known `+mos-a16` issue can't mask a NEW `+mos-xy16` crash; both verify legs run; a new crash on either leg always hard-FAILs. [classify](plans/2026-06-21-321-xy16-verify-leg-classify-known.md) · [both-legs](plans/2026-06-21-321-xy16-verify-both-legs-hardening.md) |
| KNOWN_ISSUES XPASS guard — `dev/run.sh known-issues` (unconditional in CI) | ✅ **Done (2026-06-21)** — asserts `a16regpress`/`a16scavnz` still crash `-verify-machineinstrs` under both modes; fails loudly with "drop the entry + promote to a positive gate" the moment an upstream/RA fix lands. [plan](plans/2026-06-21-321-known-issues-xpass-guard.md) |
| F4 `TXY`/`TYX` dead-flag fix (patch `0003`) | ✅ In fork; **upstream PR ready** (user-triggered to post) |

### Pending codegen (greenlit or in-progress)

With load-fold landed and the compare track closed, the per-op a16 codegen is complete (see TL;DR). The
remaining codegen frontiers are #320's far calling convention and xy16's ABI.

| Item | Status |
|---|---|
| Load-fold gate unification (AA-precision) — `noClobberBetween` | ✅ **Done 2026-06-20 (`6440db0`)** — AA-precise fold landed (−26 B, 0 regressions, verify-clean, 5 c-torture recovery sites 4-way PASS). The volatile-drop half measured net-negative (+17 B / 19 regressions) and is **closed**, not pursued |
| #320 far-pointer calling convention (`p2` pass/return) | ⬜ Build all ABI variants & measure; must ship one (ships as `0004`). See #320 table + What's next |
| #320 far function pointers (a) | ⬜ Front-end LOCKED = F2; backend gated on `0004` reaching `main` |
| xy16 hardware-stack ABI / 16-bit calling convention | ⬜ The remaining M2 codegen frontier — CC sub-decisions all resolved |

---

## ABI variations comparison — where it stands

**The "build all three and measure" plan ran to completion.** No crash interrupted it — the
measurement **short-circuited the build** at the census step.

### What was planned

Build and compare three 65816 frame strategies head-to-head:

| Strategy | Description |
|---|---|
| **(a) TCD direct-page window** | Set `D` register per-call (`tsc;phd;tcd`); locals accessed via 8-bit DP offsets — **WDC816CC/ORCA-C approach** |
| **(b) Hardware stack-relative** | 16-bit SP, locals via `,S` indexed addressing |
| **(c) Soft static stack** (llvm-mos default) | Locals in fixed-ZP `__rc*` imaginary registers |

### What was built

| Phase | Result |
|---|---|
| **P0** — `+mos-dp-frame`/`+mos-sr-frame` feature scaffolding + `frameStrategy()` | ✅ Done — byte-identical default proven 24/24 programs |
| **A0** — DP-collision proof (`D≠0` + abs `__rc` coexist; `0xBBAA` on MAME+bsnes-jg) | ✅ Done — collision avoidable |
| **A0 census** — `dev/frameabi-census.sh` over corpus+kernels | ✅ Done — **0/13 realistic functions can profit** |
| **A1–A4** — full (a) DP codegen | NOT BUILT — census short-circuited |
| **B** — full (b) stack-relative codegen | NOT BUILT — census short-circuited |
| **M** — cycle measurement harness | NOT BUILT — unnecessary |

### Why the build was short-circuited (not a crash)

The A0 census measured the frame-traffic *opportunity* directly: across 13 realistic functions (corpus
+ 6 kernels, `+mos-a16 -Os`), **11/13 have zero static-stack spills** and the other 2 are negligible.
The root cause: llvm-mos keeps locals **register-resident in `__rc*`** and routes local
arrays/structs/`&local` through a pointer *in* `__rc` (`lda (__rc),y`) — so there is nothing for any
per-frame ABI to optimize, and a DP-window would **tax** the abundant `__rc` accesses with wider
absolute loads.

Building A1–B–M would only confirm the measured NULL. The census *is* the measurement.

### Decision (2026-06-20, evidence-backed)

**(c) soft static stack retained.** Both (a) and (b) are **CONFIRMED-shelved** — not by paper
reasoning, but by direct measurement of the frame-traffic opportunity. This is a first-class upstream
finding (and is drafted as the [#321 CC design note](321-upstream-cc-frame-abi-note.md) for posting).

**Durable artifacts merged to `main` (`f114c42`):** `frameabi_a0.c`/`.sh` (feasibility proof),
`frameabi_heavy.c` (winning-boundary stress shape), `frameabi-census.sh`, `frameabi-byte-identical.sh`.

The `wt/321-frame-abi` branch is **retained until user says to tear it down** — it holds the inert,
un-landed (a)/(b) `0002` spike.

### Other CC sub-decisions (all resolved)

| Sub-decision | Status |
|---|---|
| Return values | ✅ **LOCKED** — A (low word) / X (high word) |
| Argument passing | ✅ **Adopted for first pass** — imaginary-register (`CC_MOS`, existing) |
| Recursion / reentrancy | ✅ **Solved** — soft static stack, hardened (F3 + soft-stack P0–P2) |
| Frame layout | ✅ **RESOLVED** — (c) by measurement; (a)/(b) confirmed-shelved |

---

## Computer-crash assessment

Based on the commit history and plan records, **no work-in-progress was lost to a crash**:

| Work item | State at time of crash | Outcome |
|---|---|---|
| Frame-ABI "build all three" | Census completed; A1–M correctly **not started** | Complete — NULL result is the answer |
| xy16 Csmith seeds 247/445 | Checkpointed at debugging cap, **then resumed and fixed** (`2d8ab51`, 2026-06-20) | Complete — cvise-reduced, root-caused, 4-way verified |
| Load-fold unification | Phase 1 PROCEED → Phase 2 built + byte-diffed → **landed (`6440db0`)** | Complete — AA-precision landed, volatile-drop closed net-negative |
| c-torture -Os sweep + bsnes-jg 4-way | Both completed and recorded | Complete |

Every item above ran to a clean conclusion — none was lost to a crash. The open frontiers are forward
work (the #320 far calling convention and xy16 ABI), tracked in *What's next* and TODO.

---

## What's next (prioritized)

1. **#320 far-pointer calling convention** — build all ABI variants (Imag32 quad / Imag16+bank-byte /
   A:X+Y / stack) behind feature flags & measure; must ship one (tie → Imag32), reusing the frame-ABI
   harness. Lands as `0004` — the gate for far function pointers (a).
   [plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md)

2. **#320 far function pointers (a)** — front-end LOCKED = F2 (MOS `far` attribute) + indirect
   lowering (`__call_indir_far`); **unblocks once `0004` lands on `main`**, then resumes on
   `wt/320-far-followups`. [plan](plans/2026-06-21-320-far-calls-followups.md)

3. **xy16 hardware-stack ABI** — the calling-convention implementation for 16-bit index-register
   mode. CC sub-decisions are all resolved; this is the remaining M2 codegen frontier.

4. **Upstream posts (user-triggered):**
   - F4 `TXY/TYX` dead-flag fix PR (ready)
   - Register-scavenger N/Z-liveness issue (draft ready)
   - #321 CC frame-ABI design note (draft ready)
   - #320 far-pointer design note (draft ready; unblocks the five-address-space PR)
   - DWARF step-6 test+docs PR (branch pushed)
   - #415 SNES target reconciliation (strategy drafted)

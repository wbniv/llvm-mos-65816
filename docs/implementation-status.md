# #320 / #321 implementation status — 2026-06-20

Quick-reference for "what's built, what's deferred, and where the ABI comparison landed."
For the full execution record see [ROADMAP.md](ROADMAP.md) and [TODO.md](../TODO.md).

---

## TL;DR

**#320 (far pointers / M1):** the slice that proves the concept is working — far load/store across
bank boundaries plus **runtime far-pointer deref/cast/arithmetic (Inc 3 = 3a+3b+3c, complete)**, two
emulators. The five-address-space model, far calls (JSL), and the far-pointer calling convention are not
built yet; they're gated on upstream ABI blessing.

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
| Far calls (JSL / RTL), cross-bank function pointers | ⬜ Blocked on CC decision + upstream |
| Runtime far-pointer deref (`lda [dp]`/`sta [dp]`) + near→far cast (AS0→AS2) | ✅ **Done (Inc 3, 2026-06-20)** — `dev/run.sh far_indir`/`far_cast` + `xcheck`, MAME+bsnes-jg PASS. Added the backend's first 32-bit ZP register (`Imag32`); in `0001`. [plan](plans/2026-06-20-320-far-pointer-runtime.md) |
| Runtime far-pointer arithmetic (`G_PTR_ADD` on AS2) | ✅ **Done (Inc 3c, 2026-06-20)** — `fp++` via the symmetric `s32→4×s8 G_UNMERGE_VALUES` mirror (`legalizeUnmergeS32ToBytes`, a16/`0002`; also closes a latent `uint32_t` shift-≥8 gap); `dev/run.sh far_arith` + `xcheck`, MAME+bsnes-jg PASS. [plan](plans/2026-06-20-320-far-pointer-runtime.md) |
| Far data >2 banks, far calls (JSL/RTL), far-pointer calling convention | ⬜ Deferred past Inc 3 (CC = ABI decision, upstream-gated; grouped with far calls / Inc 4) |
| Formal #320/#321 psABI document | ⬜ Premature — upstream won't bless ahead of a live implementation |

**M1 verdict:** the load/store slice is solid and two-emulator verified. Everything else waits on the
upstream ABI discussion that the design note is meant to open.

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
| **Csmith seed-247 + seed-445 runtime miscompiles** | ⬜ Phase 1 partial (see below) |
| Hardware-stack ABI / 16-bit calling convention | ⬜ Pending (see ABI section) |

### Infrastructure + correctness corpus

| Item | Status |
|---|---|
| Tier-1 differential fuzzer (`a16_fuzz.py`, builtin generator) | ✅ Standing capability |
| Csmith differential fuzzer (phases 0–4; 1–500 seeds) | ✅ Phases 0–4 done; Phase 5 (sampled CI) open |
| GCC c-torture suite (-O1 pass: 1098 PASS; -Os pass: 1114 PASS; bsnes-jg 4-way) | ✅ Done; Phase 3 (sampled CI) open |
| `corpus-a16` differential gate (+a16/+xy16 on both emus) | ✅ Standing capability + in CI |
| bsnes-jg `xcheck` in CI | ✅ Verified green (run 27823207476) |
| Native-mode crt0 (DBR=0 via `phk;plb`, explicit contract) | ✅ Done |
| Register-scavenger crash (`$p is not a GPR`) | ⬜ **Upstream bug** — XFAIL'd locally (8/500 seeds); fix deferred |
| `+mos-a16 -Os` RA failure (`globals.c`) | ⬜ XFAIL'd — coalescing ruled out; only Phase-3 residency rework could fix; re-open trigger defined |
| F4 `TXY`/`TYX` dead-flag fix (patch `0003`) | ✅ In fork; **upstream PR ready** (user-triggered to post) |

### Pending codegen (greenlit or in-progress)

| Item | Status |
|---|---|
| Load-fold gate unification (AA-precision + volatile) — `canFoldLoadIntoUser` | ⬜ **Phase 2 greenlit** — Phase 1 confirmed 43 volatile + 7 AA-precision recovery sites; needs fresh worktree |
| xy16 Csmith seeds 247+445 root cause | ⬜ **Phase 1 partial** — linear X-width trace inconclusive; minimal repro doesn't reproduce; H2 (CFG/loop-edge X-width) prime suspect; **next: delta-reduce seed 445** on `wt/321-xy16` |

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
| xy16 Phase-1 root cause (seeds 247/445) | Debugging cap (3 hypotheses) hit; **intentionally checkpointed** | Checkpointed cleanly; Phase 1 findings recorded in the plan |
| Load-fold Phase 1 measurement | Probe ran; throwaway worktree torn down; results recorded | Complete — PROCEED verdict |
| c-torture -Os sweep + bsnes-jg 4-way | Both completed and recorded | Complete |

The xy16 and load-fold items look "incomplete" because they **are** — but they stopped at a
deliberate checkpoint, not a crash. The next steps are in the fix plan and TODO.

---

## What's next (prioritized)

1. **Load-fold unification Phase 2** — `canFoldLoadIntoUser`, byte-diff the fixtures, full
   differential. Greenlit; start a fresh `throwaway/loadfold-unify` worktree.
   [plan](plans/2026-06-20-321-unify-loadfold-gate-aa-volatile.md)

2. **xy16 Csmith seeds 247+445** — delta-reduce seed 445 on `wt/321-xy16`, or CFG-aware X-lattice
   analysis across the `crc32_tab` loop edges + `transparent_crc` call boundary.
   [fix plan](plans/2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md)

3. **Csmith Phase 5 + c-torture Phase 3** — sampled CI integration.

4. **Upstream posts (user-triggered):**
   - F4 `TXY/TYX` dead-flag fix PR (ready)
   - Register-scavenger N/Z-liveness issue (draft ready)
   - #321 CC frame-ABI design note (draft ready)
   - #320 far-pointer design note (draft ready; unblocks the five-address-space PR)
   - DWARF step-6 test+docs PR (branch pushed)
   - #415 SNES target reconciliation (strategy drafted)

5. **xy16 hardware-stack ABI** — the calling-convention implementation for 16-bit index-register
   mode. CC sub-decisions are all resolved; this is the remaining M2 codegen frontier.

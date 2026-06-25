# #320 / #321 implementation status — 2026-06-25

Quick-reference for "what's built, what's deferred, and where the ABI comparison landed."
For the full execution record see [ROADMAP.md](ROADMAP.md) and [TODO.md](../TODO.md).

---

## TL;DR

**#320 (far pointers / M1):** the slice that proves the concept is working — far load/store across
bank boundaries, **runtime far-pointer deref/cast/arithmetic (Inc 3 = 3a+3b+3c)**, **direct far
CALLS (JSL/RTL, Inc 4 Phase 1)**, and **mixed-banking far→near calls (via the `__call_near_from_far`
thunk, shipped to `main` 2026-06-21)**, all on two emulators. The far-pointer calling convention is
**DONE (2026-06-21)** — all 4 ABI variants built & two-emulator measured; variant (a) **Imag32 won** and
landed as **`0004`** on `main` (round-trip-proven byte-identical to the `wt/320-far-cc` study tree).
The five-address-space model is **measured-complete** — **AS3 packed-24** (the 3-byte far-ptr storage form)
is **built + verified + landed (`0006`, 2026-06-21/22, incl. the static-init table reloc fix)**, its
**productionization thread CLOSED** (2026-06-22: Task A measured, Task B = the general near-abs relaxation
`0007`, Task C closed — no AS2 spelling to mirror), and **AS4 zero-bank = CONFIRMED measured-null**. `0007`
is now **folded onto `main`** (the stack is `0001`–`0007`; toolchain rebuilt + verified 2026-06-22), so only
the upstream PR/note remain. **Far function pointers (a)** are now **FULLY DONE + LANDED (2026-06-21)** —
the indirect-call mechanism, the full p2-value path, and `&far_fn`→24-bit land on the backend, **and** the
clang front-end is complete: the **`far`/`long_call` attribute (F2)**, a **typed `far_fn_t` variable**
(`far_fn_t fp = far_leaf; fp(x)`), and **`sizeof(far*)==4`** — all e2e-verified on both emulators (a fixed a
pre-existing `far_indir` compiler crash along the way). Pushed `origin/wt/320-far-followups`; **LANDED on
`main` 2026-06-21** — the (a) work folded into `0001` (a16-free); the lone a16-context-entangled hunk
(`MOSLegalizerInfo` PF-as-value) split into new **`0005`**; round-trip-proven to reproduce the verified tree.
The far-pointer **data-value** residuals are **closed** (2026-06-22, [plan](plans/2026-06-22-320-far-value-residuals.md)):
the **dp→near** case is a pre-existing **upstream** CC bug — an 8-bit `addrspace(1)` pointer *argument* gets a
16-bit `RS` register → illegal `COPY` (reproduces on plain `mos6502`; filed upstream
[`320-upstream-dp-arg-cc-issue.md`](320-upstream-dp-arg-cc-issue.md), no fork fix) — and **default-8-bit** far
storage is un-legalized **by design** (the 32-bit far value's `s32↔bytes` bridge is `+mos-a16`-gated → a clean
compile-time `unable to legalize` rejection, never a miscompile).

**#321 (16-bit accumulator / M2):** the core codegen is complete. Every planned per-op optimization
is either shipped, measured-and-rejected (WON'T-DO), or deferred with a concrete re-open trigger. The
**xy16 calling convention is now verified + formalized (`ebedd1c`)** — the last M2 codegen frontier,
closed: the X/Y-8-bit-at-call boundary is correct by construction, and the two xy16-specific ABI levers
were measured and shelved. The ABI comparison (three frame strategies) ran to completion — it was **not**
interrupted by crashes; the census short-circuited the build at the measurement step. **32-bit
`long`/`int32_t` support is now value-verified (2026-06-23)** — a dedicated `a16s32` 4-way micro-test +
a gated `--s32` track in the builtin fuzzer exercise the s32 path (2×s16 + (un)merge + mul/div libcalls)
deterministically; both green. **The lone `+mos-a16 -O1/-Os` RA-crash on real code (`globals.c`/
`a16regpress.c`, "ran out of registers") is now FIXED** — fork patch **`0009`** (`ad506ed`, 2026-06-25), an
*orthogonal* i8-loop-counter de-pin from `{A}` (**not** the deferred Phase-3 `Ac16`-residency rework); DEFAULT
byte-identical, −123 B / 122 c-torture progs, and `a16regpress.c` is now a positive gate. **The
scavenger-N/Z crash (`$p is not a GPR`) is also now FIXED** — pristine-upstream fork patch **`0011`**
(2026-06-26; route a live `$p` through a dead index reg into `RC17` for the unbalanced case), with the second
upstream bug it surfaced (`LDCImm 1` → `MCInstLower` unreachable) fixed as **`0012`**; `a16scavnz.c` is now a
positive gate. The lone remaining `+mos-a16` register-pressure XFAIL — the `pr15296` link-time ZP-overflow —
stays deferred behind its re-open trigger.

**Also on `main` (2026-06-23):** **#320 far tail calls** — a far→far tail `JSL g; RTL` now folds to a
direct long jump (`TailJML`/`$5C`), −1 B per site (landed in `0001`, `4adda8b`; verified both emulators).
**Extended 2026-06-26:** the **far→near** thunk tail `JSL __call_near_from_far; RTL` folds the same way (gate
matches the thunk's external symbol by exact name; `0xE0` MAME+bsnes-jg). The **far-indirect** thunk tail
stays deferred — that *call* path doesn't link on `main` (its SDK stub `__call_indir_far` is unlanded).

---

## #320 — far pointers (M1)

| Item | Status |
|---|---|
| Far load/store (absolute-long `lda $018000`) | ✅ Done — `dev/run.sh far-run far-bank1`, MAME+bsnes-jg PASS |
| Second emulator cross-check (bsnes-jg) | ✅ Done — bank-$01 read agrees on both |
| SNES SDK platform (`mos-platform/snes`, `snes-far`) | ✅ Done |
| Design note for #320 (near→far ABI discussion) | ⬜ Drafted; **user-triggered** to post ([docs/320-upstream-far-pointer-note.md](320-upstream-far-pointer-note.md)) |
| Packed-24 far pointer (`AS_FarPacked`, addrspace 3) — 3-byte storage form of a far ptr (banked-asset / jump tables) | ✅ **DONE + landed (`0006`, 2026-06-21/22).** Increment A (3-byte type: `p3:24:8`, `sizeof(packed*)==3`) + Increment B (store/load/deref via `G_MERGE/UNMERGE{PFP,S8}`, not `s24`) + **static-init table reloc fix** (`a76bf18`: a static packed far-ptr table emitted `R_MOS_ADDR8` per entry → an `AsmPrinter::emitNonStandardSizedConstant` hook + MOS override emit the `ADDR24 SEGMENT_LO/HI/BANK` triple). `dev/run.sh packed24`/`packed24_table` `0xF3`/`0xA5` MAME+bsnes-jg; corpus 7/7; fuzz 0-mismatch. **Measured (`dev/run.sh measure-packed24`):** wins ≈N B/table, break-even N≥1 (indexed access code equal). Opt-in. **Productionization thread CLOSED (2026-06-22):** Task B (byte-2 absolute-long cost) = the general near-abs relaxation `0007` (not packed-specific); Task C (`__far_packed` spelling) closed (no AS2 spelling to mirror). [close-out](plans/2026-06-22-320-packed24-residuals-close.md) · [fix plan](plans/2026-06-22-320-packed24-static-init-reloc-fix.md) · [§Build packed-24](plans/2026-06-21-320-five-address-space-model.md) |
| Five-address-space model + full PR | ⬜ Upstream-gated on design-note posting; not started (the fork implementation body — far calls/ptrs/CC + AS3 packed-24 — is landed `0001`+`0004`+`0005`+`0006`; **model measured-complete — AS4 zero-bank = measured-null, packed-24 productionization closed**) |
| Near/far "code model" + SNES near-code budget enforcement | ✅ **Done (2026-06-22, linker-script + docs only).** Decision: **no `-mcmodel` codegen mode** — near (`JSR`/`RTS`, `CodeModel::Small`, 2-byte fn ptr) is the default, far is per-symbol opt-in (`small` = all-near, `medium`/`large` = the #320 far story). The SNES near-code budget (`$8000–$FFAF` = 32688 B) is now an **enforced link-time contract**: `platforms/snes` + `snes-far` `link.ld` carve the fixed header/vectors into a `romhdr` region so `rom`'s LENGTH *is* the budget → an over-budget link fails with `region 'rom' overflowed by N bytes` (was an obscure `.snes_header` overlap). ROM **byte-identical** for in-budget programs (12 ROMs, 0 diffs); corpus 7/7; far suite PASS. Framing folded into the #320 upstream note. [plan](plans/2026-06-22-snes-near-code-budget-and-code-model.md) |
| Far calls (JSL / RTL) — direct call to a `.far_*` leaf in another bank | ✅ **Done (Inc 4 Ph1, 2026-06-20)** — `dev/run.sh far_call` + `xcheck`, MAME+bsnes-jg PASS; in `0001`. (far → far also already works — non-leaf JSL/RTL chains.) [plan](plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md) |
| Mixed-banking — a far function calling a **near** function (`__call_near_from_far` thunk) | ✅ **Done + shipped to `main` (Inc 4 follow-up b, 2026-06-21, `5717f6b`)** — `lowerCall` routes far→near through the generic bank-0 thunk (`pea .Lback-1; jmp (__rc18); rtl`) reached by `JSL` (`0001`, HasW65816-gated, a16-free). `far_near_call == 0xE0` MAME+bsnes-jg, corpus 7/7, thunk `--gc-sections`'d from near ROMs (byte-identical). Lifts the "far must be leaf-or-far-only" constraint. [plan](plans/2026-06-21-320-far-calls-followups.md) |
| Far function pointers — indirect call through a far code pointer (`__call_indir_far`) | ✅ **DONE (Inc 4 follow-up (a), 2026-06-21).** A far fn ptr can't be a `ptr addrspace(2)` IR callee (LLVM forbids a non-program-addrspace callee), so the 24-bit target is threaded via **IR-rep #1** — a volatile store to a runtime slot `__mos_far_target` + `call @__call_indir_far`; `lowerCall` emits `JSL`, the stub does `jml (__mos_far_target)`. **Backend** (`579b911`): the deep p2-value sub-project — L1 `copyCost` Imag32, L2 `getRegAllocationHints` size-guard, **L3 `selectUnMergeValues` byte→word subreg** (the real crash; "SelectImm" framing was stale), **Gap A `&far_sym`→24-bit** (`buildFarAddrWords`+`MO_ADDR24_*`→`#mos24bank`), **Gap B `G_STORE`/`G_LOAD p2`** (PF value type). **Clang front-end:** **F2 `far`/`long_call` attribute** (`285197d` — `MOSFarCall`, sharing MIPS's `long_call`/`far` GNU spelling via a shared `ParseKind`; `CGExpr` rewrite to the stash-then-thunk shape) → a clean single-file `far_leaf(0x5A)` call; **typed `far_fn_t` variable** (`5fa6d81` — a `far` bit on `FunctionType::ExtInfo` → `ptr addrspace(2)`; `far_fn_t fp = far_leaf; fp(x)`); **`sizeof(far*)==4`** (`ebdb0d1` — `getPointerWidthV(AS2)`→32 + a `getTypeInfoImpl` arm). Also fixed a **pre-existing `far_indir` SIGSEGV** (`isFarSymbol` over-fired on `.far_rodata` data taken as a near pointer → restrict the `.far*` section check to functions). **e2e `far_fnptr`/`far_fnptr_var`/`far_sizeof` + the whole far suite (12 ROMs) PASS on MAME + bsnes-jg** (a16-only), corpus 7/7, csmith 0-mismatch. **✅ LANDED on `main` (2026-06-21):** folded into `0001` (a16-free); the lone a16-context-entangled hunk (`MOSLegalizerInfo` PF-as-value) split into new **`0005`**; round-trip-proven to reproduce the verified `wt/320-far-followups` tree. **⚠ Gap (found 2026-06-26):** the **runtime stub** `__call_indir_far` (`platforms/snes/call-indir-far.s` + the `__mos_far_target` slot) was verified on the `wt/320-far-followups` worktree but **never landed into tracked `platforms/snes/` or the SDK** — so a far-**indirect** *call* currently fails to link on `main` (`ld.lld: error: undefined symbol: __call_indir_far`, proven via a minimal `far`-attribute call). The clang + backend half **is** landed (`0001`+`0005`); the SDK runtime half + a far-indirect-**call** e2e (the `far_fnptr*` ROMs are not in tracked `examples/`) need landing to make the e2e claim true on `main`. [thunk-tail plan §4](plans/2026-06-26-320-thunk-tail-calls.md). [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md) · [plan](plans/2026-06-21-320-far-calls-followups.md) · [typed-var](plans/2026-06-21-320-far-fnptr-typed-variable.md) · [sizeof](plans/2026-06-21-320-far-pointer-sizeof.md) |
| Far tail calls | ✅ **Done (direct + far→near).** Direct **far→far** `JSL <far global>; RTL` → `TailJML`/`$5C` (−1 B) landed `4adda8b` (2026-06-23). **far→near** thunk tail `JSL __call_near_from_far; RTL` → `TailJML` landed 2026-06-26 ([plan](plans/2026-06-26-320-thunk-tail-calls.md), in `0001`; `dev/run.sh far_near_call` folds to a long `jmp __call_near_from_far` + `0xE0` MAME+bsnes-jg; corpus 7/7, fuzz 0-mismatch; gate matches the thunk by exact name — conservative). **far-indirect** thunk tail (`__call_indir_far`) deferred — that *call* path doesn't link on `main` (its SDK stub is unlanded — see the far-fn-ptr row ⚠), so its tail-opt is premature. |
| Far-pointer calling convention (pass/return `p2`) | ✅ **DONE — landed `0004` on `main` (Inc 4 Ph2, 2026-06-21).** All 4 ABI variants built & two-emulator measured (`wt/320-far-cc`); variant **(a) Imag32 won** (`0xF3` MAME+bsnes-jg, default byte-identical, csmith 0-mismatch; needs `Imag32 ∈ AnyRegBank`) and shipped as stacked **`0004-320-far-cc.patch`** + the measure harness + [measurement note](320-upstream-far-cc-measurement-note.md); losers stayed a measured spike. [study plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md) · [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md) |
| Runtime far-pointer deref (`lda [dp]`/`sta [dp]`) + near→far cast (AS0→AS2) | ✅ **Done (Inc 3, 2026-06-20)** — `dev/run.sh far_indir`/`far_cast` + `xcheck`, MAME+bsnes-jg PASS. Added the backend's first 32-bit ZP register (`Imag32`); in `0001`. [plan](plans/2026-06-20-320-far-pointer-runtime.md) |
| Runtime far-pointer arithmetic (`G_PTR_ADD` on AS2) | ✅ **Done (Inc 3c, 2026-06-20)** — `fp++` via the symmetric `s32→4×s8 G_UNMERGE_VALUES` mirror (`legalizeUnmergeS32ToBytes`, a16/`0002`; also closes a latent `uint32_t` shift-≥8 gap); `dev/run.sh far_arith` + `xcheck`, MAME+bsnes-jg PASS. [plan](plans/2026-06-20-320-far-pointer-runtime.md) |
| Far data > 2 banks | ✅ **Done — gate formalized 2026-06-26.** `dev/run.sh farindex`: a `const FAR uint16_t tbl[]` spanning banks $C1/$C2/$C3 (98304 × uint16, `snes-hirom`) read at three runtime indices (100/50000/90000) that land in three distinct banks via `lda [dp]` (R_MOS_ADDR24) folds `corpus_result==0x0001D8A1`, host == +mos-a16 on MAME + bsnes-jg. Depends on the clang far-subscript fix (`0001`: index promoted to the AS2 32-bit width → carries into the bank byte). `dev/run.sh k_trig32lut` independently corroborates (the ~200 KiB sin LUT across $C1..$C4); single-object absolute-long cross-bank read is gated by `far-bank1`. [plan](plans/2026-06-26-formalize-far-data-2-banks-into-a-dedicated-passin.md) |
| Formal #320/#321 psABI document | ⬜ Premature — upstream won't bless ahead of a live implementation |

**M1 verdict:** load/store, runtime deref/cast/arithmetic, direct far calls, mixed-banking far→near, **and
far function pointers (a) — backend + clang front-end (F2 `far` attribute, typed `far_fn_t` variable,
`sizeof(far*)==4`)** — are all built and two-emulator verified. **Far data across >2 banks** is now a
dedicated gate too (`dev/run.sh farindex`, banks $C1/$C2/$C3, 2026-06-26). Far function pointers (a) are
**fully done + landed on `main`** (2026-06-21, in `0001` + `0005`). The far-pointer calling convention is **done + landed**
— all variants measured, **Imag32 won and shipped as `0004`** on `main`. The five-address-space model is the
other frontier; its PR still waits on the design-note posting.

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
| s32 legalizer (unmerge s32↔s16, 4×s8→s32 merge) | Csmith seed-50 / seed-113 gates; **`a16s32` dedicated 4-way micro-test** + **builtin fuzzer `--s32` track** (2026-06-23) | ✅ **value-verified** — `dev/run.sh a16s32` folds every s32 hazard (2×s16 carry, (un)merge, shifts, `__mulsi3`/`__udivsi3`/`__umodsi3`, s16→s32 ext, compare-as-value) → `host==default==+mos-a16==0x50F2B870` MAME+bsnes-jg; `fuzz --gen builtin --s32` 40/40 0-mismatch. [plan](plans/2026-06-23-321-32bit-long-verification.md) |
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
| 16-bit calling convention (X/Y across calls) | ✅ **Done — verified + formalized (2026-06-21, `ebedd1c`)**. The 8-bit-register boundary was already mechanical (X/Y forced 8-bit at every `isCall`/`isReturn`; X16/Y16 caller-saved); this **closes the gap** with a cross-call differential gate (`xy16call.c`/`dev/run.sh xy16call`, a load-bearing 16-bit index live across a clobbering call → `0x7E5A` 4-way). **Correct by construction:** the RA parks the cross-call-live index in a callee-saved ZP `Imag16` pair and reloads `X16` only at point of use, so physical `X16` is never live across a call — no spill hazard, no fix needed. Two xy16-specific ABI levers **measured + shelved with evidence** (i32-return-in-`A16:X16`: realistic 0 call sites, a frame-ABI-style NULL; PHX/PLX index-spill: premise removed). [plan](plans/2026-06-18-321-m2-xy16-calling-convention-verify-formalize-me.md) |

### Infrastructure + correctness corpus

| Item | Status |
|---|---|
| Tier-1 differential fuzzer (`a16_fuzz.py`, builtin generator) | ✅ Standing capability — **+ gated `--s32` 32-bit track (2026-06-23):** a seeded op-list over `uint32_t` regs, lockstep C-emit/Python-oracle, exercises the s32 path in the *deterministic* 4-way oracle (`fuzz --gen builtin --s32` 40/40 0-mismatch; `--s32` off byte-identical) |
| Csmith differential fuzzer (phases 0–5; 1–500 seeds) | ✅ **Phases 0–5 done (2026-06-21)** — sampled CI wired (`fuzz-csmith` job, host-side, 4-way, secret-gated, `mode` sampled/full) |
| GCC c-torture suite (-O1 pass: 1098 PASS; -Os pass: 1114 PASS; bsnes-jg 4-way) | ✅ **Done; Phase 3 sampled CI wired (2026-06-21)** — `torture` job (in-container, 4-way, seeded `--sample`, secret-gated, `mode` sampled/full); runner now reaps orphan emulators (process-group kill, `e10d98f`) |
| `corpus-a16` differential gate (+a16/+xy16 on both emus) | ✅ Standing capability + in CI |
| bsnes-jg `xcheck` in CI | ✅ Verified green (run 27823207476) |
| Native-mode crt0 (DBR=0 via `phk;plb`, explicit contract) | ✅ Done |
| Register-scavenger crash (`$p is not a GPR`) | ✅ **FIXED — patch `0011`** (2026-06-26, pristine-upstream). Route a live `$p` hard-stack-neutrally through a dead index reg into `RC17` for the unbalanced case + drop the stale `assertNZDeadAt`. `a16scavnz.c` promoted to a **positive gate** (`dev/run.sh a16scavnz` → `0x22A6`, both emulators, asserts-clean); `KNOWN_ISSUES["scavenger-p-not-gpr"]` dropped. Surfaced + fixed a 2nd upstream bug, **`LDCImm 1` → `MCInstLower` unreachable**, as patch `0012`. [investigation §RESOLUTION](investigations/65816-a16-scavenger-nz-liveness.md) · [plan](plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md) |
| `+mos-a16 -Os` RA failure (`globals.c`/`a16regpress.c`) | ✅ **FIXED — patch `0009`** (`ad506ed`, 2026-06-25). Orthogonal i8-loop-counter de-pin from `{A}` → `G_INC`/`G_DEC` in `selectAddSub` (**not** the Phase-3 residency rework; coalescing still ruled out); DEFAULT byte-identical, −123 B / 122 c-torture progs (0 worse). `KNOWN_ISSUES["regalloc-out-of-registers"]` dropped; `a16regpress.c` now a **positive gate** (`0x01A7`). [investigation §RESOLUTION](investigations/65816-a16-regalloc-pressure-failure.md) |
| KNOWN_ISSUES XFAIL handling — `evaluate()` classifies under `+mos-xy16` too + both-legs hardening | ✅ **Done (2026-06-21)** — a known `+mos-a16` issue can't mask a NEW `+mos-xy16` crash; both verify legs run; a new crash on either leg always hard-FAILs. [classify](plans/2026-06-21-321-xy16-verify-leg-classify-known.md) · [both-legs](plans/2026-06-21-321-xy16-verify-both-legs-hardening.md) |
| KNOWN_ISSUES XPASS guard — `dev/run.sh known-issues` (unconditional in CI) | ✅ **Done (2026-06-21)** — asserts the remaining XFAIL repro (`a16scavnz`) still crashes `-verify-machineinstrs` under both modes; fails loudly with "drop the entry + promote to a positive gate" the moment an upstream/RA fix lands. (It did exactly that for `a16regpress` → patch `0009`, now a positive gate.) [plan](plans/2026-06-21-321-known-issues-xpass-guard.md) |
| F4 `TXY`/`TYX` dead-flag fix (patch `0003`) | ✅ In fork; **upstream PR ready** (user-triggered to post) |

### Pending codegen (greenlit or in-progress)

With load-fold landed, the compare track closed, the **xy16 calling convention verified + formalized
(`ebedd1c`)**, **#320 far function pointers (a) fully done + landed (2026-06-21, `0001`+`0005`)**, and the
**#320 far-pointer calling convention landed (`0004`, Imag32 winner, 2026-06-21)**, the per-op a16 codegen,
the xy16 frontier, far fn pointers, and the far-ptr CC are all complete (see TL;DR). No remaining greenlit
codegen frontier on `main`; the five-address-space model PR is the open #320 thread (design-note-gated).

| Item | Status |
|---|---|
| Load-fold gate unification (AA-precision) — `noClobberBetween` | ✅ **Done 2026-06-20 (`6440db0`)** — AA-precise fold landed (−26 B, 0 regressions, verify-clean, 5 c-torture recovery sites 4-way PASS). The volatile-drop half measured net-negative (+17 B / 19 regressions) and is **closed**, not pursued |
| xy16 16-bit calling convention (X/Y across calls) | ✅ **Done 2026-06-21 (`ebedd1c`)** — verified (cross-call gate `xy16call`, 4-way) + formalized; correct by construction (cross-call index parks in callee-saved `Imag16`, never live in physical X16); 2 ABI levers measured + shelved. See XY16 table |
| #320 far-pointer calling convention (`p2` pass/return) | ✅ **DONE 2026-06-21** — all 4 variants measured; **Imag32 won**, landed as `0004` on `main` (round-trip-proven). See #320 table |
| #320 far function pointers (a) | ✅ **DONE + LANDED (2026-06-21)** — backend (mechanism + p2-value L1–L3, Gap A/B) + clang front-end (F2 `far`/`long_call` attribute, typed `far_fn_t` variable, `sizeof(far*)==4`) + a pre-existing `far_indir` crash fix; `far_fnptr`/`far_fnptr_var`/`far_sizeof` + whole far suite 4-way PASS; landed in `0001` (+ `0005` for the a16-context-entangled legalizer hunk). See #320 table |

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

Every item above ran to a clean conclusion — none was lost to a crash. The #320 far-pointer calling
convention (`0004`) and the far-fn-pointer (a) line are now **landed on `main`** (2026-06-21); the open
frontier is the #320 five-address-space model PR (design-note-gated), tracked in *What's next* and TODO.

---

## What's next (prioritized)

1. **#320 far-pointer calling convention** — ✅ **DONE + LANDED (2026-06-21)** (`wt/320-far-cc`): all 4 ABI
   variants built & two-emulator measured; variant (a) **Imag32 won** and shipped as **`0004`** on `main`
   (round-trip-proven); losers stayed a measured spike. Was the gate for far function pointers (a).
   [study plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md) ·
   [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md)

2. **#320 far function pointers (a)** — ✅ **DONE + LANDED (2026-06-21)**: backend (mechanism + p2-value
   L1–L3, Gap A/B) + clang front-end (F2 `far`/`long_call` attribute, typed `far_fn_t` variable,
   `sizeof(far*)==4`) + a pre-existing `far_indir` crash fix; `far_fnptr`/`far_fnptr_var`/`far_sizeof` +
   whole far suite 4-way PASS. **Landed on `main` in `0001`** (a16-free) **+ `0005`** (the a16-context-
   entangled `MOSLegalizerInfo` PF-as-value hunk); round-trip-proven. Also pushed `origin/wt/320-far-followups`.
   [plan](plans/2026-06-21-320-far-calls-followups.md) ·
   [typed-var](plans/2026-06-21-320-far-fnptr-typed-variable.md) ·
   [sizeof](plans/2026-06-21-320-far-pointer-sizeof.md)

3. **Upstream posts (user-triggered):**
   - F4 `TXY/TYX` dead-flag fix PR (ready)
   - Register-scavenger live-`$p` fix PR (`0011`, draft ready) + the `LDCImm` set-lowering fix PR (`0012`) it surfaced
   - #321 CC frame-ABI design note (draft ready)
   - #320 far-pointer design note (draft ready; unblocks the five-address-space PR)
   - DWARF step-6 test+docs PR (branch pushed)
   - #415 SNES target reconciliation (strategy drafted)

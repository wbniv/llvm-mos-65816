# llvm-mos-65816 — agent handoff: build/test mechanics & backend navigation

Verbose reference for doing codegen work on this repo. The high-level orientation, the `vendor/` model, the
three governing lessons, and commit discipline are in the auto-loaded project
[`CLAUDE.md`](../CLAUDE.md) — read that first; this file is the mechanics it points to. (Per-task specifics
live in `docs/plans/YYYY-MM-DD-<topic>.md`.)

**Preparing the upstream submission?** The reviewer-facing synthesis of the whole `0001`–`0009` patch stack —
per-patch *need / patch / proof*, the dependency + sequencing + timeline diagrams, and the testing / SNES /
dead-end appendices — is [`65816-patch-series-review-guide.md`](65816-patch-series-review-guide.md) (with an
[LLVM primer](llvm-primer-for-65816-review.md) for readers new to LLVM). It is the "how to review this" map;
this file remains the "how to build/test/navigate it" mechanics.

**Need the 65816 ISA itself** (registers, addressing modes, opcode matrix, cycle counts, native/emulation
mode, `rep`/`sep`, `M`/`X` semantics)? [`65816-references.md`](65816-references.md) collects the canonical,
freely-linkable sources — WDC's current W65C816S datasheet first — and records the **link-don't-vendor**
licensing rule (datasheets are third-party copyrighted; the release tarball stays Apache-2.0/LLVM clean).

## Active worktrees (2026-06-26)

> **CONSOLIDATION 2026-06-25 (user-directed "collapse worktrees, get things on main").** The standing
> "retain worktrees until upstream merge" policy was **explicitly overridden** for this pass. Landed to
> `main` and **torn down (local worktree + branch; `origin/wt/*` remotes kept)**:
> `wt/321-snes-hwref` (HAL split + ref docs), `wt/321-mandel-zoom` (zoom demo), `wt/321-a16-pressure`
> (patch **0009**, regalloc deadlock fix — re-verified: a16regpress + corpus-a16 globals.c now pass),
> `wt/321-trig` (far array-subscript fix folded into **0001** + libfixmath/HiROM corpus — re-verified:
> k_trig32 `0x068A6933`, k_trig32lut HiROM `0x87F0B404`, both emulators). Also torn down (already-merged
> or superseded): `wt/320-far-tailcall`, `wt/320-near-abs-bank-relax`, `wt/321-mandelbrot`,
> `wt/321-s32-verify`, `wt/321-track-a`, `wt/dp-arg-cc`, `wt/321-xy16`, `wt/320-far-cc`,
> `wt/320-far-followups` (its far-cc round-trip sources + `far_sizeof` gate salvaged to `main`),
> `wt/321-frame-abi` (NULL verdict; the inert `0002` frame-feature spike preserved as a docs/plans/spikes
> patch). The rows below mostly predate that consolidation: rows it lists as torn-down are gone, but
> rows still marked **Worktree RETAINED** remain **live**. New worktrees (post-consolidation) are
> registered at the top of the table.

| Branch | Worktree | Task | Status |
|--------|----------|------|--------|
| `wt/321-spirograph` | `/home/will/SRC/llvm-mos-65816-spirograph` | #11 **Spirograph (hypotrochoid) compiler-stress demo** ([plan](plans/2026-06-27-11-snes-spirograph-hypotrochoid.md)) | **✅ DONE + verified (2026-06-27).** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain via `cp -al`; no `vendor/` rebuild). Four curve families (hypo/epi/rose/Lissajous) bloom into a **NEAR 2bpp bitmap canvas** — new reusable `examples/snes/snesgfx/{bitmap_canvas.h` (set-pixel + Bresenham + capped dirty-tile DMA on BG3)`,text_layer.h` (BG3-cotenant tiled HUD, reuses `font8.h`)} — joypad-interactive with an on-screen `R/W/D/mode/petals` HUD. **No far pointers ⇒ full 5-way bar.** New `examples/65816/spiro.h` (shared curve math: sin/cos-LUT + 16×16→32 `__mulsi3` + gear-ratio `__udiv`), `examples/snes/spirograph.{c,h}`, `tools/spiro-sim.c`, `corpus/{spiro_sim.c` (0x32D4 curve math)`,spiro_ctrl_sim.c` (0x6A26 controller/HUD-format math, the deterministic-scripted equivalent of a JGX replay)}, `dev/spirograph.{sh,lua}`. **Verified:** `dev/run.sh corpus-a16` 9/9 (`host==default==+mos-a16==+mos-xy16` MAME+bsnes), `dev/run.sh spirograph` RESULT PASS (disasm gate `__mulsi3`+`__udiv`+`rep/sep`, bsnes 3× byte-identical, MAME+bsnes screenshots == host). SDK/example-level — no compiler change. **Worktree RETAINED** per policy; **publish to https://biohack.net/spirograph/ pending user OK.** |
| `wt/321-trig-phase3` | `/home/will/SRC/llvm-mos-65816-trig-phase2` (dir named `-trig-phase2`; repointed to the phase-3 branch) | #321 **trig compiler-test Phase 2 + Phase 3** — Q2.14 CORDIC: direct `sin/cos/atan/atan2`, derived `tan/asin/acos`, hyperbolic `sinh/cosh/tanh` ([Phase 2](plans/2026-06-26-trig-phase2-q214-cordic.md) · [Phase 3](plans/2026-06-26-trig-phase3-derived-hyperbolic.md)) | **✅ BOTH PHASES DONE + LANDED + PUSHED (2026-06-26).** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain via `cp -al`; no `vendor/` rebuild). **Phase 2** = `k_trig16` `0x9446C734` — a fresh Q2.14 CORDIC with **zero arithmetic libcalls** (native-s16 shift-add, the deliberate inverse of Phase 1's s32-libcall payload). **Phase 3** = `k_trig16x` `0x759567C4` — derived `tan/asin/acos` (a Q2.14 divide/sqrt → `__mulsi3`/`__divsi3` fire) + hyperbolic `sinh/cosh/tanh` via **CORDIC hyperbolic mode**; the 32-bit hyperbolic reference derives from the now-compiled `fix16_exp`. Both `host==default==+mos-a16` on **MAME + bsnes-jg** + host cross-width accuracy PASS (CORDIC beats libfixmath on `asin/acos`). New `examples/65816/{cordic16.h,cordic16_tables.h,k_trig16.c,k_trig16x.c}`, `tools/{gen-cordic-tables.py,trig-accuracy.c,trig-accuracy3.c}`, `dev/{k_trig16.sh,k_trig16x.sh}`. Merges `c37660f` (P2) + `4377791` (P3), pushed (`5a424df`). SDK/example-level — no compiler change. **Worktree RETAINED** per policy. |
| `wt/321-mandel-zoom` | (torn down) | #321 **Mandelbrot ZOOM PYRAMID** (shelved demo) ([plan](plans/2026-06-25-321-mandelbrot-zoom-pyramid.md)) | **🗑️ REMOVED from `main` 2026-06-26** (user request; worktree + branch already torn down — see consolidation note above). Deleted the demo, `tools/mandel-bake-pyramid.c`, `platforms/snes-zoom/`, the run scripts, `jgxcheck.cpp` `JGX_ZOOM`, and the orphaned `loopfold-*` discovery scripts. The DEFAULT-8bit matrix-fold miscompile it surfaced is **fixed** (patch `0010`; upstream repro is the self-contained `coalesce-rotate-ac.mir` lit test). Plan + screenshots kept as history. |
| `wt/321-mandelbrot` | `/home/will/SRC/llvm-mos-65816-mandelbrot` | #321 **beefy SNES Mandelbrot demo** — the first *beefy* `+mos-a16` customer ([plan](plans/2026-06-24-snes-mandelbrot-beefy-demo.md)) | **✅ DONE (2026-06-25), all on the branch — NOT yet merged to `main`.** Hardlink/non-compiler worktree (shares `main`'s prebuilt toolchain; SDK real-copied). A fixed-point Q5.10 Mandelbrot (`examples/65816/mandel.h`, shared by target + a host PNG renderer) driven through four green stages: **T1** differential gate `dev/run.sh k_mandel` (host==default==`+mos-a16`==`+mos-xy16`==`0x820B`, both emulators, `-verify` clean); **T2** on-console render `dev/run.sh mandel-shot` (fat-pixel Mode-1 BG; **real emulator screenshots from BOTH** — bsnes-jg framebuffer dump via `dev/jgxcheck.cpp`, MAME `video:snapshot` under Xvfb — on-screen CRC==host `0x9103`; `+mos-a16`==default pixel-identical); **T3a** `dev/run.sh mandel-far` (Mandelbrot far-stored into HIGH WRAM `$7E2000` via #320 `sta [dp]`, host==`+mos-a16`==`0x820B`); **T3b** `dev/run.sh mandel-mode7` (BIG 128×128 per-pixel via **Mode 7** + one 32 KiB **DMA**, screenshots both emulators, `0x75E8`). **Grew the SNES display HAL** (`platforms/snes/snes.h`: VRAM/BG/DMA/Mode-7 regs + `snes_ppu_reset_blank`), `tools/png_write.h`, `task mandel-mame` (host MAME window). **Docs:** rendering handoff [`handoffs/2026-06-24-snes-graphics-rendering.md`](handoffs/2026-06-24-snes-graphics-rendering.md), how-tos [`investigations/snes-emulator-screenshots.md`](investigations/snes-emulator-screenshots.md) · [`object-oriented-c-and-assembly.md`](investigations/object-oriented-c-and-assembly.md) · [`open-source-snes-libraries.md`](investigations/open-source-snes-libraries.md). Findings: `+mos-a16` is +21% bigger here (Lesson 2, multiply-bound); an all-inlined `+mos-a16` verifier crash (a16-regalloc family; shipped kernels use `noinline mandel_cell`). **Worktree RETAINED** (user policy); nothing on `main` yet — merge/push is user-triggered. |
| `wt/dp-arg-cc` | `/home/will/SRC/llvm-mos-65816-dp-arg-cc` | #561 DP-pointer-argument CC crash — the spike that turned the bug report into a fix | **✅ FIX DONE + upstreamed.** `addrspace(1)` (8-bit direct-page) pointer **argument** crashed the backend (CC gave it a 16-bit `RS` reg → illegal `(p1)=COPY $rs`). Fix = a `CCIfPtrAddrSpace<1, CCAssignToReg<[A, X, RC2..RC15]>>` rule (8-bit slot, mirrors the `0004` far rules + the i8 pool), placed before the generic `CCIfPtr`; covers returns too (no separate RetCC), varargs unaffected. Validated (incremental rebuild): crash gone across 5 DP-arg shapes on `mos6502`+`mosw65816`, correct codegen (`tax; lda 0,x` / store `sta 0,x`), **corpus 7/7**, new `llvm/test/CodeGen/MOS/dp-pointer-arg.ll` crashes pre-fix / passes post. **Fork patch `0008`** (`e0e8bd4`, applies on `0001`-`0007`). **Upstream [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563)** off clean `c798c3141` (`Fixes #561`, auto-closes on merge) — built via a `vendor/llvm-mos` `git worktree` at the pristine HEAD (network clone timed out). **RETAINED until merge**; on merge drop `0008` + bump the vendor pin. [issue body](320-upstream-dp-arg-cc-issue.md) · [PR body](320-upstream-dp-arg-cc-pr.md) · [plan §A](plans/2026-06-22-320-far-value-residuals.md). |
| `wt/320-far-followups` | `/home/will/SRC/llvm-mos-65816-far-followups` | #320 far-calls follow-ups — **combined plan+handoff: [plans/2026-06-21-320-far-calls-followups.md](plans/2026-06-21-320-far-calls-followups.md)** (read it to resume) | **(b) far→near DONE + SHIPPED to `main` (`5717f6b`)** — generic bank-0 thunk `__call_near_from_far`; verified `0xE0` MAME+bsnes-jg, corpus 7/7, gc'd from near ROMs. **(a) far fn pointers — BACKEND DONE + e2e VERIFIED both emulators (`579b911`, 2026-06-21):** the far indirect call works end-to-end on real silicon. Call MECHANISM `lowerCall(__call_indir_far)→JSL` + stub `jml (__mos_far_target)`; IR-rep #1. The deep p2-value `0004` sub-project is COMPLETE: ✅ L1 `copyCost` Imag32, ✅ L2 hint size-guard, ✅ **L3** (`selectUnMergeValues` byte→word subreg `sublo16/subhi16` for the `s32→2×s16` unmerge — the real crash; "SelectImm" framing was stale), ✅ **Gap A** (`&far_sym`→24-bit: `buildFarAddrWords` + `MO_ADDR24_*` → `#mos24bank`), ✅ **Gap B** (`G_STORE`/`G_LOAD p2`: list `PF` as a value type), ✅ **e2e** (`far_fnptr.c`+`.sh`: `far_leaf(0x5A)==0xFF` MAME+bsnes-jg, bank `$01`, a16-only like far_cast). Regression-clean (corpus 7/7, far_near_call+xcheck PASS). **✅ clang F2 DONE (2026-06-21):** the `far`/`long_call` MOS attribute (Attr.td `MOSFarCall` sharing `ParseKind="LongCall"` with `MipsLongCall`, interrupt-style) + a `CGExpr.cpp::EmitCall` intercept that rewrites a `far`-attributed call into the proven `store volatile ptrtoint(@__mos_far_<sym> AS2)`+`call @__call_indir_far` shape. `examples/65816/far_fnptr.c` rewritten to the **clean single-file `far` surface** (no asm/.set); `far_leaf(0x5A)==0xFF` MAME+bsnes-jg, corpus 7/7, csmith 36/40 0-mismatch, `-verify-machineinstrs` clean. **(a) is fully closed.** **✅ typed far-fn-ptr VARIABLE surface DONE (2026-06-21, [plan](plans/2026-06-21-320-far-fnptr-typed-variable.md)):** `far_fn_t fp = far_leaf; fp(0x5A)` — a `far` bit on `FunctionType::ExtInfo` (DeclOrTypeAttr riding the typedef) → `ptr addrspace(2)` via a ConvertType arm; decay materializes the p2 alias; indirect call ptrtoints the loaded fp. `far_fnptr_var.c` e2e `0xFF` both emulators, csmith 0-mismatch. **✅ `sizeof(far*)==4` DONE (2026-06-21, [plan](plans/2026-06-21-320-far-pointer-sizeof.md)):** `getPointerWidthV(AS2)`→32 + a `getTypeInfoImpl` arm for far *function* pointers → `sizeof(FAR*)==sizeof(far_fn_t)==4`; new `far_sizeof.c` (far ptr in a struct) `0xD1` both emulators. **Also fixed a PRE-EXISTING crash it surfaced** (root-caused via revert; independent of the sizeof change): `far_indir` SIGSEGV'd because `isFarSymbol` treated any `.far*`-sectioned symbol as far — restricted the `.far*` section check to **functions** (`isa<Function>`), so a `.far_rodata` datum taken as a near pointer stays 16-bit (far_indir now `0xF3` both emulators); far functions unaffected. Whole far suite (12 ROMs) + corpus 7/7 + csmith 0-mismatch green. **✅ ALL LANDED on `main` (2026-06-21):** the (a) work (backend + F2 + typed-var + sizeof + the `far_indir` fix) folded into `0001` (a16-free), `0004` landed verbatim, and the lone a16-context-entangled (a) hunk (`MOSLegalizerInfo` PF-as-value) split out to new **`0005-320-far-ptr-value-legalize.patch`** — round-trip-proven to reproduce this FF tree exactly over `clang/`+`MOS/`. (The `MOSInsertREPSEP.cpp` delta was FF *stale* vs main's current `0002`, not (a) work — excluded.) See [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md). Full state + recipes: the combined doc. |
| `wt/320-far-tailcall` | `/home/will/SRC/llvm-mos-65816-far-tailcall` | #320 **far tail calls** ([plan](plans/2026-06-22-320-far-tail-calls.md)) | **✅ DONE + verified both emulators (2026-06-22).** Compiler-changing worktree (own `vendor/` + `cp -a` warm `build/`). New **`TailJML`** pseudo (→ `JMP_AbsoluteLong` `$5C`, `R_MOS_ADDR24`) + a far arm in `MOSLateOptimization::tailJMP`: `JSL <direct far global>; RTL → TailJML`, gated `isGlobal && .far_` so near→far (`JSL;RTS`) + the bank-0 thunks (external/non-`.far_` symbols) are auto-excluded — conservative (a misclass only misses a win). Far→far tail folds **5 B→4 B** (`jsl`+`rtl`→one `$5C`). a16-independent → regenerated into the worktree's **`0001`** (round-trips `0001..0007`; `MOSLateOptimization.cpp` added to `regen-patch-0001.sh` `FAR_FILES`); **LANDED on `main` (`4adda8b`, pushed) + toolchain/SDK rebuilt + `far_tail`/corpus re-verified 2026-06-23**. **Verified:** `dev/run.sh far_tail` (new; `far_outer` single fold + `far_pick` two-block conditional, execution-discriminating `0xCB`) on **MAME + bsnes-jg**; negative gate in `far_near_call.sh` (thunk tail NOT converted); `+mos-a16` `-verify` clean; corpus 7/7; far suite (12 ROMs) green; csmith fuzz 50 0-mismatch (default+a16 inert). Design + impl each adversarially reviewed by a 3-agent workflow (all ship; one test-strengthening + one comment fix applied). **Worktree RETAINED until upstream merge** (user policy); durable artifacts on `main`. **DISK RECLAIMED 2026-06-23** (`rm -rf vendor/ build/` — ~12 G freed; 12 G→5.2 M); worktree dir + branch kept — to reactivate, `cp -a` `vendor/llvm-mos`+warm `build/` back per [howto §compiler-changing](howto-feature-worktree.md). |
| `wt/321-s32-verify` | `/home/will/SRC/llvm-mos-65816-s32-verify` | #321 **verify 32-bit `long`/`int32_t`** ([plan](plans/2026-06-23-321-32bit-long-verification.md)) | **✅ DONE + verified (2026-06-23).** Hardlink/non-compiler worktree (no `vendor/`, no rebuild) — verifies the *existing* s32 codegen (2×s16 + 4×s8↔s32 (un)merge + `__mulsi3`/`__udivsi3`/`__umodsi3`). **(1)** `examples/65816/a16s32.c` + `dev/run.sh a16s32`: folds every s32 hazard into a 32-bit `corpus_result`; full 4-way `host==default==+mos-a16==0x50F2B870` on **MAME + bsnes-jg** (4-byte read; `long` has a default leg). WANT = host-oracle of the identical `uint32_t` arithmetic (`-DHOST_ORACLE`) + runtime drift-guard. **(2)** `tools/a16_fuzz.py` `--s32` track: seeded op-list over 4 `uint32_t` regs interpreted by BOTH a C emitter and the exact Python oracle (lockstep); gated so `--s32` off is byte-identical (30/30); `dev/run.sh fuzz --gen builtin --s32` → **40/40, 0 mismatch**; `dev/fuzz.sh`/`dev/run.sh` plumbing (csmith rejects `--s32`). 2-agent workflow review → **ship** (lockstep checked over 200k randomized op-lists, 0 drift; UBSan-clean). **LANDED on `main` (`0efd62f`, pushed 2026-06-23).** **Worktree RETAINED until upstream merge; DISK RECLAIMED 2026-06-23** (`rm -rf vendor/ build/` — hardlink worktree, freed its dir entries; 646 M→5.2 M); to reactivate, `cp -al` the toolchain/SDK/bsnes-jg back per [howto §Steps](howto-feature-worktree.md). |
| `wt/320-far-cc` | `/home/will/SRC/llvm-mos-65816-far-cc` | #320 Inc 4 Ph2: far-pointer calling convention — build all 4 ABI variants (a Imag32 / b Imag16+bank / c A:X+Y / d hw-stack) & measure ([plan](plans/2026-06-20-320-far-pointer-cc-build-all-variants.md)) | **✅ DONE — `0004` LANDED on `main` (2026-06-21)** (round-trip-proven byte-identical to this worktree's `0004`). Compiler-changing worktree (own `vendor/` + warm-copied `build/`). All 4 ABI variants built + two-emulator measured; **variant (a) Imag32 won** and shipped as stacked **`0004-320-far-cc.patch`** (not `0001` — shares the `AnyRegBank`/`Ac16` line with `0002`); needed `Imag32` ∈ `AnyRegBank` (COPY-through class-constraint), round-trips `0xF3` MAME+bsnes-jg, default byte-identical, csmith 0-mismatch. The measure harness (`dev/farcc_*.sh`, `dev/measure-far-cc.sh`, `dev/probe-cycles.lua`) + the [measurement note](320-upstream-far-cc-measurement-note.md) landed too; losers stayed a measured spike. See [land plan](plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md). |
| `wt/321-track-a` | `/home/will/SRC/llvm-mos-65816-track-a` | #321 xy16 **Track A**: `requiredXWidth` 8-bit-indexed-family hardening ([plan](plans/2026-06-21-321-xy16-track-a-requiredxwidth-indexed-family-hardening.md)) | **✅ DONE — landed `46a39e6` on `main`** 2026-06-21. Compiler-changing worktree (own `vendor/` + warm-copied `build/`). The §3 memory-gated catch-all (`(mayLoad‖mayStore)&&reads X/Y→XW_X8`) **+** §3a index-reading-branch clause (closes the `JMP (abs,X)` `JMPIdxIndir` jump-table residual; user-confirmed in scope). **Verified:** default+a16 byte-identical 75/75 (gating) + xy16 byte-identical 75/75 + csmith 247/445 ROM-identical (inertness); corpus 7/7; xy16 suite + k_isort PASS; fuzz csmith 101–500 **0 mismatch/0 crash** (a seed-488 MAME timeout was QUIET-box contention vs `wt/320-far-cc`, re-verified PASS in isolation); **torture 60/0/0** (de-XFAIL'd rows stay XPASS); `-verify-machineinstrs` clean; `0002` round-trips, 0 foreign content. RED test not constructible (X8-pinned + LTO-narrows) → code-inspection hardening like `55ec505`. Landed in `0002`, **pushed to `origin/main`** (`d551f73`). **Worktree RETAINED — do NOT tear down until the #321/#320 work merges upstream** (user policy 2026-06-21; applies to all worktrees). Durable artifacts already on `main`, so removal loses nothing, but keep it until then. |
| `wt/321-frame-abi` | `/home/will/SRC/llvm-mos-65816-frame-abi` | frame-ABI head-to-head: (a) DP-window + (b) stack-relative vs (c) soft-static ([plan](plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md)) | **RESOLVED — CONFIRMED-shelved (NULL)** 2026-06-20: A0 census found 0/13 realistic fns profit (frames are ~unused; locals live in `__rc`). A1–M not built. Durable artifacts (`frameabi_*`) **MERGED to `main`** `f114c42`; CC note ready to post (user-triggered). **Branch RETAINED until notified** (holds the inert, un-landed (a)/(b) `0002` spike) — do NOT tear down. |
| `wt/321-cmpval` | `/home/will/SRC/llvm-mos-65816-cmpval` | #321 ordering-as-value branchless materialization — the 16-bit-`rol` form (candidate A) ([plan](plans/2026-06-21-321-ordering-value-branchless-banked.md)) | **RESOLVED — WON'T-DO (net-negative)** `74f04f4` 2026-06-21. Compiler-changing worktree (own `vendor/` + warm `build/`). Candidate A BUILT in full (`ROLAcc16` + `LDAImm16` + `G_CARRY_BOOL16` + `selectCarryBool16` + `legalizeZExt` rewrite; `lda #$0000; rol a` at M16). Correct + `-verify-machineinstrs` clean + DEFAULT byte-identical (gated), **wins in isolated leaves** (uge_v 25→23) **but REGRESSES every realistic a16 program** — a16cmpaudit **+654 B** (both-widths) / **+78 B** (s16-direct-gated), whole a16 corpus **+340 B, ZERO wins** (worse than the 8-bit v1's +262). Diamond is optimal (folds inversion free; M8 tail matches ambient mode; keeps the bool in `X`, not an `Imag16` ZP slot → no spill cascade). Both 8-bit (v1) AND 16-bit (candidate A) forms now closed; **no `0002` change ships** (docs-only close-out). **Worktree TORN DOWN 2026-06-21** (net-negative spike, nothing to merge); the candidate-A implementation is preserved as a durable patch `docs/plans/spikes/2026-06-21-321-ordering-value-candidate-a-spike.patch` (the base for the deferred mode-agnostic lever if ever revived). |
| `wt/320-five-space` | _(torn down 2026-06-21)_ | packed-24 (AS3) — the five-space size-opt space ([plan §Build packed-24](plans/2026-06-21-320-five-address-space-model.md)) | **Increment A DONE; Increment B deferred → worktree TORN DOWN** 2026-06-21 (12G reclaimed, `dev/worktree-teardown.sh`). **A (3-byte TYPE)** built+verified (`AS_FarPacked=3` + datalayout `p3:24:8` + clang `getPointerWidthV` case 3 → `sizeof(packed*)==3`, `table[16]==48 B`, **corpus 7/7**). **B (codegen to USE)** blocked-then-DONE — superseded by `wt/320-packed24-incB` below (Increment B built on post-F2 `main`). Durable artifacts on `main`: Increment A patch `docs/plans/spikes/2026-06-21-320-packed24-incrementA.patch`, fixtures `examples/65816/packed24/`. |
| `wt/320-packed24-incB` | _(torn down 2026-06-22)_ | #320 packed-24 (AS3) **Increment B** — codegen to store/load/deref a 3-byte packed far pointer ([handoff](plans/2026-06-21-320-packed24-incrementB-handoff.md) · [plan §Build packed-24](plans/2026-06-21-320-five-address-space-model.md)) | **✅ DONE + verified 2026-06-21** (compiler-changing worktree off post-F2 `main`; own `vendor/` + warm-copied `build/`). F2 precondition gate PASS first (`sizeof(far*)==4`; far store/load/array/struct legalize clean). **Increment B was NOT the predicted s24-narrowing job** — two findings: (1) `CodeGenPrepare::optimizeLoadExt` crashed on the invalid `MVT::i24` for a 24-bit pointer load → fixed by `getPointerTy(AS_FarPacked)→i32` (the packed ptr's register form IS the 32-bit far form; memory footprint stays 3 B via datalayout); (2) the artifact combiner doesn't look through `inttoptr/ptrtoint`, so route `p3↔3×s8` via `G_MERGE/G_UNMERGE{PFP,S8}` (no `s24`), which **folds** against the adjacent unmerge/merge in every shape clang emits (cast→store, load→cast, packed→packed copy) → no 24-bit value reaches selection. Shipped as stacked **`0006-320-packed24.patch`** (regen: `dev/regen-patch-0006.sh`; NOT folded into 0001 — packed-24 edits files 0004/0005 also touch). **Verified:** `dev/run.sh packed24` (new) `corpus_result=0xF3` on MAME **and** bsnes-jg — far ptr targets **bank $01**, so 0xF3 proves the bank byte survives 3-byte packing; `-verify-machineinstrs` clean; **corpus 7/7**; far suite (bank1/cast/arith/store/call) PASS; `fuzz 50` 0-mismatch; storage **48 B vs 64 B (−16 B/−25%)** for a 16-entry table, ×3 index cost. New e2e `examples/65816/packed24/packed24_e2e.c` + `dev/packed24.sh`, wired into `dev/xcheck.sh`. **Follow-on static-init fix LANDED `a76bf18` (2026-06-22):** static-initialized far-ptr **TABLES** now link (per-entry `R_MOS_ADDR24_SEGMENT_LO/HI`+`_BANK` triple via a `MOSAsmPrinter` retag, not a single `R_MOS_ADDR8`) — `dev/run.sh packed24_table` `0xA5` both emulators, packed 24 B vs far 32 B; + `dev/measure-packed24.sh` (Task A: packed wins, break-even N≥1). **Worktree TORN DOWN 2026-06-22** (`dev/worktree-teardown.sh`, 12G reclaimed; all durable artifacts on `main` — `0006`, the fixtures, the regen/measure scripts). (`far_near_call` failed to *link* here — `__call_near_from_far` lives in the SNES platform lib the warm SDK predated; pre-existing stale-artifact, unrelated — moot now.) |
| `wt/320-near-abs-bank-relax` | `/home/will/SRC/llvm-mos-65816-near-abs` | #320 packed-24 productionization **Task B** → a **general 65816 near-abs fix** + the `regen-patch-0001.sh` tooling refresh ([plan](plans/2026-06-22-65816-near-abs-bank-relax.md); origin = [productionization handoff](plans/2026-06-21-320-packed24-productionization-handoff.md)) | **✅ DONE + LANDED/pushed to `origin/main` (2026-06-22).** Compiler worktree (own `vendor/` + `cp -a` warm `build/`). **`0007-65816-near-abs-bank-relax.patch`** (`ff02726`): `MOSAsmBackend::fixupNeedsRelaxationAdvanced` no longer bank-relaxes (abs→long) a **NEAR** (non-`.far`) symbol — every plain-symbol **A-register** near-global access was bloating to 4-byte absolute-LONG (`8f`/`af`/`6f`…, `R_MOS_ADDR24`); X/Y escaped (no long form) and lld doesn't shrink it, so it reached the **linked ROM** (~284 sites in the a16 examples; −1 B each). Gated on the `.far*` section (far stays long); rests on the same **DBR=0** invariant the STX/STY near abs-stores already need → a misclassification can only miss the win, never emit a wrong-bank access. Task B of the productionization handoff (Task A = the *other agent's* `0006` static-init reloc fix; Task C skipped — AS2 has no `__far`/typedef spelling to mirror). **Also landed:** `dev/regen-patch-0001.sh` fixed for the **7-patch stack** (recon+verify now apply full `0001..0007`; `FAR_FILES` = all **25** files `0001` touches, clang+llvm; round-trips the committed `0001` byte-for-byte) (`d5c5946`); the 6 a16 disasm gates made relaxation-form-tolerant (`Xf`→`X[df]`). **Verified:** full `0001–0007` **combined-stack** gate green on **both emulators** — corpus 7/7, packed24 `0xF3`, packed24_table static-init (packed 24 B vs far 32 B) `0xA5`, far suite (7), the 6 a16 gates end-to-end, csmith 50/1 0-mismatch (plan §5). **Worktree RETAINED until upstream merge** (user policy); durable artifacts all on `main`, so removal loses nothing. |
| `wt/321-csmith` | `/home/will/SRC/llvm-mos-65816-csmith` | Csmith differential fuzzer — Phases 0–5 DONE (s32 fixed; sampled CI wired `e865dff`) | ~~**MERGED** `dd5616b` → main 2026-06-19~~. **Consolidated reference** (mechanism + state + open follow-ups + the WDC816CC/Plum Hall motivation): [`investigations/csmith-differential-harness.md`](investigations/csmith-differential-harness.md). |
| `wt/321-xy16` | `/home/will/SRC/llvm-mos-65816-xy16` | xy16 index-register-mode implementation (Layers 1–5) | ~~**MERGED** `35604c7` → main 2026-06-18~~. ~~**OPEN:** Csmith seeds 247+445 `+mos-xy16`-only runtime miscompiles~~ **✅ RESOLVED `2d8ab51` (2026-06-20, on `main`).** cvise-reduced to an 8-line repro + root-caused: a non-index 16-bit value classed `Xc16` was loaded into X16 and left live across an 8-bit-index op whose narrowing `sep` zeroes the X/Y high byte. Fixed via **approach B** (`selectXY16`'s `G_LOAD16_ABS` emits the direct `LDXAbs16`/`LDYAbs16` only when the value is genuinely used as an index; else lowers through the accumulator). Verified 4-way both emulators + csmith 101–500 (0 mismatch/400) + c-torture 60/60; a16/DEFAULT byte-identical (gated). Arc + refuted A′/#2: [investigation](investigations/65816-xy16-index16-highbyte-clobber.md) · [plan](plans/2026-06-20-321-xy16-seed445-cvise-reduction.md). (Separate latent **Track A** `requiredXWidth` hardening remains a follow-up.) |
| `main` | `/home/will/SRC/llvm-mos-65816` | seed-42 regression: `legalizeICmp` EQ-swap leaked into non-a16 path | ~~DONE~~ `51a5bae` |
| `main` | `/home/will/SRC/llvm-mos-65816` | indir-dst copy fold (`*p = gg`): corpus trigger check | ~~CLOSED WON'T-DO~~ — 0/6 progs, 0 B, `f52d5b8` |

## Build / compile / disasm / test — the exact commands

- **Rebuild the toolchain after a `vendor/` edit** (Docker container; incremental): `dev/run.sh toolchain`.
  **Do not** start a second concurrent toolchain build (it clobbers `build/llvm-mos`). **GOTCHA:**
  `build/llvm-mos-install/bin/clang` is a symlink with a *stale mtime*; the real binary is **`clang-23`**.
  Confirm a rebuild took by checking `clang-23`'s mtime advanced (or `nm` it for a new symbol) — a stale
  build silently serving old codegen has burned this project before.
- **Compile + MIR-verify on the host** (no container needed; `mos-clang` is the built compiler):
  ```
  build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-a16 -Os -mllvm -verify-machineinstrs -c FILE.c -o /tmp/x.o
  ```
  Use the `-Xclang -target-feature -Xclang +mos-a16` form (the driver rejects `-mattr`). Clean exit = OK.
- **Disasm / size:** `build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mosw65816 /tmp/x.o`;
  `… --section-headers /tmp/x.o` → per-function `.text.<name>` byte size. In an unlinked `.o`, zero-page
  operands all print as `$0` (relocation placeholders) — for symbolic operand names compile to assembly
  (`-S`).
- **MIR:** add `-mllvm -print-after=legalizer` / `-print-before=legalizer` / `-print-after-all` (to stderr).
- **Emulator / differential tests** (Docker; **run on a QUIET box** — concurrent docker/MAME load flakes
  MAME's settle window → false failures that pass on re-run): `dev/run.sh <name>`. The a16 suite:
  `for f in dev/a16*.sh dev/k_*.sh; do dev/run.sh "$(basename "$f" .sh)"; done`. Corpus:
  `dev/run.sh corpus` (expect `7/7`). Differential fuzzer: `dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]`
  (**Csmith is now the default**; builtin selectable via `--gen builtin`). With Csmith: expect `0 mismatch,
  0 crash` — a handful of seeds legitimately SKIP (Csmith `main` diverges before `corpus_result` is set,
  so `--gc-sections` drops it). Example: `dev/run.sh fuzz 50 1` → `~46 PASS, 0 xfail, ~4 skip (0 mismatch)`
  on seeds 1–50. Builtin (all 4-way oracle): `dev/run.sh fuzz --gen builtin 50 1` (expect `50/50, 0 mismatch`).
  **Full harness reference** (mechanism, oracle soundness, CI, open follow-ups, and the WDC816CC/Plum Hall
  motivation): [`investigations/csmith-differential-harness.md`](investigations/csmith-differential-harness.md).
  - **The "QUIET box" rule is a MAME/fuzzer rule, not a bsnes-jg one.** The **bsnes-jg leg** (`build/jgxcheck`)
    is *deterministic* — fixed frame count + direct WRAM read, no Lua bridge / settle window — so its
    verdict is load-insensitive (and it needs no SPC700 BIOS). A **bsnes-jg-only** confirmation of the
    second oracle can therefore run on a contended box; run it **serial** (one core) to stay a light
    neighbor to any concurrent MAME. Today the jgxcheck leg only runs *after* MAME inside each
    `dev/a16*.sh`; the planned MAME-skipping `JG_ONLY` guard + `dev/run.sh xcheck-suite` makes the
    second-emulator-only pass a first-class target —
    [plan](plans/2026-06-19-second-emulator-jg-only-confirmation.md).
- **Running `dev/run.sh` from a feature worktree** (the Docker run mounts a single root, so the `CLAUDE.md`
  env-override trick is host-side only): hardlink the prebuilt `build/` in with `cp -al` — full procedure in
  [`howto-feature-worktree.md`](howto-feature-worktree.md).
- **External C suite (gcc c-torture):** host prereq `dev/fetch-torture.sh` (pinned gcc-14.2.0,
  sha256-verified → gitignored `vendor/c-torture/`) + `python3 tools/torture_filter.py` (host-only
  compile/link filter → `examples/65816/torture/{inscope,unsupported}.tsv`, **1288/1779 in-scope** (the
  full suite as of the 2026-06-26 vendoring: top-level + `ieee/` 60 in-scope + `builtins/` 55 as the
  `builtins-multifile` bucket); `mos-clang` runs **directly on the host**, no Docker). Then the emulator differential gate:
  `dev/run.sh torture [N] [--opt -Os|-O1] [--start K] [--sample N [--sample-seed S]] [--no-bsnes]`
  (`tools/torture_run.py`; `--sample N` = a seeded pseudo-random subset of N tests, reproducible — the
  sampled-CI selector) — DEFAULT build is the oracle, so a non-PASS default ⇒ **SKIP** and any FAIL is a real defect; known a16 crashes
  (incl. `a16-zp-pressure-overflow`) ⇒ XFAIL. The earlier 17 a16/xy16 runtime miscompiles are all FIXED
  (frame-index `f2d65c2`, `requiredXWidth` `55ec505`, load-fold-across-call `86c2602`); the **full ieee/
  vendoring (2026-06-26) surfaced one NEW `+mos-xy16` defect** — the fp **compare-as-select** ("cmove")
  miscompile, `xfails.tsv` rows `ieee/fp-cmp-8.c` + `fp-cmp-8l.c` + `pr38016.c` (same body, one root cause;
  root-cause+fix is a follow-up). A new FAIL outside those rows is a regression.
  [plan](plans/2026-06-19-321-c-torture-execute-differential-suite.md).
- **xy16 codegen gotcha — LTO narrows small index loads to 8-bit.** The 16-bit-index pseudos
  (`LDAbsXIdx16`/`LDIndirYIdx16`) only survive to the linked ROM when the index is *genuinely* 16-bit-wide
  (e.g. `pr49419`'s `t[x]` double-indirect computed chase). A simple `arr[volatile_short_idx]` legalizes to
  `G_LOAD_ABS_IDX16` per-function (so `xy16ops`/`xy16indiry` PASS, non-LTO `-c`) but **under `--config` LTO it
  narrows back to 8-bit X** when the value provably fits — a valid optimization. Consequence: you can't
  reproduce an X=16-ambient bug with a minimal global-array test through the (LTO) differential harness;
  reach for a computed-index chase or use the c-torture rows.
- Long ops: background them and monitor; don't block on `sleep`.
- **CI** (`.github/workflows/smoke.yml`, `workflow_dispatch`-only): **four jobs.** `smoke` boots the corpus
  in MAME; `xcheck` builds the from-source toolchain (cached) + SDK, then `dev/run.sh xcheck` (bsnes-jg) and
  the secret-gated `dev/run.sh corpus-a16`. **`torture` + `fuzz-csmith`** (added 2026-06-21, `e865dff`) run
  the #321 c-torture (Phase 3) + Csmith (Phase 5) differential fuzzers — both `needs: xcheck` (reuse its
  cached toolchain) and run the same **4-way** gate (host==default==a16==xy16 on MAME + a16 on bsnes-jg).
  `torture` runs in-container (fetches the suite, seeded `--sample`); `fuzz-csmith` runs **host-side** (installs
  MAME, builds `vendor/csmith`, host `MOS_TOOLCHAIN`). A `workflow_dispatch` **`mode`** input picks `sampled`
  (default; seeded subset) or `full` (whole c-torture suite + csmith 1..500); **`sample_seed`** makes the
  subset reproducible. A commented `schedule:` block (auto-selects `full`) is ready for when public. All
  secret-gated (skip — don't fail — without the SPC700 BIOS). Dispatch: `gh workflow run snes-smoke`
  (`-f mode=full` for the whole sweep). **Monitor a run with `task ci-watch` / `dev/ci-watch.sh
  [RUN_ID|--once]`** — streams step transitions + a heartbeat + the final verdict and exits with the run's
  conclusion (background it; GitHub exposes in-progress step *logs* only in the web UI, so ci-watch tracks
  structure, not log text). The `smoke`/`xcheck` legs are proven green: run 27823207476 (2026-06-19, cold
  ~1h46m; cached thereafter); `torture`/`fuzz-csmith` are locally green (sampled 4-way), on-runner dispatch
  pending.

## The correctness gate + micro-test pattern

The bar is the **differential**: host-computed == default(non-`+mos-a16`)@MAME == `+mos-a16`@MAME ==
`+mos-a16`@bsnes-jg, plus `-verify-machineinstrs` clean. New value-level behavior gets a
`examples/65816/a16<name>.c` + `dev/a16<name>.sh` micro-test (pattern: a `corpus_result` the test asserts
across host/default/a16 on both emulators, often with a disasm gate, e.g. native `cmp` present and no 8-bit
`cpx/cpy`), wired into `dev/run.sh`, and is exercised by the fuzzer (`tools/a16_fuzz.py`). Use
`examples/65816/a16eqval*.c` + `dev/a16eqval*.sh` as templates. Close the script with
`emu_verdict "$rc" "<pass detail incl. an emulator-agreement clause>"` (from `dev/_emu.sh`), **not** a
hand-rolled `echo "RESULT: …"` — the helper prints `RESULT: FAIL`/`PASS` and, under `JG_ONLY`
(`dev/run.sh xcheck-suite`, the bsnes-jg-only pass), rewrites the "both emulators" claim so a MAME-skipped
run stays honest.

**Gating discipline — the fuzzer guards the DEFAULT build too.** Every `+mos-a16` change must be gated so it
*cannot* alter non-`+mos-a16` codegen — and that includes **operand canonicalizations / helper predicates**,
not just instruction defs and selection. A green a16 suite is **not** sufficient: the differential fuzzer
compiles each program *both* default and `+mos-a16` and compares to the host oracle, so an a16 helper that
leaks into the 8-bit path surfaces as a `default@MAME ≠ host` mismatch. Concrete bite (seed-42, fixed in
`0002` 2026-06-18): an EQ-only operand swap in `legalizeICmp` was guarded by a predicate that did **not**
check `hasAccum16` (nor `Pred==EQ`), so a non-EQ `<`/`>` compare in the *default* build hit
`std::swap(LHS, RHS)` and reversed the comparison →
[plan](plans/2026-06-18-321-seed42-legalizeicmp-swap-fix.md). Gate on the **same predicate that enables the
feature behavior** (e.g. `NativeS16Eq` = `hasAccum16 && Type==S16 && Pred==ICMP_EQ`), not a looser
operand-shape test.

**Attributing a fuzzer/regression finding to a patch (or single hunk) — isolated-worktree + ccache
bisection.** When a differential mismatch must be pinned to a specific patch/hunk and MIR diffing is
inconclusive (state-sensitive bug, byte-identical post-legalize IR), bisect with *builds*: spin a detached
worktree of `vendor/llvm-mos` at pristine upstream (`git -C vendor/llvm-mos worktree add --detach <dir>
<HEAD-sha>`), `git apply` a chosen *subset* of `patches/llvm-mos/*.patch` hunks (filter a patch to specific
files/hunks with `awk` on the `diff --git` / `@@` headers; revert one with `git apply -R`), build into a
**separate** `build/` dir with `CCACHE_DIR=$PWD/build/.ccache` reused (each incremental rebuild is minutes,
not the 30–90 min cold build — LLVM TUs hit ccache, only the changed MOS target recompiles + relinks), and
run the one-program differential (`dev/run.sh fuzz 1 <seed>`) on each. The unpatched `/opt/llvm-mos` in the
dev container is the correct-value oracle. **Never** build a subset into the shared `build/llvm-mos` (it
clobbers the toolchain other agents use). Trust the build result over any plausible mechanism — two
"obvious" causes (a concurrent edit; the register topology) were each refuted this way before the real
one-line cause was found.

## Measurement methodology (size/speed claims)

- Compare **native-`+mos-a16` vs 8-bit-`+mos-a16` on the *same* C shape** — toggle only the feature gate.
  Never compare `+mos-a16` vs non-`+mos-a16` (that conflates the value's ALU/load codegen with the change
  under study). Often the *current* `+mos-a16` output already IS the 8-bit baseline for the shape (the gate
  doesn't fire yet) — capture it, make the change, rebuild, diff.
- Decide on **bytes** (the `-Os` target), cycles as tiebreaker; report both. Hand-count 65816 cycles if
  needed (DP=0 assumption; the *delta* is usually insensitive to the DP penalty).
- **Addressing/DBR contract (don't over-generalize the `inc abs` note).** Near data is bank-0 low WRAM
  ($0200–$1FFF). The **8-bit `abs` path is DBR-relative** (`R_MOS_ADDR16`, reads `DBR:addr`); the **native-16
  `long` path is DBR-independent** (`R_MOS_ADDR24`). So data access is a *mix*, not uniformly
  DBR-independent. The crt0 establishes **DBR=0 explicitly** (`phk; plb` in `.init.50`) so the 8-bit `abs`
  globals + MMIO writes land in bank 0; gate `dev/run.sh crt0native`. See
  [native-mode-crt0-xy16 plan](plans/2026-06-18-321-native-mode-crt0-xy16.md). Full power-on→`main()`
  walkthrough: [snes-bootup-sequence](snes-bootup-sequence.md).
- **Measure in realistic 16-bit-ambient context, not just isolated leaf functions.** A leaf function pins
  the ambient accumulator mode at 8-bit and over-charges `rep`/`sep` to the op under study; real `+mos-a16`
  code holds `M=0` across sustained compute. (This regime difference has flipped measured conclusions
  here.)

## Navigating the backend (grep — don't trust line numbers; `vendor/` is multi-agent)

Line numbers drift because `vendor/` is edited by multiple agents — **grep for symbol/string anchors.**
Under `vendor/llvm-mos/llvm/lib/Target/MOS/`:

- `MOSLegalizerInfo.cpp` — GISel legalization: `legalizeICmp`, `legalizeAddSub`, `legalizeLoadStore16`, the
  `+mos-a16` gates (e.g. `NativeS16Eq`); also the `hasAccum16()`-gated s32↔s16 rules
  (`G_ANYEXT`/`G_TRUNC`/`G_MERGE_VALUES`/`G_UNMERGE_VALUES`) so `+mos-a16` handles `int32_t`/`long`. **Wide
  scalars under a16 narrow to s16 (not s8), so s32 is 2×s16** — new wide merge/unmerge shapes need rules:
  the direct **4×s8→s32 `G_MERGE_VALUES`** is custom-legalized (`legalizeMergeS32FromBytes`) into the legal
  2-level form (`merge→s16 ×2, then →s32`) because `selectMergeValues` only takes a 2-source merge. The
  symmetric s32→4×s8 unmerge is still `unsupported` (no seed hit it yet). *Gotcha:* a whole-module frozen
  `.ll` is a poor regression fixture for these — it over-triggers by compiling runtime fns (`__adddf3`, s64)
  with `+mos-a16`, which the real link doesn't; use the deterministic Csmith seed as the gate instead.
- `MOSInstructionSelector.cpp` — selection: `select*`, the `m_CmpNZ*` / `CmpNZ*_match` matchers, operand-fold
  helpers (`getImm16Operand`, `foldableAbsLoad16`/`foldableIndirLoad16`). **A16 load-fold helpers MUST guard
  against intervening clobbers:** folding a load into a later ALU/compare operand re-reads memory at the
  *user's* point, so `noStoreBetween(Def,User)` bails if any `mayStore`/`isCall` sits between (else a load
  folded across a call reads the mutated value — the pr34768 miscompile). Upstream 8-bit folds use
  `shouldFoldMemAccess` (AA-precise) for this, but it bails on *volatile* loads which the #321 corpus folds
  single-use; `noStoreBetween` is the volatile-tolerant tailoring. Any new a16 fold helper must replicate it.
  **Upcoming — Phase 2 greenlit 2026-06-20:** the split will be unified in `canFoldLoadIntoUser(Dst,Src,AA)`:
  volatile-bail becomes a single-use clamp; `foldableAbsLoad16`/`foldableIndirLoad16`/`noStoreBetween` are
  deleted. Phase-1 instrument-and-count found 43 volatile-recovery sites + 7 AA-precision sites across 2615
  compiles. Until landed: "any new fold helper" still means `noStoreBetween` + single-use.
  [plan](plans/2026-06-20-321-unify-loadfold-gate-aa-volatile.md).
- `MOSInstrPseudos.td` + `MOSInstrInfo.cpp` — pseudos: `CmpBrImag16` (Imag16-resident LHS),
  `CmpBrImm16` (const RHS), `CmpBrAbsAbs16` (both-global), `CmpBrAbsImm16` (global LHS + const RHS),
  `CmpBrImagAbs16` (computed LHS + global RHS); + their post-RA expansion (`expandCmpBr16`).
- `MOSInsertREPSEP.cpp` — M-flag (accumulator 8/16) **and** X-flag (xy16 index 8/16) mode tracking across
  blocks (parallel lattices + the `rep`/`sep` placement). `requiredXWidth(MI)` is the per-instruction
  index-width classifier — it must return `XW_X8` for every op that reads/writes an index reg (X/Y) at
  8-bit intent (loads/stores/transfers/push-pull **and** the value ops: compares `CMPImm`/`CMPImag8`/
  `CMPAbs` and register `INC`/`DEC` of X/Y) so they don't run in a stray X=16 ambient. Adding a new
  8-bit index op? Add it here. Whole file is `hasAccum16()`-gated; X-lattice work is `HasIndex16`-gated.
- `MOSLateOptimization.cpp` — post-RA peephole: `threadAccum16` eliminates redundant `STAImag16 R;
  LDAImag16 R` round-trips between dependent native-s16 ops (A16-threading Phases 0–1–1.5 done).
- `MOSRegisterInfo.td` — register classes: `GPR` = {A,X,Y}, `Ac16` = {A16}, `Imag8`/`Imag16` = the
  zero-page imaginary registers (`$rc*` / `$rs*`).

Harness/tests: `examples/65816/`, `dev/run.sh` + `dev/*.sh`, `tools/a16_fuzz.py`.

# TODO

llvm-mos-65816 = bringing an optimizing open-source C compiler to the WDC 65816 via
[llvm-mos](https://github.com/llvm-mos/llvm-mos), plus the SNES platform to exercise it.
See [docs/ROADMAP.md](docs/ROADMAP.md) for the M0 → M1 → M2 plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for upstream status and rationale.
Background: [docs/investigations/llvm-overview.md](docs/investigations/llvm-overview.md)
(what LLVM is, and where llvm-mos fits). Every plan under `docs/plans/` is catalogued in
[docs/investigations/plan-index.md](docs/investigations/plan-index.md) — a one-row-per-plan
table-of-contents (summary · commits · category), sorted oldest → newest.

**Status markers:** `[ ]` open · `[wip]` in progress · `[verify]` implemented, verification
not yet run+recorded (run the linked plan's verification steps, paste raw output + PASS/FAIL
back into the plan, then promote to `[x]`) · `[x]` done (moved to Done, one tight line).
Plan-first: non-trivial work gets a `docs/plans/YYYY-MM-DD-<topic>.md` and a TODO entry.


## Open

### M0 — Test Bench

_M0 complete — test bench stands (ROADMAP steps 1–2 PASS). See Done._

### M1 — Far Pointers (first real codegen)

- [ ] **#320 far-pointer DATA-VALUE type — BUILT BY THE F2 AGENT (verified 2026-06-21); residuals only.**
  The desirable work the five-space census surfaced (store/load/array/struct a far pointer + `sizeof==4`)
  was **built by the far-fn-ptr agent**, not just unblocked. Verified by compiling
  `examples/65816/far-value-evidence/` against their toolchain (`wt/320-far-followups`, clang-23 @
  2026-06-21 19:36): under `+mos-a16`, `s1`–`s4` (store/load/array/struct), `z1` (`sizeof==4`), and `c1`
  (far→near) **all OK** (vs all-FAIL on `main`). `getPointerWidthV` gained `case 2: return 32`; `PF` is a
  storable value type (s32 merge → bytes). **Done, not ours to re-implement.** Caveat: it's in
  `wt/320-far-followups` (pushed `origin/`), **LANDED on `main` 2026-06-21** (was `wt/320-far-followups`-only): the
  far-value implementation now ships in `0001` + `0004` + `0005`; the full five-space *upstream PR* stays
  ABI-blessing-gated (tracked in [upstream-contribution-status](docs/upstream-contribution-status.md)). **Residuals (both close-out, no fork patch — [plan](docs/plans/2026-06-22-320-far-value-residuals.md)):** (a) **"`dp→near` cast" =
  pre-existing UPSTREAM bug, now root-caused (2026-06-22) as a DP-pointer-ARGUMENT crash** — *any* use of an
  `addrspace(1)` (8-bit DP) pointer arg fails on plain `mos6502` (the CC passes it in a 16-bit `RS` reg →
  illegal `(p1)=COPY $rs`, "Copy Instruction illegal with mismatching sizes"; asserts-aborts at
  `MOSRegisterInfo.cpp:1146`, SIGSEGVs in `MOSLateOptimization` w/o `-verify`). Stock `p1:8:8` (our `0001`
  only adds `p2:32:8`) ⇒ **upstream issue to draft** (user-triggered post), not a fork fix; (b) far-ptr
  storage under **default 8-bit** is un-legalized — **CLOSED 2026-06-22: a16-gated by design.** A far ptr is
  a 32-bit value; its `s32↔bytes` bridge (`G_MERGE/G_UNMERGE {S32,S8}`) is fully `hasAccum16`-gated
  (MOSLegalizerInfo.cpp:152-169, `unsupported()` else). Under 8-bit, storage fails as a **clean Legalizer
  `unable to legalize` rejection — no object, no miscompile** (verified all four s1-s4 fixtures, no `-verify`),
  unlike the (a) crash. Verdict is `0005`-invariant; no 8-bit-only use case (far ⇒ banking ⇒ 65816 ⇒ a16).
  No fork fix. Evidence: `dev/measure-far-ptr-value-state.sh`.
  [plan §Re-evaluation](docs/plans/2026-06-21-320-five-address-space-model.md) ·
  [F2 hand-off](docs/plans/2026-06-21-320-far-calls-followups.md).
- [ ] **#320 five-address-space model — Phase 0+3 DONE; new spaces (AS3 packed-24, AS4 zero-bank) DEFERRED
  (premature, not nulls).** asiekierka's #320 proposal is 5 spaces (`0`=far-default/`1`=DP/`2`=16-abs/
  `3`=packed-24/`4`=zero-bank); we ship 3 additive (`0`=near-default/`1`=DP/`2`=32-bit far). **Two hard
  constraints:** (C1) one MOS datalayout shared with the 6502 ⇒ `0`=far-default is **architecturally
  foreclosed** (would break every 6502 pointer); "far by default" can only be a clang memory-model flag.
  (C2) `addrspace(2)`=far is load-bearing tree-wide ⇒ keep additive numbers, defer any rename to upstream.
  **Phase 0 (`dev/measure-five-space-census.sh`):** ~~0a representability~~ **GO** — 24-bit IS representable
  (the note's "LLVM needs pow2 pointer sizes" is **WRONG**: `parseSize` has no pow2 rule, `getPointerSize`=3
  bytes; backend carries `_BitInt(24)`). The real far reason is `MVT` has no `i24` (plumbing, not an IR
  limit). **0b/Phase 3:** packed-24 would size-optimize *storing a far pointer*, but **storing far pointers
  doesn't work at all yet** → packed-24 optimizes a non-existent capability ⇒ **DEFER** behind the
  far-pointer-value-completion item above (NOT a null — the capability is wanted; the byte-packing is the
  premature part). Zero-bank ≈ a near pointer ⇒ marginal. **Update 2026-06-21 (user said build it):**
  measured the win = **25% storage** on far-ptr tables (16: 64→48 B) **but a ×3-index cost** (3-byte
  elements) — opt-in so it never regresses non-users. **Increment A DONE + verified** (the 3-byte TYPE:
  `AS_FarPacked=3` + datalayout `p3:24:8` + clang width; `sizeof(packed*)==3`, table 48 B, **corpus 7/7**).
  **Increment B (codegen to store/load/deref packed ptrs) DONE + verified 2026-06-21** on
  `wt/320-packed24-incB` (off post-F2 `main`) — NOT the predicted s24-narrowing job: (1) `getPointerTy(
  AS_FarPacked)→i32` to stop `CodeGenPrepare` crashing on the invalid `MVT::i24`; (2) bridge `p3↔3×s8`
  via `G_MERGE/G_UNMERGE{PFP,S8}` (no `s24`, no `inttoptr` roundtrip — the artifact combiner folds the
  bridge against the adjacent unmerge/merge). Shipped as stacked **`0006-320-packed24.patch`** (regen
  `dev/regen-patch-0006.sh`; not folded into 0001 — touches files 0004/0005 share). **Verified:**
  `dev/run.sh packed24` (new e2e, bank $01) `0xF3` MAME **and** bsnes-jg (bank byte survives 3-byte
  packing); `-verify-machineinstrs` clean; corpus 7/7; far suite PASS; `fuzz 50` 0-mismatch; storage
  −16 B/−25% (16-entry table 64→48 B), ×3 index cost. Worktree torn down (`f168003`); work landed on `main`.
  **Productionization batch — (A) DONE + static-init reloc FIXED (2026-06-22)**
  ([handoff](docs/plans/2026-06-21-320-packed24-productionization-handoff.md) ·
  [fix plan](docs/plans/2026-06-22-320-packed24-static-init-reloc-fix.md)): ~~(A) measure the win in realistic
  context~~ **DONE** (`dev/run.sh measure-packed24`): packed wins **≈N bytes at every N, break-even N≥1** —
  the indexed-walk access code is equal (far loads only 3 of its 4 entry bytes; ×3-vs-×4 stride is a
  constant), so the feared ×3-index/byte-2 cost does **not** apply to indexed table access. Task A also
  surfaced that a **statically-initialized packed table didn't link** (each 3-byte entry emitted one
  `R_MOS_ADDR8` — no 3-byte data fixup); **FIXED** via an `AsmPrinter::emitNonStandardSizedConstant` hook +
  MOS override emitting the `ADDR24 SEGMENT_LO/HI/BANK` triple (landed in the updated **`0006`**; new
  `dev/run.sh packed24_table` `0xA5` MAME+bsnes-jg, corpus 7/7, fuzz 0-mismatch). **Productionization thread
  CLOSED (2026-06-22)** ([close-out](docs/plans/2026-06-22-320-packed24-residuals-close.md)): ~~(B) byte-2
  absolute-long cost~~ **= `0007`** — the cost is general, not packed-specific (only the A-register byte 2
  bloated; STX/STY have no long form), so it was built as the near-abs bank-relaxation `0007` (`8f/af→8d/ad`
  for ALL near pointers; its plan is literally "the realization of Task B", −2 B on packed byte-2, verified
  `0001–0007` both emulators); a packed-local fix would duplicate `0007`'s DBR logic ⇒ **don't**. ~~(C)
  `__far_packed` spelling~~ **closed** — precondition unmet (no AS2 spelling exists to mirror; far/dp/packed
  are all per-file local `#define`s), so it's the forbidden one-off; revive only via a shared `<mos.h>`
  covering all spaces (SDK concern). Worktree `wt/320-packed24-incB` torn down (`f168003`, 12 G reclaimed).
  Separate threads: zero-bank (AS4) **CONFIRMED measured-null** (2026-06-22, model complete); ~~fold `0007`
  onto `main`'s stack~~ **DONE** (merged 2026-06-22 — stack is now `0001`–`0007`, toolchain rebuilt + verified);
  post the upstream note (C1 + pow2 + census) — user-triggered.
  [incB handoff](docs/plans/2026-06-21-320-packed24-incrementB-handoff.md) ·
  [plan §Build packed-24](docs/plans/2026-06-21-320-five-address-space-model.md).
- [ ] **#320 post design note upstream** (user-triggered). Post the drafted note
  ([docs/320-upstream-far-pointer-note.md](docs/320-upstream-far-pointer-note.md)) to #320 / the
  llvm-mos Discord (@asiekierka/@mysterymath) — bring a running implementation, not a question.
  Note is drafted & ready; posting is the manual step. **Now also carries a "Code model: near vs far"
  section** (2026-06-22): near=`small`/default, far=`medium/large`/per-symbol → no `-mcmodel` mode; the
  SNES near-code budget is a link-time contract enforced in the SDK platform (see Done [snes-near-code-budget]).
### M2 — Optimizing Payoff

- [x] ~~**`dev/regen-patch-0004.sh` delta-based redesign**~~ — **DONE 2026-06-25.** The old
  "baseline = every patch EXCEPT 0004" approach was structurally broken by `0008` (mos-dp-arg-cc, authored
  on `0004`'s far-CC table → won't `git apply` onto a 0004-less baseline). Rewrote on the `regen-patch-0001.sh`
  delta method: reconstruct the full `0001..0009` stack, capture new far-CC edits as a delta, re-derive `0004`
  by applying the committed `0004` + delta onto a minimal `0001+0002+0003` baseline (so `0005..0009`'s shared-file
  hunks never leak in and `0008` is never applied onto a 0004-less tree). Round-trips clean: `RESULT: PASS —
  reapplied 0001..0009 == live vendor MOS dir` (regenerated `0004` differs from the committed one only by the
  git index-hash header, now reflecting the current baseline).
- [x] ~~**Rebuild main's toolchain to make the consolidation codegen live**~~ — **DONE 2026-06-25.** main's
  `vendor/llvm-mos` was reconciled to committed `0001..0009`, then `dev/run.sh toolchain` + SDK rebuilt
  (`snes-hirom`/`snes-zoom` platforms). Gates GREEN on the rebuilt compiler, both emulators: `corpus` 7/7,
  `a16regpress` `0x01A7` + `corpus-a16` 6/6 (`0009` live), `k_trig32lut` `0x87F0B404` (far-subscript fix live —
  200 KiB HiROM far LUT, index ≥ 32768), far suite `0xF3`. main is now consistent: patches == vendor == built toolchain.
- [x] **#321 beefy SNES demo — fixed-point Mandelbrot, differentially verified + rendered on both emulators. DONE 2026-06-25.**
  First *beefy* `+mos-a16` customer. Branch `wt/321-mandelbrot`.
  **Track 1 DONE+green** (`dev/run.sh k_mandel`): Q5.10 escape-time kernel (`examples/65816/mandel.h`) compiled
  by both the SNES target and a host PNG renderer; CRC16 of a 16×10 gate slice → `corpus_result`, asserting
  host(`0x820B`)==default==`+mos-a16`==`+mos-xy16` on MAME+bsnes-jg, `-verify` clean. Found: `+mos-a16` is
  +21% *bigger* (Lesson 2 — multiply-bound) and an all-inlined-form `+mos-a16` verifier crash (a16-regalloc
  pressure family; shipped kernel uses `noinline mandel_cell`). **Track 2 DONE+green** (`dev/run.sh
  mandel-shot`): renders ON the SNES (`examples/snes/mandel-display.c`, +mos-a16, fat-pixel Mode-1 BG) and
  captures a **real emulator screenshot from BOTH** cores headless — bsnes-jg framebuffer dump + MAME
  `video:snapshot` under Xvfb — each asserting on-screen CRC==host (`0x9103`); `+mos-a16`==default
  pixel-for-pixel. Grew the SNES display HAL (`platforms/snes/snes.h`: VRAM/DMA/BG regs + `snes_ppu_reset_blank`),
  shared PNG encoder (`tools/png_write.h`), how-to
  [docs/investigations/snes-emulator-screenshots.md](docs/investigations/snes-emulator-screenshots.md).
  **Track 3a DONE+green** (`dev/run.sh mandel-far`): Mandelbrot far-stored into HIGH WRAM (`$7E2000`, reachable
  only by 24-bit addressing) via #320 far stores (`sta [dp]`) + far-load CRC; +mos-a16-only, host==+mos-a16
  (`0x820B`) on both emulators + disasm gate (`examples/65816/k_mandel_far.c`). **Track 3b DONE+green**
  (`dev/run.sh mandel-mode7`): a BIG 128×128 per-pixel Mandelbrot far-stored to high WRAM, displayed via **Mode 7**
  (linear 8bpp, 256 tiles), uploaded by one **32 KiB DMA**, 2× zoom; screenshots MAME + bsnes-jg, on-screen
  CRC==host (`0x75E8`). Grew the HAL with Mode 7 + DMA regs; rendering **handoff for the next agent**:
  [docs/handoffs/2026-06-24-snes-graphics-rendering.md](docs/handoffs/2026-06-24-snes-graphics-rendering.md).
  [plan](docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md).

- [x] **#321 native s16 — 16-bit comparison follow-ups — DONE 2026-06-21, track CLOSED.** ([plan](docs/plans/2026-06-21-321-native-s16-comparison-followups.md)) Compare surface measured ~complete (`dev/measure-compare-surface.sh`): everything native except the optimal byte-wise register-resident equality. The one open lever — the **ordering-as-value branchless carry-tail** (`zext(sbc-carry)`→`G_UADDE(0,0,carry)` in `legalizeZExt`) — was **BUILT + measured net-negative in realistic context** (correct + leaf-win real `uge_v` 25→19 + default byte-identical 75/75, but the 8-bit `adc` tail's `sep` breaks 16-bit runs: a16cmpaudit **+262 B** rep/sep-churn + `eor` inversions; c-torture 56 progs net≈0 **with** a +5 B regression) → **WON'T-DO** (the select-diamond is the ambient-16-bit optimum; clean gating infeasible — the cost is ambient-mode-dependent, invisible at legalize time). Classic lesson #1 leaf→ambient flip; spike on `wt/321-cmpval` (un-landed). **The mode-matched 16-bit-`rol` follow-up form (separate [banked plan §0a](docs/plans/2026-06-21-321-ordering-value-branchless-banked.md) — a real `ROLAcc16`/`LDAImm16`/`G_CARRY_BOOL16` materialization, `lda #$0000; rol a` at M16) was ALSO BUILT + measured 2026-06-21 → REGRESSES HARDER than v1: a16cmpaudit +654 B (both-widths) / +78 B (s16-direct-gated), whole a16 corpus +340 B with ZERO programs improving → WON'T-DO. Both 8-bit AND 16-bit forms closed: the select-diamond folds inversion free, its M8 tail matches ambient mode, and it keeps the boolean in `X` (not an `Imag16` ZP slot that cascades to spills). Deferred lever = mode-agnostic post-REPSEP pseudo (uncertain/partial upside, delicate REPSEP work — not pursued).** (unsigned ordering, ~~(a) equality `== !=`~~,
  and ~~(b) signed `slt/sle/sgt/sge`~~ all landed — see Done). Remaining: (c) **equality as a value**
  (`b = (a == c)`): the `+mos-a16` prologue **regression** is FIXED 2026-06-16 (an s16 load consumed
  only by `G_UNMERGE` now loads byte-wise instead of a wasteful 16-bit-load→`A16`→spill→re-read —
  `legalizeLoadStore16`; brings EQ-as-value to parity with default — see Done). The **full native
  compare** (one `rep; lda; cmp; sep` + materialize Z→0/1, beating default) is **WON'T-IMPLEMENT** (both
  materializations measured 2026-06-18: Option A reuse-ops **+14 B**, Option B explicit branchless `rol`/`adc`
  tail **+16…+28 B** — worse, because branchless forgoes the `CmpBr` compare-fusion the diamond exploits, and
  equality's Z isn't rotatable so the value must be formed first; the select-diamond is near-optimal; see the
  [full-native materialize plan §Phase 0](docs/plans/2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md)
  + [Option B proof](docs/plans/2026-06-18-prove-option-b-rol-tail-materialization-for-native.md)); ~~(d) fold a near-abs global RHS into `CMPAbs16`~~ (landed — see Done; also
  folds the LHS via `lda abs`). **Tier-1 fuzzer finding F3 (the `SelectImm $a16` crash on a 16-bit-
  accumulator value spilled across a call) is FIXED** for BOTH stacks: static (2026-06-16, direct
  `STAbs16`/`LDAbs16`; `examples/65816/a16spill.c`) and soft/reentrant (2026-06-16, 16-bit indirect
  `STAIndir16`/`LDAIndir16` in `expandLDSTStk`; `examples/65816/a16spillr.c`). It was an
  `Ac16`-spill register-allocator bug — NOT this comparison/legalizer item (the legalizer-gate guess was
  tried and reverted). See Done.
  [F3 plan](docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md) ·
  [plan](docs/plans/2026-06-14-321-native-16bit-compares.md) ·
  [equality plan](docs/plans/2026-06-15-321-native-16bit-equality-compares.md) ·
  [signed plan](docs/plans/2026-06-15-321-native-16bit-signed-compares.md) ·
  [compare-operand-fold plan](docs/plans/2026-06-15-321-native-16bit-compare-abs-operand-fold.md) ·
  [full-native materialize plan](docs/plans/2026-06-18-321-native-s16-eq-as-value-full-native-materialize.md) ·
  [Option B rol-tail proof](docs/plans/2026-06-18-prove-option-b-rol-tail-materialization-for-native.md).
- [ ] **#321 soft-stack (reentrant) spill coverage — close the gap the F3 fix exposed.** The F3 `Ac16`
  spill fix landed on **both** stacks, but the soft-stack half was found only by a hand-written recursive
  reproducer — the **fuzzer never reaches it**: `gen_funcs` emits only leaf functions (`expr(pure=True)`
  excludes the `call` leaf), so the call graph is acyclic → `MOSNonReentrant` marks every function
  `nonreentrant` → all get static frames. ~~P0: teach `tools/a16_fuzz.py` to emit a **recursive** function
  (the proven soft-stack trigger) so `expandLDSTStk` spills of `Ac16`/`Imag16`/8-bit get value-level
  differential coverage (host==default==a16, both emulators).~~ **P0 VERIFIED 2026-06-18** (`RecFuncDef`;
  `fuzz 50 1` + `fuzz 50 56`: 15/50 PASS each, `+mos-a16` correct all 100 seeds; soft-stack `sta ($0),y`
  confirmed in seed-2 `f0`; 35/50 `xy16@MAME=0x0000` are pre-existing xy16 hang bugs, not a16 regressions;
  two new `+mos-xy16` compiler bugs found+fixed: `selectXY16` unclassed-s16 guard + `copyPhysRegImpl`
  Xc16/Yc16↔Imag16 cases; also found+fixed upstream F4, patch `0003`). ~~P1: document the `expandLDSTStk` spill
  contract at the `MOSRegisterInfo.cpp:528` assert (every spillable ≥16-bit class needs an explicit case
  — `xy16` index-16 is the latent next one).~~ **P1 DONE 2026-06-17** (SPILL CONTRACT comment at the
  `expandLDSTStk` tail assert + the static-path mirror in `MOSInstrInfo::loadStoreRegStackSlot`;
  comment-only, `0002` round-trips). ~~P2: add a hermetic `.ll` crash-regression for the soft-stack
  `Ac16` spill.~~ **P2 DONE 2026-06-17** — `examples/65816/a16spillir.ll` (frozen IR of `a16spillr.c`) +
  `dev/a16spillir.sh`: an `llc` gate (verify-clean + `STStk/LDStk $a16` present), drift-immune companion
  to `a16spillr.c`; test-only, no vendor change
  ([P2 plan](docs/plans/2026-06-17-p2-hermetic-ll-crash-regression-for-the-soft-stack.md)).
  P3 (optional, upstream, not #321): `__attribute__((reentrant))` can't force the soft
  stack — ~~file an issue~~ **issue DRAFTED + source-verified
  ([docs/321-upstream-reentrant-soft-stack-issue.md](docs/321-upstream-reentrant-soft-stack-issue.md));
  filing is user-triggered**. [plan](docs/plans/2026-06-16-321-soft-stack-spill-coverage.md).
- [ ] **#321 native s16 — agreed optimization order (after load-fold).** ~~(2) 16-bit compares/branches~~
  (slice 1, unsigned ordering — done); ~~(3) inc/dec + 16-bit shifts~~ (constant shifts incl. signed
  `>>`/ASHR done — see Done; ~~1-byte `inc a`/`dec a`~~ done — see Done [register + global `g±1` via
  `lda; inc/dec a; sta`]; remaining: ~~variable shifts~~ [**WON'T DO** — task7 spike 2026-06-17: inline counted loop costs more bytes than `__ashlhi3`/`__lsrhi3` libcall at −Os], amount ≥8 [byte-relabel
  already optimal]; ~~memory-RMW `inc abs`/`dec abs`~~ investigated + rejected — no `inc long` on the
  65816 and `inc abs` is DBR-relative, unsafe vs the platform's long (DBR-independent) data addressing;
  see Done); ~~(4) indexed/array access~~ (indirect `(zp)` load/store done; ~~`abs,x`/`(zp),y` 16-bit
  indexed load/store~~ done — `a16absidx` + `a16indiry` PASS both emus; X-flag dimension NOT needed —
  llvm-mos is pointer-based; [plan](docs/plans/2026-06-18-321-abs-x-indiry-16bit-indexed-load-store.md)); (5) A16-threading (value stays
  live in the accumulator across ops — biggest win but reintroduces the coalescer-crash risk, so
  deferred behind a broad corpus — **the corpus now exists: Tier 1 landed 2026-06-16 (differential
  fuzzer + 6 kernels + 2 combinatorial tests; it already found+fixed 2 backend bugs), so this is
  de-risked and unblocked**); ~~(6) cross-block REP/SEP mode-tracking~~ (M-flag done — see Done;
  X-flag is a separate dimension); (7) hardware-stack ABI / 16-bit calling convention (upstream-gated).
  ROADMAP step 5 frontier.
  [1d-retry plan](docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md).
- [ ] **#321 A16-threading — keep the running s16 value live in the accumulator across ops** (item (5)
  above; the ROADMAP-step-5 "biggest win", de-risked now the Tier-1 corpus exists). **Phases 0–1 + 1.5
  DONE (2026-06-17 — see Done):** the redundant `STAImag16 R; LDAImag16 R` round-trip between dependent
  native s16 ops is eliminated by a coalescer-safe post-RA peephole (`threadAccum16` in
  `MOSLateOptimization`) — adjacent in Phase 1, non-adjacent (incl. across volatile stores + multi-reload)
  in Phase 1.5 — so the value threads through `A16` across the chain (`lda;adc;and;sbc;…;sta`). Measured
  −31/−36 % on dependent chains, −4..−10 B on real kernels; a corrected 300-program scan shows the true
  non-adjacent remainder is **1**. **Phase 2 retired:** fold-while-threaded is **already optimal** (interior
  immediates *and* near-abs globals fold into the threaded chain today — existing selection folds compose
  with the peephole). **Remaining — (3) the genuine hard core, DEFERRED:** RA-level `Ac16` residency. The
  actual lever is **pre-RA `Ac16` residency** (thread the single-use producer's `Ac16` vreg into the
  consumer at `selectAlu16Native`, collapsing the `INF` single-instruction transits that exhaust the
  allocator); the `shouldCoalesce` 8-bit↔`Ac16` barrier (the `$a16 = LDImm` 1d crash) is a **safety
  companion, NOT the fix** — the asserts root-cause (`50a59b5`) **ruled coalescing out** as the
  `a16regpress.c` crash cause. Realizable gain is capped by the single 65816 accumulator (two live 16-bit
  values must spill to `Imag16`) and it reopens the coalescer-crash risk → high-risk/low-reward, so
  **keep the XFAIL** with a concrete re-open trigger + a gated B0→B1→B2 spike recipe (see Watch + the plan).
  **↔ Shared core (native-s16 surface close-out):** a *single* deferred frontier — RA-level 16-bit-value
  residency under register pressure (A16-threading Phase 3 ≡ ALU-chain >14-live ≡ the `pr15296` ZP-overflow).
  **Two crashes once lumped into this core left it with orthogonal targeted fixes:** the
  `globals.c`/`a16regpress.c` `-Os` RA-**crash** (de-pin the i8 loop counter from `{A}` → `G_INC`/`G_DEC`)
  — **FIXED, patch `0009`** (`ad506ed`, 2026-06-25) — and the `+mos-a16`/`+mos-xy16` **scavenger-N/Z crash**
  (route a live `$p` through a dead index reg into `RC17`) — **FIXED, patch `0011`** (2026-06-26; + `0012`
  for a `LDCImm` MC-lowering bug it surfaced); both are now positive gates. The rest stays behind **one**
  re-open trigger (a 2nd independent *realistic* `regalloc-out-of-registers` / `a16-zp-pressure-overflow`,
  **or** a real fn crossing ~10/14 `Imag16` pairs) → **one** gated B0→B1→B2 spike.
  [close-out](docs/plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md).
  [plan](docs/plans/2026-06-17-321-a16-threading.md) ·
  [Phase-3 deferral formalization](docs/plans/2026-06-20-321-a16-threading-phase-3-formalize-the-deferral-r.md).
- [ ] **#321 16-bit ALU chain extensions** (extends Inc 1c, which fused add-chains only). Done:
  ~~the multi-use add chain~~ (`add_chain16_ld`), ~~immediates *within* add chains~~ (`a+b+c+K` → final
  `adc #imm`), and ~~AND/OR/XOR chains~~ (`bit_chain16`/`_ld`, no carry-init) — see Done. SUB chains are
  **moot** (the optimizer reassociates `a-b-c` to `a-(b+c)`, not a homogeneous chain). Remaining —
  **multi-value register pressure: CHARACTERIZED (measured 2026-06-18); the premise is largely already
  solved.** There are ~14 16-bit slots (the `Imag16` pool), not one: 2–9 live s16 values already compile to
  one `rep`/`sep` bracket with the 2nd value folded as a memory operand (`and/adc __rcN`), −58..−65 % vs
  default, and correct (verify-clean, no crash) even at pool exhaustion. The lone genuine residual — M=16
  fragmenting into many `rep`/`sep` brackets when a spill is emitted byte-wise-in-8-bit under **>14 live
  s16** (pool exhaustion) — is **pathological-only**. **Phase 0 scan RAN 2026-06-18
  (`dev/measure-zp-pressure.sh`): 0 of 13 real functions exhaust the pool (max ~5 of 14 pairs) → DEFER
  confirmed with data** (the scan also surfaced a separate `+mos-a16 -Os` RA *crash* on `globals.c` — see
  its own bullet above).
  **↔ Shared core (native-s16 surface close-out):** a *single* deferred frontier — RA-level 16-bit-value
  residency under register pressure (A16-threading Phase 3 ≡ ALU-chain >14-live ≡ the `pr15296` ZP-overflow).
  **Two crashes once lumped into this core left it with orthogonal targeted fixes:** the
  `globals.c`/`a16regpress.c` `-Os` RA-**crash** (de-pin the i8 loop counter from `{A}` → `G_INC`/`G_DEC`)
  — **FIXED, patch `0009`** (`ad506ed`, 2026-06-25) — and the `+mos-a16`/`+mos-xy16` **scavenger-N/Z crash**
  (route a live `$p` through a dead index reg into `RC17`) — **FIXED, patch `0011`** (2026-06-26; + `0012`
  for a `LDCImm` MC-lowering bug it surfaced); both are now positive gates. The rest stays behind **one**
  re-open trigger (a 2nd independent *realistic* `regalloc-out-of-registers` / `a16-zp-pressure-overflow`,
  **or** a real fn crossing ~10/14 `Imag16` pairs) → **one** gated B0→B1→B2 spike.
  [close-out](docs/plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md).
  [multi-value pressure plan](docs/plans/2026-06-18-321-16bit-alu-multivalue-register-pressure.md) ·
  [1c plan](docs/plans/2026-06-14-321-increment-1c-chained-16bit-alu.md) ·
  [add-chain-immediate plan](docs/plans/2026-06-15-321-native-s16-add-chain-immediate.md) ·
  [bitwise-chains plan](docs/plans/2026-06-15-321-native-s16-bitwise-chains.md).
- [ ] **#321 stage 1 — full xy16 mode + ABI** (after Increment 1): ~~X/Y permanently 16-bit~~
  ~~REP/SEP mode-tracking across control flow + churn minimization~~ (M-flag done — see Done; the
  ~~X-flag is a separate mode dimension still to add to the dataflow~~ **X-flag lattice DONE 2026-06-18**
  — Layers 1–5 committed to `wt/321-xy16`: feature flag + Xc16/Yc16 regs + pseudos + parallel
  X-lattice in `MOSInsertREPSEP` + static/soft-stack spills + `selectXY16` skeleton; all compile
  clean, `xy16spill` PASS); 16-bit arithmetic; ~~native-mode crt0~~ (entry + 16-bit SP + native
  vectors already present; explicit DBR=0 is the one real gap — dedicated item below); then
  hardware-stack ABI + calling convention. ROADMAP step 5.
  **Legalizer integration DONE** (B1 `allUsesAreXY16Compatible` load→`Xc16` constraint + B2 16-bit-index
  `abs,X16`/`(zp),Y16` widening via `Use16BitIdx`; `selectXY16` C1 direct + C2 indexed handlers all wired).
  Both B2 sub-paths now gated: `abs,X16` by `xy16ops`, `(zp),Y16` by **`xy16indiry`** (added 2026-06-19 —
  the path was wired-but-untested; gate PASSES, no bug; [plan](docs/plans/2026-06-19-321-xy16-indiry-gate.md)).
  **Remaining follow-ons: hardware-stack ABI + calling convention** (gated on the CC decision). (Native-mode
  crt0 needed no change for in-function xy16; its lone gap — explicit DBR=0 — is the dedicated item below.)
  [xy16 plan](docs/plans/2026-06-17-321-xy16-index-register-mode.md) · [handoff](docs/plans/2026-06-18-321-xy16-implementation-handoff.md).
- [ ] **#321 calling-convention — frame decision RESOLVED (phased) 2026-06-18; remaining work deferred/gated.**
  [CC decision analysis](docs/investigations/65816-calling-convention-decision.md) ·
  [decision record](docs/plans/2026-06-18-321-cc-frame-phased-decision.md). The "one decision" decomposes
  into 4 sub-decisions, now all dispositioned: ~~return~~ (A low / X high — **LOCKED 2026-06-17**,
  `dev/run.sh a16ret`, codegen unchanged; see Done); ~~args~~ (**keep imaginary-register** passing — adopted
  for the first pass); ~~recursion~~ (the already-hardened soft static stack); and the ~~hard **frame** fork~~
  (**RESOLVED phased 2026-06-18**: the first pass keeps the soft static stack; the **TCD DP-window** is
  deferred behind a ZP-pressure measurement; pure stack-relative is ruled out as dominated). Never blocked
  xy16 + native-mode crt0. **Remaining:** (1) ~~the ZP-pressure measurement~~ **RAN 2026-06-18**
  (`dev/measure-zp-pressure.sh`, `9fc5cf2`): the ZP is **slack** (real code max ~5 of 14 pairs) → the
  **DP-window (a) is shelved with evidence**, not built (revisit only if future code nears the ceiling); (2)
  upstream posture — post the prior-art note + a first-pass CC to #321 (user-triggered; see Upstream section).
  [A/X-return plan](docs/plans/2026-06-17-321-ax-return-convention.md) ·
  [prior-art note](docs/320-321-65816-c-abi-prior-art.md).
- [ ] **#321 frame-ABI head-to-head — RESOLVED 2026-06-20: CONFIRMED-shelved (NULL), measured.** Revived the
  (a)/(b) frame fork the ZP-pressure proxy had shelved on paper, on a `wt/321-frame-abi` feature worktree.
  **P0** (`c2eaf61`): off-by-default `+mos-dp-frame`/`+mos-sr-frame` features + `frameStrategy()` plumbing,
  byte-identical-default proven (24/24). **A0** (`a73c564`): the DP↔`__rc` collision (SNES linker pins
  `__rc*` at ZP `$00–$1F`; 65816 ZP addressing is `D`-relative) is **avoidable** — a DP-window at `D=$1000`
  read the `__rc16` cell via absolute correctly, `corpus_result==0xBBAA` on MAME+bsnes (`frameabi_a0.c`/`.sh`).
  But the **A0 census** (`9617b0f`, `dev/frameabi-census.sh`) short-circuited the build: **0/13 realistic
  corpus+kernel functions can profit** — locals are register-resident in `__rc` and local aggregates go
  through a pointer in `__rc`, so frame/spill traffic is ~0 and there is **nothing for any frame ABI to
  optimize**; only contrived volatile/const-shuffle shapes profit (`frameabi_heavy.c`). So A1–A4/B/M were
  **not built** (would only confirm the measured NULL). A *stronger* result than the proxy shelving — the
  opportunity itself was measured empty. ~~Durable artifacts merged to `main`~~ (`f114c42`:
  `frameabi_a0.c`/`.sh`, `frameabi_heavy.c`, `frameabi-census.sh`, `frameabi-byte-identical.sh`). **Remaining:**
  (1) the `wt/321-frame-abi` branch is **retained until notified** (user, 2026-06-20) — holds the inert,
  un-landed (a)/(b) `0002` spike; tear down only when told; (2) post the prepared #321 CC design note
  (user-triggered — see Upstream / Contribution + [note](docs/321-upstream-cc-frame-abi-note.md)).
  [plan](docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).
- [ ] **#3 SNES Blossom on-screen interactive port — the graphical payoff demo (Phase 1 kernel DONE).**
  Phase 1 (`k_hopalong.c`, the Q8.8 Hopalong/Blossom attractor math) is landed + 4-way verified (see
  Done). Remaining = render it natively + make it interactive. **Graphics is greenfield** (the repo's
  only on-screen code is `hello.c`'s green backdrop): Mode 7 chunky 8bpp framebuffer (identity
  tilemap; per-pixel = high-byte VRAM write), a 64 KB hit-count **shadow buffer in WRAM bank `$7E`**
  via runtime far pointer (the `+mos-a16` far path, cf. `examples/65816/far_indir.c`), VBlank DMA of
  recolored bands shadow→VRAM, 256-color CGRAM palette + palette-cycling — this **pulls forward the
  deferred Phase-2 graphics layer** (add VRAM `$2115–$2119`, Mode-7 matrix `$211A–$2120`, DMA `$420B`/
  `$4300–$430A` regs to `platforms/snes/snes.h` + a small reusable gfx helper). Then joypad controls
  (random a/b/c, switch palette/formula/color-mode, auto-scale). Optional perf: SNES hw multiplier
  (`$4202/$4203→$4216`) for the hot `b*x`. [plan](docs/plans/2026-06-24-blossom-snes.md).
- [x] ~~**#321 Mandelbrot zoom pyramid** — BUILT (Phases 1+2, branch `wt/321-mandel-zoom`) then **SHELVED as a
  demo** (user call, 2026-06-25): as a *display* it's a flashy slideshow, not a smooth zoom — a full-screen
  128×128 chr swap (16 KiB) can't fit one vblank so each level boundary force-blanks (flashes), and *between*
  swaps it's just Mode-7 magnify like the interactive demo; as a `+mos-a16` codegen customer it's redundant
  (same `view.h` matrix math). Branch kept (unmerged) as the live repro for the bug below. KEEPERS landed on
  `main`: the MAME key-remap + the compiler-bug finding.~~ [plan](docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md)
- [x] ~~**MAME key remap for the SNES demos** (`dev/mame-snes-input.cfg`)~~ — binds each SNES button to its
  matching keyboard letter (R→SNES R, Y→Y, A→A, L→L, S→Select, Enter→Start) so the demo labels just work;
  MAME's defaults are non-obvious (SNES R = keyboard X, Y = Left-Ctrl, A = Space). `task mandel-mame` drops it
  in. (Fixes the "Y/A/R don't work" report — it was the key map, not the ROM; verified by injecting the field.)
- [x] ~~**DEFAULT-8bit 65816 matrix-fold-LOOP miscompile → coalescer fix**~~ — **FIXED 2026-06-26.** A CRC fold over `int16_t m[4]` miscompiled vs the unrolled form (default-8bit; `0xE60E`≠`0xF56C`). cvise→43-line repro, then an instruction-level bsnes-core trace falsified the "wrong-X" lead and pinned it to the **register coalescer** merging two rotate-referenced values into the A-only `Ac` class (strands a loop-carried CRC byte in `Y`; back-edge `ROL` reads stale `A`). Fix in `MOSRegisterInfo::shouldCoalesce` (generic default-8bit → **upstream**), fork patch `0010-coalesce-rotate-ac.patch` + LLVM lit test. Repro fixed, corpus 7/7, torture 30/30, csmith 54/60 (0 mismatch). Upstream PR queued ([`upstream-coalesce-rotate-ac-pr.md`](docs/upstream-coalesce-rotate-ac-pr.md)). [plan](docs/plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md) · [investigation](docs/investigations/2026-06-25-default8-65816-loopfold-miscompile.md).

- [x] ~~**SNES hardware reference docs + subsystem-split `snes.h` + generators**~~ — **LANDED on `main`**
  2026-06-25 (consolidation). The umbrella `snes.h` re-exports every prior symbol (`VMAIN_INC_LOW_1`,
  `snes_read_pad1`, `snes_wait_vblank` carried into the split headers); compile-verified.
  Durable reference set produced *from source*: (1) subsystem-split HAL headers
  (`platforms/snes/snes_{ppu,dma,cpu,apu,wram,joypad}.h`) under a thin umbrella `snes.h`, annotated with
  `@reg`/`@bit`; (2) a **complete CPU-visible MMIO register map** generated from those headers
  (`tools/gen-snes-regmap.py`); (3) a **compact 65816 reference** generated from the in-tree LLVM-MOS
  backend TableGen (`llvm-tblgen --dump-json`) and **validated against the canonical opcode matrix as a
  correctness oracle** — which doubles as a **65816 backend-encoding audit**
  (`tools/gen-65816-ref.py` → `65816-opcode-audit.md`); (4) an authored SNES hardware summary. Adopts
  `wt/321-mandelbrot`'s exact HAL symbol names (merge stays a union). Unblocks #3's greenfield graphics
  layer with a real register reference.
  [plan](docs/plans/2026-06-25-snes-hardware-reference-docs-subsystem-split-snes.md).

### Test Bench / CI

- [ ] **#321 Yarpgen as a second random generator behind `--gen yarpgen`** (follow-up to the now-**Done**
  Csmith fuzzer — see Done `[321-csmith-fuzzer]`). Targets the `-O1/-Os` loop/scalar-opt surface — the same
  register-pressure regime that produced the `regalloc-out-of-registers` (fixed, `0009`) and
  `scavenger-p-not-gpr` (fixed, `0011`) crashes and still hosts the open `a16-zp-pressure-overflow` XFAIL, so
  it's the natural next instrument. Two
  costs: redirect its baked-in `printf` to `corpus_result`; the 16-bit-int caveat (no `platform.info`
  equivalent → would need width surgery to stay UB-free). The `--gen` seam already added for Csmith makes it
  drop-in. [plan §Follow-ups](docs/plans/2026-06-19-321-csmith-differential-fuzzer.md) ·
  [harness reference](docs/investigations/csmith-differential-harness.md).
- [wip] **#321 vendor the GCC `c-torture/execute` correctness suite behind the differential gate** — slot the
  de-facto-standard *execution*-correctness suite (1656 top-level self-checking `abort()`/`exit(0)` programs)
  into the existing engine (`tools/a16_fuzz.py`), using the **default (non-a16) build as the trusted oracle**: a
  test is in-scope iff the default build runs it to the PASS sentinel, then any `+mos-a16`/`+mos-xy16`
  disagreement is a real defect (sidesteps "is this test appropriate for 16-bit `int`" — if default handles it,
  a16 must too). Fetch-don't-commit (GPLv3 → sha256-pinned gcc-14.2.0, gitignored, reproducible via
  `dev/fetch-torture.sh`, the WDC816CC/ORCA-refs precedent). **Phases 0+1 + Phase 2 `-O1` pass DONE
  2026-06-19**: filter → **1253/1656 in-scope**; runner (`tools/torture_run.py` + `dev/run.sh torture`).
  Full `-O1` pass: **1098 PASS, 136 SKIP, 3 known-XFAIL** (ZP-pressure) **+ 16 confirmed NEW runtime
  miscompiles** (a16/xy16 wrong-value, all reproduced isolated on both emulators → `xfails.tsv`, gate
  green-modulo-known). **`-Os` pass DONE 2026-06-20** — full sweep of all 1168 in-scope @ `-Os`: **1114 PASS,
  0 FAIL, 54 SKIP** after fixing the **2 FAILs it found** (`pr34768-1/-2` — a pre-existing a16
  load-fold-across-call miscompile, see Done `[321-abs-load-fold-across-call]`); 0 XPASS churn confirms the
  `CMPIndir16` fold (`9009260`) non-regressing. **Full bsnes-jg 4-way confirmation pass DONE 2026-06-20** —
  re-ran the entire in-scope set @ `-Os` with the bsnes-jg leg on **every** test (not just per-FAIL):
  **1174 PASS, 0 FAIL, 54 SKIP** — `host==default@MAME==a16@MAME==a16@bsnes-jg` holds suite-wide, no
  MAME-vs-bsnes divergence.
  [sweep plan](docs/plans/2026-06-20-321-broad-c-torture-sweep.md). ~~**Remaining:** Phase 3 sampled CI~~
  **Phase 3 sampled CI DONE 2026-06-21** — the **`torture`** job in `.github/workflows/smoke.yml`
  (in-container, `needs: xcheck` for the cached toolchain, 4-way differential, secret-gated skip-not-fail;
  `mode` input `sampled` [seeded `--sample 150 --sample-seed S` @ `-Os`] / `full` [whole in-scope @ `-Os`
  **and** `-O1`]). Added a seeded `--sample`/`--sample-seed` to `tools/torture_run.py` (was sequential-slice
  only). Local sampled verify `dev/run.sh torture --sample 150 --sample-seed 1 --opt -Os` = **143 PASS, 0
  FAIL, 7 SKIP, 0 XFAIL** (4-way, MAME + bsnes-jg). ~~**Optional tail:** reap orphan MAMEs in the runner~~
  **Orphan-MAME reaper DONE 2026-06-21** — `_run_emu` in `tools/a16_fuzz.py` spawns every emulator in its
  own session/process group and `killpg`s the whole group on timeout / exit / SIGTERM (no leaked boots
  across long local sweeps); behaviour-preserving (same `CompletedProcess`, re-raises `TimeoutExpired`).
  Verified: forking child reaped group-wide on timeout; normal path unregressed (`torture --sample 8` 8/8).
  [plan](docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md).
### Upstream / Contribution

_Live queue + exact post commands: [docs/upstream-contribution-status.md](docs/upstream-contribution-status.md)
— keep it in sync (drafted → ready-to-post → posted) with the items in this section._

- [ ] **Reconcile with llvm-mos-sdk#415 (the existing SNES target draft PR).** Build ON @Phillip-May's
  stalled-but-working SDK scaffolding, don't replace it: reuse his `snesxc` register lib + multi-bank
  linker (with credit); contribute on top our native-mode crt0 (unlocks 16-bit codegen) + the
  dual-emulator CI bench his PR lacks; keep the backend codegen (#320/#321) entirely separate (it
  lands in `llvm-mos`, targets any `-mcpu=mosw65816` platform). Strategy + the tier-1/tier-2
  positioning note for engaging @asiekierka on #321 are drafted in
  [415-snes-target-reconciliation](docs/415-snes-target-reconciliation.md). User-triggered (posting).
- [wip] **Upstream the F4 `mos-late-opt` TXY/TYX dead-flag fix** — ✅ **PR
  [#562](https://github.com/llvm-mos/llvm-mos/pull/562) opened 2026-06-22.** Upstream llvm-mos bug
  (`MOSLateOptimization.cpp`); **breaking commit = `dbce7ad1e9cd2`** ("Support emitting TXY/TYX on
  W65816/65EL02", #299, 2023-06-17) — added the TYX/TXY rewrite branches without setting `Load`, so they
  skip the dead/kill-flag cleanup that predates them (`8416d2408044`, 2022). Carried in the fork as patch
  `0003`. **Awaiting review/merge** → once merged, drop `0003` + bump the vendor pin.
  [F4 plan](docs/plans/2026-06-16-321-f4-late-opt-txy-dead-flag.md).
- [ ] **Post the register-scavenger live-`$p` fix PR (`0011`) + the `LDCImm` set-lowering fix PR (`0012`)**
  (user-triggered). The scavenger N/Z crash is now **FIXED** (was an issue-with-no-fix): route a live `$p`
  hard-stack-neutrally through a dead index reg into `RC17` for the unbalanced case + drop the stale
  `assertNZDeadAt`. Fixing it surfaced a second pristine-upstream bug (`LDCImm 1` → `MCInstLower` unreachable),
  fixed as `0012`. Mint branches off `c798c31416f7`; exact `gh pr create` in
  [upstream-contribution-status](docs/upstream-contribution-status.md) (item 4) · bodies
  [scavenger](docs/upstream-scavenger-live-p-pr.md) + [LDCImm](docs/upstream-ldcimm-set-lowering-pr.md) ·
  [plan](docs/plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md).
- [wip] **DP-pointer-argument calling-convention crash — reported + FIXED upstream** — ✅ **issue
  [#561](https://github.com/llvm-mos/llvm-mos/issues/561) (2026-06-22) + fix [PR #563](https://github.com/llvm-mos/llvm-mos/pull/563)
  (2026-06-23, `Fixes #561` → auto-closes on merge).** Passing an `addrspace(1)` (8-bit direct-page) pointer
  **argument** crashed the MOS backend: the CC materialized it into a 16-bit `RS` reg → illegal `(p1)=COPY
  $rs`. **Pure upstream** — reproduces on plain `mos6502`; **breaking commit = `e618537e7d5e`** ("Use address
  space 1 for ZP pointers", 2022-07-25). **Fix** (spike GO, `wt/dp-arg-cc`): a `CCIfPtrAddrSpace<1,
  CCAssignToReg<[A, X, RC2..RC15]>>` rule giving the DP pointer an 8-bit slot (mirrors the far rules + i8
  pool) + `llvm/test/CodeGen/MOS/dp-pointer-arg.ll`; validated (crash gone 5 shapes mos6502+mosw65816,
  correct `lda 0,x`/`sta 0,x`, corpus 7/7, test crashes pre-fix/passes post). Carried as **fork patch `0008`**
  (`e0e8bd4`); drop on merge + bump the vendor pin. **Awaiting upstream review.**
  [plan](docs/plans/2026-06-22-320-far-value-residuals.md) (Part A) · issue body
  `docs/320-upstream-dp-arg-cc-issue.md` · PR body `docs/320-upstream-dp-arg-cc-pr.md`.
- [ ] **Post the DWARF step-6 test+docs PR** (user-triggered; ROADMAP step 6). Branch
  `wbniv:mos-dwarf-65816-test-docs` (`0ae9415`) pushed and ready. Exact `gh pr create` in
  [upstream-contribution-status](docs/upstream-contribution-status.md) (item 5) · body
  [docs/321-upstream-dwarf-output-elf-companion.md](docs/321-upstream-dwarf-output-elf-companion.md).
- [ ] **Post the #321 CC frame-ABI design note** (user-triggered; note, not a PR). Implementation-backed
  evidence for the calling-convention discussion: the per-frame DP-window/stack-relative ABIs are feasible
  but NULL on real code (0/13 functions profit — locals are `__rc`-resident), so keep the soft static stack
  by measurement. Exact `gh issue comment 321` (and/or Discord CC thread) in
  [upstream-contribution-status](docs/upstream-contribution-status.md) (item 6) · body
  [docs/321-upstream-cc-frame-abi-note.md](docs/321-upstream-cc-frame-abi-note.md) · record
  [frame-ABI study §Outcome](docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).
- [ ] **#320 far-pointer codegen body — feature-complete, but Future/blocked** (not a postable artifact yet).
  The fork's whole far-pointer slice (far calls (b); far function pointers (a) incl. the clang `far`/`long_call`
  attribute, typed `far_fn_t` variable, `sizeof(far*)==4`, the far_indir/`isFarSymbol` crash fix) is now
  feature-complete + pushed `origin/wt/320-far-followups`, verified both emulators. It forms the bulk of the
  eventual #320 PR but is **gated on the ABI-blessing design note** (the M1 "#320 post design note upstream"
  item) — so it's tracked under *Future/blocked* in
  [upstream-contribution-status](docs/upstream-contribution-status.md), not ready-to-post.
- [ ] **Re-enable CI auto-triggers when repo goes public.** Add `push:` + `pull_request:` to
  `.github/workflows/smoke.yml` (currently `workflow_dispatch`-only — parked until public). One-liner:
  uncomment the two trigger lines in the `on:` block.

### Distribution / Packaging

- [ ] **#321 Cross-platform toolchain builds — interim `linux-arm64` + `windows-x86_64` (keep `linux-x86_64`),
  cross-compiled from the existing Linux x86-64 Docker** (no mac/Win CI runners; scope locked 2026-06-25).
  Until #321 merges/fixes upstream, upstream CI emits no binary carrying these patches, so arm64-Linux /
  Windows devs have no prebuilt fork — ship those two. Only the host binaries (clang/lld/llvm-*) differ per
  platform; the MOS compiler-rt builtins + clang resource headers + SNES SDK are host-agnostic and copied once
  from the canonical Linux build, so the cross builds disable the runtimes sub-build and reuse
  `build/llvm-mos/bin` tablegens via `LLVM_NATIVE_TOOL_DIR`. **Inc 0 DONE** — build side (`dd2802a`) +
  `dev/package-release.sh` generalized to a `PLATFORM` arg (native target artifacts reused, multi-format strip
  via native objcopy, Windows curated-`.exe`/`.zip` branch, qemu/wine self-test via `dev/cross-selftest.sh`);
  `linux-x86_64` proven **byte-identical** (orig-vs-refactored staged-tree diff). **Inc 1 DONE+validated** —
  `linux-arm64` built, packaged, qemu self-test PASS with ROM `sha256 == native`. **Inc 2 DONE (functional
  deferred)** — `windows-x86_64` built/packaged (curated `clang.exe`+`mos-clang.exe`+`ld.lld`+binutils aliases
  + 3 mingw DLLs, `.zip`); **wine can't run the mingw-LLVM binary** (faults `0xC0000005` in core codegen at
  every `-O`), so it ships on the **structural + codegen-identity-by-construction** gate with the functional
  `-Os` check **deferred to real Windows** (soft-fail `exit 2`, BEFORE-PUBLISH notice). **Inc 3 DONE** —
  `task cross-build PLATFORM=` + `task package-all`. **REMAINING:** real-Windows functional verification +
  publish. **Deferred:** `macos-arm64` (osxcross + a user-supplied macOS SDK in `dev/sdks/` — Apple licensing;
  functional self-test needs a real Mac) — out of interim scope, likely retired by upstream CI. Whole
  capability retires when `0001–0009` land upstream. [plan](docs/plans/2026-06-25-cross-platform-toolchain-builds.md).

- [ ] **Clean-room test of the *published* SNES compiler — wired into the publish gate** — in a throwaway
  Docker container with NO dev toolchain, acquire the published compiler and compile a **sound-free**
  reference Mandelbrot (`examples/snes/mandel-display.c`, 32×28 N=15, CRC `0x9103`; secondary
  `examples/65816/k_mandel.c` `0x820B`), then verify on **bsnes-jg** (embedded SPC700 IPL → no BIOS, no sound)
  against the host oracle (`mandel-render`) — both default-8bit and `+mos-a16`. Every run emits three artifacts
  to `build/release-test/`: a **compile log** (`release-test-<method>.log`, timestamped, shows the exact
  `mos-snes-clang` command + output), the **SNES Mandelbrot screenshot(s)** (`mandel-<build>.png`, bsnes-jg
  framebuffer), and a nicely-formatted self-contained **HTML release report** (`release-report-<stamp>.html`:
  embeds the log + screenshots, plus config, release-package details, and a names+sizes table of the bundled
  `.md`/`.pdf` docs). **Policy: always test on release** (the mandatory `METHOD=local` gate in
  `dev/package-release.sh`, so *every* `task package` is clean-room-verified + reported before upload); **no
  periodic/scheduled CI smoke** — `apt`/`tarball` methods are manual post-deploy confirmations. Rig image
  `dev/Dockerfile.release-test` (pinned bsnes-jg + jgxcheck + oracle + fixtures, no toolchain) +
  `dev/test-release.sh` + `dev/release-report.py` + `task release-test`.
  [plan](docs/plans/2026-06-25-test-published-snes-compiler.md).


## Watch

_Items here need periodic checking (e.g. an upstream llvm-mos change to track, or a deferred decision to
revisit) rather than active work._

- [ ] **Reevaluate the deferred s16-register-pressure core (Phase-3 `Ac16`/ZP residency).** **Two** crashes
  once attributed to this core turned out to have *orthogonal* targeted fixes, **not** the residency rework:
  the `globals.c`/`a16regpress.c` `-Os` RA-**crash** (patch `0009`, `ad506ed`, 2026-06-25 — an i8-loop-counter
  de-pin from `{A}`; `a16regpress.c` now a positive gate, `0x01A7`) and the `+mos-a16`/`+mos-xy16`
  **scavenger-N/Z crash** (patch `0011`, 2026-06-26 — route a live `$p` through a dead index reg into `RC17`;
  + `0012` for a `LDCImm` MC-lowering bug it surfaced; `a16scavnz.c` now a positive gate, `0x22A6`). What
  **remains deferred** is the general pre-RA `Ac16`/ZP-residency rework, now motivated by only **one**
  *pathological* XFAIL — the link-time ZP overflow (`pr15296.c`, `a16-zp-pressure-overflow`).
  It is high-risk (regresses the common a16 path / reopens a crash class) and low-reward (Phase 1.5 already
  captured the threading wins; real code is slack). **Re-open only when** either **(a)** the corpus / c-torture
  / fuzzer surfaces a *second independent* `regalloc-out-of-registers` (or `a16-zp-pressure-overflow`) from
  **realistic** (not hand-reduced) code, or **(b)** the ZP-pressure baseline (`dev/measure-zp-pressure.sh`)
  shows a real corpus function crossing **~10 of 14** `Imag16` pairs. If a trigger fires, run the gated
  B0→B1→B2 spike (recipe in the A16-threading plan §5). Full root cause:
  [a16-regalloc-pressure-failure](docs/investigations/65816-a16-regalloc-pressure-failure.md) ·
  [scavenger N/Z](docs/investigations/65816-a16-scavenger-nz-liveness.md) ·
  [deferral formalization](docs/plans/2026-06-20-321-a16-threading-phase-3-formalize-the-deferral-r.md).


## Parked

- [ ] **Mesen2 as a third emulator** — abandoned for now: the prebuilt crashes on 26.04
  (glibc-2.43) and headless `--testrunner` won't run Lua; would need a source build against 26.04.
  MAME + bsnes-jg already give a two-emulator cross-check, so this is shelved unless a third opinion
  is needed. [second-emulator plan](docs/plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md).
- [ ] **Formal #320/#321 psABI document** — deferred as premature: llvm-mos is implementation-first
  (@mysterymath won't bless an ABI ahead of a high-quality implementation). Promote once a credible
  implementation exists or the maintainers ask. Overlaps the WDC816CC/ORCA-C prior-art item above.
  [upstream design-note plan](docs/plans/2026-06-14-320-upstream-design-note.md).


## Done

- 2026-06-26 — [321-scavenger-live-p] **#321 `+mos-a16`/`+mos-xy16` register-scavenger crash (`$p is not a GPR`) — FIXED, pristine-upstream fork patch `0011` (+ `0012` for the bug it surfaced).** The 8/500-seed scavenger crash (`a16scavnz.c`; family 169/173/196/268/271/272/306/420) was *previously* deferred as an upstream issue-with-no-fix. **Root cause** (asserts-confirmed): `MOSRegisterInfo::saveScavengerRegister` assumed N/Z dead at every scavenge point AND that a live `$p` is only preserved across a *balanced* hard-stack range; both break under 16-bit-accumulator flag live ranges, where a 16-bit compare keeps N (or Z) live across a frame-index materialization whose carry the scavenger places in `$c` (a sub-register of `$p`) — forcing the whole `$p` preserved across an *unbalanced* range → illegal `STImag8 $p` + undefined-`$p` `PH $p`. **Fix (`0011`):** for the unbalanced case, route `$p` **hard-stack-neutrally** through a dead 8-bit index register into the reserved `RC17` slot (`PHP;PL<idx>;ST<idx> RC17` / `LD<idx> RC17;PH<idx>;PLP`) — each half net-0 on the stack, so independent of the imbalance; width-safe because `MOSInsertREPSEP` (runs after scavenging) forces index ops to `XW_X8` even under `+mos-xy16`. Plus: flag the no-reaching-def `PHP` `undef` (verifier), drop the stale `assertNZDeadAt` (its premise is the false invariant; flag preservation is holistic via the scavenger's interleaved P-saves). **Second bug found while validating** (compilation reached MC lowering once the scavenger no longer crashed): `MOSMCInstLower` lowered `LDCImm` only for `0`/`-1`, but a *set* i1 carry can arrive as `1` (a 16-bit `SBC` carry-in) → `llvm_unreachable` on asserts (silent UB under NDEBUG); a plain `+mos-a16` 16-bit subtract reproduces it. **Fix (`0012`):** lower any nonzero i1 as `SEC`. Both pristine-upstream (drop on merge); `0011`/`0012` round-trip (`0001..0012` == live tree). DEFAULT 8-bit unaffected; corpus 7/7; `a16scavnz.c` promoted to a **positive gate** (`dev/run.sh a16scavnz` → `0x22A6`, host==default==`+mos-a16`==`+mos-xy16`, MAME+bsnes-jg, **asserts-clean**); `KNOWN_ISSUES["scavenger-p-not-gpr"]` + its repro row dropped; differential fuzzer 0 mismatch/0 crash. [plan](docs/plans/2026-06-26-321-scavenger-nz-live-p-save-fix.md) · [investigation §RESOLUTION](docs/investigations/65816-a16-scavenger-nz-liveness.md) · [scavenger PR](docs/upstream-scavenger-live-p-pr.md) · [LDCImm PR](docs/upstream-ldcimm-set-lowering-pr.md).
- 2026-06-25 — [321-a16-pressure-fix] **#321 `+mos-a16 -O1/-Os` regalloc out-of-registers crash on real code (`globals.c`) — FIXED, fork patch `0009`.** The `globals.c`/`a16regpress.c` *"ran out of registers during register allocation"* deadlock under `+mos-a16 -O1/-Os` (DEFAULT 8-bit + `+mos-a16 -O0` always compiled clean) is fixed. **Root cause** (fresh asserts pinpoint, `-debug-only=regalloc`): the final blocker was **not** `Ac16`-residency but a single **A-pinned i8 loop counter** — the strength-reduced array byte index (stepped `i += 2`) selects to `add Ac,imm → ADCImm` (class `Ac`={A}; `adc` is hardware-A-only), held live across the 16-bit indexed-load `Ac16`=A:B transit → collides on physical A; last-chance recolor fails (singleton `{A}`) and the 1-instr INF transit can't spill. **Fix (`0009`, `ad506ed`):** under `hasAccum16()`, `MOSInstructionSelector::selectAddSub` lowers a small-constant i8 add/sub (`|amt| ≤ 2`) to a relocatable `G_INC`/`G_DEC` chain (Anyi8 = A/X/Y/zp) instead of the A-pinned `ADCImm`, so the byte index coalesces into the X array index (`inx; inx; cpx`) and frees A16 — **one spillable/relocatable change, no RA rework**. Refutes the 2026-06-18 *"no targeted fix, only the general Phase-3 `Ac16`-residency rework"* conclusion **for this crash** (coalescing still ruled out — it's an orthogonal de-pin). DEFAULT 8-bit byte-identical (gated); **−123 B over 122 c-torture programs (0 worse)**; both `a16regpress.c` and the original `globals.c` compile + run clean (release + asserts). `KNOWN_ISSUES["regalloc-out-of-registers"]` dropped + repro row removed; `examples/65816/a16regpress.c` promoted to a **positive gate** (`dev/run.sh a16regpress` → `0x01A7`, both emulators). `regen-patch-0009.sh` round-trips (`0001..0009` == live `MOSInstructionSelector.cpp`). **NOT fixed by `0009`** (still XFAIL — the genuinely-deferred s16-pressure core): the scavenger-N/Z crash (`a16scavnz.c`, `scavenger-p-not-gpr`) + the `pr15296.c` link-time ZP overflow (`a16-zp-pressure-overflow`), both byte-identical pre/post. [plan](docs/plans/2026-06-24-321-a16-pressure-fix-implementation.md) · [handoff](docs/plans/2026-06-23-321-a16-pressure-scavenger-fix-handoff.md) · [investigation §RESOLUTION](docs/investigations/65816-a16-regalloc-pressure-failure.md).
- 2026-06-25 — [321-mandel-zoom-pyramid] **Mandelbrot ZOOM PYRAMID — true increasing detail on zoom-in (#321 M2), Phases 1 + 2.** The interactive demo only *magnifies* its baked bitmap; this adds genuinely-deeper detail. The host bakes a STACK of Mandelbrot levels, each 2× finer zoom centered on the real-axis mini-Mandelbrot (`c=-1.7548776662`, finalized by rendering several centres to PNG — Lesson 1); on the SNES, Mode 7 hardware-zooms the current level and the ROM **DMAs the next finer level** as zoom crosses each 2× threshold — so the dive runs into NEW structure (whole set → down the antenna → a complete tiny copy of the set) with **zero on-console fractal math**. 64×64 × 6 levels = 32× deep fits one 32 KiB LoROM bank (no linker change); builds **both default-8bit and `+mos-a16`** (near ROM DMA, no far pointer). New `tools/mandel-bake-pyramid.c` (host `double` renderer → gitignored `examples/snes/pyramid_image.h`: per-level tiled chr, one shared normalized palette, `MANDEL_PYR[]`/`MANDEL_PYR_HASH[]`, per-level PNGs), `examples/snes/{zoom.h (pure host-replayable level-swap state machine — `[S0/2,2·S0]` hysteresis, R/L dive, Y/A rotate), mandel-zoom.c}`, `dev/mandel-zoom.sh`; `mode7.h` gains parametric `m7_tilemap_identity`; `jgxcheck.cpp` gains `JGX_ZOOM`. **Differential PASS** (`dev/run.sh mandel-zoom`): per-level image hash all 6 levels host==default==`+mos-a16` (SMOKE 0x9191 + HASH) on MAME + bsnes-jg; scripted-zoom view-math host==target both builds (ZOOM, swaps=3); `-verify` clean; 32 KiB fit. Regressions green (`mandel-interactive` 0xF99C, `mandel-mode7` 0x75E8). **The gate caught a real DEFAULT-8bit matrix-fold-loop MISCOMPILE** (loop `m[i]` folds 0x456E vs correct 0xB115; unrolled form correct; context-sensitive, independent of #321 — see the new follow-up item). **Phase 2 DONE+green (`6fb3d1b`): multi-bank LoROM, 128×128 × 8 levels = 256× deep, 256 KiB / 8 banks** — new `platforms/snes-zoom` platform (one bank-aligned level per bank), bake `PYR_MULTIBANK` mode (per-level `.rodata_levelK` + `MANDEL_PYR_BANK[]`), the swap DMAs from `(bank : addr16)` (no far pointer → still builds default+`+mos-a16`), `snes-checksum.py` 256 KiB, a `jgxcheck` VRAM-readback gate + host ROM-file per-bank hash. `dev/run.sh mandel-zoom` (PYR_MODE=hd default | sd) PASS both modes/builds. **Found the vblank limit** (a 16 KiB swap DMA overruns vblank → truncated mid-transfer; fixed by force-blanking the large swap — the VRAM gate caught it). Live: `task mandel-zoom-play`. [plan](docs/plans/2026-06-25-321-mandelbrot-zoom-pyramid.md).
- 2026-06-25 — [321-interactive-mandelbrot] **Interactive SNES Mandelbrot — a real-time Mode 7 joypad fly-around (#321 M2), INSTANT boot, host==default==+mos-a16.** The static `mandel-mode7` was too slow (~4 min on-console compute); this bakes the 128×128 image host-side TILED into Mode 7 character order (`tools/mandel-bake.c` → gitignored `examples/snes/mandel_image.h`) and DMAs it straight ROM→VRAM at boot — no compute, no de-linearize loop (measured the reused `build_vbuf` at ~5–6 s of black boot and redesigned around it). Removing the far staging buffer means the demo builds **both default-8bit and `+mos-a16`**. New `examples/snes/{mandel-interactive.c, mode7.h (shared Mode 7 upload + DMA + matrix setters, refactored out of mandel-mode7.c), view.h (pure pan/zoom/rotate state + the 8.8 Mode 7 matrix 16×16→32 multiplies)}`, joypad HAL in `platforms/snes/snes.h` (`snes_read_pad1`/`snes_wait_vblank` + `JOY_*` + `VMAIN_INC_LOW_1`). **Differential PASS:** displayed-image hash **`0xF99C`** host==default==`+mos-a16` on MAME (Xvfb snapshot) + bsnes-jg; a **scripted-input view-math gate** (`dev/jgxcheck.cpp -DJGX_VIEW` replays `view.h` over the ROM's ground-truth pad log) host==target for BOTH builds; `-verify-machineinstrs` clean; 32 KiB fit. The gate caught a real 8/16 promotion bug (`h>>15` on the 16-bit-int target → negative-int arithmetic shift). Bonus fixes: a pre-existing dep-tracking bug (`dev/sync-platform.sh` — editing `platforms/snes/snes.h` now reaches the build) and `dev/build.sh` (bake the header + build `mos-a16-only`-marked far examples with +mos-a16; `dev/run.sh build` was broken on main since the beefy merge). Regressions green: `mandel-mode7` 0x75E8, `k_mandel` 0x820B, corpus 7/7. Controls: D-pad pan / L-R zoom / Y-A rotate / Select palette / Start reset (`task mandel-play`). [plan](docs/plans/2026-06-25-321-interactive-mandelbrot-mode7.md).
- 2026-06-25 — [321-csmith-fuzzer] **#321 Csmith differential fuzzer DONE (Phases 0–5) + consolidated into a single-file reference.** Off-the-shelf [Csmith](https://github.com/csmith-project/csmith) replaced the hand-rolled generator as the `dev/run.sh fuzz` default (builtin kept via `--gen builtin`): per-seed gen (`tools/csmith_run.py`) → host-side fit pre-filter → the 4-way **default-as-oracle** differential (`host`≡`default@MAME` == `+mos-a16` == `+mos-xy16` == `+mos-a16@bsnes-jg`), sound because `platform.info` (int=2) + kept `safe_math` make output UB-free at the target's 16-bit `int`. SNES adapter `examples/65816/csmith/{csmith_snes.h,platform.info}` folds Csmith's 32-bit CRC into `corpus_result`; `vendor/csmith` built on demand (`dev/fetch-csmith.sh`). **Caught + drove fixes:** the a16 `G_UNMERGE`/`G_MERGE` s32 legalizer gaps (seeds 11, 113) + the `+mos-xy16` high-byte clobber (seeds 247+445) — all FIXED on `main`. **Phase 5 (`e865dff`):** sampled/full `fuzz-csmith` CI job (host-side, `needs: xcheck`, secret-gated, nightly `schedule:` ready-but-commented). Merged `dd5616b` (2026-06-19); consolidated 2026-06-25 — mechanism + state + open residue (nightly schedule, far/AS2/AS3 out-of-scope-by-design, regression-seed extraction, Yarpgen) + the WDC816CC/Plum Hall motivation — into [investigation](docs/investigations/csmith-differential-harness.md). [plan](docs/plans/2026-06-19-321-csmith-differential-fuzzer.md).
- 2026-06-24 — [blossom-snes-kernel] **Blossom (Hopalong attractor) ported to SNES — Phase 1 headless Q8.8 math kernel, 4-way verified.** The math heart of Blossom 4.0 (`~/Downloads/blossom.html`) the 1989 way: fixed-point + a 512 B sqrt LUT (`BLOSSOM.TBL`-style), no FPU. New `examples/65816/k_hopalong.c` (Q8.8 `short` orbit, `volatile` params so the 1024-iter loop can't fold, `tools/gen-sqrt-lut.py`-generated `SQRT_LUT`, rotate-xor fold → `corpus_result`; `#ifdef HOST` oracle), `dev/k_hopalong.sh` (`dev/run.sh k_hopalong`). `sign(x)*sqrt` written as a conditional negate (not `__mulhi3`) → a16 +46 B shrank to **+14 B**. **Differential PASS:** host == default == `+mos-a16` == **`0x1BBC`** on MAME + bsnes-jg; `-verify-machineinstrs` clean; native 16-bit active (12 rep/13 sep). a16 is **+14 B** vs default — the expected 8/16-interleave regression class (`b*x` `__mulsi3` + sign/clamp branches through 16-bit math), a measurement not a defect. On-screen interactive renderer = #3 (Open/M2). [plan](docs/plans/2026-06-24-blossom-snes.md).
- 2026-06-24 — [reviewer-presentation] **Reviewer-facing presentation of the `0001`–`0008` stack — review guide + LLVM primer + upstream-PR Appendix D, plus 2 ROM-neutral platform refinements.** New `docs/65816-patch-series-review-guide.md` (per-patch need/patch/proof, dependency+sequencing+timeline diagrams, Appendices A–D, GitHub-linked to all 8 patches + 17 artifacts) + `docs/llvm-primer-for-65816-review.md` (front-end→IR→backend→MC, GlobalISel/TableGen/MC/RA + glossary) for the upstream submission. Appendix D + `dev/upstream-status.sh` = the bug-fix-PR accounting (`0003`→PR #562, `0008`→#561/PR #563; scavenger deferred). Platform: `clang.cfg` now defaults `-mcpu=mosw65816`; crt0 `.init.50` rewritten from hand-encoded `.byte` to 65816 mnemonics (`-fno-lto` so module-level asm gets `W65816`) — both **ROM-byte-identical** (corpus 7/7, smoke 0x42). Renderer fix in python-tui-lib `0134f1c` (footnote links). [plan](docs/plans/2026-06-24-reviewer-patch-series-presentation.md).
- 2026-06-23 — [321-s32-verification] **#321 32-bit `long`/`int32_t` support VERIFIED — micro-test + builtin-fuzzer s32 track (no compiler change).** Two complementary differential verifications of the existing s32 codegen (2×s16 + 4×s8↔s32 (un)merge + `__mulsi3`/`__udivsi3`/`__umodsi3` libcalls). **(1)** `examples/65816/a16s32.c` + `dev/run.sh a16s32`: folds every s32 hazard into a 32-bit `corpus_result`; full 4-way `host==default==+mos-a16==0x50F2B870` on **MAME + bsnes-jg** (4-byte read; `long` has a default leg, so stronger than the far tests). WANT is the host-oracle of the identical `uint32_t` arithmetic (`-DHOST_ORACLE`) + a runtime drift-guard. **(2)** `tools/a16_fuzz.py` gains a `--s32` track: a seeded op-list over 4 `uint32_t` regs interpreted by BOTH a C emitter and the exact Python oracle (lockstep), gated so `--s32` off is byte-identical (30/30). `dev/run.sh fuzz --gen builtin --s32` → **40/40, 0 mismatch** (deterministic 4-way now exercises `long`; csmith already did non-deterministically). Both deliverables 2-agent-workflow reviewed → **ship** (emit/eval lockstep checked over 200k randomized op-lists, 0 drift; UBSan-clean; one impl-defined-consistency comment added). Worktree `wt/321-s32-verify` retained. [plan](docs/plans/2026-06-23-321-32bit-long-verification.md).
- 2026-06-22 — [320-far-tail-calls] **#320 far tail calls DONE — far→far tail folds 5 B→4 B, verified both emulators.** New `TailJML` pseudo (→ `JMP_AbsoluteLong` `$5C`, `R_MOS_ADDR24`) + a far arm in `MOSLateOptimization::tailJMP`: `JSL <direct far global>; RTL → TailJML`, gated `isGlobal && .far_` so near→far (`JSL;RTS`) + the bank-0 thunks (external/non-`.far_` symbols) auto-exclude — conservative (a misclass only misses a win). a16-independent → regenerated into the worktree's `0001` (round-trips `0001..0007`; `MOSLateOptimization.cpp` added to `FAR_FILES`); **landed on `main` (`4adda8b`) + toolchain rebuilt/verified 2026-06-23.** New `dev/run.sh far_tail` (`far_outer` single fold + execution-discriminating two-block `far_pick` → `0xCB`) MAME+bsnes-jg; negative gate in `far_near_call.sh` (thunk tail NOT converted); `+mos-a16` verify clean; corpus 7/7, far suite 12 ROMs, csmith 50 0-mismatch. Design + impl each 3-agent-workflow reviewed (all ship; one test-strengthening + one comment fix applied). Worktree `wt/320-far-tailcall` retained till upstream. [plan](docs/plans/2026-06-22-320-far-tail-calls.md).
- 2026-06-22 — [0007-fold-toolchain-rebuild] **Patch stack is now `0001`–`0007` on `main`; toolchain rebuilt clean from the stack + verified.** The near-abs bank-relaxation **`0007`** (Task B's realization) **and** the `regen-patch-0001.sh` 7-patch-stack / complete-`FAR_FILES` tooling refresh landed on `main` (`ff02726` / `d5c5946`, integrated via the 2026-06-22 merge). A **clean `dev/run.sh toolchain` rebuild from the patch stack** (vendor reset → apply `0001`–`0007` → 8m31s incremental build) brought this checkout's install — a stale 2026-06-20 snapshot — back in sync with committed `main`. **Verified:** `far_near_call == 0xE0` (the far→near thunk routing; its earlier failure was the **stale install**, not a regression — main's source always had it), `corpus` 7/7, `far_call == 0xF3`, `a16 == 0x0042` on both emulators.
- 2026-06-22 — [snes-near-code-budget] **SNES near-code budget is now an enforced link-time contract (+ the near/far "code model" framing).** Answers *"add a mode that limits codegen to 64k/32k?"* → **no** — near (`JSR`/`RTS`, `CodeModel::Small`, 2-byte fn ptr) is already the default, far is per-symbol opt-in, so a `-mcmodel` mode buys no codegen win. **Fix (linker-script only, no `vendor/`):** `platforms/snes/link.ld` + `snes-far/link.ld` carve the fixed header+vectors into a `romhdr` MEMORY region so `rom`'s LENGTH (`$8000–$FFAF` = 0x7FB0 = 32688 B) **is** the budget → an over-budget link now fails with the clear `region 'rom' overflowed by N bytes` (was an obscure `.snes_header` overlap). **Verified:** ROM **byte-identical** for in-budget programs (7 snes corpus + 5 snes-far ROMs, 0 diffs); `corpus` 7/7; far suite PASS (`far-bank1`/`far-run`/`far_call`/`far_store`/`far_arith` == 0xF3, byte-identical); overflow probe → `overflowed by 206 bytes`. (`far_near_call` failed at verification time **only** due to a stale 2026-06-20 install — proven by stash+rebuild, not this change; a later clean toolchain rebuild restored it to `== 0xE0`.) Docs: "Code model: near vs far" section in the #320 upstream note + a pointer in upstream-contribution-status. [plan](docs/plans/2026-06-22-snes-near-code-budget-and-code-model.md).
- 2026-06-22 — [321-native-s16-surface-consolidation] **#321 native-s16 surface CONSOLIDATED + measured-COMPLETE — the #321 analogue of the zero-bank close (nothing built).** Durable roll-up `dev/measure-native-s16-surface.sh` drives the three existing harnesses + adds the missing ROADMAP step-5 acceptance table. **Phase 0 (RAN 2026-06-22):** all three states reproduce — compares native except the optimal byte-wise register-resident EQ-as-value; A16-threading `roundtrips=0` (post-`threadAccum16` optimum); ZP `0/13` pool-exhaust (max ~5/14). Step-5 **a16-vs-default is honestly MIXED** — the sustained-16-bit class wins (`chain −63%`, `multivalue −65%`, `k_isort −39%`, **aggregate −22%/−220 B**, corpus **7/7**) while 8/16-interleave stress kernels regress by-design (`k_prng +60%`, `k_crc16 +27%`; verified pure `rep`/`sep`+`Imag16` cost, no libcall asymmetry) → confirms **why a16 is opt-in/per-op-gated**. **The one fact it contributes:** A16-threading Phase 3 ≡ ALU-chain >14-live ≡ `globals.c` `-Os` RA-crash are the **same** deferred core (RA-level 16-bit residency under register pressure) — one frontier, one trigger, one B0→B1→B2 recipe, now cross-referenced from all three still-open items. New ≥8-shift bracket-fragmentation candidate routed to a future gated spike (didn't meet the GO bar). GO contingency did **not** fire; doc cascade landed (`a584a78`: ROADMAP §5 + upstream-status fold). [plan](docs/plans/2026-06-22-321-native-s16-surface-consolidation-and-close.md) · [close-out](docs/plans/2026-06-22-321-native-s16-surface-consolidation-knock-out-the.md).
- 2026-06-22 — [m1-incremental-rebuild] **M1 incremental-rebuild time MEASURED (plan step 4 PASS): editing one backend `.cpp` → ~11 s relink, not a full rebuild.** Real string-literal edit to `MOSInsertREPSEP.cpp` (preprocessor-surviving → true ccache miss) → `dev/run.sh toolchain` = 12 ninja steps (recompile TU + re-`ar` MOS lib + relink lld/clang-23/clang-scan-deps), 11 s wall / 10 s in-container, vs 30–90 min cold. Measured on a verified-quiet host in an isolated real-copy worktree (per howto §compiler-changing); evidence in the plan. [m1 plan](docs/plans/2026-06-14-m1-from-source-toolchain.md).
- 2026-06-22 — [320-zerobank-as4] **#320 zero-bank (AS4) measure-and-closed: CONFIRMED measured-null — the five-address-space model is now COMPLETE (all 5 spaces measured).** De-lumped the circular 0b census (the old `dev/measure-five-space-census.sh` line "zero-bank likewise has 0 users" was a lumped assertion, never an AS4-specific probe) into a direct, reproducible measurement — `dev/measure-zerobank-census.sh` + `examples/65816/zerobank_probe.c`, host-only: **0 realistic sites** carry bank-0 data as a far-typed pointer (corpus/kernels `Nfar=0`; far suite stores 0 far ptrs, all transient), and at any site zero-bank — bit-identical to a near pointer (`p4:16:8`==`p0:16:8`) — **ties the "near + lazy `near→far` cast" incumbent on every axis**: storage 2 B==2 B, global access `ad`==near's `ad`, runtime deref `(dp)` (no far indexed-long mode; AS4 cheap access is globals-only). Its one possible access win (forcing `ad` over `af`) is exactly the in-flight `0007` near-abs relaxation's win for ALL near pointers — not a new far-typed space. Premise-checked (workflow: 4 readers + 3 adversarial skeptics, 0 wins); feasible (~30 LoC, reuses near path + 0006 cast template, no `MVT` workaround) so **null by worth, not infeasibility** — dominated like frame-ABI's DP/SR frames by the soft static stack. **Nothing built.** Five-space §Phase 2, the upstream note + status, and the circular census line all updated. [plan](docs/plans/2026-06-22-320-zerobank-as4-measure-and-close.md).
- 2026-06-21 — [320-far-pointer-integration] **#320 far-pointer line LANDED on `main`: far fn pointers (a) folded into `0001`, the far-pointer calling convention (Imag32) as `0004`, the lone a16-context-entangled legalizer hunk as `0005`.** Round-trip patch surgery (`dev/land-far-integration.sh`): extracted the (a) recipes as `diff(R, FF)` against a same-base reference (`R` = pristine+`0001`+`0002`+`0003`+`0004`; `FF` = `wt/320-far-followups`), folded the a16-free far-fn-ptr work (backend Layers 1–3 + Gap A/B + the `__call_indir_far` mechanism + clang F2 `far`/`long_call` attr + typed `far_fn_t` var + `sizeof(far*)==4` + the `isFarSymbol` far_indir fix) into `0001` (a16-free — 0 `mos-a16`/`Ac16`/`hasAccum16` in the new hunks), landed the canonical far-cc `0004` (Imag32 won the 4-variant measure, 70 B/50441), and split the lone a16-context-entangled (a) hunk (`MOSLegalizerInfo` PF-as-value, which edits `0002`'s `if(hasAccum16)` block) into new **`0005`**. **Round-trip-proven:** `0001`+`0002`+`0003`+`0004`+`0005` reproduces the verified FF tree EXACTLY over `clang/`+`MOS/`, except two documented non-(a) files — `MOSInsertREPSEP.cpp` (FF working tree stale vs main's *current* `0002` X-width catch-all) and `clang/cmake/caches/MOS.cmake` (build-config drift, in no patch). `0002`/`0003` SHAs unchanged; `0004` = canonical `2efa05f2`. Harness landed too (`dev/farcc_*.sh`, `measure-far-cc.sh`, `probe-cycles.lua`, `regen-patch-0004.sh` baseline extended for `0005`, new `regen-patch-0005.sh`) + the far-cc measurement note (upstream-status #7). [land plan](docs/plans/2026-06-21-320-far-pointer-integration-land-0004-and-a-recipes.md).
- 2026-06-21 — [321-xy16-cc-boundary] **#321 xy16 calling-convention — boundary VERIFIED + formalized; both optimization levers measured + shelved (the last open M2 CC item; codegen-inert).** The xy16 (16-bit X/Y index) call/return boundary was already mechanically implemented (X/Y forced 8-bit at every `isCall`/`isReturn` via `MOSInsertREPSEP` `requiredXWidth`→`XW_X8`, `XIn[Entry]=XW_X8`; X16/Y16 caller-saved in `MOS_CSR_RegMask`) but **UNTESTED across a call** — every prior xy16 test indexes *within* a function; `xy16spillr` carries `Ac16`. New deterministic guard `examples/65816/xy16call.c` + `dev/xy16call.sh` (`dev/run.sh xy16call`): a genuine 16-bit index (`0x0102`, load-bearing high byte → the value test is itself the LTO-narrowing detector) held live across a clobbering `noinline` call, then used as an array index → 4-way `host==default==+mos-a16==+mos-xy16==0x7E5A` on **MAME + bsnes-jg**, PASS. **Measured finding (refined the plan's hypothesis):** the boundary is correct *by construction* — the RA allocates the cross-call-live index to a **callee-saved ZP imaginary pair** (`$rs10`, in the `JSR` preserve regmask), reloading it into X16 via `LDXImag16` only at the point of use; **physical X16 is NEVER live across a call**, so the narrowing `sep` before the `jsr` can't touch the ZP-resident value and there is no X16 spill (A2 fix = no-op). Contract formalized in the CC decision doc §"Index registers across calls — adopted" + the prior-art note. **Both xy16-specific levers measured + shelved:** (B1) i32-return-in-`A16:X16` census `dev/xy16ret32-census.sh` → REALISTIC `N_i32callsite=0` (same 0/realistic signature as the frame-ABI NULL), only 30 i32-returning call sites across all 1228 in-scope c-torture programs — realizing it needs an ABI-wide typed hole in the REP/SEP "8-bit at boundary" invariant for traffic realistic code doesn't produce; (B2) `PHX`/`PLX` hardware-stack index-spill — premise removed by the measurement (no physical-X16 spill across calls), bounded near-zero by the existing ZP-pressure slack (~5/14 pairs), and against the soft/static-stack-only grain. Codegen-inert: test + docs + census + an `a16_fuzz.py` comment only — no `vendor/`, no `0002` regen (corpus/fuzz/c-torture not re-run — guaranteed-pass + shared-box courtesy). [plan](docs/plans/2026-06-18-321-m2-xy16-calling-convention-verify-formalize-me.md).
- 2026-06-21 — [worktree-teardown-enforcement] **Worktree-teardown enforcement — keep durable artifacts, reclaim dupes (hook + wrapper).** Enforces the user policy (memory `worktree-teardown-keep-durable-artifacts`): on teardown reclaim the 95%+ `vendor/`+`build/` dupes but never lose the scripts/verdicts that reconstruct a conclusion; retain worktrees until upstream merge. Git has no `worktree remove` hook → the only intercept is a Claude Code **PreToolUse(Bash)** guard (`.claude/hooks/guard-worktree-teardown.sh`, wired in `.claude/settings.json`) that DENYs raw `git worktree remove` / `git branch -[dD] wt/…` and redirects to **`dev/worktree-teardown.sh`** — the blessed teardown that hard-aborts if any tracked work isn't on `main` (compares vs `main`, not the worktree's stale HEAD), then removes + reports reclaimed GB. Command-position-anchored matcher (mentions/`grep`/`list`/`add`/the wrapper pass through); the wrapper's internal removes are subprocess-exempt. `.gitignore` un-ignores `.claude/settings.json`+`hooks/` so the wiring is reproducible. Verified **15/15** (`dev/test-worktree-teardown.sh`): wt/321-track-a PASS (reclaim 12 GB); wt/320-far-cc ABORT on 2 unmerged commits. Schema confirmed via claude-code-guide. Committed `f2b61a2`. Follow-up: sha256 `hook-runner` integrity (deferred). [plan](docs/plans/2026-06-21-worktree-teardown-enforcement-hook.md).
- 2026-06-21 — [321-known-issues-xpass-guard] **#321: known-issues XPASS guard — surface "drop the entry" the moment a deferred bug is fixed.** The deferred RA/scavenger defects are XFAIL'd via `KNOWN_ISSUES` with *"REMOVE when fixed"* comments, but nothing **surfaced the trigger**: an upstream/RA fix would just make the repro silently verify clean, leaving a stale entry that masks a future regression of the same signature. New guard: `KNOWN_ISSUE_REPROS` table + `tools/a16_fuzz.py known-issues` subcommand asserts each repro (`a16regpress.c`→regalloc-out-of-registers, `a16scavnz.c`→scavenger-p-not-gpr) STILL crashes `-verify-machineinstrs` under **both** `+mos-a16` and `+mos-xy16` with its expected kid; **XPASS** (verifies clean) or **DRIFT** (different/no signature, or missing) → hard FAIL printing the exact follow-up (drop the `KNOWN_ISSUES` entry + promote to a positive gate). Pure host verify (no SDK/emulator/secret). Wired: `dev/known-issues.sh` + `dev/run.sh known-issues` + an **unconditional CI step** in `smoke.yml`'s `xcheck` job (after the toolchain build), so any push/PR carrying the fix turns CI red with the instruction. Verified: guard PASS 4/4 legs (host + container/CI path); a simulated fix (row → clean TU) trips a loud FAIL exit 1 with the drop+promote ACTION. (`a16-zp-pressure-overflow` out of scope — its repro is a gitignored c-torture *link* error, not a verify crash.) [plan](docs/plans/2026-06-21-321-known-issues-xpass-guard.md).
- 2026-06-21 — [321-xy16-verify-both-legs] **#321 xy16: both-legs verify hardening — a known `+mos-a16` issue can no longer mask a NEW `+mos-xy16` crash.** Follow-up to [321-xy16-verify-classify-known]: that fix still let the **a16** verify leg early-return `XFAIL` on a known issue *before* the **xy16** leg ran, so a genuinely-new xy16-only crash (e.g. an X-lattice regression) on a known-a16 program was silently hidden behind the a16 XFAIL. Hardening: in `evaluate()` run **both** legs (unless a16 is itself a NEW crash → fast-path early-out), then decide by priority — a **NEW (unclassified) crash on either leg hard-FAILs**, and only if neither leg has a new crash does a known issue on either leg yield `XFAIL`. Closes the masking gap for the population (16-bit-pressure programs) most likely to expose an X-lattice regression. Perf cost = one extra xy16 verify only for known-a16-issue programs (the 8 scavenger seeds, `globals`, the two repros) — negligible; clean-a16 already ran xy16, new-a16-crash still early-outs. Python-only tool change — no `vendor/`, no `0002` regen. Verified: a 7-row decision-table unit test (mocked `verify_machineinstrs`) ALL PASS incl. the critical **a16=known + xy16=new → CRASH**; `check` a16regpress/a16scavnz still XFAIL; `corpus-a16` 5/6 PASS + `globals` XFAIL (no flip, now both legs); builtin fuzz seed 306 → XFAIL `scavenger-p-not-gpr`. [plan](docs/plans/2026-06-21-321-xy16-verify-both-legs-hardening.md).
- 2026-06-21 — [321-xy16-verify-classify-known] **#321 xy16: classify known-issue crashes under `+mos-xy16` too — symmetric XFAIL in `evaluate()`.** `tools/a16_fuzz.py` `evaluate()` runs the MIR-verify crash gate under both `+mos-a16` and `+mos-xy16` (xy16 implies a16), but only the **a16** leg ran `classify_known()` → `XFAIL`; the **xy16** leg unconditionally returned `CRASH`, so a known, deferred defect tripping the xy16 verify mis-reported as a hard `FAIL` instead of a tracked `XFAIL`. Fix = mirror the a16 leg — `classify_known(vlog_xy)` → `XFAIL` ahead of the `CRASH` fallthrough (an *unmatched* xy16 crash still hard-FAILs, preserving the leg's X-lattice regression-guard role). The two known repros `a16regpress.c` (`regalloc-out-of-registers`) + `a16scavnz.c` (`scavenger-p-not-gpr`) fail MIR-verify under **both** modes with identical signatures (measured host-side), but both crash the **a16** leg first → via `check` they already XFAIL'd at the short-circuit; this is **latent-gap closure** (bites when a16 verifies clean but xy16 doesn't, or a sweep reaches the xy16 leg directly). Python-only tool change — no `vendor/`, no `0002` regen. Verified: host MIR-verify signatures match `KNOWN_ISSUES` under both modes; `check` still `PASS (known issue)` for both; direct unit exercise proves the xy16 leg now returns `XFAIL` (was `CRASH`); `dev/run.sh xy16ops` PASS + `corpus-a16` 5/6 PASS, `globals` XFAIL (no row flip); diff confined to the `if not ok_xy:` branch. [plan](docs/plans/2026-06-21-321-xy16-verify-leg-classify-known.md).
- 2026-06-21 — [321-xy16-track-a] **#321 xy16 Track A: `requiredXWidth` 8-bit-indexed-family hardening — the last `requiredXWidth` index-width omission, closed structurally.** Third + broadest member of the `requiredXWidth` omission family (after `55ec505` value-ops + `4d8a2bd` transfers/push): the broad 8-bit indexed/indirect family (`LDAAbsIdx`/`LDAZpIdx`/`ST{Abs,Zp}Idx`/`LDIndirIdx`/`STIndirIdx`, the 18 ALU-indexed `{ADC,SBC,AND,ORA,EOR,CMP}{Abs,Zp,Indir}Idx`, the 4 RMW `{ASL,LSR,ROL,ROR}Idx`, **and** the 4 a16-value/8-bit-index `*Idx16` forms `LD/ST{Abs,Indir}Idx16`) fell through `MOSInsertREPSEP::requiredXWidth` to `XW_None` (X-passthrough) instead of `XW_X8` — so a stray X=16 ambient at one would deref a 16-bit index with a garbage high byte (the addressing-index sibling of the pr49419 value-compare bug). Fix = a **memory-gated structural catch-all** `(mayLoad()||mayStore()) && readsRegister(X/Y) → XW_X8` after the `XLow` check + value-op switch, **plus** an index-reading-branch clause `isBranch() && readsRegister(X/Y) → XW_X8` that closes the `JMP (abs,X)` jump-table dispatch (`JMPIdxIndir`, the one family member the memory rule can't reach — a non-`mayLoad` branch). `TRI` threaded into `requiredXWidth` + all 3 call sites. The `mayLoad/mayStore` gate is the refinement over a bare `readsRegister`: it excludes the M-governed `T_A` (TXA/TYA), which reads X/Y as a *value* (mayLoad=mayStore=0) — a stray `sep #$10` before it would zero a live 16-bit X high byte (a real regression, not a size nit). **Correctness-safe + `HasIndex16`-gated**: verified 32/32 that every 16-bit-index (`Xc16`/`Yc16`) op carries `XLow=1` → returns `XW_X16` *before* the catch-all, so it can only ever insert a `sep`, never widen a live 16-bit value. **Hardening, not a live bug**: the gap is X8-pinned everywhere in real code, so the change is byte-identical on the corpus. Verified (clang-23 rebuilt): default+a16 disasm **byte-identical 75/75** (gating proof) + xy16 **byte-identical 75/75** + csmith 247/445 ROM-identical (inertness); corpus 7/7; xy16 suite (basic/ops/indiry/spill/spillr) + `k_isort` PASS both emulators; fuzz csmith 200×2 (seeds 101–500) **0 mismatch/0 crash** (one seed-488 MAME timeout was QUIET-box contention, re-verified PASS in isolation); **torture 60 PASS, 0 FAIL, 0 XFAIL** (the de-XFAIL'd pr49419/doloop-1/20041011-1/va-arg-22 rows stay XPASS); `-verify-machineinstrs` clean; `0002` round-trips with 0 foreign content (the `.td` `@@`-shifts are cosmetic — main's committed `0002` had drifted behind far-cc's `0001` growth; #321 content byte-identical). **No standalone RED test** (X8-pinned + LTO narrows small indices — a purpose-built candidate compiled byte-identical and LTO-narrowed to X8; shipped as code-inspection hardening like `55ec505`); regression guard = the structural-safety proof + the byte-identical proof + the c-torture suite. Closes the last known `requiredXWidth` index-width omission, full stop. [plan](docs/plans/2026-06-21-321-xy16-track-a-requiredxwidth-indexed-family-hardening.md).
- 2026-06-20 — [321-xy16-seed247-445] **#321 xy16 seeds 247/445 `+mos-xy16` miscompile — FIXED (approach B).** cvise-reduced to an 8-line UB-free repro; root cause: a non-index 16-bit value classed `Xc16`, loaded into X16 and left live across an 8-bit-index op whose index-narrowing `sep #$10` zeroes the X/Y high byte. Fix: `selectXY16`'s `G_LOAD16_ABS` emits the direct `LDXAbs16`/`LDYAbs16` only when the value is genuinely used as an index, else reclasses to `Imag16` and lowers through the accumulator (≈22 lines, `HasIndex16`-gated → a16/default byte-identical). Verified 4-way both emulators (incl. MAME) + csmith 101–500 (0 mismatch/400) + c-torture 60/60; `-verify-machineinstrs` clean; smaller code (`main` 61→54 B). Patch `0002`=`2d8ab51`; refuted A′ (pre-RA clobber) + #2 (scheduler) documented. See [reduction plan](docs/plans/2026-06-20-321-xy16-seed445-cvise-reduction.md) · [investigation](docs/investigations/65816-xy16-index16-highbyte-clobber.md).
- 2026-06-20 — [320-inc4-far-calls] **#320 Inc 4 Phase 1 — far CALLS (JSL/RTL) + Phase 0 far-pointer STORE (`sta [dp]`), two-emulator verified.** The cross-function half of #320 begins: a direct call to a function the linker placed in another 64 KB bank now emits **JSL** ($22, pushes a 3-byte PBR:PC) and the callee returns via **RTL** ($6B, pops 3). New `JSL`/`RTL` pseudos mirror `JSR`/`MOSReturn<RTS>`; `MOSCallLowering::lowerCall`/`lowerReturn` swap JSR→JSL / RTS→RTL when the callee/function is in a `.far_*` section, **`STI.hasW65816()`-gated** so default 6502 codegen is byte-identical. `.far_text`→`rom_1` (bank $01) added to `snes-far/link.ld`. `__far` = section attribute (no clang change); caller (JSL) and callee (RTL) are driven by the same attribute so they always agree. **MVP scope:** the far function is a LEAF — a far fn that `JSR`'d a near fn would keep PBR=$01 and run the wrong bank's bytes (mixed-banking + far function pointers + far tail calls are follow-ups; tail-call opt auto-skips since it keys on `MOS::JSR`). Gate `examples/65816/far_call.c` + `dev/far_call.sh`: `jsl` at the call + `rtl` in the far leaf, `far_leaf @ 0x18000` (bank $01), value 0xF3 crosses the boundary on MAME + bsnes-jg (far calls are a16-independent — 8-bit args). **Phase 0** closed the Inc 3 `sta [dp]` store loose end: `examples/65816/far_store.c` + `dev/far_store.sh` (disasm `87`, store-then-read-back 0xF3, both emulators). No regression: corpus 7/7 (near JSR/RTS intact), a16call/a16ret PASS, Csmith 27/30 (0 mismatch/crash), all 5 prior far ROMs PASS. In `0001` (a16-independent); new **`dev/regen-patch-0001.sh`** (sequential worktrees — 3-at-once overflowed /tmp) regenerates the far patch by isolating the far delta from 0002's interleaved a16 hunks, round-trip verified (0001 a16-free, 0002 still stacks). Gotcha recorded: a `.far_text` linker change needs `dev/run.sh build` (SDK rebuild), not just `toolchain` — else far code silently orphans into bank $00. [plan](docs/plans/2026-06-20-320-inc4-far-calls-and-far-pointer-cc.md).
- 2026-06-20 — [320-inc3c-far-arith] **#320 Inc 3c — runtime far-pointer arithmetic (`fp++` / `G_PTR_ADD` on AS2), two-emulator verified — Inc 3 COMPLETE.** The last deferred Inc 3 item. `fp++` on an `address_space(2)` far pointer now lowers and executes: `G_PTR_ADD {PF,S32}` skips the `G_INC` fast-path (32-bit base) → generic `ptrtoint`/`add`/`inttoptr`; the s32 ±1 add (`legalizeAddSub`) splits the value with `buildUnmerge(S8, s32)` = a **4×s8 ← s32 `G_UNMERGE_VALUES`** that was `unsupported()` — the one gap blocking 3c. Fix = the symmetric mirror of the existing `legalizeMergeS32FromBytes`: **`legalizeUnmergeS32ToBytes`** (`customFor({{S8,S32}})` under `hasAccum16`, in `0002`) rewrites it 2-level — unmerge s32→2×s16 (legal `{S16,S32}`), then each s16→2×s8 (legal `{S8,S16}`), reusing the 4 original byte defs; builds only unmerges so no merge↔unmerge artifact-combine loop. Default 8-bit codegen untouched (a16-gated). **Bonus:** also closes a latent a16 bug — a `uint32_t` shift-by-≥8 (`legalizeShiftRotate`) emitted the same unsupported unmerge; no test hit it yet. Gate `examples/65816/far_arith.c` + `dev/far_arith.sh` + `xcheck` row (bank $00, `fp++` then `lda [dp]`, `arr[1]=0xA9 ^ 0x5A = 0xF3`). Verified (clang-23 rebuilt): far_arith disasm `2a: a7 00 lda [$0]` + MAME `0xF3` + bsnes-jg `0xF3`; far_indir/far_cast/far-run/far-bank1 no regression; a16incdec/a16add/a16sub PASS both emulators; Csmith 27/30 (0 mismatch, 0 crash, 0 error); `0002` regen round-trips (only the `legalizeUnmergeS32ToBytes` hunk — 0 foreign, `0001` untouched). 3a/3b shipped in `0001`; this unmerge in `0002`. **#320 Inc 3 (3a+3b+3c) now complete**; far-pointer CC + far calls remain Inc 4 (upstream-gated). [task plan](docs/plans/2026-06-20-do-3c-finish-320-increment-3-runtime-far-pointer-a.md) · [inc3 plan](docs/plans/2026-06-20-320-far-pointer-runtime.md).
- 2026-06-20 — [320-inc3-far-runtime] **#320 Inc 3 — runtime far-pointer dereference (`lda [dp]`) + near→far cast, two-emulator verified.** A far pointer computed at RUNTIME (opaque via volatile, can't fold to absolute-long) now dereferences via 65816 indirect-long `lda [dp]` (opcode A7), and an AS0→AS2 `addrspacecast` zero-extends a near pointer to far (bank $00). Added the backend's **first first-class 32-bit ZP register** — `Imag32`, a quad over two `RS` words = 4 contiguous `__rc` bytes the `[dp]` mode reads (subreg indices `sublo16`/`subhi16`, `RL#K` entities, `getReservedRegs` quad-overlap reservation so a far ptr never lands on the stack ptr `RS0`/scavenger `RS8`, `getRegClassForType(32)`, a `selectMergeValues` 2×s16→Imag32 compose with two class-pin sites vs class-less bridge COPYs, `copyPhysReg`, `__rc`-symbol lowering) + 4 legalizer type-rules (`G_INTTOPTR`/`G_PTRTOINT`/`G_PTR_ADD`/`G_ADDRSPACE_CAST` for `PF`) + `tryFarIndirectAddressing`. Needs `+mos-a16` (a runtime far ptr is a 32-bit *value*; far machinery itself is a16-independent). The handoff's `LDA_IndirectLong` MC defs already existed (CC1_All multiclass) → `MOSInstrInfo.td` untouched. Gates `dev/run.sh far_indir`/`far_cast` (A7 + corpus_result=0xF3) + `xcheck` — MAME+bsnes-jg PASS; corpus 7/7, a16unmerge/a16spill/a16ptr + far-run/far-bank1 no regression; in `0001` (regen-patch.sh round-trips, 0002 re-stacked). **3c (far arithmetic) landed 2026-06-20** (the s32→4×s8 unmerge mirror — see [320-inc3c-far-arith] above); far-pointer CC deferred to Inc 4. [plan](docs/plans/2026-06-20-320-far-pointer-runtime.md).
- 2026-06-20 — [321-loadfold-unify] **#321 unify the a16 load-fold gate — measured, then SPLIT: AA-precision landed, volatile-drop closed net-negative.** Spun out of the load-fold-call-hazard audit §Deferred. **Phase 1** (instrument-and-count probes on a throwaway worktree, 2615 compile-only runs) confirmed both recoveries exist (Probe A 7 sites, Probe B 43). **Phase 2** built both halves + byte-diff'd, which **split the unification**: **(a) AA-precision LANDED** — `noStoreBetween`→**`noClobberBetween`** + a `mayAlias(AA,*Def)` check (an *ordered* store still hard-bails, so a volatile load never reorders across a volatile store); `AA` threaded through `foldable{Abs,Indir}Load16` + 10 call sites (the `GIMatchTableExecutor` base member). **−26 B** over the a16 corpus, **0 regressions**, verify-machineinstrs clean (0 new fails), all **5 Probe-A c-torture recovery sites + a 120-test sweep PASS** host==default==+mos-a16==+mos-xy16 on both MAME & bsnes-jg, `0002` round-trips (no foreign hunks). **(b) volatile-drop CLOSED (net-negative, not pursued)** — dropping `shouldFoldMemAccess`'s volatile bail is *correct* but measured **net +17 B / 19 regressions** (folding a single-use volatile load consumed as bytes loses to imag8: `a16abscmp` +43, `a16cmp` +37); a residency/schedule-gated version is high-effort for modest, entangled wins → **recorded, not a backlog item.** The literal single-helper merge was rejected by measurement (inherits `shouldFoldMemAccess`'s ordered-ref scan → regresses `a16abscmp`'s `volatile g1==g2` fold across the intervening operand load). Keepers: `dev/measure-loadfold-recovery.sh` (Phase 1 gate), `dev/measure-loadfold-bytes.sh` (Phase 2 byte-diff). [plan](docs/plans/2026-06-20-321-unify-loadfold-gate-aa-volatile.md) · [audit](docs/plans/2026-06-20-321-audit-a16-loadfold-call-hazard.md).
- 2026-06-20 — [321-a16-s32-merge-s8x4] **#321 fix: a16 `G_MERGE_VALUES` 4×s8→s32 legalizer gap (Csmith seed 113).** The Csmith Phase-4 sweep (seeds 101–300) found a `+mos-a16` LTO codegen crash: `LLVM ERROR: unable to legalize %_(s32) = G_MERGE_VALUES s8,s8,s8,s8 (in function: main)`. Extends the prior s32 work ([321-a16-unmerge-s32], which handled s32↔**s16**): under a16 s32 is 2×s16, so 2×s16→s32 merge is legal, but a **direct 4×s8→s32** merge (an i8→i32 sext the artifact combiner couldn't fold) hit `unsupported()`. `selectMergeValues` only takes a 2-source merge, so the fix is in the **legalizer**: a custom action (`legalizeMergeS32FromBytes`, gated `customFor({{S32,S8}})` under `hasAccum16()`) rewrites it into the legal 2-level form `merge(merge(a,b)→s16, merge(c,d)→s16)→s32`, which the artifact combiner folds — no selector change. Default codegen untouched. Repro is the deterministic Csmith seed (the merge is an LTO-only artifact; minimal C / per-TU IR don't reproduce, and a whole-module frozen `.ll` over-triggers by compiling runtime fns like `__adddf3` with +mos-a16 — so no hermetic `.ll`, gate is the differential). Verified (clang-23 rebuilt): `dev/run.sh fuzz --gen csmith 1 113` → `0x21B1` all-agree 0-crash (was crash); `a16unmerge` (s32↔s16 gate) still PASS; a16cmpaudit 0x5EE0; `0002` round-trips (`legalizeMergeS32FromBytes` only). [plan](docs/plans/2026-06-20-321-a16-s32-merge-s8x4-legalizer.md).
- 2026-06-20 — [321-abs-load-fold-across-call] **#321 fix: a16 load-fold must not move a load across a memory-clobbering call (the broad `-Os` c-torture sweep's only 2 FAILs).** The full `-Os` torture sweep (all 1168 in-scope, the first-ever `-Os` pass — prior full pass was `-O1`) found **2 FAILs: `pr34768-1`/`pr34768-2`** (default PASS, a16@MAME=a16@bsnes=`0xDEAD`). Root cause = a **pre-existing a16 backend miscompile** (NOT the middle-end — post-LTO IR is byte-identical to default and correct; NOT `9009260`): `foldableAbsLoad16`/`foldableIndirLoad16` fold a single-use same-BB 16-bit load into the consuming ALU/compare op as a memory operand (`adc abs`/`cmp abs`/`cmp (zp)`), but checked only single-use + same-BB — **never whether an instruction between the load and the user clobbers that memory**. With a call in between (`int tmp=g; clobber(); use(tmp,g)`), folding moves the read **past** the clobber → reads the mutated value. `pr34768` (`int tmp=x; (c?foo:bar)(); return tmp+x;`, `foo` does `x=-x`): at `-Os`, LTO const-props `c=1` → straight-line `foo()` call → a16 emitted `jsr foo; lda x; adc x` (= `x+x`, wrong) instead of saving `tmp` before the call; `-O1` passed only because it didn't const-collapse the ternary. Fix = new `noStoreBetween(Def,User)` scanning the strictly-between instrs; bail on any `mayStore()`/`isCall()`/`hasUnmodeledSideEffects()` → stage through `Imag16` as before (conservative per lesson #2 — a miss only forgoes a win). Applied to **both** helpers (`foldableIndirLoad16` from `9009260` shared the latent flaw). Buggy abs fold introduced in `ef4671d`. Default codegen unaffected (no 16-bit fold). Regression guard: `examples/65816/a16loadcall.c` + `dev/a16loadcall.sh` (abs + `(zp)` + compare operands across a clobbering call, host-verified 0x0100). Verified (clang-23 rebuilt): pr34768-1/-2 `-Os` PASS both emulators; a16loadcall 0x0100 4-way; **folds preserved** (a16cmpidx ≥5 `cmp (zp)`/a16abscmp/a16loadfold/a16mixfold/a16cmpaudit/a16cmp all PASS — no win lost); **full `-Os` re-sweep 1114 PASS / 0 FAIL** (was 2); fuzz 45/50 0-mismatch/0-crash; verify-machineinstrs clean; `0002` round-trips (noStoreBetween only, no foreign hunks). `86c2602`. **Audit follow-up 2026-06-20 (no code change):** swept every a16 load-fold site for the same across-call hazard — the two helpers fixed here were the **only** vulnerable ones; all others guard via `shouldFoldMemAccess` (8-bit `m_FoldedLd*`, `loadStoreValueIntoA16`) or explicit `isCall`/`mayStore` (`threadAccum16` + late peepholes). Did **not** consolidate onto `shouldFoldMemAccess` — it bails on all volatile loads, which would regress the #321 single-use *volatile*-operand folds the corpus relies on (a16abscmp/a16loadfold/a16mixfold); `noStoreBetween` is volatile-tolerant + across-clobber-safe, complementary by design. Bug class closed. [fix plan](docs/plans/2026-06-20-321-abs-load-fold-across-call-miscompile.md) · [audit plan](docs/plans/2026-06-20-321-audit-a16-loadfold-call-hazard.md).
- 2026-06-20 — [321-native-16bit-indexed-compares] **#321 native s16 — 16-bit RHS-indexed compare fold (`cmp (zp)`, CMPIndir16) + whole-compare-surface differential-audit.** Extend (#2) then harden (#1). Phase-0 measurement corrected the scope: `u16 arr[i]` does **not** become `lda abs,x` (the `*2` element scaling routes it through a computed pointer → `lda (zp)` plain-indirect, `G_LOAD16_INDIR`), so the gap is a RHS-indexed *indirect* compare and the fold instr is **`CMPIndir16` (`cmp (zp)`, $D2)**, not `CMPAbsIdx16` — cleaner: no index reg → no X-flag-lattice coupling, no frame-index concern. Before: `limit < arr[i]` staged `arr[i]` through an `Imag16` temp (`lda (zp); sta __rc; lda limit; cmp __rc` — the store survives, `lda limit` clobbers A16 between so threading can't remove it). Fix = new `CMPIndir16` MC instr (`MOSCMP16` + `PseudoInstExpansion<(CMP_Indirect addr8:$addr)>`, `Ac16:$l, Imag16:$addr`) + `foldableIndirLoad16` helper (single-use + same-BB `G_LOAD16_INDIR`) + a new `selectSbc16` RHS arm folding it to `cmp (zp)` instead of `CMPImag16`. Gated (lesson #2): single-use + same-BB → 1-to-1 volatile-safe; multi-use/cross-block/non-indirect → falls to today's `CMPImag16` (a miss only forgoes a win). LHS-indexed (`arr[i] < limit`) was already optimal (threads back into A16); `lim > arr[i]` swaps arr[i] to the LHS (`lda (zp); cmp`). EQ-indexed + `cmp abs,x`/`(zp),y` indexed forms + xy16-16-bit-index **deferred** (gate on a frequency scan). Regression guard: `examples/65816/a16cmpidx.c` (5 `cmp (zp)` folds, 0x1111 both emulators) + the Phase-3 audit harness `a16cmpaudit.c` (8 predicates × {value,branch} × 6 RHS shapes + LHS-indexed, host oracle 0x5EE0, host==default==a16 both emulators). Verified: a16cmpidx 0x1111 + a16cmpaudit 0x5EE0 (both 4-way agree), a16 compare suite 6/6, fuzz 50 0-mismatch/0-crash, torture 60/60, verify-machineinstrs clean; `0002` regen round-trips (only the CMPIndir16 hunk, no foreign symbols). [plan](docs/plans/2026-06-19-321-native-s16-16-bit-indexed-comparisons-rhs-cmp.md).
- 2026-06-20 — [321-xy16-xflag-lattice] **#321 xy16: fix the `requiredXWidth` index-width gap — ONE fix cleared all 5 remaining defects.** `MOSInsertREPSEP::requiredXWidth` enumerated the index-register *address/load/store/transfer* ops needing X=8 but omitted the index-register **value** ops: the compares `CMPImm`/`CMPImag8`/`CMPAbs` reading X/Y (→ `cpx`/`cpy`) and register `INC`/`DEC` (→ `inx`/`iny`/`dex`/`dey`). They fell through to `XW_None` (X-agnostic), so each ran in whatever X width was AMBIENT — and after a 16-bit-indexed load (`rep #$30`) the ambient is X=16, so `cpy #imm` read a 2-byte immediate and compared the loop counter's UNINITIALIZED high byte (the counter was created/incremented at X=8) → wrong bound → hang (`corpus_result` 0x0000) or wrong value. Root-caused via `pr49419` (MIR after `mos-insert-rep-sep`: `CMPImm $y,2` had a `sep #$20`-only restore before it, X still 16). Fix: classify those ops `XW_X8` when the X/Y operand is the compared/modified value (compares = operand 1, op0 is the `Cc` carry def; inc/dec = operand 0). Cleared the whole cluster: **pr49419, doloop-1, 20041011-1, va-arg-22** (all 4 xy16 `xfails.tsv` rows) **+ `k_isort`'s xy16 leg** — the shared-X-flag-cause hypothesis confirmed (as the frame-index fix cleared 13). xy16-only by construction (`requiredXWidth` is `HasIndex16`-gated; the pass early-returns unless `hasAccum16()` — default + `+mos-a16` untouched). Verified: torture XPASS ×4, `k_isort` 0xF47A all-agree (default==a16==xy16==host), fuzz 45/50 0-mismatch/0-crash + verify-machineinstrs clean, corpus 7/7; `0002` regen round-trips, diff exclusively this hunk. Regression guard: 4 de-XFAIL'd torture rows + `k_isort` (always-on xy16 leg). No standalone micro-test — the B2 16-bit-index gate still fires per-function (`xy16ops` PASSES) but **under LTO** (the differential harness links via `--config`) a provably-small global/pointer index narrows back to X8, so only `pr49419`'s double-indirect computed chase keeps a 16-bit index through LTO; a minimal global-array test would compile to all-X8 in the linked ROM and not exercise the X=16 ambient. [plan](docs/plans/2026-06-19-321-xy16-xflag-lattice-fix.md).
- 2026-06-19 — [321-jg-only-suite] **#321 bsnes-jg-only confirmation runner (`dev/run.sh xcheck-suite`).** MAME-skipping `JG_ONLY` pass over value-differential micro-tests; 45/45 PASS ~49 s incl. all 4 xy16 value tests; no BIOS/quiet-box needed. [plan](docs/plans/2026-06-19-second-emulator-jg-only-confirmation.md).
- 2026-06-19 — [321-corpus-a16-gate] **#321 `corpus-a16` differential gate (standing capability).** `dev/run.sh corpus-a16`; builds +a16/+xy16 vs default on both emus; VERIFIED 2026-06-19 arith/control/arrays/structs/funcs PASS, `globals` XFAIL. [plan](docs/plans/2026-06-19-321-corpus-a16-differential-mode.md).
- 2026-06-19 — [321-corpus-a16-ci] **#321 `corpus-a16` in CI — VERIFIED green (run `27823207476`).** Secret-gated step in `smoke.yml` `xcheck` job; +a16/+xy16 on MAME+bsnes-jg, `globals` XFAIL; first real CI run. [plan](docs/plans/2026-06-19-321-corpus-a16-ci.md).
- 2026-06-19 — [321-bsnes-jg-xcheck-ci] **#321 bsnes-jg `xcheck` in CI — VERIFIED green (run `27823207476`, ~1h46m cold; cached after).** `smoke.yml` `xcheck` job: from-source toolchain+SDK, `dev/run.sh xcheck` on bsnes-jg; first real CI validation. [plan](docs/plans/2026-06-15-wire-bsnes-jg-xcheck-into-ci.md).
- 2026-06-19 — [321-cmpbrabsimm16-frameindex] **fix the `CmpBrAbsImm16` frame-index elimination scramble — ONE line cleared 13 c-torture miscompiles.** `MOSRegisterInfo::eliminateFrameIndex` chose a frame object's displacement by a positional guess ("the operand after the frame index is its displacement immediate"); for the a16 fused pseudo `CmpBrAbsImm16` (`addr16:$l, i16imm:$r`) the post-address operand is the COMPARE immediate, so a16-LTO static/zero-page-stack accesses resolved to `base+compareImm` not `base+frameOffset` → wrong values → 0xDEAD. Fix: key the displacement source off the opcode (`LDStk`/`STStk`/`Addr{Lo,Hi}stk` → trailing imm operand; everything else incl. all `CmpBrAbs*` → the FI operand's own `getOffset()`). Default codegen unchanged by construction (no 8-bit instr has the FI-then-immediate layout). Root-caused via `20071210-1` (filed as a REPSEP/computed-goto suspect — it wasn't); the class sweep cleared 13 of 18 `xfails.tsv` rows (incl. `pr34768-1/-2` + `20010518-2`, both mis-hypothesized). Regression guard: 13 de-XFAIL'd torture rows + `examples/65816/a16frameidx` (0x4321 both emulators). Verified: corpus 7/7, fuzz 45/50 0-mismatch, a16 suite all-PASS (the `k_isort` xy16 fail is pre-existing, proven unrelated). `f2d65c2`; `0002` round-trips, no foreign hunks. [plan](docs/plans/2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md).
- 2026-06-19 — [321-torture-dg-require] **honor `dg-require-effective-target` in the c-torture Phase-0 filter — closes the oracle gap that admitted `pr7284-1`.** `tools/torture_filter.py` now denies the unsatisfiable integer-width requirements (`int32plus`/`int128`) before building, so UB-reliant tests (e.g. `pr7284-1`'s `n<<24` on 16-bit `int`) are bucketed `dg-require-unsupported` instead of passing default by UB-luck and "failing" a16 as false positives. In-scope 1253→1228 (58 dg-require-unsupported); `pr7284-1` removed from `xfails.tsv`. Harness-only (no `0002` change). [plan](docs/plans/2026-06-19-321-torture-honor-dg-require-effective-target.md).
- 2026-06-19 — [dwarf-round-trip] **DWARF round-trip (ROADMAP step 6) + drmon VS Code GUI: COMPLETE.** `-g` builds emit `<rom>.elf` companion; drmon loads it via libdwarf; source breakpoints fire in VS Code + MAME headlessly (8/8). `dev/run.sh dwarf` 7/7. Upstream PR halves drafted (lit test + `.elf` doc note). Left: user-triggered upstream posting (item 5 in upstream-contribution-status.md). [plan](docs/plans/2026-06-18-dwarf-round-trip-roadmap-step-6-drmon-tie-in.md).
- 2026-06-19 — [321-a16-unmerge-s32] **#321 `+mos-a16` s32 (`long`/`int32_t`) support — fixed the `G_UNMERGE_VALUES s32` backend abort.** Csmith-found (`wt/321-csmith` seed 11 + 9 more, XFAILed as `a16-unmerge-s32`): `+mos-a16` aborted on valid C using `int32_t`/`long` in s16-interacting shapes (e.g. `trunc i32→i16`), while DEFAULT compiled clean. Root cause: under `+mos-a16` s16 is a legal type so narrowing stops at s16 and diverts s32 into 2×s16 pieces, but the s32↔s16 legalizer glue didn't exist (no minimal fix — the cascade unmerge→trunc→anyext is the s32-under-a16 feature). Fix = **4 additive `hasAccum16()`-gated legalizer rules** (`G_ANYEXT`/`G_TRUNC`/`G_MERGE`/`G_UNMERGE` for s32↔s16); the artifact combiner folds the (un)merge so **no selector change**; `G_ZEXT` left at maxScalar S8 (raising to S16 broke s8→s16 zext). Verified: sweep **92/100 PASS, 0 mismatch, 0 xfail** (was 83/10/7); corpus-a16 5/6+xfail; hermetic `dev/run.sh a16unmerge` (frozen seed-11 `.ll`, **red-green validated** with fresh `mos-clang` — `llc` is stale, not in the `toolchain` rebuild path); `0002` regen round-trips. Remaining bookkeeping: remove the `a16-unmerge-s32` XFAIL on `wt/321-csmith`. [plan](docs/plans/2026-06-19-321-a16-unmerge-s32-legalizer.md).
- 2026-06-19 — [pre-public-polish] **Repo: Apache-2.0 LICENSE + NOTICE, README → M2, gitignore transcripts.** All four steps PASS (181af86). [plan](docs/plans/2026-06-14-pre-public-polish-license-readme-m2-gitignore.md).
- 2026-06-19 — [xy16-hang-verification] **#321 xy16: verified the runtime hangs are FIXED — no live hang remains.** The soft-stack P0 note's "35/50 `xy16@MAME=0x0000` hangs" were cleared by `8961afb` (byte-level `ldx/ldy/stx/sty` `XHigh` fix) + `4d8a2bd` (X-governed transfer/push-pull annotation). Fresh confirmation: `fuzz 50 1` and `fuzz 50 56` (the exact recorded-hang batches) = **50/50** each; `fuzz 500` = **492/500, 0 mismatch, 0 hangs**. Sole residual = 8 `$p`-spill **compile** xfails (169/173/196/268/271/272/306/420) — the separate `scavenger-p-not-gpr` item, not a hang. Corrected the stale "active area" triage note. (No code change — measurement only.)
- 2026-06-19 — [xy16-skeleton-comment-fix] **#321 xy16: corrected the stale `// skeleton`/`returns false for everything` comments on `selectXY16`** — the function is fully implemented (C1 direct + C2 `abs,X16`/`(zp),Y16` indexed); comment-only `0002` regen, round-trip PASS, no codegen change. [plan](docs/plans/2026-06-19-fix-the-stale-skeleton-comments-in-selectxy16-rege.md).
- 2026-06-18 — [repsep-x-annotation-for-x-governed-transfers-push] **#321 xy16: seed-31 FIXED — REPSEP X-annotation for X-governed transfers/push-pull unblocked the critical-edge fix. fuzz 500 → 492/500, 0 mismatch.** Two commits. **Commit A** (`4d8a2bd`): `requiredXWidth` now returns `XW_X8` for `TA` (TAX/TAY), `TX` (TXY/TYX) and `PH`/`PL` with `$x`/`$y` (PHX/PLX/PHY/PLY) — index transfers/push-pull whose width is X-flag-governed; the 8-bit-intent pseudos were `XW_None`, so when the dataflow holds X=16 across a loop back-edge an 8-bit `TAY`/`TYX` ran 16-bit and dragged B-accumulator garbage into `Y.high`/`X.high` (the M side never had this — `requiredWidth` defaults to `MW_M8`). `T_A` (TXA/TYA) left X-agnostic (M-governed). Monotone-conservative (only adds `sep #$10`). **Bonus: fixed seed-157** (a second transfer-in-held-X16 mismatch). **Commit B** (re-applied the reverted `B.begin()` critical-edge placement, now safe): replaces the whole-function `placeLegacy` bail with a single absolute-mode entry switch at the target block's start (retains `placeLegacy` only for the X-passthrough-conflict corner). Verified: seed-31/157/160 all pass; `fuzz 500` 491→492/500 with seed-31 the only FAIL→PASS delta (bisect: seed-160 PASS on both bail and B.begin paths, no new regression); corpus 7/7, xy16 suite green, verify-clean on 31/160, `0002` round-trips (foreign-hunks=5). Residual 8 fuzz crashes are the separate pre-existing `$p`-spill bug (own open item). [impl plan](docs/plans/2026-06-18-repsep-x-annotation-for-x-governed-transfers-push.md) · [critical-edge analysis](docs/plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md).
- 2026-06-18 — [321-repsep-critical-edge-x16-liveness] **#321 seed-31 critical-edge fix: implemented + verified-correct, then REVERTED (regresses seed-160) — investigation logged.** Root-caused seed-31 (the hang fix's lone fuzz-50 residual): `MOSInsertREPSEP` bails to `placeLegacy` on a true critical edge (`bb.1→bb.3`), which forces X=8 at every block terminator and truncates `$x16` live across `bb.0→bb.1` (`sep #$30` zeroes X.high → wrong `cpx` branch). Replaced the bail with a single `B.begin()` entry-switch (provably correct in isolation). **Fixed seed-31, fuzz 50/50, suite green** — BUT `fuzz 200` exposed a **regression at seed-160**: removing the bail makes critical-edge functions use the dataflow's loop-mode-*holding*, which surfaces a **pre-existing latent bug** — X-agnostic transfer instructions (`TAY`/`TYX`, whose width is governed by the X flag) drag B-accumulator garbage into `Y.high`/`X.high` when X16 is held across the back-edge. Per "never regress", **reverted** (vendor + `0002` byte-identical to the hang-fix commit). seed-31 is now **blocked on the transfer-instruction fix** (open). Also surfaced pre-existing 51–200 residuals: seed-157 (xy16 mismatch), seed-169/173/196 (`+mos-a16` `$p`-spill verify crash, pre-REPSEP). Lesson: a green fuzz-50 is not enough for a core-pass change — the wider sweep + bail-bisect caught it. [plan](docs/plans/2026-06-18-321-repsep-critical-edge-x16-liveness.md).
- 2026-06-18 — [321-xy16-hang-fix-xhigh] **#321 xy16 hang fix: byte-level `ldx/ldy/stx/sty` ran in X16 → 2-byte read/write corrupted adjacent ZP/struct bytes → soft-stack overflow → `xy16@MAME=0x0000`.** `XHigh=1` on 14 real X/Y instr defs (`MOSInstrFormats.td` CC0_Regular + `MOSInstrInfo.td`) **plus** `requiredXWidth()` register-residency for the generic load/store pseudos that only become `LDX_ZeroPage`/etc. at MC-lowering, after REPSEP (`LDAbs`/`LDImag8`/`LDImm`/`STAbs`/`STImag8`/`LDXIdx`/`LDYIdx` with `$x`/`$y` → `XW_X8`). Fuzz **16/50 → 49/50, all 34 hangs cleared**; corpus 7/7, xy16 suite green; `0002` round-trips. Lone residual = seed-31, a separate critical-edge X16-liveness bug (own open item). [plan](docs/plans/2026-06-18-321-xy16-hang-fix-xhigh.md).
- 2026-06-18 — [321-native-mode-crt0-xy16] **#321 native-mode crt0 DBR=0 contract.** `phk; plb` in `.init.50` makes DBR=0 an explicit contract; standing `crt0native` gate; fuzz 50/50 green. [plan](docs/plans/2026-06-18-321-native-mode-crt0-xy16.md).
- 2026-06-18 — [321-abs-x-indiry-indexed-load-store] **#321 Increment 1e: native 16-bit `abs,x` and `(zp),y` indexed load/store.** `tryIndexedAddressing16` detects `G_PTR_ADD(global, G_ZEXTLOAD(s16))` → `G_LOAD16_ABS_IDX` → `lda abs,x` (M=0); and `G_PTR_ADD(zp_ptr, G_ZEXTLOAD(s16))` → `G_LOAD16_INDIR_IDX` → `lda (zp),y` (M=0). 4 new GISel pseudos + 4 logical MC pseudos + selector helpers. G_ZEXTLOAD (not G_ZEXT) because IRTranslator fuses load+zext; safe to `buildTrunc(S8)` because G_ZEXTLOAD legalises to `G_MERGE_VALUES(lo, G_CONSTANT(0))` — RA cannot elide the explicit constant (cf. seed-56 crash where known-bits-zero path caused undefined-pair spill). `a16absidx` (BF, 0x9ABC) + `a16indiry` (B1, 0x5678) PASS on MAME + bsnes-jg; fuzz 100/100 (seeds 1–100), 0 mismatch; `0002` round-trips. [plan](docs/plans/2026-06-18-321-abs-x-indiry-16bit-indexed-load-store.md).
- 2026-06-18 — [321-mem-access-follow-ups] **#321 s16 memory-access follow-ups: all closed** — indirect/abs/copy-fold done; (a) indir-dst WON'T-DO: corpus check 2026-06-18 0/6 progs 0 B pattern absent; (b) moot; (c) WON'T-DO. [plan](docs/plans/2026-06-18-321-indir-dst-copy-fold.md).
- 2026-06-18 — [321-seed42-legalizeicmp-swap] **fix #321 fuzzer-found default-build miscompile: an EQ-canonicalization operand-swap in `0002`'s `legalizeICmp` leaked into the non-a16 8-bit path.** seed-42 (`dev/run.sh fuzz 1 42`, surfaced during a16ret verification) computed `corpus_result=0xB226` vs correct `0xEC0D` in BOTH default 8-bit AND `+mos-a16` builds (host=python-16bit + unpatched-upstream@MAME both 0xEC0D). Root-caused by ~20 isolated ccache-reuse build bisections: register topology (A16/B/Ac16) **innocent** (upstream+topology=0xEC0D), as were td/feature-infra, selector, InstrInfo, LateOpt, RegisterInfo, the unconditional InsertREPSEP pass (it early-exits `!hasAccum16`), and the legalizer constructor rules — narrowed to `MOSLegalizerInfo::legalizeICmp`. The FIRST of two EQ-canonicalization swaps was guarded only by `ComputedVsGlobal` (which does NOT require `hasAccum16` and has no `Pred==EQ` check), so in the default build a non-EQ compare (`<`/`>`) with a computed-s16-vs-foldable-abs-global operand pair hit `std::swap(LHS,RHS)` → **reversed the comparison** → wrong value. (The SECOND swap was correctly gated on `NativeS16Eq`; the first was missing it — exactly governing-lesson-#2: gate so a misclassification only misses a win, never regresses.) **Fix (1 line):** gate the first swap on `NativeS16Eq` (= `hasAccum16 && Pred==EQ && S16`), so it fires only in the intended native-a16-EQ path where EQ's Z-symmetry makes the swap safe. Verified: seed-42 default+a16 → `0xEC0D`; a16 suite **50/50**, corpus **7/7**, **fuzz 50/50** (0 mismatch); `a16eqvalmg` still native (`cmp` long fold ×2) + `0x0111`, verify-clean. `0002` regenerated — only `MOSLegalizerInfo.cpp` changed, no foreign hunks, round-trips. [fix plan](docs/plans/2026-06-18-321-seed42-legalizeicmp-swap-fix.md) ·
[found during a16ret](docs/plans/2026-06-17-321-ax-return-convention.md).
- 2026-06-17 — [321-ax-return-convention] **lock the A (low) / X (high) return convention as a tested ABI invariant (test+docs only, no codegen change).** The free, uncontroversial CC piece: `i8 → A`, `i16 → A(low):X(high)` is already emergent from `CC_MOS` byte-splitting (no `RetCC_MOS`) AND the documented prior art (WDC816CC p.21 / ORCA `A_X`). New `examples/65816/a16ret.c` + `dev/a16ret.sh` (wired into `dev/run.sh`): value differential `corpus_result==0x2387` host==default==+mos-a16 (MAME+bsnes-jg) + a byte-pinned disasm gate — i16 return is `ldx <high>; lda <low>; rts` (X reads `__rc`+1 vs A, proving high→X/low→A), i8 return delivers A alone. The value test catches miscompiles; the disasm gate catches convention drift (a value test alone can't — a consistent A↔X swap round-trips). Decision recorded in CC-analysis §"Return values — adopted" + the prior-art note. Verified: a16 suite 50/50, corpus 7/7, no `vendor/`/`0002` change. [plan](docs/plans/2026-06-17-321-ax-return-convention.md).
- 2026-06-17 — [321-unify-1b-1c-peephole] **retire 1b/1c GISel combiner peephole — native path now handles all shapes** (~1400 lines deleted; corpus 7/7, 5 in-scope a16 tests PASS, full suite 43/43 confirmed by concurrent task7 run, -verify-machineinstrs clean). [plan](docs/plans/2026-06-17-321-unify-1b-1c-peephole-into-native.md).
- 2026-06-17 — [321-task7-eq-residuals] **EQ-as-value task7: `computed==global` → `CmpBrImagAbs16` (`lda zp; cmp long`); items 2–7 confirmed-deferred.** New pseudo + legalizer `ComputedVsGlobal` gate + `foldableAbsLoad16(RHS16)` selector fold + canonicalization swap (`isFoldableAbsS16Load(LHS) && isImag16Resident(RHS)`) + `GlobalVsImm` guard; `a16eqvalmg` 0x0111 host==default==+mos-a16 (MAME+bsnes-jg, both orderings, 2×`cf` in-block + 2×`c5` cross-block fallback). Disasm gate: `cf` (CMP Long 24-bit, SNES global addressing), not `cd` (was a wrong gate). Spike measurements: item 2 (`x==0` as value) +5 B (native rep/sep worse than byte-OR); item 5 (indir-dst) already −13 B via 16-bit mode (selector reorder ~4 B more, corpus gain unverified → deferred); items 3/4/6/7 confirmed by prior spikes. `0002` round-trips (7×`CmpBrImagAbs16`, no TXY/TYX). [plan](docs/plans/2026-06-17-321-task7-eq-residuals-indir-dst-xflag-varshift.md).
- 2026-06-17 — [321-a16-threading] **A16-threading Phase 1.5: relax the redundant-reload peephole beyond strict adjacency (non-adjacent + multi-reload, threads across volatile stores).** Generalized `threadAccum16` so the `STAImag16`→`LDAImag16` pair need not be adjacent: intervening instructions are allowed if none rewrites `$a16` (`modifiesRegister(MOS::A16)` catches 8-bit sub-`A` writes + `xba`; calls/inline-asm bail) or overwrites the home. A volatile *store* between is fine (it only READS `$a16` — the store stays put, only the non-volatile reload of the `Imag16` temp drops; a volatile *load* writes `$a16` and is caught). Handles the multi-reload case (a kept store reloaded more than once — its pending entry survives until the store is actually erased) and clears stale `$a16` kills across the gap. **Measurement honesty:** the opportunity was first mis-sized at "~40/300 programs"; a mode-aware scan cut the byte-assembly false positives (`sta lo; stx hi; rep #32; lda` assembles a value, not a reload), then counting *all* `lda` (not just `lda __rcN`) as A16-clobbers cut the indirect/abs-load false positives — the **true** non-adjacent opportunity was ~14, of which Phase 1.5 captures all but **1**/300. Non-breaking: suite + kernels **47/47**, corpus 7/7, **fuzz 50/50** (0 mismatch/crash/error), `-verify-machineinstrs` clean over 47 examples + 150 fuzz programs (exercising volatile-store threading), `0002` round-trips (`threadAccum16` + `isInlineAsm`, no `TXY`/`TYX`). **Phase 2 retired** (fold-while-threaded already optimal); Phase 3 (RA-level `Ac16` residency) stays deferred. [plan](docs/plans/2026-06-17-321-a16-threading.md).
- 2026-06-17 — [321-a16-threading] **A16-threading Phases 0–1: eliminate the redundant Imag16 round-trip between dependent native-s16 ops (coalescer-free; −31/−36 % on dependent chains).** The ROADMAP-step-5 "biggest win", de-risked by the Tier-1 corpus. Each native s16 op is self-contained (`LDAImag16 → OP → STAImag16`, value home = `Imag16` between ops — the 1d-retry coalescer-safe invariant), so a dependent chain stores each intermediate and **immediately reloads it** (`sta __rcN; lda __rcN`). **Phase 0 (measure):** 20 such round-trips across the test set (12 synthetic, 8 in real kernels). **Phase 1 (the fix):** a new post-RA peephole `threadAccum16` in `MOSLateOptimization.cpp` — when `$rsN = STAImag16 $a16` is immediately followed by `$a16 = LDAImag16 $rsN`, erase the redundant reload (`$a16` already holds the value) and DCE the dead store, so the value threads through `$a16` across the chain (`lda;adc;and;sbc;…;sta`). **Post-RA on purpose:** RA has already chosen `$a16` both sides, so collapsing the pair cannot reintroduce the 1d coalescer crash (an 8-bit value coalescing into `A16`); `LDAImag16`/`STAImag16` model no NZ def, so erasing them is flag-safe; strict adjacency keeps it conservative. **Measured:** all 20 round-trips → 0; chain3 39→27 B (−31%), chain5 55→35 (−36%), k_crc16/k_prng/k_bits/k_isort −4/−8/−8/−10 B. New `examples/65816/a16thread.c` + `dev/a16thread.sh` (0 round-trips, 1 rep/sep bracket, corpus_result 0x2544 host==default==+mos-a16 on MAME + bsnes-jg) + reusable `dev/measure-a16-threading.sh`. Non-breaking: a16 suite + kernels **47/47**, corpus 7/7, **fuzz 50/50** (0 mismatch/crash/error), `-verify-machineinstrs` 47/47 clean (incl. `a16localx`, the coalescer-crash guard), `0002` round-trips (carries `threadAccum16`, no `TXY`/`TYX` — F4 stays in `0003`). Phases 2 (selection-time fusion) + 3 (RA-level `Ac16` residency) remain — see Open. [plan](docs/plans/2026-06-17-321-a16-threading.md).
- 2026-06-17 — [321-native-s16-eq-v2-computed-imag16-lhs] **native s16 equality-as-value v2: COMPUTED / Imag16-resident operands go native (`(a+b) == (c+d)`, −3 B; multi-use chained −13 B).** The last gated EQ-as-value win from the spike. A **gate-only** change (no new pseudo — rides the existing `buildNZSelect → MOSLowerSelect → G_BRCOND_IMM → CmpBrImag16/CmpBrImm16` path): `legalizeICmp` now fires native EQ when both operands are already **Imag16-resident** (a computed native-s16 value or an indirect load) or one is a constant. `isComputedS16` matches the generic ALU/shift ops (G_ADD/SUB/AND/OR/XOR/SHL/LSHR/ASHR) **and** the load-rooted MOS combiner pseudos (G_ADD16_ABSLD/G_SUB16_ABSLD/G_ADDCHAIN16_ABSLD/G_BITCHAIN16_ABSLD — a multi-use `(a+b)` of globals becomes G_ADD16_ABSLD, not generic G_ADD); `ComputedEq` fires only when neither operand is a register-arg (which would spill — the +8 B regression the spike measured) or a global (v3's domain). **Measured:** computed==computed −3 B, computed==const −2 B, the multi-use chained test 146→133 B (−13 B), and `computed == param` **byte-identical** (gate declines → no regression). New `examples/65816/a16eqvalc.c` + `dev/a16eqvalc.sh` (native 16-bit cmp, cmp #imm for the const, no cpx/cpy; corpus_result 0x1101 host==default==+mos-a16 on MAME + bsnes-jg). Non-breaking: a16 suite + corpus 7/7, **fuzz 50/50** (0 mismatch/crash/error), `-verify-machineinstrs` clean, `0002` round-trips. Completes the four gated EQ-as-value wins (v1/v3/imm/v2). [plan](docs/plans/2026-06-17-321-native-s16-eq-v2-computed-imag16-lhs.md).
- 2026-06-17 — [321-native-s16-eq-imm-constant-through-merge] **native s16 `g == 0x1234` folds to `lda abs; cmp #imm` — recover the byte-split constant (+ lights up the dormant `CmpBrImm16`).** The v3 follow-up: a 16-bit constant EQ operand is byte-split into `G_MERGE_VALUES(i8 lo, i8 hi)` during legalization (a `G_CONSTANT i16` is illegal), so the EQ matcher `CmpNZImm16_match` — which recovered the RHS only via `getIConstantVRegValWithLookThrough` — missed it and fell to `CmpBrImag16` (constant materialized). Added a shared `getI16Const(R, const MRI&)` that recovers a constant directly OR through `G_MERGE_VALUES` of two byte constants (two non-constant byte loads → nullopt, so `g == h` isn't mistaken for an immediate), used it in `CmpNZImm16_match`, and DRY'd `getImm16Operand` (the ordering/ALU path already had this exact logic) to call it. Re-instated the `CmpBrAbsImm16` pseudo + the `selectBrCondImm` `m_CmpNZImm16` fold (foldable-abs LHS → `lda abs`, const RHS → `cmp #imm`; else the now-reachable `CmpBrImm16`) + `expandCmpBr16`/dispatch/`getBranchDestBlock`, and the `GlobalVsImm` gate disjunct (+ canonicalization swap) in `legalizeICmp` so value-use `g == imm` goes native. **Bonus:** v1's `*p == 0x1234` and the branch `if (g == 0x1234)` now select `CmpBrImm16` → `cmp #imm` (was materialized `LDImm16`+`cmp zp`). `examples/65816/a16eqvalg.c` extended with `r3 = (g0 == 0x1234)` (3 `CmpBrAbsAbs16` + 1 `CmpBrAbsImm16`; gate asserts `cmp #imm16`, no `cmp zp`, no `cpx/cpy`; corpus_result 0x1101 host==default==+mos-a16 on MAME + bsnes-jg). Non-breaking (the `getImm16Operand` refactor is byte-identical — `a16imm`/`a16localimm`/`a16chainimm` green): a16 suite + corpus 7/7, **fuzz 50/50** (0 mismatch/crash/error), `-verify-machineinstrs` clean, `0002` round-trips. [plan](docs/plans/2026-06-17-321-native-s16-eq-imm-constant-through-merge.md).
- 2026-06-17 — [321-native-s16-eq-as-value-v3-abs-fold-globals] **native s16 equality-as-value v3: both-global `g1 == g2` folds to native `lda abs; cmp abs` (−48 B / −24% on a chained test).** Building on v1, an s16 `g1 == g2` consumed as a VALUE (and the branch `if (g1 == g2)`) now reads BOTH globals in place — `rep; lda abs g1; cmp abs g2; sep; beq/bne` + 0/1 — instead of round-tripping each through an `Imag16` pair (the blanket-native form the v1 spike measured as +4 B in isolation) or narrowing to the 8-bit cpx/cmp chain. New pseudo `CmpBrAbsAbs16` (mirrors `selectSbc16`'s `a16abscmp` fold on the EQ branch-pseudo path): gate `BothGlobal` (`isFoldableAbsS16Load` ×2, single-use) in `legalizeICmp`, the fold in `selectBrCondImm`'s `m_CmpNZImag16` block (erases the two folded `G_LOAD16_ABS`; the dead `COPY`+`G_SBC` are cleaned by `isTriviallyDead`), `expandCmpBr16` → `LDAbs16; CMPAbs16; BR`, and `analyzeBranch` now scans ALL memrefs for volatility (`CmpBrAbsAbs16` carries two). **Measured −48 B** (`a16eqvalg` `.text.main` 0x9a vs the gate-disabled 8-bit baseline 0xca) — confirming the spike's +4/+12 "regressions" were isolated-leaf artifacts (in 16-bit-ambient code even the non-folded native form beats 8-bit). Single + independent both-global compares fold fully; deep expression-chaining hoists some operands cross-block (volatile → can't fold safely) but those stay native (still a win). **`g1 == 0x1234` deferred** — the 16-bit constant is byte-split (`G_MERGE_VALUES`) before selection, blocking `CmpBrAbsImm16` and the dormant `CmpBrImm16` alike (needs a `CmpNZ16` constant-through-merge fix; see Open). New `examples/65816/a16eqvalg.c` + `dev/a16eqvalg.sh` (native disasm gate + 0x0101 host==default==+mos-a16 on MAME + bsnes-jg). Stale gates in `a16eq` (branch) + `a16eqval` (value) updated — v3 improved their global compares from `cmp zp` to `cmp abs/long` (the `a16eqval` byte-wise stopgap is now superseded). Verified: a16 suite 36/36, corpus 7/7, **fuzz 50/50** (0 mismatch/crash/error), `-verify-machineinstrs` clean, `0002` round-trips. [plan](docs/plans/2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md).
- 2026-06-17 — [321-native-s16-eq-gated-impl] **native s16 equality-as-value v1: an indirect-load operand goes native (−4 B).** `b = (*p == c)` consumed as a VALUE narrowed to the 8-bit cpx/cmp two-byte chain even under +mos-a16. A spike proved the *blanket* native form regresses register/global operands (the native compare routes the LHS through `Imag16` + `rep`/`sep` that the tight 8-bit `cpx;cmp` avoids), so it is **gated** (`isIndirectS16Load` in `MOSLegalizerInfo::legalizeICmp`) to fire only when an EQ operand is a non-absolute (indirect) s16 load — there the value already lands in `Imag16`, so the native 16-bit compare reads it directly (`rep; lda (zp); cmp; sep; beq/bne` + 0/1 materialize) instead of unmerging it back to bytes; `eq_deref` 38→34 B. **No new pseudo** — the value materializes via the existing `buildNZSelect → MOSLowerSelect → G_BRCOND_IMM → CmpBrImag16` path (the original `CmpSelImag16` sketch proved unnecessary). Subsumes the closed indirect-s16-load byte-wise follow-up (a native EQ keeps the operand 16-bit → no `G_UNMERGE`, no spill-vs-byte-spill dilemma). Verified: register/global/computed shapes byte-identical (no regression), `-verify-machineinstrs` clean, ambient indirect-EQ native; `examples/65816/a16eqvalp.c` host==default==+mos-a16 0x0101 on MAME + bsnes-jg; suite 44/44, corpus 7/7, **fuzz 50/50** (F4-fixed build, 0 mismatch), `0002` round-trips (no F4 leakage). v2 (computed-LHS) + v3 (abs-fold globals) remain — see Open. [plan](docs/plans/2026-06-16-321-native-s16-eq-gated-impl.md).
- 2026-06-16 — [321-indirect-s16-load-bytewise] **indirect s16 load consumed only as bytes: investigated → WON'T-IMPLEMENT.** The byte-wise-load fix (`7c0fe56`) gates only the *absolute* s16 load; the open question was whether to extend the `AllUsesUnmerge` guard to the **indirect** load (`G_LOAD16_INDIR`, `legalizeLoadStore16`). Measured native-vs-byte-wise via a scratch `!AllUsesUnmerge` gate: in isolated **leaf** functions byte-wise won −6 B (no `rep`/`sep`/spill island), BUT `+mos-a16` runs predominantly in **16-bit (M=0)** mode, and re-measuring in 16-bit-ambient code showed the win is **schedule-dependent** — byte-wise wins only when the load is *adjacent* to its byte-compare (`loop_deref` −6 B) and is a **+2 B regression** when 16-bit math is scheduled between load and compare (`mixed_deref`, the common shape), because it then carries two byte-spills across that region vs the native form's one word-spill. The blanket gate can't distinguish them, so it fails the "not meaningfully worse elsewhere" bar. The real fix is **native s16 EQ-as-value** (removes the `G_UNMERGE` entirely) — folded into the Open M2 native-EQ item. Tree left native (scratch reverted, codegen byte-identical to baseline). [plan](docs/plans/2026-06-16-321-indirect-s16-load-bytewise.md).
- 2026-06-16 — [321-s16-load-unmerge-bytewise] **s16 equality-as-value prologue regression FIXED: an s16 load consumed only by `G_UNMERGE` now loads byte-wise.** Investigating M2 item (c) (`b = (a == c)`) surfaced a `+mos-a16` *regression*: the s16 operand loads were emitted as native 16-bit `G_LOAD16_ABS` (`lda abs → A16; sta imag16`) and then the 8-bit-narrowed compare `G_UNMERGE`d them straight back into bytes — a wasteful round-trip the default build never does. Fix (`MOSLegalizerInfo::legalizeLoadStore16`): when every use of an s16 load is `G_UNMERGE`, skip the native 16-bit load and fall to the byte-wise `narrowScalar` (matches default). `b = (a == c)` now loads operands byte-wise (no `rep`-bracketed prologue before the compare) — back to parity with default. Regression `examples/65816/a16eqval.c` + `dev/a16eqval.sh` (`corpus_result == 0x0101` host==default==a16 on both emulators + a no-prologue disasm gate). Non-breaking: suite 42/42 (now 43 w/ a16eqval), corpus 7/7, fuzz 50/50; `0002` round-trips. The FULL native equality-as-value (a fused compare-select) remains deferred — see Open M2. [plan](docs/plans/2026-06-16-321-s16-load-unmerge-bytewise.md).
- 2026-06-16 — [321-softstack-ac16-spill] **F3 follow-up FIXED: the soft-stack (reentrant) `Ac16` spill.** The static-stack F3 fix left the soft-stack spill path with the same `Imag16`-only gap — a reentrant `+mos-a16` function holding a 16-bit value in the accumulator across a call crashed (`Scavenger spill for register not yet implemented` / `SelectImm $a16`) because `MOSRegisterInfo::expandLDSTStk` fell `Ac16` through to a byte path that `COPY`ed `A16` to an 8-bit GPR (the high byte `B` isn't byte-addressable without `XBA`). Fix: spill `Ac16` with one 16-bit **indirect** `STAIndir16`/`LDAIndir16` through a slot pointer formed in the spill's reserved `Imag16:$scratch` (reusing the existing far-offset `AddrLostk`/`AddrHistk` machinery — no new post-RA allocation) — the indirect analog of the static `STAbs16`/`LDAbs16` fix. Proved the crash on the pre-fix build first (recursion forces the soft stack: `MOSNonReentrant` only marks non-recursive functions `nonreentrant`). Regression `examples/65816/a16spillr.c` + `dev/a16spillr.sh`: `corpus_result == 0x3457` host==default==+mos-a16 on MAME + bsnes-jg; the MLow=1 op is rep/sep-bracketed. Non-breaking: suite 42/42, corpus 7/7 (incl. recursive `funcs`), fuzz 50/50; `0002` round-trips. [plan](docs/plans/2-one-tracked-follow-up-glimmering-ladybug.md).
- 2026-06-16 — [321-fix-cmp-value-selectimm] **F3 FIXED (the `SelectImm $a16` crash → `fuzz 50 1` 50/50, 0 xfail): spill the 16-bit accumulator `Ac16` via a direct 16-bit `LDAbs16`/`STAbs16`, not a COPY through an 8-bit GPR.** Root-caused to **register allocation**, not the legalizer: `MOSInstrInfo::loadStoreRegStackSlot` only special-cased `Imag16`, so an `Ac16` value spilled across a call fell through to a single-byte path that emitted `GPR = COPY A16` → `copyPhysRegImpl` (`:743`, `Anyi1` branch) → invalid `SelectImm $a16`. Added an `Ac16` case using `LDAbs16`/`STAbs16` to the frame index, restoring the native-s16 invariant ("A16 entered/left only via 16-bit load/store"). The first-guess legalizer-gate fix (the s16 ordering native gate lacking the equality gate's all-uses-are-`G_BRCOND_IMM` guard) was implemented and **disproven** first (clean SSA, but all 8 seeds still crashed post-RA; reverted). Verified: repro + 8 seeds compile clean; `fuzz 50 1` → 50/50 (seed 1 `0x525C`, seed 7 `0x9447`, all four oracles agree); a16+kernels suite 40/40, corpus 7/7; `0002` round-trips. New regression `examples/65816/a16spill.c` + `dev/a16spill.sh` (compile-time gate; the fuzzer de-XFAIL covers values). Follow-up: soft-stack `Ac16` spill (`expandLDSTStk`) has the same gap (pre-existing, corpus-unreachable). [plan](docs/plans/2026-06-16-321-fix-cmp-value-selectimm.md).
- 2026-06-16 — [321-tier1-broaden-corpus] **Tier 1: broaden the test corpus — the safety net that de-risks A16-threading (Tier 2) + peephole unification (Tier 3).** A **differential** corpus: each program's `corpus_result` must agree across host-computed == default(trusted 8-bit) == `+mos-a16` on **both** MAME and bsnes-jg, plus `-verify-machineinstrs`. (1) Seeded **fuzzer** `tools/a16_fuzz.py` + `dev/run.sh fuzz [N] [seed]` — random UB-free C over mixed 16/8-bit vars and the full operator set, with a Python evaluator validated 500/500 against host gcc, delta-reduced triage, XFAIL-classified known issues; `fuzz 50 1` → 42/50 PASS + 8 xfail, **0 mismatch/crash/error**. (2) Six **kernels** (`k_crc16` 0x29B1, `k_fxmul`, `k_prng`, `k_bits`, `k_satadd`, `k_isort`). (3) Two **combinatorial** tests (`a16mix1/2`). It immediately found **3** real defects (next two entries + the deferred SelectImm crash). Non-breaking: a16 suite + kernels + combinatorial = **40/40** on a quiet box, corpus 7/7. [plan](docs/plans/2026-06-15-321-tier1-broaden-corpus.md).
- 2026-06-16 — [321-fix-asl-lsr-carry-clobber] **backend fix (found by Tier-1 `k_crc16`): 16-bit `asl`/`lsr` must model the carry clobber.** A CRC16 differential FAIL (`+mos-a16` 0x036D ≠ correct 0x29B1, both emulators agreeing → deterministic miscompile) minimized to `if (crc & 0x8000) crc=(crc<<1)^P; else crc=crc<<1;`: the hoisted common `crc<<1` (`ASLAcc16`) was scheduled **between** the `cmp` and its `bcs`, clobbering the branch carry (carry := bit 15). `ASLAcc16`/`LSRAcc16` declared no carry def, so the scheduler placed them in a live-carry interval. Fix: `let Defs = [C]` on both (`MOSInstrLogical.td`); `RORAcc16` already modeled carry, `INC/DECAcc16` correctly don't clobber C. Regression `k_crc16` → 0x29B1 both emus; native shifts unaffected; `0002` round-trips. [plan](docs/plans/2026-06-15-321-tier1-broaden-corpus.md).
- 2026-06-16 — [321-fix-ashr-ge8-hang] **backend fix (found by Tier-1 fuzzer): signed `>>` by ≥ 8 hung the compiler.** 5 fuzz seeds timed out the `+mos-a16` compile; minimized to a 2-line `(short)g >> 8` that never terminates (`>> 7` is fine — the native ASHR path covers 1–7; unsigned `>>` is fine; default build compiles in 0.04 s). The `Amt >= 8` byte-decomposition path computed the ASHR sign-fill with an s16 `ICMP_SLT(Src,0)`; under `+mos-a16` that re-enters the native signed-compare legalization as a compare-result-as-VALUE and loops. Fix: 8-bit `AShr(highByte, 7)` sign broadcast — no s16 compare (`MOSLegalizerInfo.cpp`). Regression `a16ashift8` → 0x001F both emus (amounts 8 & 13, neg + pos); `0002` round-trips. Harness hardened too: `_run` retries an environmental timeout, a *persistent* one is surfaced as a triaged CRASH. [plan](docs/plans/2026-06-15-321-tier1-broaden-corpus.md).
- 2026-06-15 — [321-native-s16-bitwise-chains] **ALU-chain ext: 16-bit AND/OR/XOR chains.** A homogeneous ≥3-term bitwise chain of near-abs globals now threads the running value through A16 (`lda a; and b; and c; sta`) with **no carry-init**, the bitwise analogue of the add chain. `collectAddChain` generalized to `collectAluChain` (parameterized by the chain operator + per-op constant fold); new `bit_chain16`/`bit_chain16_ld` combiners + `G_BITCHAIN16_ABS{,LD}` pseudos (opcode-parameterized) + `selectBitChain16`. ADD path left untouched (only the shared walk generalized). SUB chains moot (reassociated to `a-(b+c)`). `a16bitchain` reads 0x6261 (AND/OR/XOR, store + multi-use). 31 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-s16-bitwise-chains.md).
- 2026-06-15 — [321-native-s16-add-chain-immediate] **ALU-chain ext: immediate term in an add chain (`a+b+c+K`).** A constant in a ≥3-term add chain had broken the chain match (every leaf had to be a load), dropping the whole chain to the round-tripping per-add path. `collectAddChain` now folds constant leaves into one running immediate (rematerializable, never erased), and both chain forms end in `adc #imm` (`lda a; clc; adc b; clc; adc c; clc; adc #K; sta`). Threshold is `loads + (const?1:0) >= 3`, keeping the 2-operand cases (`a+b`, `a+K`) on the `alu16_abs`/`absld` immediate path. `a16chainimm` reads 0x2569 (store + multi-use forms). 30 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-s16-add-chain-immediate.md).
- 2026-06-15 — [320-321-c-abi-prior-art] **standalone 65816 C calling-convention prior-art note (WDC816CC / ORCA-C).** Documented prior art for the #320/#321 calling-convention decision, read **firsthand** from primary sources: WDC816CC manual pp.21–26 + ORCA/C `Gen.pas` (`GenEnt` emits `tsc/phd/tcd`; `A_X` return class). Both shipped-in-production compilers converge on a **hybrid** frame — args on the hardware stack, then `PHD`/`TCD` remap the Direct Page onto the frame for fast 8-bit-offset locals (hard **256-byte frame cap**, "partly done for speed"), return in **A** (low)/**X** (high); the `near`/`far` keyword model maps onto #320's addrspaces. Surfacing upstream rides the user-triggered #320 posting. Sources vendored (gitignored — redistribution-restricted) at `docs/refs/65816-c-abi/` + `dev/fetch-refs.sh` (sha256-verified). [note](docs/320-321-65816-c-abi-prior-art.md) · [plan](docs/plans/2026-06-15-wdc816cc-orca-c-65816-c-abi-prior-art-note-primary.md).
- 2026-06-15 — [321-native-s16-add-chain-multiuse] **load-fold (c): multi-use add chain (`t = a+b+c+d`, reused).** A ≥3-term add chain of near-abs globals whose result is reused — which `add_chain16` (store-rooted) couldn't reach — now threads the running sum through A16 via a new `add_chain16_ld` combiner → `G_ADDCHAIN16_ABSLD` → `lda a; clc; adc b; clc; adc c; clc; adc d; sta t`, dropping the N−2 intermediate `sta tmp; lda tmp` Imag16 round-trips. Mirrors how `alu16_absld` extended `alu16_abs`; reuses `collectAddChain` over the root's operands (multi-use root, single-use interior). `a16chainld` reads 0x1234 (sum stays in A16: 1 `sta zp`, not 3). **Completes all load-fold follow-ups (a/b/c).** 29 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-s16-add-chain-multiuse.md).
- 2026-06-15 — [321-native-s16-inc-dec-abs] **`inc a`/`dec a` for global `g ± 1` (+ `inc abs` rejected).** `selectAlu16Abs` now emits `lda <g>; inc/dec a; sta <g>` for a global ±1 instead of `clc; lda; adc #$0001; sta` (3 instrs vs 4), keeping the compiler's 24-bit long addressing. A single `inc abs`/`dec abs` memory-RMW was prototyped and **reverted**: the 65816 has no `inc long`, `inc abs` is DBR-relative, and this platform's native-16 path uses DBR-independent long loads/stores (the 8-bit `abs` path *is* DBR-relative — see the 2026-06-18 native-crt0 DBR=0 work) — the RMW only works via the low-8KB WRAM mirror (DBR=0 + bank-0 LoRAM), a latent miscompile for any high global. `a16incabs` reads 0x3502 (3 inc + 1 dec, no adc #1, no ee/ce). 28 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-s16-inc-dec-memory-rmw.md).
- 2026-06-15 — [321-native-s16-inc-dec] **1-byte `inc a` / `dec a` (register ±1).** A 16-bit register/local `x ± 1` had dropped to an 8-bit byte inc/dec-with-carry chain (sep/ldx/inc-zp/bne/inc-zp/rep) thrashing M-mode in a 16-bit region. `legalizeAddSub` now keeps s16 ±1 un-narrowed under +mos-a16 and `selectAlu16Native` emits one `inc a`/`dec a` (new `INCAcc16`/`DECAcc16` MLow=1 pseudos; ADD+1/SUB-1→inc, ADD-1/SUB+1→dec). `a16incdec` reads 0x2668 (2 inc + 2 dec, no byte chain); `a16loopred` guards that a counted `while(i){x++;i--}` still strength-reduces to a native 16-bit add (0x1239). Bonus: the now-native trailing `+1` removes a forced mode switch in a16ashift (drops a sep) and a16ptr (merges 2 rep brackets); both gates updated. Variable/≥8 shifts intentionally left (libcall / byte-relabel already optimal); memory-RMW `inc abs` is the follow-up. 27 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-s16-inc-dec-accumulator.md).
- 2026-06-15 — [321-native-s16-single-use-non-store-fold] **load-fold (b): single-use-non-store results.** A both-global ALU op whose single-use result does not feed a near-abs store (the case `alu16_absld` skips via its `>1 use` guard, `alu16_abs` as a non-store) folds both operands directly in `selectAlu16Native` — covered implicitly by the mixed-operand fold (keyed on operands, not result use-count). No new codegen; `a16sunfold` (0x3480 both emus, 0 globals materialized) is the regression guard. 25 a16* tests + corpus 7/7 green; patch `0002` unchanged + round-trips. [plan](docs/plans/2026-06-15-321-native-s16-single-use-non-store-fold.md).
- 2026-06-15 — [321-native-s16-mixed-operand-fold] **mixed-operand load-fold (`t = a16v OP local`).** `selectAlu16Native` reads a single-use near-abs global operand directly instead of materializing it into an Imag16 pair — two fold sites: operand A → LHS `lda abs` (`LDAbs16`), operand B → absolute ALU form (`adc|sbc|and|ora|eor abs`). Uniform across ADD/SUB/AND/OR/XOR; correct for both SUB directions (minuend is always the loaded A) with no commutativity swap. Volatile-safe 1-to-1 fold (reuses `foldableAbsLoad16`). `a16mixfold` reads 0x2DC0 both emus (6 mixed ops, global read in place); 24 a16* tests + corpus 7/7 green; `0002` round-trips. (a16localx's adc-zp gate updated to also count adc-abs.) [plan](docs/plans/2026-06-15-321-native-s16-mixed-operand-load-fold.md).
- 2026-06-15 — [321-native-s16-compare-abs-fold] **fold near-abs global operands into the 16-bit compare (`a < gv`).** `selectSbc16` reads a single-use near-abs `G_LOAD16_ABS` operand directly — LHS via `lda abs` (`LDAbs16`), RHS via `cmp abs` (`CMPAbs16`) — so a global-vs-global compare is `rep; lda abs; cmp abs; sep; bcc/bcs` (no Imag16 round-trip, no `cmp zp`). Volatile-safe 1-to-1 fold; signed/XOR'd operands stay on the Imag16 path. `a16abscmp` reads 0x4303 both emus; 23 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-16bit-compare-abs-operand-fold.md).
- 2026-06-15 — [321-native-s16-copy16-fold] **fuse the 16-bit indirect copy (`g = *p`).** Extends the
  abs→abs copy fusion to indirect/mixed copies at selection: a single-use 16-bit `G_LOAD16_ABS`/
  `G_LOAD16_INDIR` feeding a 16-bit store folds the load directly into the accumulator (new helper
  `loadStoreValueIntoA16` in the store paths of `selectMem16Abs`/`selectMem16Indir`), gated by
  `shouldFoldMemAccess` (same block, non-volatile load, no aliasing/ordered op between) — so `g = *p`
  is `lda (p); sta g` instead of `lda (p); sta tmp; lda tmp; sta g`. `a16copy` (abs←indir) folds with
  no Imag16 round-trip and reads 0x3456; `-verify-machineinstrs` clean; both MAME + bsnes-jg.
  Non-breaking: corpus 7/7, all 22 a16* tests green, patch `0002` round-trips. The indir-dst direction
  folds only when the dst-pointer load doesn't intervene as an ordered memref (volatile-pointer copies
  conservatively stay a round-trip — correct).
  [plan](docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md).

- 2026-06-15 — [321-native-s16-copy16abs] **fuse the 16-bit global-to-global copy (`g = gg`).** The
  absolute load/store landed `g = gg` as `lda gg; sta tmp; lda tmp; sta g` — the value round-tripped
  through an Imag16 temp because the load and store were selected independently. A new pre-legalizer
  combiner `copy16abs` (`matchCopy16Abs`/`applyCopy16Abs`) folds `G_STORE(single-use near-abs
  G_LOAD(absSrc), absDst)` into `G_COPY16_ABS`, which `selectCopy16Abs` lowers to `lda src; sta dst`
  (LDAbs16+STAbs16, both MLow=1, no temp) in one rep/sep. Disjoint from alu16_abs/add_chain16 (those
  need a G_ALU value). `g = gg` is now 2 ops; `a16abs` still reads 0x5A3D; `-verify-machineinstrs`
  clean; both MAME + bsnes-jg. Non-breaking: corpus 7/7, all 21 a16* tests green, patch `0002`
  round-trips. Follow-up: extend to indirect/mixed copies (`*q = *p`, `g = *p`).
  [plan](docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md).

- 2026-06-15 — [321-native-16bit-absolute-load-store] **native 16-bit absolute load/store (`g = gg`).**
  A 16-bit global-to-global copy / global store of a computed value did a 4-op 8-bit X/Y byte shuffle
  with no rep/sep; now `legalizeLoadStore16` routes a global-addressed s16 access (via
  `matchAbsoluteAddressing`) to `G_LOAD16_ABS`/`G_STORE16_ABS`, selected (`selectMem16Abs`) to
  `lda abs`/`sta abs` via the existing `LDAbs16`/`STAbs16` `MLow=1` forms. `a16abs` reads 0x5A3D, no
  byte shuffle; register-valued `corpus_result = …` stores across the suite go native and merge into
  the preceding bracket (fewer rep/sep). **Constant-valued stores are gated out** (kept on the
  STZ-fusion/byte path — `g16 = 0` stays `rep; stz; sep`). The merge changed the rep/sep shape of 11
  existing tests; all were emulator-verified still correct before the stale exact-count gates were
  relaxed. `-verify-machineinstrs` clean; both MAME + bsnes-jg. Non-breaking: corpus 7/7, all 21 a16*
  tests green, patch `0002` round-trips. Follow-up: fuse the load→store copy (drop the Imag16 temp
  round-trip).
  [plan](docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md).

- 2026-06-15 — [321-native-16bit-indirect-load-store] **native 16-bit indirect load/store (`*p`,
  `a[i]`, `a[i]=v`).** Scope correction: indexed/array access does NOT need the X-flag dimension —
  llvm-mos lowers arrays via computed pointers whose arithmetic is already native 16-bit; only the
  16-bit VALUE was loaded/stored as two 8-bit indirect ops (`lda (zp); lda (zp),y`). Now an s16
  `G_LOAD`/`G_STORE` through a non-absolute 16-bit pointer routes (new `legalizeLoadStore16`, gated on
  `!matchAbsoluteAddressing`) to `G_LOAD16_INDIR`/`G_STORE16_INDIR`, selected (`selectMem16Indir`) to
  `lda (zp)`/`sta (zp)` via new `LDAIndir16`/`STAIndir16` `MLow=1` forms in one rep/sep; the whole
  pointer (incl. `a[i]`'s G_PTR_ADD) materializes into the Imag16 pair so plain-indirect is always
  correct. Absolute/indexed s16 access falls back to byte-pair narrowing (follow-ups). `a16ptr`
  round-trips 0xABCE via `*p`, no `(zp),y`; `-verify-machineinstrs` clean (it caught a misplaced load
  memref on `STAImag16` — moved to the real `LDAIndir16`); both MAME + bsnes-jg. Non-breaking: corpus
  7/7 (default pointer/array codegen untouched), all 20 a16* tests green, patch `0002` round-trips.
  [plan](docs/plans/2026-06-15-321-native-16bit-indirect-load-store.md).

- 2026-06-15 — [321-native-16bit-signed-compares] **native 16-bit signed ordering compares
  (`< <= > >=` on `short`).** Signed order equals unsigned order after flipping the sign bit, so
  `legalizeICmp` rewrites an s16 `SLT` (the canonical signed primitive — the other three reduce to it)
  to `ULT` on `(a^0x8000, b^0x8000)`: the XORs are the already-native 16-bit EOR and the compare
  re-legalizes through the already-native unsigned UGE carry path (`rep; eor #$8000; …; cmp; sep;
  bcc/bcs`). No new flag handling (no V/N^V), no selector/pseudo changes — a one-block hook. `a16scmp`
  reads 0x0111 with negative operands (an unsigned misread would get every ordering wrong);
  `-verify-machineinstrs` clean; both MAME + bsnes-jg. Non-breaking: corpus 7/7, all 19 a16* tests
  green, patch `0002` round-trips. Compare→stored-bool is the remaining compare follow-up.
  [plan](docs/plans/2026-06-15-321-native-16bit-signed-compares.md).

- 2026-06-15 — [321-native-16bit-equality-compares] **native 16-bit equality compares (`== !=`).**
  An s16 `a == b`/`a != b` narrowed to a two-block 8-bit `cmp/cpx` chain; now each `==`/`!=` feeding a
  branch is one fused 16-bit compare-branch `rep; lda; cmp; sep; beq/bne`. Unlike the carry (ordering)
  path, Z can't be a plain i1 (selectSbc asserts N/Z must fuse into a terminator), so: the legalizer
  keeps s16 `ICMP_EQ` un-narrowed only when every use is `G_BRCOND_IMM`; new `CmpBrImag16`/`CmpBrImm16`
  pseudos (Defs `[C,A16,NZ]`) carry it; type-discriminated `CmpNZ16` matchers + new `selectBrCondImm`
  cases (handled before the 8-bit ones, with an s8 guard added to the 8-bit matcher); and `expandCmpBr16`
  lowers post-RA to `LDAImag16; CMPImag16/CMPImm16` (both `MLow=1`, so REP/SEP brackets the `lda;cmp`)
  + `BR` reading Z (sep preserves Z). `a16eq` reads 0x0011 (operands differ in both bytes), no 8-bit
  cpx/cpy; `-verify-machineinstrs` clean; both MAME + bsnes-jg. Non-breaking: corpus 7/7, all 18 a16*
  tests green, patch `0002` round-trips. Equality→stored-bool and signed compares are follow-ups.
  [plan](docs/plans/2026-06-15-321-native-16bit-equality-compares.md).

- 2026-06-15 — [321-native-16bit-signed-shift-ashr] **native 16-bit signed (arithmetic) right shift
  (`>>` on `short`).** Completes the constant-shift family. The 65816 has no native ASR, so
  `selectShift16Native` emits `cmp #$8000; ror a` per bit (the compare sets carry = the sign bit, the
  rotate replicates it into bit 15) via a new carry-threaded `RORAcc16` `MLow=1` form; the legalizer
  gate adds `G_ASHR` to the [1,7] native passthrough. `a16ashift` sign-extends 0xF000 >> 3 = 0xFE00
  (reads 0xFE01) under one rep/sep, no 8-bit lsr/ror byte chain, no libcall; both MAME + bsnes-jg.
  Non-breaking: corpus 7/7, all 17 a16* tests green, patch `0002` round-trips.
  [plan](docs/plans/2026-06-15-321-native-16bit-signed-shift-ashr.md).

- 2026-06-15 — [321-native-16bit-constant-shifts] **native 16-bit constant shifts (`<<`, unsigned
  `>>`).** `x << k` / unsigned `x >> k` (k a compile-time constant) had narrowed to the 8-bit
  `asl/rol` (or `lsr/ror`) byte-pair chain even under `+mos-a16`. The legalizer now leaves a small s16
  `G_SHL`/`G_LSHR` (amount 1–7) un-narrowed (`legalizeShiftRotate`, after the `Amt==0` base case) and
  `selectShift16Native` emits one `lda; (asl|lsr)×k; sta` run on the `Imag16` value via new
  `ASLAcc16`/`LSRAcc16` `MLow=1` pseudos (expand onto `ASL_Accumulator`/`LSR_Accumulator`; no carry
  operand — each shift self-fills 0). The value enters A16 only via LDAImag16 and leaves via STAImag16
  (no Ac16↔8-bit COPY). `a16shift` reads 0x1278 with 4× `asl` + 2× `lsr` under one rep/sep (the mode
  tracker folds a following add into the same bracket), no `rol/ror` pairs, no `__ashlhi3` libcall;
  both MAME + bsnes-jg. Follow-ups: signed `>>` (ASHR needs ror+sign), variable shifts, amount ≥8 /
  `xba`, 1-byte `inc a`/`dec a`, memory-RMW `inc abs`, shift-into-store fusion. Non-breaking: corpus
  7/7, all 16 a16* tests green, patch `0002` round-trips.
  [plan](docs/plans/2026-06-15-321-native-16bit-constant-shifts.md).

- 2026-06-15 — [321-cross-block-repsep] **cross-block REP/SEP mode-tracking.** `MOSInsertREPSEP` was
  per-block and 8-bit-anchored, so a loop with a 16-bit body re-ran `rep … sep` every iteration. It now
  runs a forward dataflow over the M-width lattice (`{None, M8, M16, Conflict}`) and places switches
  only at genuine transitions — inside a block (seeded with the block's `In` width, no forced 8-bit at
  exit) and on CFG edges `P→B` where `Out[P]≠In[B]`. `requiredWidth()` keeps entry/calls/returns 8-bit
  (the ABI boundary) and branches/carry-init agnostic; v1 bails the whole function to legacy per-block
  anchoring on any switch that would hit a true critical edge. Must-win lands: a 16-bit loop body holds
  16-bit mode across iterations — `rep` hoisted to the preheader, `sep` sunk to the exit, none in the
  body (`a16loop` 0x2340); a call inside a 16-bit region runs 8-bit (`a16call` 0x4456). Both on MAME +
  bsnes-jg. New `dev/regen-patch.sh` captures the isolated-worktree patch-regen method. Non-breaking:
  corpus 7/7, all 13 a16* tests green, patch `0002` round-trips.
  [plan](docs/plans/2026-06-15-321-cross-block-repsep-mode-tracking.md).

- 2026-06-14 — [321-native-16bit-compares] **native 16-bit unsigned-ordering compares (slice 1).**
  `if (a16v < b16v)` (and `<= > >=`) compiled to a verbose multi-block 8-bit `cpx/cpy` chain; now it's
  one 16-bit compare: `rep #$20; lda; cmp; sep #$20; bcc/bcs`. The legalizer keeps s16 **UGE**
  un-narrowed under `hasAccum16` (all four orderings canonicalize to UGE = the C flag, no terminator-
  fusion) by emitting a width-flexible 16-bit `G_SBC`; `selectSbc16` lowers it to `lda lhs; cmp rhs`
  (new `CMPImag16`/`CMPAbs16`/`CMPImm16`, `MLow=1` → one rep/sep bracket) producing C, which the branch
  reads. A constant RHS folds to `cmp #imm16` (`CMP_Immediate16` exists via the `CC1_All` multiclass).
  `a16cmp.c` (four orderings + a high-byte-differs case: low byte bigger, high byte smaller) shows 5
  16-bit `cmp`, **zero** 8-bit `cpx/cpy`, and `corpus_result==0x1103` on both MAME and bsnes-jg.
  Non-breaking: corpus 7/7, all 13 a16* tests green, patch `0002` round-trips. Equality (`== !=`, Z →
  CmpBr fusion), signed (N^V), and compare→select are follow-ups.
  [plan](docs/plans/2026-06-14-321-native-16bit-compares.md).

- 2026-06-14 — [321-native-s16-load-fold] **fold near-abs global operands into the 16-bit ALU.** For a
  multi-use `t = a16v OP b16v` (the store-fused peephole can't reach a multi-use result), the new
  combiner rule `alu16_absld` reads both globals directly via the 16-bit absolute forms instead of
  copying each byte-wise into an `Imag16` pair (~8 instrs dropped): `clc; rep; lda b16v; adc a16v; sta
  __rc2; sep`. New register-result pseudos `G_{ADD,SUB,AND,OR,XOR}16_ABSLD` (skipped by the legalizer
  opcode-range, no rule) + `selectAlu16AbsLd` (clone of `selectAlu16Abs` ending in `STAImag16`); reuses
  `nearAbsLoad`/`nearAbsGlobalDef`. The `>1-use` guard means single-store globals still fuse via
  `alu16_abs` (a16add/sub/bit stay green). `a16loadfold.c` reads 0x2345 (lda/adc abs, no `adc zp`) on
  both MAME and bsnes-jg; with `volatile` operands a16local/sub/bit fold too (gates widened, results
  unchanged), pure-native `adc zp` stays covered by a16localx. Non-breaking: corpus 7/7, all 12 a16*
  tests green, patch `0002` round-trips. Mixed load+register + single-use-non-store cases are follow-ups.
  [plan](docs/plans/2026-06-14-321-native-s16-fold-global-operand-loads-into-the.md).

- 2026-06-14 — [321-native-s16-imm-fold] **fold a constant operand into the immediate ALU form
  (`adc #imm`).** `selectAlu16Native` folds a compile-time-constant operand into `ADCImm16`/`ANDImm16`/
  `ORAImm16`/`EORImm16` instead of materializing it into an `Imag16` pair — `t = a16v + 0x0345` →
  `clc; rep; lda a16v; adc #$0345; sta; sep`, dropping the ~4-instr `ldx #lo;stx;ldx #hi;stx`. A
  `getImm16Operand` helper handles both shapes (direct constant, and a `G_MERGE` of two byte constants
  → `lo|hi<<8`); commutative ops fold either operand (swap); SUB never folds (no `SBCImm16`; `x-C`
  canonicalized to `x+(-C)` upstream); the dead constant is auto-erased by `isTriviallyDead`.
  `a16localimm.c` asserts `adc #` (opcode 69, not 65), no materialization, 0x1545 on both emulators.
  Non-breaking: corpus 7/7, all a16* tests green, patch `0002` round-trips.
  [plan](docs/plans/2026-06-14-321-native-s16-immediate-operand-optimization-adc.md).

- 2026-06-14 — [321-increment-1d-retry] **GISel-native s16 — the A16-aliasing coalescer crash SOLVED;
  native 16-bit add/sub/and/or/xor all ship** (steps 1-5). Re-diagnosed from the code: the crash was NOT the `A16=A`
  aliasing (the peephole makes `Ac16` vregs and is fine; aliasing is needed for transient-`A16`
  soundness) — it was the reverted prototype keeping the value resident *in* `Ac16` and shuffling it
  to/from `Imag16` with `copyPhysReg` (COPY-like), so an 8-bit `LDImm` coalesced into that COPY →
  `$a16 = LDImm`. Fix mirrors the peephole: s16 **value lives in `Imag16`**; native add selects to a
  self-contained `lda zp; clc; adc zp; sta zp` on the transient `A16` (new `LDAImag16`/`ADCImag16`/
  `STAImag16`, with `STAImag16` DEF-ing its `Imag16` like `STImag8`) — accumulator entered/left **only
  via load/store, never a COPY to/from 8-bit**. A multi-use **local** add (`a16local.c`, peephole-
  impossible) runs `0x1122`; the exact complex case that crashed the prototype (`a16localx.c`: 5 native
  adds, reused locals, heavy `Imag16` pressure) **compiles clean** (`-verify-machineinstrs`) and runs
  `0x33A0` — both on **both** MAME and bsnes-jg. Step 5 generalized `selectAdd16Native` → `selectAlu16Native`
  for native s16 **sub** (`sec/sbc`, `a16localsub` 0x1222) and **bitwise** (`and/ora/eor`, `a16localbit`
  0x000F), widening the legalizer gate to s16 `G_SUB` + `G_AND/OR/XOR` under `+mos-a16`. Immediate operands
  work (constant materialized into `Imag16`; `adc #imm` deferred as a size opt). Non-breaking: corpus 7/7,
  all 10 a16* tests green, SDK builds, patch `0002` round-trips. `dev/run.sh a16local|a16localx|a16localsub|a16localbit`.
  [plan](docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md).

- 2026-06-14 — [321-increment-1c-chained-16bit-alu] **chained 16-bit ADD — a value stays live in A16
  across ops** (first general-path slice): `g = a + b + c` fuses (pre-legalizer combiner, recursive
  `collectAddChain` over the G_ADD tree → variadic `G_ADDCHAIN16_ABS` → `selectAddChain16`) to one
  bracket `rep #$20; lda b; clc; adc a; clc; adc c; sta g; sep #$20`, threading the running sum
  through A16 (the intermediate `a+b` survives in the accumulator for `+c`). Reads
  `corpus_result == 0x1230` on **both** MAME and bsnes-jg. Disjoint from 1b's `alu16_abs` (fires only
  on ≥3-term load chains). Non-breaking: 1b (add/sub/bitwise/imm) + 1a + corpus 7/7 green, SDK builds.
  `dev/run.sh a16chain`; patch `0002-321-accum16.patch`. First codegen where a 16-bit value survives
  across operations in the register — the start of the general path.
  [plan](docs/plans/2026-06-14-321-increment-1c-chained-16bit-alu.md).

- 2026-06-14 — [321-increment-1b-dual-width-accumulator] **a running 16-bit ALU (add/sub/and/or/xor)
  through the dual-width A16 accumulator** — modeled the 65816's 16-bit accumulator `A16 = B:A` (class
  `Ac16`, aliasing `A`; named A16 not WDC's "C" to avoid the carry-flag footgun), then a pre-legalizer
  combiner fuses `g = a OP b` (near abs globals) → a `G_{ADD,SUB,AND,OR,XOR}16_ABS` op → `selectAlu16Abs`
  emitting one REP/SEP-bracketed 16-bit sequence: `clc;lda;adc;sta` (0x2345), `sec;lda;sbc;sta` (0x0123),
  and `lda;and|ora|eor;sta` (AND→0x0F00; three bitwise ops merge into ONE bracket). All read back correct
  on **both** MAME and bsnes-jg; add is 31 B vs 48 B for the 8-bit carry chain. Also **immediate
  operands** — `g = a OP #imm16` selects `adc/and/ora/eor #imm` (`a+0x0345`→0x1545; subtract-by-const
  folds to add of the negated const), and the REP/SEP pass now treats the carry-init as M-width-agnostic
  so consecutive ops share one bracket. Non-breaking: corpus 7/7, Inc 1a + far xcheck green, SDK builds.
  Findings: a legalizer rule for a MOS-specific *generic* opcode corrupts the legalizer tables (skip by
  opcode-range instead); the carry-init must not split the REP/SEP run. `dev/run.sh a16add|a16sub|a16bit|a16imm`;
  patch `0002-321-accum16.patch`. The genuine hard core of #321. Next (general path): chained ops /
  values staying live in A16. [plan](docs/plans/2026-06-14-321-increment-1b-dual-width-accumulator.md).

- 2026-06-14 — [321-native-mode-crt0] **SNES platform now boots 65816 native mode** — crt0 `.init.50`
  does `clc; xce` + a 16-bit `ldx #$01ff; txs` (page-1 stack) + `sep #$30` (8-bit A/X default), so
  *every* program runs native; the four 65816-only opcodes are emitted as `.byte` (SDK assembles crt0
  as 6502). a16 drops its test-local `clc; xce` and still reads `0x0042` on both emulators — driven
  solely by the crt0. Non-breaking: corpus 7/7, far-run/far-bank1/xcheck all green in native 8-bit.
  Platform-only change (no backend/patch). Enables all future 16-bit codegen to run unmodified.
  [plan](docs/plans/2026-06-14-321-native-mode-crt0.md).
- 2026-06-14 — [321-increment-1a-16bit-accumulator] **first real 16-bit-accumulator codegen** — a
  16-bit store-of-zero fuses (under opt-in `+mos-a16`) to `rep #$20; stz; sep #$20` via the new
  `MOSInsertREPSEP` pass (reuses the MC `MLow/MHigh` width TSFlags), and — run in 65816 native mode —
  fully zeroes the 16-bit value: `corpus_result == 0x0042` on **both** MAME and bsnes-jg. Non-breaking
  (corpus 7/7, far/xcheck unaffected; feature not implied by W65816). Tracked patch
  `0002-321-accum16.patch`; `dev/run.sh a16`. Finding: 16-bit registers need native mode (XCE) — the
  deferred prerequisite. ROADMAP step 5 (first slice). [plan](docs/plans/2026-06-14-321-increment-1-16bit-accumulator.md).
- 2026-06-14 — [second-emulator-xcheck] **second-emulator fidelity cross-check** — `dev/run.sh xcheck`
  boots the far ROMs in **bsnes-jg** (cycle-accurate, independent of MAME) headless and reads WRAM via
  `Bsnes::getMemoryRaw(MainRAM)` (a small `dev/jgxcheck.cpp` harness, no SDL/X/save-state): far-run
  (bank $00) + far-bank1 (bank $01) both `got=0xF3`, agreeing with MAME — the bank-$01 far read isn't a
  MAME quirk. Mesen2 abandoned (prebuilt crashes on 26.04 glibc-2.43; headless `--testrunner` won't run
  Lua). Completes ROADMAP step 3's "both emulators".
  [plan](docs/plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md).
- 2026-06-14 — [320-upstream-design-note] drafted the upstream #320 design note
  ([docs/320-upstream-far-pointer-note.md](docs/320-upstream-far-pointer-note.md)): leads with the
  verified running slice (Inc 1/2/2b, by commit), the addrspace-numbering divergence (slice `2`=far
  additive vs proposal `0`=far-default) + a reconciliation path, the open ABI decisions, and the
  WDC816CC/ORCA-C calling-convention prior art. Code-first artifact to anchor the #320 discussion;
  posting upstream is user-triggered. [plan](docs/plans/2026-06-14-320-upstream-design-note.md).
- 2026-06-14 — [320-increment-2b-multi-bank-far-read] far read now **crosses a real ROM bank
  boundary**: a 64 KiB LoROM (`snes-far` child platform, banks $00+$01) places a far global in bank
  $01 ($018000), far-read via `lda $018000` (`af 00 80 01`); the cross-bank result round-trips in MAME
  (`SMOKE: PASS got=0xF3`). No codegen/native-mode change (section attr + linker rule; `snes-checksum.py`
  now owns the ROM-size byte). New `dev/run.sh far-bank1` + `examples/65816/far-bank1.c`; 5/5 PASS,
  default snes platform untouched (corpus 7/7, far-run PASS). Completes ROADMAP step 3.
  [plan](docs/plans/2026-06-14-320-increment-2b-multi-bank-rom-far-read.md).
- 2026-06-14 — [320-increment-2-far-emulator-run] far-pointer codegen now **executes in MAME**: a
  `-mcpu=mosw65816` program far-LOADs a ROM constant and far-STOREs the result to WRAM; the byte
  reads back `0xF3` (`SMOKE: PASS`) on the existing single-bank emulation-mode crt0. Finding:
  absolute-long ignores the DBR → no native mode needed (XCE/DBR/16-bit regs re-scoped to M2/#321);
  multi-bank far-read split to Increment 2b. New `dev/run.sh far-run` + `examples/65816/far-run.c`;
  5/5 verification steps PASS, corpus still 7/7. ROADMAP step 3 (execution half).
  [plan](docs/plans/2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md).
- 2026-06-14 — [320-increment-1-far-codegen] far (addrspace 2) load/store now lowers to 65816
  absolute-long (`LDA/STA $xxxxxx`, AF/8F, 4-byte incl. bank), gated on `W65816`; near stays 16-bit,
  far global → `R_MOS_ADDR24`. GISel `G_LOAD/STORE_FAR_ABS` → `LDAbsLong/STAbsLong` MC wrappers.
  `dev/run.sh far` 5/5 PASS + corpus 7/7 on the patched from-source toolchain. ROADMAP step 4.
  Tracked patch `0001-320-far-addrspace.patch`. [plan](docs/plans/2026-06-14-320-far-pointer-codegen.md).
- 2026-06-14 — [m1-phase0-toolchain] llvm-mos built FROM SOURCE in the dev container
  (`dev/run.sh toolchain`), lean (clang+lld, dropped clang-tools-extra → 39.2→26.1 min cold). Bench
  toolchain selectable via `MOS_TOOLCHAIN`; `build.sh` wipes the SDK tree on toolchain change. Corpus
  7/7 on the self-built compiler (byte-equiv to prebuilt). M1 codegen prerequisite.
  [plan](docs/plans/2026-06-14-m1-from-source-toolchain.md).
- 2026-06-14 — [regression-corpus] 6 self-contained C programs (`examples/snes/corpus/`) exercising
  ALU / control flow / arrays+.rodata / structs+pointers / calls+recursion / crt0 init; host-checked
  vs `expected.tsv`. `dev/run.sh corpus` 7/7 PASS, negative control + clean-room `repro` green.
  ROADMAP step 2. [plan](docs/plans/2026-06-14-m0-regression-corpus-5-self-contained-c-programs.md).
- 2026-06-14 — [emulator-smoke-loop] `dev/run.sh smoke` boots hello.sfc headless in MAME's `snes`
  driver, asserts `sentinel==0x42` in WRAM. Negative control + clean-room `dev/run.sh repro` +
  manual GitHub CI (run 27475012894) all green. Closes ROADMAP step 1 (run-half).
  [plan](docs/plans/2026-06-14-emulator-smoke-loop.md).
- 2026-06-13 — [snes-sdk-platform] SNES SDK platform (crt0, header, link.ld, snes.h, clang.cfg)
  builds a valid 32 KiB LoROM `.sfc` from C via the 6502 backend; structural verification PASS
  (reset→crt0 byte-exact, `main()` placed, checksum 0xFFFF). ROADMAP step 1, structural half.


## Inbox — auto-captured plan deferrals

_Auto-added from plan "Out of scope"/"Deferred" sections at commit time. Triage each into M1/M2/etc. and delete it here — it will not come back._

<!-- BEGIN auto-captured-deferrals (managed by audit-plan-deferrals.sh — triage these into the curated sections above; the fingerprint ledger means a deleted item is NOT re-added) -->
<!-- triaged 2026-06-16: both Tier-1 "out of scope" bullets are non-work — the
     fault-injection mode is explicitly "not needed" (the seed corpus is the volume),
     and "Backend fixes: minimize → root-cause → fix" is the PROCESS that was followed
     and COMPLETED this increment (2 bugs fixed, 1 deferred/XFAIL). Nothing open. -->
<!-- triaged 2026-06-16: all six captured deferrals already live in curated M2 items.
     • "Full native s16 EQ-as-value" + "Indirect s16 load consumed only as bytes"
       (s16-load-unmerge-bytewise.md) -> the M2 bullet "#321 native s16 equality-as-value
       — the full native compare (deferred from item (c))".
     • the [verify] flag for s16-load-unmerge-bytewise -> verification now recorded in the
       plan (all PASS, commit 7c0fe56).
     • the three soft-stack-spill-coverage notes (xy16 index-16 spill impl, the upstream
       `reentrant`-attribute issue, interrupt/optnone alternative triggers) -> covered by
       the M2 bullet "#321 soft-stack (reentrant) spill coverage" + its plan's Out-of-scope.
     Nothing open here. -->
<!-- triaged 2026-06-16: indirect-s16-load-bytewise is a PLANNED, investigation-gated item
     (Status: planned) — its "Verification (if implemented)" section is intentionally unrun
     (nothing built yet). Tracked by the M2 "equality-as-value" bullet. Not a missed step. -->
<!-- triaged 2026-06-17: both F4-plan deferrals dispositioned.
     • P1/P2/P3 (expandLDSTStk contract note, .ll durability, reentrant upstream note) -> the F4
       plan's Out-of-scope explicitly defers these to the parent soft-stack plan; covered by the M2
       Open bullet "#321 soft-stack (reentrant) spill coverage" (which lists exactly P1/P2/P3).
     • "Upstreaming the PR is user-triggered" -> PROMOTED to a curated Upstream/Contribution bullet
       ("Upstream the F4 mos-late-opt TXY/TYX dead-flag fix"). Nothing open here. -->
<!-- triaged 2026-06-17: native-s16-EQ v1 landed (commit 37674ff). All four are already curated:
     • v2 (computed-LHS), v3 (abs-fold globals), and the post-A16-threading re-measure -> the M2
       Open bullet "#321 native s16 equality-as-value — v2/v3 (remaining gated wins)".
     • the cmpsel "[verify]" is a false positive: that plan is design+spike, and its Verification
       contract was fulfilled by the gated-impl plan's recorded PASS (eq_deref native, suite 44/44,
       corpus 7/7, fuzz 50/50, a16eqvalp both emulators). Nothing open here. -->
<!-- triaged 2026-06-17: the ten v3/gated-impl EQ-as-value deferrals all dispositioned.
     LANDED since capture (done, not deferred):
       • v2 computed/Imag16 LHS (a+b)==c        -> fd6b281 (plan v2-computed-imag16-lhs).
       • v3 abs-fold both-global g1==g2          -> efce68f (plan v3-abs-fold-globals).
       • g1==0x1234 global-vs-immediate (x3 fps) -> f8a32ae (plan eq-imm-constant-through-merge);
         the byte-split-constant blocker is fixed (getI16Const through G_MERGE_VALUES).
     COVERED by the curated M2 bullet "#321 native s16 equality-as-value — micro-cases"
     (its (a)/(b)/(c) + the A16-threading re-measure) — all intentionally 8-bit today (no regression):
       • mixed global-vs-register / global-vs-computed-local (g1==a, g1==(b+c)) -> (a).
       • register/param operands (eq_ret, eq_store)                             -> (c).
       • g1==0 (RHSIsZero, G_CMPZ path)                                         -> (b).
       • chained value-EQ with cross-block-hoisted loads (stays native = a win, not a regression).
       • re-measure after A16-threading                                        -> the bullet's tail.
     Nothing open here. -->
<!-- triaged 2026-06-17: both P2-plan deferrals already covered.
     • "upstream lit test under llvm/test/CodeGen/MOS/" -> belongs with the #321 UPSTREAMING work
       (Upstream/Contribution section); the constraint (regen-patch mirrors only the lib dir, so a
       vendor test file is lost) is documented in the P2 plan + the soft-stack plan's P2 section.
     • "xy16 index-16 spill case" -> gated on the xy16 increment; covered by the curated M2 soft-stack
       bullet (P1's expandLDSTStk SPILL CONTRACT tripwire) + the M2 X-flag/xy16 re-evaluate item.
     Nothing open here. -->
<!-- triaged 2026-06-17: both A/X-return-plan deferrals already covered (intentional follow-ups, not lost work).
     • "A16-aware return optimization (drop the Imag16 round-trip) + xy16 32-bit-return evolution" -> the A/X
       plan's Non-goals/Out-of-scope explicitly defers these; the optimization is A16-threading-adjacent
       (curated M2 "#321 A16-threading" item) and the 16-bit-register return is gated on the curated M2 xy16 item.
     • "argument-passing + frame-storage sub-decisions" -> the curated M2 "#321 calling-convention decision"
       bullet + docs/investigations/65816-calling-convention-decision.md (the hard frame fork, gated on a
       product steer + post-xy16 measurement). Nothing open here. -->
<!-- triaged 2026-06-17: both SNES-415 plan deferrals already covered (this plan was routed in from
     ~/.claude/plans by a housekeeping pass; its Out-of-scope/follow-ups travel with the now-tracked plan).
     • "Upstreaming: cut the llvm-mos-sdk PR from platforms/snes-8bit/" -> the curated Open bullet
       "Reconcile with llvm-mos-sdk#415 (the existing SNES target draft PR)" + the Upstream queue entry in
       docs/upstream-contribution-status.md (#415 reconciliation, user-triggered posting). Already tracked.
     • "Port the DMA/VRAM helpers to 16-bit codegen" -> a Phase-2 (16-bit native target) deferral documented
       in the plan's own Out-of-scope, gated behind the same #415 reconciliation + the broader #321 effort.
     Nothing open here. -->
<!-- triaged 2026-06-17: pre-implementation plan — verification steps require the implementation to exist first; tracked as the #321 stage-1 xy16 TODO item (Open) → fp:b24d6be9c36ef6e5 -->
<!-- triaged 2026-06-18: both are "Out of scope" NON-GOALS from the seed-42 fix plan (clarifying the A/X
     return convention and the +mos-a16 EQ fold are UNCHANGED) — not deferred work. The fix is complete +
     verified (a16 50/50, corpus 7/7, fuzz 50/50). fp:27bd502017f767b4 fp:5d3100a79ceeab83 -->
<!-- triaged 2026-06-18: both plans are WON'T-DO — corpus trigger check 0/6 progs 0 B; the
     verification sections were for the implementation (never executed). No work pending.
     fp:91dc9eb4b93c09c3 fp:ac13f5e988de2e42 -->
<!-- triaged 2026-06-18: both crt0-xy16 plan deferrals already covered.
     • "Hardware-stack ABI / 16-bit calling convention" -> already the curated M2 Open item
       "#321 calling-convention decision (open, blocks the hardware-stack ABI)"; gated on the
       same calling-convention / frame sub-decision. No new work here.
     • "Native interrupt service" -> not active work; bare `rti` stubs are width-safe for bring-up.
       The M16/X16-entry `php`/force-width note is recorded in the plan for the future worker who
       lands real vblank/IRQ handlers. Nothing open today. fp:ba56664f75e7c2fa fp:dd5e492a20c5fd16 -->
<!-- triaged 2026-06-18: prove-option-b Verification section now has all 5 steps recorded with raw output +
     PASS (the experiment ran: Option B measured +16..+28 B, WON'T-IMPLEMENT confirmed). The flag fired
     because the steps were written as a contract before the run; they are now filled. Nothing open. fp:e9e161484c038906 -->
<!-- triaged 2026-06-18: both xy16-hang-fix deferrals PROMOTED to the curated M2 Open bullet
     "#321 xy16 — remaining REPSEP X-annotation gaps (watch pending fuzz evidence)" — PHX/PLX/PHY/PLY
     in X16 mode + TAX/TXA/… transfers in mixed modes. They are speculative (no corpus/fuzz evidence
     yet), so tracked as watch items, not active work. Detail stays in the plan's Deferred section.
     fp:089392f5e8b0053d fp:9a09f71d5902e937 -->
<!-- triaged 2026-06-18: all three repsep-x-annotation "Out of scope" bullets dispositioned.
     • seed-157 — NO LONGER a residual: FIXED by Commit A (transfer X-annotation); it was a second
       transfer-in-held-X16 bug. Recorded as fixed in the curated "$p-spill compiler crash" item.
     • seed-169/173/196 — covered by the curated "+mos-a16 $p-spill compiler crash" item (now lists all
       8 seeds: 169/173/196/268/271/272/306/420).
     • TSX/TXS — non-work: no compiler-pseudo path (crt0 stack init is hand-written asm); would only
       matter for a future native-hardware-stack frame. Nothing open.
     fp:e3eda71d77592d8c fp:d64f4a3bcd9e3615 fp:5357e60ef6ea3fea -->
<!-- triaged 2026-06-19: all four are FALSE POSITIVES from the DWARF step-6 plan's Step 5 "DONE" section —
     none is deferred work. The first two are the *rationale* for a justified deviation (regen-patch only
     mirrors lib/, and full llvm-lit is unbuildable here), and the last two are the *delivered* artifacts
     (dev/run.sh dwarf gate 7/7 + the verified staged lit test) — Step 5 is complete (commit cc940f1).
     Nothing open. fp:02d8811ec8003aa5 fp:b4a301783ca3b9e3 fp:110cfbbe5aab25e6 fp:fe7817097ea1d37e -->
<!-- triaged 2026-06-19: all three corpus-a16-plan "Out of scope" bullets dispositioned.
     • "Fixing globals.c" -> already the curated M2 Open bullet "#321 +mos-a16 -O1/-Os register-allocation
       FAILURE on real code (corpus globals.c)" (root-caused; DECISION = keep XFAIL, reevaluate at M2 wrap-up).
     • "Wiring corpus-a16 into CI" -> PROMOTED to a curated Test Bench/CI bullet ("Wire corpus-a16 into CI",
       right below the corpus-a16 gate item).
     • "New corpus programs" -> non-work scope marker: this plan deliberately added none; broadening the
       corpus (Tier-2) is open-ended future work, not a tracked deliverable here. Nothing open.
     fp:3807f2b481a45e90 fp:13cb10ca9b2122a5 fp:f1527e7e0ec4fec4 -->
<!-- triaged 2026-06-19: both corpus-a16-CI plan "Out of scope" bullets are non-work.
     • "Adding push:/pull_request: triggers" -> intentional posture, not pending work: the whole
       snes-smoke workflow stays workflow_dispatch-only until the repo goes public / collaborators push
       (documented in smoke.yml's header + the curated "Wire bsnes-jg xcheck into CI" item). Re-add triggers
       then, for ALL jobs at once — not a corpus-a16-specific task.
     • "A separate corpus-a16 job (rejected above)" -> a rejected design alternative, not work. The chosen
       design extends the xcheck job (no toolchain-build duplication). Nothing open.
     fp:5f8372d2444e1e6b fp:6a08cf207dd87a4b -->
<!-- triaged 2026-06-19: all three xy16-indiry-gate "Out of scope" bullets dispositioned (none is work for this task).
     • "open xy16 fuzz failures / emulator hangs" -> CORRECTED 2026-06-19: the xy16 runtime hangs are FIXED
       (8961afb XHigh + 4d8a2bd X-governed transfers); fresh fuzz 50 1 / 50 56 = 50/50 and fuzz 500 = 492/500,
       0 mismatch / 0 hangs. The only residual is the $p-spill COMPILE crash (8 xfails) — the curated
       "#321 $p-spill register-scavenger crash" item (TODO above), NOT a hang. (See Done.)
     • "hardware-stack ABI + calling convention" -> now the explicit remaining follow-on IN that same stage-1
       item (just reconciled), and gated on the curated "#321 calling-convention" item. Already covered.
     • "standalone (zp),Y16 STORE gate" -> deliberate scope marker: the load path is the higher-value read; the
       symmetric store pseudo (STIndirYIdx16) is exercised by the fuzzer's xy16 track. Nothing open.
     fp:1fcc2870d2445ea7 fp:9b195ad521b9ffae fp:8e99366f38c84605 -->
<!-- triaged 2026-06-19: both from the comment-fix plan, both resolved.
     • "Any functional change. Comments only." -> the Out-of-scope marker itself (no work — the change is
       literally comments only).
     • the [verify] flag -> RESOLVED: the plan's "Result — VERIFIED 2026-06-19" section now records the regen
       round-trip PASS + the comment-only 0002 diff (committed c2882b3). Nothing open.
     fp:93d7dc31ec1433be fp:be0273e614032501 -->
<!-- triaged 2026-06-19: all four are explicit "## Out of scope" NON-GOALS from the c-torture plan, not
     deferred work — they scope the plan, nothing to track.
     • Csmith/Yarpgen random generation -> a separate (generator) axis; we already have tools/a16_fuzz.py.
     • c-testsuite stdout model -> recorded as the fallback if the GPL fetch is rejected; not built otherwise.
     • Conformance claims -> deliberately disclaimed (this is differential bug-finding, not ISO certification).
     • Floating-point / full-libc tests -> outside the freestanding subset; the Phase-0 filter excludes them.
     fp:3d23564aa9d16214 fp:9502a10868aa863f fp:9ef5b0820dd8d148 fp:a2b25e70c9c08d3b -->
<!-- triaged 2026-06-19: all four verification steps were run immediately before commit 181af86 (grep counts and grep output recorded in the plan, all PASS). The [verify] flag is a false positive — the plan was fulfilled in the same session. Nothing open. fp:72e135cd9174e480 -->
<!-- triaged 2026-06-19: promoted into curated entries — the Csmith fuzzer (+ its Yarpgen follow-up) under
     Test Bench / CI, and the `G_UNMERGE_VALUES s32` finding (now FIXED, see Done) under M2 — Optimizing
     Payoff. These three were the plan's own Follow-ups bullets (Yarpgen; Yarpgen-vs-known-bugs; "add the
     Csmith TODO entry"); now covered. fp:192eb34724f01c54 fp:0350991c23596f7a fp:d29683e80d7e9f15 -->
<!-- triaged 2026-06-20: all three are the indexed-compares plan's own Deferred section, dispositioned there + in the Done entry [321-native-16bit-indexed-compares].
     • "Indexed LHS explicit fold" -> NON-WORK: Phase 0 measured the LHS case (`arr[i] < limit`) already optimal (the staged value threads back into A16 via threadAccum16); the "only if Phase 0 shows threading misses it" gate did not trigger.
     • "EQ RHS-indexed fusion" + "+mos-xy16 16-bit-index compares" -> real but measurement-gated extensions, intentionally not built in v1 (low frequency / separate instruction); fully recorded in the plan's Deferred section, to be revived only if a frequency scan justifies them. Nothing open. fp:2a340a3f28882754 fp:2596e84dcec84614 fp:c65f6994b1384180 -->
<!-- triaged 2026-06-20: both are explicit "## Out of scope / non-goals" NON-GOALS from the Phase-3
     deferral-formalization plan, not deferred work.
     • "No compiler change" -> the whole point of the plan: the deferral IS the deliverable (the curated
       Watch re-open trigger + the M2 A16-threading bullet's gated B0->B1->B2 spike recipe). Nothing to build.
     • "The other two XFALs keep their own TODO bullets" -> already true: `scavenger-p-not-gpr` and
       `a16-zp-pressure-overflow` each have their own curated M2 bullets. Nothing open.
     fp:fd9f6337217bdfdf fp:d23acc84e2e4c0bd -->
<!-- triaged 2026-06-20: all three are explicit "## Out of scope / non-goals" NON-GOALS from the frame-ABI
     head-to-head plan, not deferred work — they scope the study.
     • "Not changing argument passing / A/X return" -> those CC sub-decisions are LOCKED/adopted; this study
       is the frame/locals sub-decision only.
     • "Not auto-merging (a)/(b)" -> the pre-registered go/no-go IS the plan's decision rule; nothing to track.
     • "Not posting upstream from this plan" -> upstream posting is the curated user-triggered CC item; the
       evidence paragraph is prepared by phase D. Nothing open.
     fp:29fde811ff5d23b8 fp:45ce4d0c0263904b fp:ad37a4514712de70 -->
<!-- triaged 2026-06-20: all three are RESOLVED-status bullets from the audit doc's
     "## Deferred → RESOLVED" section (the hook matched the word "Deferred" in the heading) —
     NOT open work. They record the loadfold-unify outcome (AA-precision landed; volatile-drop
     closed net-negative; the literal single-helper merge rejected by measurement), now captured
     by the Done item [321-loadfold-unify]. Nothing to track.
     fp:5f85cd31e68981cc fp:f85cd73b8f51bdd5 fp:98f82e24c01c1ac9 -->
<!-- triaged 2026-06-20: verification run + recorded in the plan's "## Verification — DONE" section (all 5 steps ✓; commits 9a255fd/6779286). fp:7b6f4179413cb08f -->
<!-- triaged 2026-06-20: both #320 Inc 3 deferrals dispositioned.
     • "Far-pointer calling convention" -> already the curated M1 Open bullet "#320 far-pointer calling
       convention — pass/return a 32-bit p2 across function boundaries" (added this increment; grouped with
       far calls / Inc 4, upstream-gated). Duplicate.
     • "G_STORE runtime far (sta [dp])" -> NOT open work: the store path IS implemented this increment
       (G_STORE_FAR_INDIR -> STIndirLong, the symmetric [dp] store), exercised by the legalizer/selector
       alongside the load. Only a dedicated far_store.c micro-test is unwritten — trivial polish, not a
       tracked deliverable. Nothing open.
     fp:2f1aaa13df1acdfe fp:edb3f3d7062da359 -->
<!-- triaged 2026-06-20: re-capture of the two #320 Inc 3 "out of scope" deferrals from the migrated
     task plan (do-3c-finish-...); both already dispositioned in the 2026-06-20 note above (only the
     fingerprints differ — new plan file, restated wording).
     • "Far-pointer calling convention" -> the curated M1 Open bullet "#320 far-pointer calling
       convention" (grouped with far calls / Inc 4, upstream-gated). Duplicate.
     • "sta [dp] store micro-test" -> NOT open work: the store path IS implemented
       (G_STORE_FAR_INDIR -> STIndirLong, the symmetric [dp] store); only a dedicated far_store.c
       micro-test is unwritten — trivial polish, not a tracked deliverable. Nothing open.
     fp:bffa7ff820f61a6a fp:41566cc6a199377c -->
<!-- triaged 2026-06-20: all four are "## Out of scope / non-goals" NON-GOALS from the far-pointer-CC
     Phase 2 plan (the hook matched the "Not ..." bullets) — scope boundaries, not open work.
     • "not changing near-ptr/scalar passing or the A/X return (LOCKED)" + "not auto-merging variants"
       -> methodology guardrails of the study itself; nothing to track.
     • "far function pointers / indirect far calls" -> already the curated M1 bullet "#320 far calls —
       follow-ups (a)". Duplicate.
     • "not posting upstream" -> the curated user-triggered "#320 post design note upstream" bullet.
       Duplicate. Nothing open.
     fp:b7a659d550bb10a3 fp:9b54c26fd2f46d90 fp:5612fe3202e783db fp:a5a5bc42d30cd1b6 -->
<!-- triaged 2026-06-25: all three are far-cc STUDY scope-boundary non-goals ("Not X"), not open work —
     and the far-cc work has LANDED (0004 Imag32 winner on main; far function pointers via the curated M1
     "#320 far calls follow-ups (a)"; only the winner merged, the losers stayed inert spikes — exactly as
     these guardrails state). Echoes the earlier far-cc-variants triage just above. Nothing to track.
     fp:608f27e69a9ee6af fp:d15da622c632fbdd fp:209db6851015623a -->
<!-- triaged 2026-06-25: VERIFIED + recorded. Ran the far-cc-variants verification on main — all 4 variant
     round-trips PASS (dev/run.sh farcc_{imag32,split,axy,stack} == 0xF3, both emulators, -verify clean),
     far-suite non-regression PASS, and 0001/0009 round-trip byte-identical. Results written into the plan's
     new "## Verification results — re-run on main 2026-06-25" section. The residual tooling (regen-0004
     structural redesign + main toolchain rebuild) is split out as its own curated M2 item below — it is NOT
     part of this study's codegen verification. fp:e3b7f46b9e51afa0 -->
<!-- triaged 2026-06-21: native-s16-comparison-followups §5 verification is intentionally Phase-0-gated (it runs only IF the Phase 0 §3 byte-diff measures a win; the §4a step-1 audit IS recorded). Covered by the curated M2 "comparison follow-ups" SCOPED item above. Not a missed step. fp:c91b9765672261df -->
<!-- triaged 2026-06-21: banked plan §5 verification is MOOT — candidate A was BUILT + measured net-negative (a16cmpaudit +654/+78 B, a16 corpus +340 B zero wins) and CLOSED WON'T-DO (§0a); nothing lands in 0002, so there is no codegen to verify. Covered by the curated M2 "comparison follow-ups" item above (now records both the 8-bit v1 AND 16-bit candidate-A close-outs). Not a missed step. fp:5f242fd76b40e2f7 -->
<!-- triaged 2026-06-21: all four far-calls-followups "Out of scope" bullets are non-work — covered
     by curated items or explicit non-goals of the now-tracked plan:
     • (c) far tail calls -> already named as "(c) far tail calls = separate" inside the curated M1
       "#320 far calls — follow-ups" bullet (conservative-safe today: tail peephole keys on JSR).
     • far-pointer DATA CC (p2 passing/returning) -> the curated M1 "#320 Inc 4 Phase 2 — far-pointer
       calling convention" bullet + wt/320-far-cc.
     • SPC700 indirect-far -> explicit NON-GOAL (65816-only; the __rc17 thunk path is untouched).
     • Auto-promoting near callees to far -> explicit NON-GOAL ((b) keeps near callees byte-identical;
       uniform-far is a measured control/fallback, not a shipped default).
     fp:a5f1db95f5a9627a fp:5221ad4b75df9534 fp:78cda9a654aa2b5f fp:fde87b8fe11d4df6 -->
<!-- triaged 2026-06-21: RESOLVED — the land plan now has a §Verification (2026-06-21) section with PASS recorded (round-trip empty over clang/+MOS/ except the 2 documented drift/stale files; a16-free + 0002/0003-sha-unchanged + sequence-apply all PASS). Landing is done; nothing left to run. fp:a51d6afac2a18fef -->
<!-- triaged 2026-06-21: the packed24-incrementB-handoff §3 "Verification gate" is INSTRUCTIONS for the future agent who builds Increment B (the bar THEY must clear), not a verification to run now — Increment B is deferred until F2 lands on main. Nothing to verify here; covered by the curated M1 five-space item + its handoff link. fp:3d3c94fe546a028c -->
<!-- triaged 2026-06-21: the packed24-productionization-handoff §2 "Verification gate" is INSTRUCTIONS for the future agent who picks up the next batch (the bar THEY must clear), not a verification to run now — it's a forward-looking resume prompt, not a completed plan. Tracked by the curated M1 five-space item's "next batch" link. Nothing to verify here. fp:93f3ef0f25357389 -->
<!-- triaged 2026-06-22: all four are explicit "Out of scope" NON-GOALS from the SNES near-code-budget
     plan (2026-06-22-snes-near-code-budget-and-code-model.md), not deferred work — each is a decision
     already stated in the curated M1 bullet "SNES near-code budget link-time assertion + #320 near/far
     code-model framing note": no -mcmodel mode (near IS the default, zero codegen win), no -mno-far
     guardrail (far is per-symbol opt-in; user skipped), rom_1 left as-is (already a named overflow-checked
     region), linker-script + docs only (no vendor edit). Nothing open.
     fp:a349fdb9e6fb6627 fp:13a459b641dd2a38 fp:27a0f051def92af7 fp:9c15ab41c1ea4e0c -->
<!-- triaged 2026-06-22: both close-out "Follow-up" bullets are already curated, not new work.
     • "Integrate 0007 onto main's patch stack" -> already a named separate thread in the M2 five-space
       item ("fold 0007 onto main's stack") and tracked in upstream-contribution-status.md (0007 built on
       wt/320-near-abs-bank-relax, not yet landed). Its own thread, not a packed-24 residual.
     • "Post the #320 upstream design note" -> the standing user-triggered item in the Upstream/Contribution
       section + upstream-contribution-status.md (artifact docs/320-upstream-far-pointer-note.md).
     Both fingerprints ledgered; deleted permanently. Nothing open here.
     fp:8a5ca7613ee06e0a fp:883b7d12864cf920 -->
<!-- triaged 2026-06-22: all five are the knock-out close-out plan's explicit "Out of scope" NON-GOALS,
     not open work — a measure-and-close that builds nothing.
     • "Building anything / A16-threading Phase 3 / multi-value spill-fusion" + "Re-opening either WON'T-DO"
       -> the recorded keep-the-XFAIL / WON'T-DO decisions; the shared deferred core is tracked by the three
       open items (globals.c RA / A16-threading Phase 3 / ALU >14-live), now unified with one trigger.
     • "≥8-shift bracket-fragmentation candidate" -> routed to a FUTURE measurement-gated spike (didn't meet
       the GO bar); a new docs/plans/ entry only if pursued. Not open now.
     • "CC/ABI track, xy16, the two RA/scavenger bugs" -> named boundary; owned by their own curated items.
     • "upstream paragraph posting" -> user-triggered, already drafted in-plan + folded into upstream-status.
     Fingerprints ledgered; deleted permanently. Nothing open here.
     fp:ceeea11785514bd6 fp:15f2dd1d2684d2f2 fp:c49fd89e43e4867a fp:5c1003efe2386b53 fp:a2954d6096e3b85c -->
<!-- triaged 2026-06-22: all three 2026-06-22-65816-near-abs-bank-relax.md follow-ups handled — the two
     "Belt-and-suspenders … full 0001-0007 gate" bullets are DONE (§5: combined-stack gate all green on
     both emulators 2026-06-22); "Upstreamable (generic llvm-mos 65816 size fix)" is a future
     user-triggered candidate recorded in the plan's §Status Follow-ups (not yet a drafted artifact, so
     not queued in upstream-contribution-status.md). Nothing open to track here.
     fp:92f89fa0e9b5b7fe fp:61d02e85f1ef111f fp:e9d664a8ba74dadc -->
<!-- triaged 2026-06-23: all three are scope-markers / a forward-note / a contingency from the routed
     far-cc AXY variant-(c) hygiene plan (2026-06-21-320-far-cc-axy-variant-c-hygiene-capture.md), not open
     work for this housekeeping pass — variant (d)/M-harness/winner-promotion are explicitly out of scope
     (covered by the curated M1 far-pointer-CC item + 2026-06-21-320-far-cc-variants-bcd-and-measure.md),
     the D-step fold-note is a forward reminder for that effort, and the 'debug variant (c)' branch is a
     conditional contingency, not active work. Owned by the far-cc effort; nothing new opened here.
     fp:3dc7cd082923d714 fp:be1ae59165aaf65d fp:f4fd52ba2dcb7fba -->
<!-- triaged 2026-06-23: scavenger-nz-fix-spike verification IS recorded — step 1 FAIL → NO-GO outcome
     documented in the plan (the conservative canSaveScavengerRegister(P) gate dead-ends the scavenger on a
     flag-class pseudo with no spill impl). Not a pending [verify]; spike concluded, issue stays issue-only.
     fp:ff8c440178114461 -->
<!-- triaged 2026-06-24: all three are scope notes from the reviewer-presentation plan, not open work.
     • "codegen unchanged" = a scope statement (this task = docs + two ROM-byte-neutral platform
       refinements); nothing to build.
     • "GitHub links resolve once main is pushed" = RESOLVED — main merged + pushed at the close of the task.
     • "posting upstream artifacts is user-triggered" = a standing fact, already curated in the
       Upstream/Contribution section + upstream-contribution-status.md. Nothing open here.
     fp:05152983f417d956 fp:2b58be7d4ba4a17d fp:383468bec170eac8 -->
<!-- triaged 2026-06-24: all three are the deferred Phase-2/3 sub-points of the Blossom SNES port,
     already curated as the single "#3 SNES Blossom on-screen interactive port" item under Open/M2
     (graphics layer = Mode-7 framebuffer + $7E shadow buffer + DMA + CGRAM regs; interactivity =
     joypad controls; optional perf = $4202 hw multiplier). Not separate open work — covered there.
     fp:9a83cc394836d1de fp:8b629fbc2e270274 fp:fb7011942a1132aa -->
<!-- triaged 2026-06-25: this IS done — the matching Test Bench / CI entry was promoted to Done as
     [321-csmith-fuzzer] in the same commit (2cfd375) that captured this deferral; the struck-through plan
     bullet is the now-completed action, not open work. fp:bd0898d1d5c10cfa -->
<!-- triaged 2026-06-25: PLANNED pre-implementation plan (Status: PLANNED) — its Verification section is
     intentionally unrun because nothing is built yet; the steps require the increments to exist first. Tracked
     by the curated open item "#321 Cross-platform toolchain builds" under Distribution / Packaging, where the
     PASS evidence will be recorded as Inc 0–4 land. Not a missed step. fp:6676955ce1f1f4cf -->
<!-- triaged 2026-06-25: trig Phase 2 (16-bit CORDIC) + Phase 3 (derived/hyperbolic) are curated FUTURE
     phases of the trig differential plan, not deferrals — the plan itself tracks them. Phase 1 (Q16.16
     libfixmath) landed + verified this session (k_trig32 0x068A6933, k_trig32lut HiROM 0x87F0B404, both
     emulators). fp:b69409f652ecf145 fp:6129cc5f0e5198c0 -->
- [verify] **2026-06-26-shared-plan-index-tooling** — Verification section present but no PASS recorded — run + record the steps. _from [2026-06-26-shared-plan-index-tooling.md](docs/plans/2026-06-26-shared-plan-index-tooling.md)_  <!-- fp:118418f2ad7a1a78 -->
<!-- END auto-captured-deferrals -->

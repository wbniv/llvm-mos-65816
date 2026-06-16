# TODO

llvm-mos-65816 = bringing an optimizing open-source C compiler to the WDC 65816 via
[llvm-mos](https://github.com/llvm-mos/llvm-mos), plus the SNES platform to exercise it.
See [docs/ROADMAP.md](docs/ROADMAP.md) for the M0 → M1 → M2 plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for upstream status and rationale.
Background: [docs/investigations/llvm-overview.md](docs/investigations/llvm-overview.md)
(what LLVM is, and where llvm-mos fits).

**Status markers:** `[ ]` open · `[wip]` in progress · `[verify]` implemented, verification
not yet run+recorded (run the linked plan's verification steps, paste raw output + PASS/FAIL
back into the plan, then promote to `[x]`) · `[x]` done (moved to Done, one tight line).
Plan-first: non-trivial work gets a `docs/plans/YYYY-MM-DD-<topic>.md` and a TODO entry.


## Open

### M0 — Test Bench

_M0 complete — test bench stands (ROADMAP steps 1–2 PASS). See Done._

### M1 — Far Pointers (first real codegen)

- [ ] **#320 post design note upstream** (user-triggered). Post the drafted note
  ([docs/320-upstream-far-pointer-note.md](docs/320-upstream-far-pointer-note.md)) to #320 / the
  llvm-mos Discord (@asiekierka/@mysterymath) to open the ABI-blessing discussion. Note is drafted &
  ready; this is the manual step that unblocks the full model below.
- [ ] **#320 full five-address-space model + PR.** Implement the five-address-space layout
  (asiekierka's 32-bit-default, packed 24-bit, zero-bank, abs-16) after maintainer ABI blessing, then
  open the PR. Upstream-gated — coordinate on Discord with the running slice + design note in hand.
  Blocked on the posting step above.
- [ ] **#320 runtime far-pointer operations** (the far-pointer *codegen* deferred past the static
  far load/store slice). From the Inc 2 / 2b "out of scope": near→far casts, far-pointer arithmetic,
  indirect-long `[dp]` load/store, far *code* / `JSL` across banks, automatic bank assignment, and
  far data spanning >2 banks. The address-space layout above is the prerequisite.
  [Inc 2 plan](docs/plans/2026-06-14-320-increment-2-far-pointer-emulator-end-to-end-mi.md),
  [Inc 2b plan](docs/plans/2026-06-14-320-increment-2b-multi-bank-rom-far-read.md).

### M2 — Optimizing Payoff

- [ ] **#321 native s16 — 16-bit comparison follow-ups** (unsigned ordering, ~~(a) equality `== !=`~~,
  and ~~(b) signed `slt/sle/sgt/sge`~~ all landed — see Done). Remaining: (c) **equality as a value**
  (`b = (a == c)`): the `+mos-a16` prologue **regression** is FIXED 2026-06-16 (an s16 load consumed
  only by `G_UNMERGE` now loads byte-wise instead of a wasteful 16-bit-load→`A16`→spill→re-read —
  `legalizeLoadStore16`; brings EQ-as-value to parity with default — see Done). The **full native
  compare** (one `rep; lda; cmp; sep` + materialize Z→0/1, beating default) is still deferred — see the
  dedicated bullet below; ~~(d) fold a near-abs global RHS into `CMPAbs16`~~ (landed — see Done; also
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
  [compare-operand-fold plan](docs/plans/2026-06-15-321-native-16bit-compare-abs-operand-fold.md).
- [ ] **#321 native s16 equality-as-value — the full native compare (deferred from item (c)).** With the
  prologue regression fixed, `b = (a == c)` now matches default (8-bit cpx chain + carry-materialize). A
  *native* version would be one `rep; lda; cmp; sep` then materialize **Z**→0/1 — but the backend has
  **no compare that produces N/Z as a value**: every flag-as-value path is carry-based (the 8-bit
  EQ-as-value computes equality into C via `sec`/`clc`), and 16-bit Z exists only as the fused
  compare-**branch** (`CmpBrImag16`/`CmpBrImm16`, `selectBrCondImm`). Making it native needs a new fused
  compare-**select** pseudo (`CmpSelImag16`/`CmpSelImm16`) + expansion (mirror `expandCmpBr16` but end in
  `beq/bne; ldx #1/stz`), folded into `SelectImm` selection via the existing `m_CmpNZ*16` matchers, plus
  relaxing the `NativeS16EqBranch` gate. Deliberately deferred by the 2026-06-15 equality work for this
  reason; substantial; modest win on a rare pattern. **Also:** the byte-wise-load fix gates only the
  *absolute* s16 load — an **indirect** s16 load (`G_LOAD16_INDIR`) consumed only by `G_UNMERGE` still
  round-trips through `A16`; the same `AllUsesUnmerge` guard would apply (lower priority).
  [plan](docs/plans/2026-06-16-321-s16-load-unmerge-bytewise.md).
- [ ] **#321 soft-stack (reentrant) spill coverage — close the gap the F3 fix exposed.** The F3 `Ac16`
  spill fix landed on **both** stacks, but the soft-stack half was found only by a hand-written recursive
  reproducer — the **fuzzer never reaches it**: `gen_funcs` emits only leaf functions (`expr(pure=True)`
  excludes the `call` leaf), so the call graph is acyclic → `MOSNonReentrant` marks every function
  `nonreentrant` → all get static frames. P0: teach `tools/a16_fuzz.py` to emit a **recursive** function
  (the proven soft-stack trigger) so `expandLDSTStk` spills of `Ac16`/`Imag16`/8-bit get value-level
  differential coverage (host==default==a16, both emulators). P1: document the `expandLDSTStk` spill
  contract at the `MOSRegisterInfo.cpp:528` assert (every spillable ≥16-bit class needs an explicit case
  — `xy16` index-16 is the latent next one). P2: add a hermetic `.ll` crash-regression for the soft-stack
  `Ac16` spill. P3 (optional, upstream, not #321): `__attribute__((reentrant))` can't force the soft
  stack — file an issue. [plan](docs/plans/2026-06-16-321-soft-stack-spill-coverage.md).
- [ ] **#321 native s16 — agreed optimization order (after load-fold).** ~~(2) 16-bit compares/branches~~
  (slice 1, unsigned ordering — done); ~~(3) inc/dec + 16-bit shifts~~ (constant shifts incl. signed
  `>>`/ASHR done — see Done; ~~1-byte `inc a`/`dec a`~~ done — see Done [register + global `g±1` via
  `lda; inc/dec a; sta`]; remaining: variable shifts [libcall today, low value], amount ≥8 [byte-relabel
  already optimal]; ~~memory-RMW `inc abs`/`dec abs`~~ investigated + rejected — no `inc long` on the
  65816 and `inc abs` is DBR-relative, unsafe vs the platform's long (DBR-independent) data addressing;
  see Done); ~~(4) indexed/array access~~ (indirect `(zp)` load/
  store done — see Done; the X-flag dimension is NOT needed for arrays — llvm-mos is pointer-based;
  remaining: 16-bit absolute & indexed `abs,x`/`(zp),y` load/store); (5) A16-threading (value stays
  live in the accumulator across ops — biggest win but reintroduces the coalescer-crash risk, so
  deferred behind a broad corpus — **the corpus now exists: Tier 1 landed 2026-06-16 (differential
  fuzzer + 6 kernels + 2 combinatorial tests; it already found+fixed 2 backend bugs), so this is
  de-risked and unblocked**); ~~(6) cross-block REP/SEP mode-tracking~~ (M-flag done — see Done;
  X-flag is a separate dimension); (7) hardware-stack ABI / 16-bit calling convention (upstream-gated).
  ROADMAP step 5 frontier.
  [1d-retry plan](docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md).
- [ ] **#321 native s16 memory-access follow-ups** (indirect `(zp)`, absolute, the abs→abs copy fusion,
  ~~and the indirect copy fusion~~ all landed — see Done). Remaining: (a) the indir-**dst** copy fold
  (`*p = gg`, `*q = *p`) only fires when the dst-pointer load doesn't sit between the value-load and the
  store as an ordered (volatile) memref — for a volatile pointer it conservatively stays a round-trip;
  consider loading the dst pointer first so the value-load is adjacent to the store; (b) the indexed
  `abs,x`/`(zp),y` forms are **moot** (llvm-mos is fully pointer-based); (c) **re-evaluate the X-flag
  (xy16) mode dimension** — NOT required for array access; assess whether it pays off before building.
  [indirect plan](docs/plans/2026-06-15-321-native-16bit-indirect-load-store.md) ·
  [absolute plan](docs/plans/2026-06-15-321-native-16bit-absolute-load-store.md).
- [ ] **#321 16-bit ALU chain extensions** (extends Inc 1c, which fused add-chains only). Done:
  ~~the multi-use add chain~~ (`add_chain16_ld`), ~~immediates *within* add chains~~ (`a+b+c+K` → final
  `adc #imm`), and ~~AND/OR/XOR chains~~ (`bit_chain16`/`_ld`, no carry-init) — see Done. SUB chains are
  **moot** (the optimizer reassociates `a-b-c` to `a-(b+c)`, not a homogeneous chain). Remaining:
  **spilling when >1 16-bit value is live at once** (the deeper register-allocation work).
  [1c plan](docs/plans/2026-06-14-321-increment-1c-chained-16bit-alu.md) ·
  [add-chain-immediate plan](docs/plans/2026-06-15-321-native-s16-add-chain-immediate.md) ·
  [bitwise-chains plan](docs/plans/2026-06-15-321-native-s16-bitwise-chains.md).
- [ ] **#321 unify the 1b/1c peephole into the GISel-native path** (cleanup, once the native path is
  proven on a broad corpus — **that corpus now exists: Tier 1, 2026-06-16, so this is unblocked**). The
  all-global-shape peephole currently coexists as a proven fast-path; fold it into the native path to
  retire the dual codegen path.
  [1d-retry plan](docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md) ·
  [Tier-1 plan](docs/plans/2026-06-15-321-tier1-broaden-corpus.md).
- [ ] **#321 stage 1 — full xy16 mode + ABI** (after Increment 1): X/Y permanently 16-bit;
  ~~REP/SEP mode-tracking across control flow + churn minimization~~ (M-flag done — see Done; the
  X-flag is a separate mode dimension still to add to the dataflow); 16-bit arithmetic; **native-mode
  crt0** (XCE + native vectors + DBR — the prerequisite for 16-bit registers, moved here from #320
  Increment 2); then hardware-stack ABI + calling convention. ROADMAP step 5.
- [ ] **DWARF round-trip (drmon tie-in).** `-g` build emits llvm-mos DWARF that drmon's DAP loads
  with correct line/variable mapping. ROADMAP step 6; drdevtools `mame-65816-gdbstub` pre-wires it.

### Test Bench / CI

- [x] **#321 Tier-1 differential fuzzer (standing capability).** `tools/a16_fuzz.py` +
  `dev/run.sh fuzz [N] [seed]`: seeded generator of random UB-free C over mixed 16/8-bit vars and the
  full `+mos-a16` operator set; compiles each DEFAULT + `+mos-a16`, runs both on MAME + bsnes-jg, and
  asserts host==default==a16 + `-verify-machineinstrs`. Delta-reduced triage (`build/fuzz-triage/`),
  reproducible seeds, XFAIL-classified known issues. Run on a quiet box (concurrent load flakes MAME).
  Re-run before/after any A16-threading (Tier 2) or peephole-unification (Tier 3) change.
  [Tier-1 plan](docs/plans/2026-06-15-321-tier1-broaden-corpus.md). _(See Done for the landing + bugs.)_
- [verify] **Wire the bsnes-jg `xcheck` into CI** — implemented + YAML-validated; a green CI dispatch
  is the remaining confirmation (heavy, user-triggered: the from-source toolchain build is ~30–90 min).
  Added an `xcheck` job to `smoke.yml` (parallel to `smoke`): builds the from-source patched toolchain
  (cached via `actions/cache@v5`, keyed on the backend patches; skipped on hit) + the snes-far SDK,
  then `dev/run.sh xcheck` on bsnes-jg. Runs unconditionally (no SPC700 secret needed). Verify with
  `gh workflow run snes-smoke && gh run watch` (cold then warm).
  [plan](docs/plans/2026-06-15-wire-bsnes-jg-xcheck-into-ci.md) ·
  [second-emulator plan](docs/plans/2026-06-14-second-emulator-cross-check-bsnes-jg.md).
- [verify] **M1 toolchain incremental-rebuild time not yet measured** — the from-source plan's
  verification step 4 ("editing a backend file relinks fast") is "not separately timed yet"; measure
  once the first #320 codegen edits land.
  [m1 plan](docs/plans/2026-06-14-m1-from-source-toolchain.md).

### Upstream / Contribution

- [ ] **Reconcile with llvm-mos-sdk#415 (the existing SNES target draft PR).** Build ON @Phillip-May's
  stalled-but-working SDK scaffolding, don't replace it: reuse his `snesxc` register lib + multi-bank
  linker (with credit); contribute on top our native-mode crt0 (unlocks 16-bit codegen) + the
  dual-emulator CI bench his PR lacks; keep the backend codegen (#320/#321) entirely separate (it
  lands in `llvm-mos`, targets any `-mcpu=mosw65816` platform). Strategy + the tier-1/tier-2
  positioning note for engaging @asiekierka on #321 are drafted in
  [415-snes-target-reconciliation](docs/415-snes-target-reconciliation.md). User-triggered (posting).


## Watch

_Nothing being watched yet — items move here when they need periodic checking (e.g. an upstream
llvm-mos change to track) rather than active work._


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
- 2026-06-15 — [321-native-s16-inc-dec-abs] **`inc a`/`dec a` for global `g ± 1` (+ `inc abs` rejected).** `selectAlu16Abs` now emits `lda <g>; inc/dec a; sta <g>` for a global ±1 instead of `clc; lda; adc #$0001; sta` (3 instrs vs 4), keeping the compiler's 24-bit long addressing. A single `inc abs`/`dec abs` memory-RMW was prototyped and **reverted**: the 65816 has no `inc long`, `inc abs` is DBR-relative, and this platform addresses all data via DBR-independent long loads/stores — the RMW only works via the low-8KB WRAM mirror (DBR=0 + bank-0 LoRAM), a latent miscompile for any high global. `a16incabs` reads 0x3502 (3 inc + 1 dec, no adc #1, no ee/ce). 28 a16* tests + corpus 7/7 green; `0002` round-trips. [plan](docs/plans/2026-06-15-321-native-s16-inc-dec-memory-rmw.md).
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
<!-- END auto-captured-deferrals -->

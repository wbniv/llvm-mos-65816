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

### M2 — Optimizing Payoff

- [ ] **#321 native s16 — load-fold follow-ups** (the [load-fold](docs/plans/2026-06-14-321-native-s16-fold-global-operand-loads-into-the.md)
  core landed — see Done). Remaining same-machinery extensions: (a) **mixed operand** `t = a16v + local`
  (one global load + one `Imag16` register — dispatch addressing mode per operand); (b) single-use-non-
  store results (the `>1 use` guard skips these today); (c) chained multi-use load expressions (extend
  `add_chain16`).
- [ ] **#321 native s16 — 16-bit comparison follow-ups** (slice 1, unsigned ordering `< <= > >=`,
  landed — see Done). Remaining, same approach: (a) **equality** (`== !=`) — the Z flag must fuse into
  the branch terminator (a 16-bit `CmpBr` in `selectBrCondImm`); (b) **signed** (`slt/sle/sgt/sge`) —
  the N^V 16-bit lowering in `legalizeICmp`; (c) compare feeding a **select**/bool value (not a branch);
  (d) fold a near-abs global RHS into `CMPAbs16` (mirror `selectAlu16AbsLd`).
  [plan](docs/plans/2026-06-14-321-native-16bit-compares.md).
- [ ] **#321 native s16 — agreed optimization order (after load-fold).** (2) 16-bit compares/branches
  (currently narrow to 8-bit chains); (3) inc/dec + 16-bit shifts; (4) indexed/array access; (5)
  A16-threading (value stays live in the accumulator across ops — biggest win but reintroduces the
  coalescer-crash risk, so deferred behind a broad corpus); (6) cross-block REP/SEP mode-tracking; (7)
  hardware-stack ABI / 16-bit calling convention (upstream-gated). ROADMAP step 5 frontier.
  [1d-retry plan](docs/plans/2026-06-14-321-increment-1d-retry-imag16-native-s16.md).
- [ ] **#321 stage 1 — full xy16 mode + ABI** (after Increment 1): X/Y permanently 16-bit; REP/SEP
  mode-tracking across control flow + churn minimization; 16-bit arithmetic; **native-mode crt0** (XCE
  + native vectors + DBR — the prerequisite for 16-bit registers, moved here from #320 Increment 2);
  then hardware-stack ABI + calling convention. ROADMAP step 5.
- [ ] **DWARF round-trip (drmon tie-in).** `-g` build emits llvm-mos DWARF that drmon's DAP loads
  with correct line/variable mapping. ROADMAP step 6; drdevtools `mame-65816-gdbstub` pre-wires it.

### Upstream / Contribution

- [ ] **Reconcile with llvm-mos-sdk#415 (the existing SNES target draft PR).** Build ON @Phillip-May's
  stalled-but-working SDK scaffolding, don't replace it: reuse his `snesxc` register lib + multi-bank
  linker (with credit); contribute on top our native-mode crt0 (unlocks 16-bit codegen) + the
  dual-emulator CI bench his PR lacks; keep the backend codegen (#320/#321) entirely separate (it
  lands in `llvm-mos`, targets any `-mcpu=mosw65816` platform). Strategy + the tier-1/tier-2
  positioning note for engaging @asiekierka on #321 are drafted in
  [415-snes-target-reconciliation](docs/415-snes-target-reconciliation.md). User-triggered (posting).
- [ ] **Surface WDC816CC/ORCA-C ABI prior art in #320/#321** — low-effort, no-code contribution
  documenting the calling-convention prior art (DP frame vs hardware-stack frame). Summarized in the
  [#320 design note](docs/320-upstream-far-pointer-note.md) (open ABI decisions §3) with an offer to
  expand into a standalone prior-art writeup if the maintainers want it; promote when that's done.


## Watch

_Nothing being watched yet — items move here when they need periodic checking (e.g. an upstream
llvm-mos change to track) rather than active work._


## Parked

_Nothing parked yet — items move here when intentionally shelved (feasibility done but not
starting, or blocked on an external factor)._


## Done

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

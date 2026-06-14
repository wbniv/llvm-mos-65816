# M2 / #321 — Increment 1b: dual-width accumulator register (the hard core)

**Date:** 2026-06-14 · **Status:** **COMPLETE — a running 16-bit add, verified on both emulators.**
`g16 = a16v + b16v` (0x1234 + 0x1111) compiles under `+mos-a16` to one bracket
`clc; rep #$20; lda; adc; sta; sep #$20` and computes **`corpus_result == 0x2345`** on **both** MAME
and bsnes-jg, driven solely by the native-mode crt0. Non-breaking: corpus 7/7, Inc 1a (0x0042) and far
xcheck all green. `dev/run.sh a16add`. The real value flows through the dual-width `A16` accumulator —
the genuine hard core of #321. · **Milestone:** M2 (ROADMAP step 5). **Builds on:** Increment 1a (the
`MOSInsertREPSEP`
pass + opt-in `+mos-a16` feature, [plan](2026-06-14-321-increment-1-16bit-accumulator.md)) and the
native-mode crt0 ([plan](2026-06-14-321-native-mode-crt0.md)) that lets 16-bit codegen run on the
emulators with no per-test mode entry.

## Context

Increment 1a proved the **REP/SEP-insertion mechanism** by fusing a 16-bit store-of-**zero**
(`*g16 = 0` → `rep #$20; stz; sep #$20`) entirely inside the `MOSInsertREPSEP` pass — no register
modeling, because `STZ` has no register operand. 1b is the next step: flow a **real (non-zero)
16-bit value** through a 16-bit-mode accumulator. The original Inc 1 plan framed 1b as "model the
dual-width `A`/`C` register … reuses everything 1a builds." The grounding investigation below shows
that framing is right about the *destination* but wrong about "reuses everything / cheap": the
natural 16-bit cases don't go through `A` at all in 8-bit codegen, so there is **no fusion shortcut**
analogous to 1a — 1b is genuinely the register-modeling hard core.

## Grounding investigation (2026-06-14) — how 16-bit ops actually lower today

Built five `unsigned short` kernels with the from-source toolchain (`+mos-a16`, `-Os`,
`-mcpu=mosw65816`) and dumped the 8-bit lowering (`mos-clang -S`). Raw results:

| Source | 8-bit lowering | Uses `A`? |
|---|---|---|
| `dst = src;` (mem→mem copy) | `ldx src; ldy src+1; stx dst; sty dst+1` | **no** (X/Y) |
| `g = 0x1234;` (const store) | `ldx #52; stx g; ldx #18; stx g+1` | **no** (X) |
| `return g;` | `lda g; ldx g+1` | low byte only |
| `g = a + b;` | `ldx a; stx __rc2; ldx a+1; stx __rc3; lda b; ldx b+1; stx __rc4;`<br/>`clc; adc __rc2; tax; lda __rc4; adc __rc3; stx g; sta g+1` | yes (carry chain) |
| `g = g + 1;` | `ldx g; ldy g+1; inx; bne L; iny; L: stx g; sty g+1` | **no** (X/Y + branch) |

**Findings.**

1. **No fuseable `A` pair exists for the natural cases.** Copy/const-store/inc spread the two bytes
   across **X and Y** (or X-immediate pairs), not a `LDA/STA` pair. 1a's trick — match two adjacent
   `STZAbs` to the same global at offsets N/N+1 — has no analogue here, because there is no
   `LDA …; STA …; LDA …+1; STA …+1` to collapse. The 6502 backend simply doesn't route 16-bit
   value-moves through the accumulator.

2. **A constant-store fusion would be break-even, not a win.** The one case with an obvious pair
   shape (`g = 0x1234`) is 10 bytes in 8-bit (`ldx#/stx ×2`) and **also 10 bytes** fused
   (`rep #$20 (2) + lda #$1234 (3) + sta g (3) + sep #$20 (2)`). The 4-byte REP/SEP bracket exactly
   eats the one saved load/store. This is the amortization caveat 1a already recorded (finding (b)):
   a single 16-bit op under its own REP/SEP pair never beats 8-bit. So a const-store peephole would
   **fail ROADMAP step 5's "smaller/faster" bar** — not worth doing.

3. **The first slice that actually wins is the 16-bit `add`** — and it requires the dual-width
   register. `g = a + b` is ~13 instructions / ~25 bytes of 8-bit carry chain; the 16-bit form is
   `rep #$20; lda a; clc; adc b; sta g; sep #$20` ≈ 14 bytes — a real win, **and** the REP/SEP
   overhead amortizes because several 16-bit ops sit between one bracket. There is no peephole for
   it: the 8-bit chain (`adc lo; tax; lda; adc hi`) doesn't pattern-match to a single op. Reaching it
   means the instruction selector must target a real 16-bit accumulator and reg-alloc must handle it.

4. **Building blocks already exist in the MC layer.** `CC1_All` (`MOSInstrInfo.td:31-37`) already
   generates `_Immediate16` forms (`Inst24`, `MLow=1`) for every cc=01 opcode — so `LDA_Immediate16`,
   `ADC_Immediate16`, etc. exist as MC instructions; `STA`/`LDA` absolute are width-agnostic opcodes
   the M flag governs at runtime. The streamer's `emit816MXState` already emits `$ml/$mh` mapping
   symbols from those TSFlags. So the **MC/encoding layer is ready**; the entire gap is **GISel +
   register modeling** (legalizer keep-16-bit, a 16-bit-accumulator register class that aliases `A`,
   register-bank, selector, calling-convention for the 16-bit return/arg).

**Conclusion.** 1b cannot be a pass-level peephole like 1a. It is the genuine dual-width-register
core of #321. The cheap-fusion well is dry; the next real, milestone-meeting progress is the register
modeling, with the **16-bit `add`** as the first target that both runs correctly and is smaller.

## Approach options (decision pending — see "Open decision")

### Option A — full dual-width accumulator register modeling (the real #321 core)

Model `A` as the low half of a 16-bit accumulator `C` aliasing the same physical bits, sized by the
runtime M flag. Decomposed into buildable sub-steps, each kept non-breaking (inert without `+mos-a16`):

1. ~~**Register class + aliasing (tablegen).**~~ **DONE** (2026-06-14). Added `def A16` (= `B`:`A`,
   `A` as `sublo`) + the high-byte `def B` + class `def Ac16` in `MOSRegisterInfo.td`. Named `A16`
   (not the WDC name `C`) on purpose — `def C` is the *carry flag*; conflating them is a 65816
   footgun, called out in a comment at the definition. Verified non-breaking: toolchain rebuilds
   clean (87 targets, `MOSGenRegisterInfo.inc` regen), corpus **7/7** — the register is inert (nothing
   selects it yet). In `patches/llvm-mos/0002-321-accum16.patch`.
2. **Legalizer (feature-gated).** Under `HasAccum16`, keep a 16-bit `G_ADD`/`G_LOAD`/`G_STORE` as a
   single 16-bit op instead of `narrowScalar`→S8 pairs, for the straight-line leaf case. *Verify: MIR
   shows un-narrowed 16-bit ops; 8-bit path unchanged.*
3. **Selector + reg-bank.** Select the 16-bit ops to `LDA_Immediate16`/`ADC*16`/`STA` targeting the
   `C16` class; teach `MOSRegisterBankInfo` the accumulator-16 bank. *Verify: `-verify-machineinstrs`
   clean, no GISel fallback.*
4. **REP/SEP pass extension.** The existing mode-walk already reads `MLow` TSFlags and brackets runs
   of 16-bit ops — so once selected ops carry `MLow`, the pass brackets the whole `add` with **one**
   `rep/sep` pair (the amortization win). *Verify: disasm shows one bracket around the add.*
5. **Calling-convention pin.** Keep the Inc-1 leaf convention (A 8-bit at entry/exit); the 16-bit
   value lives only within the bracket. The real ABI (16-bit args/returns) stays deferred to stage 1.

Target test: `examples/65816/a16add.c` — `g16 = a16 + b16` reads the correct 16-bit sum on **both**
emulators and the `+mos-a16` function is **smaller** than the 8-bit build. Captured in
`patches/llvm-mos/0002-321-accum16.patch` (extended).

**Risk:** highest in the project — register aliasing, reg-bank, and selector interact; sub-steps 1-3
build but aren't independently runtime-verifiable until 3 lands, so it's closer to a "big bang" than
1a's incremental fusion. Expect many edit→`dev/run.sh toolchain`→inspect cycles.

### Option B — INC-absolute memory idiom (a real win without register modeling)

Recognize the `g = g + 1` idiom (`ldx g; ldy g+1; inx; bne; iny; stx g; sty g+1`) and fuse it to
`rep #$20; inc g; sep #$20` (16-bit `INC` absolute operates on memory, width by M — **no accumulator
register needed**). Genuine size win (~13→7 B). **But** the idiom spans a branch (the `bne`/`iny`
carry), so matching it in `MOSInsertREPSEP` is fragile cross-BB pattern-work — narrow and somewhat
throwaway (only `+1`/`-1` memory updates), and it doesn't advance toward the register core.

### Why not a constant-store peephole

Finding 2: break-even, fails the "smaller/faster" bar. Explicitly rejected.

## Open decision (blocks implementation)

The grounding finding re-frames 1b away from "cheap, reuses 1a" toward "the hard register core."
**Decision needed:** commit to **Option A** (the real dual-width register, first target the 16-bit
`add`) — accepting it's the largest, highest-risk piece of the project and lands over several
build cycles — or do **Option B** (INC idiom) first as a smaller real win while deferring A. The
recommendation is **Option A**: the cheap wins are exhausted, A is the actual #321 deliverable, and
the MC layer is already in place so the work is GISel/regalloc, not encoding.

## Implementation design (grounded 2026-06-14)

Decisive findings from reading the GISel pipeline:
- **Register banks are unused** — one `AnyRegBank`; allocation is driven by the *register class* of
  the selected instruction's operands. So `A16` is forced purely by selecting ops with `Ac16`
  operands (the class has only `A16`); just add `Ac16` to `AnyRegBank`.
- **The pre-legalizer combiner** (`createMOSCombiner` at `addPreLegalizeMachineIR`) sees the clean
  generic DAG `G_STORE(G_ADD(G_LOAD a, G_LOAD b), g)` (confirmed: `int` is 16-bit, so the add is a
  real `s16 G_ADD`). Matching here avoids the race with per-instruction narrowing in the legalizer.
- **`MOSInsertREPSEP` reads `MLow` TSFlags at `addPreEmitPass`**, on the *logical* instructions
  (before MCInst expansion). So if the 16-bit logical ops carry `MLow=1`, the existing mode-walk
  brackets the run with one `rep #$20 … sep #$20` pair — step 4 is essentially free.

The pieces (mirroring #320's far-pointer custom-pseudo style) — **all shipped:**
1. ✅ `Ac16` register class added to `AnyRegBank` (`MOSRegisterBanks.td`).
2. ✅ `MLow` bit on `MOSLogicalInstr` (TSFlags{0}, matching the MC `Inst` base) + three logical
   ops `LDAbs16`/`ADCAbs16`/`STAbs16` (`MLow=1`, `Ac16` operands, `PseudoInstExpansion` to the
   width-agnostic `LDA/ADC/STA_Absolute`) + a `HasAccum16` tablegen `Predicate` (the feature only had
   a C++ accessor before).
3. ✅ `G_ADD16_ABS` op (`MOSInstrGISel.td`, `[HasAccum16]`): three global-address operands + three
   memoperands.
4. ✅ Combiner rule `add16_abs` (`MOSCombine.td` + `MOSCombiner.cpp`): match `G_STORE(G_ADD(load,
   load))` (s16, near abs globals, single uses, `HasAccum16`) → build `G_ADD16_ABS`, erase the
   store/add/loads.
5. ✅ Legalizer: **NO rule** (see gotcha below) — `G_ADD16_ABS` is a target-specific opcode the
   legalizer skips by range.
6. ✅ Selector: `selectAdd16Abs` emits `clc (LDImm1, first/outside the run); lda a; adc b; sta g`
   with vregs constrained to `Ac16`; the REP/SEP pass brackets the three `MLow=1` ops.

**Two gotchas hit and fixed:**
- **A legalizer rule for a MOS-specific *generic* opcode corrupts the legalizer tables** (heap
  bad-free at TargetMachine teardown — crashed the SDK's LTO link of `crt0`, code unrelated to
  `+mos-a16`). Fix: register no rule. `G_ADD16_ABS`'s opcode is above `PRE_ISEL_GENERIC_OPCODE_END`,
  so the legalizer skips it by range, while `MOSGenericInstruction` still sets `isPreISelOpcode` so
  InstructionSelect selects it — exactly how #320's far pseudos work. (A brief detour making it a
  *non-generic* pseudo cured the crash but then InstructionSelect skipped it, silently dropping the
  add — generic-without-rule is the correct combination.)
- **The `clc` must be emitted *before* the 16-bit run, not between `lda` and `adc`.** The REP/SEP
  mode-walk toggles back to 8-bit on any `MLow=0` instruction, so a `clc` inside the run would split
  it into three brackets. `lda` doesn't touch carry, so `clc; lda; adc; sta` is correct and keeps one
  bracket.
- Note: near-global absolute accesses encode as absolute-**long** (`af/6f/8f`) on W65816 — pre-existing
  behavior (the 8-bit accumulator `LDAbs` does the same); correct in native mode (DBR=0) and the M
  flag still governs width. An `af→ad` size tweak is orthogonal and out of scope.

## Verification — all PASS (2026-06-14, from-source toolchain + rebuilt SDK)

1. **Non-breaking** — without `+mos-a16`: 6502 corpus 7/7, Inc 1a still 0x0042, far xcheck both
   emulators agree. The feature/combiner/pass are inert by default; the SDK builds (the LTO link that
   the legalizer-rule bug crashed). PASS.

```
==> corpus: 7/7 passed
a16:     RESULT: PASS — 16-bit STZ (rep/stz/sep) zeroes g16; both emulators read 0x0042
xcheck:  far-run + far-bank1 both got=0xF3 — bsnes-jg agrees with MAME
SDK:     SDK OK
```

2. **16-bit add lowering (the deliverable)** — `a16add.c` with `+mos-a16`: one `rep #$20` … `sep #$20`
   bracket around `lda`/`adc`/`sta`, `clc` outside it. PASS.

```
       0: 18           	clc
       1: c2 20        	rep	#$20
       3: af 00 00 00  	lda	$0
       7: 6f 00 00 00  	adc	$0
       b: 8f 00 00 00  	sta	$0
       f: e2 20        	sep	#$20
  PASS: exactly one rep #$20 / one sep #$20 / 16-bit adc present
```

3. **Correct on both emulators** — `g16 = a16v + b16v` = 0x1234 + 0x1111 = 0x2345, driven solely by
   the native-mode crt0 (no inline XCE). PASS.

```
MAME:     SMOKE: PASS addr=0x7E0206 len=2 got=0x2345 (ran 60 ticks)
bsnes-jg: SMOKE: PASS off=0x206 len=2 got=0x2345 (ran 180 frames, bsnes-jg)
RESULT: PASS — 16-bit add computes 0x2345; both emulators agree
```

4. **Smaller than 8-bit mode** — `main` is 31 bytes with `+mos-a16` vs 48 without (the carry chain),
   meeting ROADMAP step 5's "smaller/faster". PASS.

```
  a16add.o    main = 31 bytes   (+mos-a16: clc/rep/lda/adc/sta/sep)
  a16add_8.o  main = 48 bytes   (8-bit ADC carry chain)
```

5. **No GISel fallback / clean compile** — `a16add.c` compiles and links with no fallback or verifier
   error; the SDK (LTO) builds clean. PASS.

## Out of scope (later)

- Full **xy16** mode + the **hardware-stack ABI** + **calling convention** (16-bit args/returns) —
  #321 stage 1 after the accumulator core works.
- **Mode-tracking across control flow** (the pass is still straight-line/leaf) + REP/SEP churn
  minimization across blocks.
- Upstream PR — after a credible running 16-bit-add slice + the ABI discussion.

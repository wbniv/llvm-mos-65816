# AsmPrinter does not mark 16-bit immediates under `+mos-a16` — print `#mos16(N)` so a16 code round-trips

**TODO entry:** `- [wip T4] **AsmPrinter does not mark 16-bit immediates under `+mos-a16` — worse than the
long-address gap above.**` (`TODO.md`, M2 / #320 section).
**Diagnosis:** [audit §6.3](../investigations/2026-09-24-mos24-far-addressing-completeness-audit.md#63-the-second-instance--16-bit-immediates-under-mos-a16).
**Sibling item, already landed:** [`2026-09-24-asmprinter-long-address.md`](2026-09-24-asmprinter-long-address.md)
(patch `0044`, commit `5ea5006c`). Its §2 derives the design and its §3 names the shape this item inherits.
**This plan does not re-derive that design** — it records the two places the inherited note was wrong.

**Visible surface:** none. This changes generated assembly text only — no UI, page, TUI or document — so
there is no mockup bundle.

---

## 1. The defect

Under `+mos-a16` the accumulator is 16 bits (`M=0`), so the compiler selects the `Immediate16` addressing
mode: a 3-byte instruction whose operand is an `Imm16` fixup. `MOSMCInstLower` hands the InstPrinter a
plain `MCOperand::createImm`, and `printOperand` prints it bare:

```
a16.s:  rep  #32        ; M=0 — accumulator is 16-bit
        lda  g16
        clc
        adc  #66        ; compiler's own object: 69 42 00   (3 bytes)
        sta  corpus_result
        sep  #32
```

Re-parsing `adc #66` — which is what `-save-temps` does — makes the matcher pick the narrowest candidate
(`isImm8()` is `[0, 255]`), so it reassembles to `69 42`, **two** bytes. Under M=0 the CPU then eats the
next opcode's first byte as the immediate's high byte: the whole instruction stream desynchronises from
that point. Values ≥ 256 are safe by accident — they cannot fit `isImm8()` — which is why this was never
noticed.

Measured baseline, this toolchain (`build/llvm-mos-install`, `clang-23` 2026-09-24 15:04, the `0044`
build), `dev/probe-far-roundtrip.sh` under `-Os -Xclang -target-feature -Xclang +mos-a16`:

```
far/packed24 corpus (26)   : round-trip: 24 identical,  2 divergent, 0 skipped
full 65816 corpus (117)    : round-trip: 85 identical, 32 divergent, 0 skipped
```

The two remaining far-corpus divergences are exactly the ones `0044` left behind (`farindex.c:26`,
`farspill-probe.c:110`). The 32 over the full corpus are this defect's true blast radius.

A census of every immediate the corpus prints under `+mos-a16` (and under `+mos-a16 +mos-xy16`) — 5 993
decimal immediates plus 122 modifier-carrying ones — found **no** negative immediate, **no** immediate
above `0xFFFF`, and **no** width modifier (`mos16lo`/`mos16hi`/`mos24segment*`) sitting on an `Immediate16`
operand: every `ldx #mos16lo(arr)` in the corpus is a genuine 2-byte `LDX_Immediate` (`a2 00`), even under
`+mos-xy16`. So the ambiguous set is exactly *plain constants in `[0, 0xFF]`*.

## 2. Design — inherited from `0044`, with two corrections

**Chosen (unchanged from `0044` §3): a `PrintMethod` on the `imm16` operand, printing `mos16(N)` iff the
bare text would re-parse narrower.** The `#` comes from `Immediate16`'s `OperandsStr` (`"#$param"`), so
the result is `adc #mos16(66)`. `printOperand` already spells `mos16(N)` for a constant `VK_IMM16`, and
the parser already binds the modifier's width (`0039`), so this adds only the *decision to mark*.

| operand | printed | why |
|---|---|---|
| constant in `[0x100, 0xFFFF]` | `#43981` | cannot fit `isImm8()` — already unambiguous |
| constant in `[0, 0xFF]` | `#mos16(66)` | would re-parse as an 8-bit immediate |
| constant outside `[0, 0xFFFF]` | `#mos16(-1)` | bare `#-1` matches *neither* `isImm8` nor `isImm16`, so it does not even assemble; `mos16()` masks to the operand's width, which is what the encoder does anyway (unreachable in the corpus, handled for robustness) |
| any other expression (bare symbol, sum) | `#mos16(sym)` | a bare symbol matches the narrowest candidate |
| expression already carrying a MOS modifier | unchanged | it prints its own modifier; wrapping twice gives `mos16(mos16(x))` |

**Correction 1 — the threshold is `≤ 0xFF`, and it is not a guess: the disassembler already implements
it.** `MOSDisassembler::getInstruction` (`Disassembler/MOSDisassembler.cpp:326-333`) wraps a decoded
`Immediate16` operand in a `VK_IMM16` expression exactly when `(uint64_t)Op.getImm() <= UCHAR_MAX`. That
is the same rule, on the other side of the same printer, already in the tree. The `Imm16` fixup value is
a non-negative 16-bit pattern on the disassembly path, and the corpus census above shows the codegen path
never produces a negative or over-wide one — but the printer handles both anyway, because for an
immediate (unlike an address) `mos16()` masking to the operand's width is precisely what `encodeImm<Imm16>`
does, so marking is never *less* faithful than leaving it bare.

**Correction 2 — the sibling's proposed lit test cannot fail pre-fix, so the regression guard has to be a
CodeGen test, not an MC one.** `0044`'s test disassembles bytes and feeds the text back
(`MC/MOS/long-address-roundtrip-65816.s`). That instrument does not reach this bug:

- The disassembler only enters `MLow`/`XLow` via the **mapping symbols** `$ml`/`$mh`/`$xl`/`$xh`
  (`MOSDisassembler::onSymbolStart`, `MOSDisassembler.cpp:244-261`) — never from `rep`/`sep` bytes. A raw
  `llvm-mc -disassemble` byte list has no symbols, so `0xc2,0x20 0x69,0x42,0x00` decodes as
  `rep #32` / `adc #66` / `brk`: the 3-byte immediate form is not even reached (measured, §5 step 1).
- And when it *is* reached (`llvm-objdump` over a real object, which has the mapping symbols), correction 1
  says the disassembler has already wrapped the operand — so the printer's new rule is a no-op there and
  the test passes **pre-fix**.

There is no MC-level way to build an `Immediate16` MCInst carrying a plain small `imm`: the assembler has
no M-state, so text always matches `Imm8` first. Only codegen produces one. The regression guard is
therefore `llvm/test/CodeGen/MOS/a16-immediate-width.ll` (`llc -mattr=+mos-a16`, CHECK the printed
`#mos16(...)`), which does fail pre-fix. The `0044`-style MC test is dropped rather than written green.

**Kept as-is, deliberately: the disassembler's own wrapper is not removed.** With the PrintMethod in
place it is redundant, but the two compose without double-wrapping (the printer sees a `MOSMCExpr` with a
non-`VK_NONE` kind and prints it unchanged), and deleting stock llvm-mos code to save nothing is churn on
a fork-only patch.

**Accepted cosmetic over-marking: 65CE02 `phw #imm`.** `PHW_Immediate` (`MOSInstrInfo.td:527`) is the one
non-65816 user of the `Immediate16` mode, and its immediate slot has no narrower sibling, so its bare text
never lies. It will nevertheless print `phw #mos16($42)` for a small constant. Over-marking is never a
correctness regression — the modifier states the operand's true width and re-parses to the identical
encoding — and carving out a parallel `imm16`-without-PrintMethod operand class to save four characters on
one opcode costs more surface than it buys. `MC/MOS/all-65ce02-opcodes.s` uses `phw #$eaea` (> 0xFF), so
there is no test churn; §5 step 4 is what proves it.

**Rejected — wrap in `MOSMCInstLower` instead** (i.e. have codegen emit a `VK_IMM16` expression for a
small a16 immediate, mirroring `wrapAbsoluteIdxBase`'s zero-page rule at `MOSMCInstLower.cpp:51`). It
fixes the same fixtures, and it is arguably the more honest home since the defect only exists on the
codegen path. Rejected because it would make three copies of one rule — the disassembler's, the lowerer's,
and none in the printer, which is the single place every MCInst passes through regardless of origin. The
printer version subsumes the disassembler's and needs no per-opcode knowledge.

**Rejected — `.a8`/`.a16` mode directives.** Same argument as `0044` §2: a directive is *stateful*, its
meaning depends on where the reader enters the file, and every hand-written `asm()` block inherits
whatever state the surrounding generated code left. The modifier is per-operand and cannot be left
switched on. (This is the alternative the audit flagged as the reason to rank the item T4; it is settled
here the same way its sibling settled it.)

## 3. Implementation

New standalone patch **`0045-mos-asm-print-a16-immediate.patch`**, applied after `0044`. **Fork-only**:
see §6. Files, all under `llvm/lib/Target/MOS`:

1. `MCTargetDesc/MOSInstPrinter.h` — declare `printImm16Operand(const MCInst *, unsigned, raw_ostream &)`.
2. `MCTargetDesc/MOSInstPrinter.cpp` — implement it per §2's table.
3. `MOSInstrFormats.td` — `def imm16 : imm16at<1>` gains `let PrintMethod = "printImm16Operand";`.
   Scoped to the `def`, not the `imm16at<>` class, so `imm16at5` (the HuC6280 `tii`/`tdd` block length,
   whose slot likewise has no narrower sibling) stays bare.
4. `llvm/test/CodeGen/MOS/a16-immediate-width.ll` — new lit test (§2, correction 2).

Registration, mirroring `0044`:

- `dev/toolchain.sh` — `apply_patch 0045-mos-asm-print-a16-immediate` after `0044`.
- `dev/regen-patch.sh` — append to `STANDALONE_MOSDIR`; add the new test to `TESTRELS` so `0045`
  reverse-applies cleanly out of a `0002` regeneration.

## 4. Risk

- **a16 assembly gets wordier.** Every 16-bit immediate ≤ 255 in `-S` output grows a `mos16(…)` wrapper —
  5 006 of the corpus's 5 993 decimal immediates are in that range, though most are `imm8` operands on
  `rep`/`sep`/`ldx`/`ldy` and unaffected. Deliberate: the bare form is wrong.
- **Object output must be unchanged.** The InstPrinter never runs under `-filetype=obj`, so this cannot
  move a single byte of a `-c` build. §5 step 5/6 (the two corpus gates) are the guard.
- **Lit churn on non-65816 CPUs.** Only `phw` is exposed (§2); step 4 measures it.

## 5. Verification

1. **The MC round-trip instrument cannot reach this bug** — `llvm-mc -disassemble` on
   `0xc2,0x20 0x69,0x42,0x00` does not enter M=0 (evidence for correction 2).
2. **New lit test fails pre-fix, passes post-fix** — `llvm/test/CodeGen/MOS/a16-immediate-width.ll`
   against the pre-fix `llc` and the rebuilt one.
3. **`dev/run.sh lit`** — 159 discovered (158 after `0044`, plus this test), the same four known failures.
4. **`dev/probe-far-roundtrip.sh`** under `+mos-a16`: the far corpus reaches **0 divergent** (from 2), and
   the full 117-fixture corpus reaches **0 divergent** (from 32). Default 8-bit stays at 0 divergent.
5. **`dev/run.sh corpus`** — 80/80.
6. **`dev/run.sh corpus-a16`** — 79/79, 0 xfail.
7. **`dev/regen-patch.sh`** — `0002` round-trips and does not absorb `0045`. Run with `P2` redirected to a
   scratch file, because `patches/llvm-mos/0002-321-accum16.patch` carries another workstream's
   uncommitted edits.

## 6. Upstream target: none

Unlike its sibling, **this patch has no upstream destination and queues no PR-draft follow-up.** `0044` is
stock 65816 — a bare `lda far_sym` is ambiguous on any llvm-mos build. This one is not: upstream, nothing
constructs an `Immediate16` MCInst carrying a plain small `imm`. The assembler always matches `Imm8` on
that text, and the disassembler wraps the operand itself
(`MOSDisassembler.cpp:326-333`). `+mos-a16` codegen — which does not exist upstream — is the only producer.
So `docs/upstream-contribution-status.md` is **not** touched, and no `[T2] draft the upstream PR` item
follows this one.

---

## 7. Verification results

Toolchain rebuilt 2026-09-24 18:53 (`dev/run.sh toolchain`, `rc=0`, `done in 0m 42s` — incremental,
ccache): `build/llvm-mos-install/bin/clang-23` mtime 15:04 → 18:53, size 124831592 → 124832072 B;
`build/llvm-mos/bin/llc` relinked at 18:53. That build carries `0045` on top of the `0044` tree.

### Step 1 — the MC round-trip instrument cannot reach this bug

`llvm-mc -disassemble` over a byte list that *starts with* `rep #$20`:

```
--- bytes fed in ---              --- llvm-mc -triple mos -mcpu=mosw65816 -disassemble ---
0xc2,0x20                             rep     #32
0x69,0x42,0x00                        adc     #66
0xa9,0x05,0x00                        brk
0xc9,0xff,0x00                        lda     #5
0x69,0xcd,0xab                        brk
0xe2,0x20                             cmp     #255
0xc2,0x10                             brk
0xa2,0x07,0x00                        adc     #205
                                      plb
                                      sep     #32
                                      rep     #16
                                      ldx     #7
                                      brk
```

The three-byte `69 42 00` decoded as a two-byte `adc #66` plus a `brk`: `MLow` never became true,
because it is driven by the `$ml`/`$mh`/`$xl`/`$xh` **mapping symbols**
(`MOSDisassembler::onSymbolStart`), which a raw byte list does not have. So an
`0044`-style `-disassemble | llvm-mc` test cannot exercise the `Immediate16` printer path at all — and
where it *can* be exercised (`llvm-objdump` over a real object) the disassembler has already wrapped the
operand, so such a test would be green before the fix.

**PASS** — correction 2 in §2 is established; the regression guard is a CodeGen test.

### Step 2 — the new lit test fails pre-fix, passes post-fix

Pre-fix (`build/llvm-mos/bin/llc`, the 15:04 `0044` build), `FileCheck` over its own output:

```
$ llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs \
      < llvm/test/CodeGen/MOS/a16-immediate-width.ll | FileCheck <same>
a16-immediate-width.ll:20:10: error: CHECK: expected string not found in input
; CHECK: adc #mos16(66)                     note: possible intended match here:  adc #66
a16-immediate-width.ll:44:10: error: CHECK: expected string not found in input
; CHECK: eor #mos16(255)                    note: possible intended match here:  eor #255
a16-immediate-width.ll:56:10: error: CHECK: expected string not found in input
; CHECK: cmp #mos16(5)                      note: possible intended match here:  cmp #5
FileCheck rc=1
```

Post-fix (the 18:53 build), same command:

```
FILECHECK PASS

	rep	#32              rep	#32              rep	#32              rep	#32
	lda	g16              lda	g16              lda	g16              lda	g16
	adc	#mos16(66)       adc	#43981           eor	#mos16(255)      cmp	#mos16(5)
	sep	#32              sep	#32              sep	#32              sep	#32
	                                                                  lda	#0
	                                                                  lda	#1
```

**PASS** — ≤ 255 marked, 43981 bare, and the 8-bit `lda #0` / `lda #1` the same function emits once M is
back to 1 stay bare.

The compiler's own output for the fixture the audit quoted:

```
a16.s:  adc	#mos16(66)      (was: adc #66  -> reassembled 69 42, two bytes, M=0 desync)
```

and the same object through `llvm-objdump`, showing the printer and the disassembler's own wrapper
compose without double-wrapping:

```
       d: 69 42 00     	adc	#mos16($42)
```

### Step 3 — `dev/run.sh lit`

```
Failed Tests (4):
  LLVM :: CodeGen/MOS/legalizer.mir
  LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll
  LLVM :: CodeGen/MOS/shift-rotate.ll
  LLVM :: MC/MOS/addressing-modes-65816.s
Total Discovered Tests: 159
  Unsupported:   2 (1.26%)
  Passed     : 153 (96.23%)
  Failed     :   4 (2.52%)
```

159 discovered against the 158 `0044` recorded — the new test, and it passes (153 vs 152). The failure
set equals the recorded pre-existing four. No `phw` churn: `MC/MOS/all-65ce02-opcodes.s` uses
`phw #$eaea` (> 0xFF), which stays bare.

**PASS**

### Step 4 — `dev/probe-far-roundtrip.sh`

Before (15:04 `0044` toolchain) → after (18:53):

```
far/packed24 corpus (26), +mos-a16
  before: round-trip: 24 identical,  2 divergent, 0 skipped
            divergent: farindex.c:26  farspill-probe.c:110
  after : round-trip: 26 identical,  0 divergent, 0 skipped

far/packed24 corpus, default 8-bit
  before: round-trip:  8 identical,  0 divergent, 18 skipped   (0044's end state)
  after : round-trip:  8 identical,  0 divergent, 18 skipped

full 65816 corpus (117), +mos-a16
  before: round-trip: 85 identical, 32 divergent, 0 skipped
            divergent: a16.c a16abscmp.c a16chainimm.c a16cmp.c a16cmpaudit.c a16cmpidx.c a16eq.c
                       a16eqvalg.c a16frameidx.c a16isr.c a16mix2.c a16s32.c a16scmp.c a16spill.c
                       a16spillr.c asmisland-probe.c farindex.c farspill-probe.c frameabi_heavy.c
                       k_bits.c k_blossom_far.c k_buddha_far.c k_isort.c k_mandel.c k_mandel_far.c
                       k_trig16x.c rcundef2.c shift64seam-probe.c xy16-inplace-memmove-repro.c
                       xy16basic.c xy16spill.c xy16spillr.c
  after : round-trip: 117 identical, 0 divergent, 0 skipped
```

Post-fix, all three modes over the widened corpus (the new `--all` flag, §8):

```
dev/probe-far-roundtrip.sh --all                          -> 95 identical, 0 divergent, 22 skipped
dev/probe-far-roundtrip.sh --all --flags "-Os $A16"       -> 117 identical, 0 divergent, 0 skipped
dev/probe-far-roundtrip.sh --all --flags "-Os $A16 $XY16" -> 117 identical, 0 divergent, 0 skipped
```

(The 22 skips in default 8-bit are the far-pointer-storage fixtures that do not legalize without
`+mos-a16` — the deliberate, already-recorded a16 gate, not a round-trip failure.)

**PASS** — every 65816 fixture round-trips byte-identically in every mode.

### Step 5 — `dev/run.sh corpus`

```
    ok  SPC700 IPL present and verified (sha1 97e352553e94242ae823547cd853eecda55c20f0, 64 B)
==> corpus: 80/80 passed
CORPUS rc=0
```

**PASS** — 80/80, matching the baseline `0044` left.

Directly on the risk that object emission moved: an object compiled by the **pre-fix** driver (18:47,
before the rebuild) against the same source through the **post-fix** one:

```
10f7fd17a19bdd4be696dfc2c03d951e9a4d5977a5222fe196ba79f6886ff791  far_arith.o       (pre-fix, 18:47)
10f7fd17a19bdd4be696dfc2c03d951e9a4d5977a5222fe196ba79f6886ff791  far_arith.post.o  (post-fix)
```

Byte-identical, as the mechanism requires: `-filetype=obj` never runs the InstPrinter.

### Step 6 — `dev/run.sh corpus-a16`

The four-way differential (host == default == `+mos-a16` == `+mos-xy16`, MAME + bsnes-jg):

```
==> corpus-a16: 79/79 passed, 0 xfail
CORPUSA16 rc=0
```

79 `PASS` lines, no `FAIL`.

**PASS** — matches the 79/79, 0 xfail baseline `0044` recorded, so `0045` does not move the differential.

**All seven steps PASS.**

### Step 7 — `0002` regeneration excludes `0045`

Run from a copy of `dev/regen-patch.sh` with `P2` pointed at a scratch file, because
`patches/llvm-mos/0002-321-accum16.patch` carries another workstream's uncommitted edits and must not be
overwritten (the copy lived in `dev/` so its `$0`-relative `ROOT` still resolved, and was deleted
immediately afterwards).

```
    wrote .../0002-regen-scratch.patch (6478 lines, 38 files)
==> [verify] apply 0001 + new 0002 (+0003) to a fresh pristine worktree
==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir
RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)

$ grep -c 'printImm16Operand\|a16-immediate-width' .../0002-regen-scratch.patch
0
$ diff <(grep '^diff --git' regen-scratch) <(grep '^diff --git' patches/llvm-mos/0002-...)
(no output — same 38 files as the working-tree 0002)
```

**PASS** — `0045` reverse-applies cleanly out of the regeneration and does not leak into `0002`.

### Extra — idempotency and the `phw` over-marking, measured

```
$ llvm-mc -triple mos -mcpu=mosw65816 -show-encoding
	lda	#mos16(66)     ; encoding: [0xa9,0x42,0x00]
	lda	#mos16(sym)    ; encoding: [0xa9,A,A]   fixup A ... kind: Imm16

$ llvm-mc -triple mos -mcpu=mos65ce02 -show-encoding
	phw	#mos16(66)     ; encoding: [0xf4,0x42,0x00]   <- over-marked, §2; same bytes
	phw	#60138         ; encoding: [0xf4,0xea,0xea]
```

No `mos16(mos16(...))`, and the over-marked `phw` re-parses to the identical encoding.

---

## 8. Also changed, and follow-ups

- **`dev/probe-far-roundtrip.sh` gained `--all`.** The far/packed24 default corpus reaches only 2 of the
  32 fixtures this defect touched, so it was a weak guard for this class. `--all` widens the default set
  to every `examples/65816` fixture (117) and the usage text now records the three expected-clean
  invocations. The default is unchanged (the far set is ~3× faster), so the `[T2]` "promote the probe to
  a committed gate" item still owns the decision about what a gate run costs — this just gives it a
  ready-made switch and a clean baseline in all three modes.
- **No upstream follow-up.** See §6: downstream-only, so `docs/upstream-contribution-status.md` is
  untouched and no PR-draft item follows.
- **Residual, not reachable in the corpus:** a *narrower* width modifier (`mos16lo`/`mos16hi`) sitting on
  an `Immediate16` operand would be left unmarked by rule 1 and would still re-parse as 8-bit. The census
  in §1 found none — every such immediate in the corpus is a genuine `imm8` operand — and one would be a
  lowering bug rather than a printing one. Recorded so it is not rediscovered as a printer gap.
- **The X-side has no codegen test, because codegen does not reach it.** `LDX_Immediate16` /
  `CPX_Immediate16` share the same `imm16` operand and the same rule, but under `+mos-a16 +mos-xy16` the
  compiler still emits only two-byte index immediates (`a2 00`, the `mos16lo`/`mos16hi` pairs) — measured
  over all 117 fixtures and re-checked on a synthetic indexed-load IR, where the only marked immediate is
  the accumulator's `adc #mos16(3)`. The printer covers the X forms; they become testable if a later
  change folds a constant into an index immediate.
- **The disassembler's own wrapper (`MOSDisassembler.cpp:326-333`) is now redundant** but deliberately
  left in place (§2). If it is ever removed, the printer keeps `llvm-objdump` correct.

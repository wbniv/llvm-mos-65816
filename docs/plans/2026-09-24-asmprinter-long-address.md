# AsmPrinter does not mark long (24-bit) addresses — print `mos24(...)` so far code round-trips

**TODO entry:** `- [wip T4] **AsmPrinter does not mark long (24-bit) addresses — far load/store and `$5C` tail
jumps print identically to their 16-bit siblings.**` (`TODO.md`, M2 / #320 section).
**Diagnosis:** [`docs/investigations/2026-09-24-mos24-far-addressing-completeness-audit.md` §6](../investigations/2026-09-24-mos24-far-addressing-completeness-audit.md#6-disassembly--round-trip--the-genuine-functional-gap).
**Sibling item (separate dispatch):** `[T4] AsmPrinter does not mark 16-bit immediates under +mos-a16` —
it inherits the shape chosen here (§3).

**Visible surface:** none. This changes generated assembly text and `llvm-objdump` output, not any UI,
page, TUI or document — so there is no mockup bundle.

---

## 1. The defect

`MOSAsmPrinter` prints every 24-bit operand bare. `LDAbsLong`/`STAbsLong` (`$af`/`$8f`) and the far
tail-call pseudo `TailJML` (`JMP_AbsoluteLong`, `$5C`) come out as

```
	lda	far_src
	sta	corpus_result
	jmp	far_pick
```

which is textually identical to their 16-bit siblings `$ad`/`$8d`/`$4c`. Re-parsing that text — exactly
what `-save-temps` does, a first-party clang flag with no hand-written asm and no third-party assembler
involved — makes the matcher pick the **narrowest** candidate, so:

- a far load/store loses its bank byte and becomes DBR-relative (`af`→`ad`, `8f`→`8d`);
- a far tail call becomes a bank-local jump (`5c`→`4c`) — it lands in the **wrong ROM bank**;
- branch displacements are then recomputed over the shrunken code, so the result is *self-consistent*
  and wrong rather than obviously broken.

`$5C` is additionally unspellable: `MOSInstrInfo.td:769` gives `JMP_AbsoluteLong` the mnemonic `"jmp"`,
the same string as `JMP_Absolute`, and `jml` is only accepted for the indirect `$DC` form.

The parser half is already correct — patch `0039` made an explicit width modifier bind the operand's
width, and `mos24(sym)`, `mos24(sym+4)`, `mos24(sym),x`, `jmp mos24(sym)` and `jsl mos24(sym)` all select
the long encoding today (measured, §4 step 1). This is purely the missing printer half.

Measured baseline (`dev/probe-far-roundtrip.sh`, fixed `llvm-mc`):

```
+mos-a16 -Os : round-trip: 18 identical, 8 divergent, 0 skipped
-Os          : round-trip:  4 identical, 4 divergent, 18 skipped
```

## 2. Design — the shape, and what was rejected

**Chosen: wrap at print time, conditionally, in the InstPrinter.**

Give the `addr24` operand class a `PrintMethod` that emits `mos24(<operand>)` **whenever the bare text
could re-parse narrower**, and the bare operand otherwise:

| operand | printed | why |
|---|---|---|
| symbol / any expression | `mos24(sym)` | a bare symbol always matches the narrowest candidate |
| constant ≤ `0xFFFF` | `mos24($abcd)` | would re-parse as absolute (or zero page) |
| constant > `0xFFFF` | `$eaeaea` | cannot fit a 16-bit operand — already unambiguous |
| expression already carrying a MOS modifier | unchanged | it prints its own modifier; wrapping twice would give `mos24(mos24(x))` and break asm→asm idempotency |

The rule is **"print the width only when the text would otherwise lie"**, the same discipline
`MOSMCInstLower::wrapAbsoluteIdxBase` already applies to a zero-page-matching indexed base (and which
`0039` repaired). It is conservative in the right direction: over-wrapping costs a few characters of
assembly text, under-wrapping is wrong code.

**Why the InstPrinter and not `MOSMCInstLower`.** `wrapAbsoluteIdxBase` lives in the lowerer because it
is a *selection* decision (`ZeroPageX` vs `AbsoluteX` are different opcodes, chosen there). Width marking
is not: the opcode is already `_AbsoluteLong`, only its *rendering* is lossy. Putting it in the printer
- fixes the disassembler with the same code (`llvm-objdump` output of a bank-0 long access has the
  identical defect — it is the same `MOSInstPrinter`), and
- is ~12 lines plus one `.td` line, against a per-opcode table in the lowerer covering `LDA`/`STA`/`ADC`/
  `SBC`/`AND`/`EOR`/`ORA`/`CMP` × {`AbsoluteLong`, `AbsoluteXLong`} + `JMP`/`JSL` — which still would not
  fix objdump.

Only `AbsoluteLong` and `AbsoluteXLong` use `addr24` (`IndirectLong` is `addr8`, and is syntactically
unambiguous via its brackets), and both are `HasW65816`-gated, so the blast radius is exactly the 65816
long forms.

**Rejected — `.a24` / mode-directive.** A directive that puts the assembler into a "long" state is
*stateful*: its effect depends on where the reader enters the file, it has to be saved/restored across
`.macro`/`.include`, and every hand-written `asm()` block inherits whatever state the surrounding
generated code left. The modifier is per-operand and local — it cannot be left switched on. It also
already exists and is already parsed, which matters for upstream acceptability.

**Rejected — `jml` as a new mnemonic for `$5C`.** `mos24()` already makes `$5C` unambiguous
(`jmp mos24(sym)` → `[0x5c,...]`, measured), so a second spelling fixes nothing that is broken. Adding it
would mean new parser surface, a decision about whether `jml ($1234)` (`$DC`, which llvm-mos already
spells `jml`) and `jml $123456` should share a mnemonic, and a change to disassembler output — all of it
orthogonal to the correctness bug and all of it extra argument surface on an upstream PR. One mechanism
covering loads, stores, indexed loads and both long jumps beats two mechanisms covering one case each.
(`JML` for `$5C` *is* attested outside llvm-mos — it is the Merlin/ORCA-M spelling and appears in WDC's
alternate-mnemonic table — so this is a deliberate deferral, not a "we could not find one". If a later
item wants it for readability, it is additive and independent of this fix.)

**Not in scope, recorded so it is not rediscovered:** the same asymmetry exists one width down — a bare
`lda $12` at an `addr16` operand re-parses as zero page. The audit's measurement found **no** instance of
it (the compiler does not emit literal sub-256 absolute addresses), so no `addr16` change ships here; if
the round-trip gate (`[T2]` item) ever sees one, the identical `PrintMethod` applies.

## 3. The shape the sibling a16-immediate item inherits

Same rule, one layer over, on the `imm16` operand class: print `#mos16(N)` **iff the value would
re-parse narrower** (i.e. `N ≤ 0xFF`), bare otherwise. `MOSInstPrinter::printOperand` already prints
`mos16(N)` for a constant `VK_IMM16` expression, so the spelling and the parser support are in place;
what that item adds is the *decision to mark*, via a `PrintMethod` on `imm16at<>` exactly parallel to
this patch's `printAddr24Operand`. It must stay a separate, fork-only patch (`+mos-a16` is downstream)
and it does **not** need to re-derive the design.

## 4. Implementation

New standalone patch **`0044-mos-asm-print-long-address.patch`** (stock-65816, upstream-postable; NOT
folded into `0002`). Files, all inside `llvm/lib/Target/MOS`:

1. `MCTargetDesc/MOSInstPrinter.h` — declare `printAddr24Operand(const MCInst *, unsigned, raw_ostream &)`.
2. `MCTargetDesc/MOSInstPrinter.cpp` — implement it per the table in §2.
3. `MOSInstrFormats.td` — `class addr24at<int offset>` gains `let PrintMethod = "printAddr24Operand";`.
4. `llvm/test/MC/MOS/long-address-roundtrip-65816.s` — new lit test (see §5 step 2).

Registration, mirroring `0039`/`0043`:

- `dev/toolchain.sh` — `apply_patch 0044-mos-asm-print-long-address` after `0043`.
- `dev/regen-patch.sh` — append to `STANDALONE_MOSDIR`; add the new test to `TESTRELS` so `0044`
  reverse-applies cleanly out of a `0002` regeneration.

## 5. Verification

1. **Parser already accepts every long form under `mos24()`** (pre-work evidence; fixed `llvm-mc`).
2. **New lit test** `llvm/test/MC/MOS/long-address-roundtrip-65816.s` — assemble-and-print plus
   assemble-to-object, pinning: `lda`/`sta`/`lda …,x` on a symbol print `mos24(sym)`; `jmp` on a far
   symbol prints `mos24(sym)` and encodes `$5c`; a `> 0xFFFF` constant stays bare; printing an
   already-modified operand does not double-wrap. Must FAIL pre-fix.
3. **`dev/run.sh lit`** — the two MOS suites; no new failures against the four known.
4. **`dev/probe-far-roundtrip.sh`** on `far-run.c`, `far_tail.c`, `far_near_call.c`, `far-bank1.c`,
   `packed24_e2e.c`, `packed24_table.c` — the long-address fixtures reach 0 divergent lines under
   **default 8-bit** (`farindex.c`/`farspill-probe.c` stay divergent under `+mos-a16`: those are the
   sibling item's 16-bit immediates, not this gap).
5. **`dev/run.sh corpus`** — 7/7 (guards the `-c` path, which must be byte-unchanged).
6. **`dev/run.sh corpus-a16`** — 79/79 (same guard under `+mos-a16`).
7. **`-c` output byte-identical.** The printer cannot affect object emission; confirm by comparing the
   `R_MOS_ADDR24` relocation sets of the `-c` and `-S`-then-assemble paths, and an object built from an
   unchanged 65816 MC source by the pre-fix and post-fix assembler.
8. **`dev/regen-patch.sh`** — `0002` round-trips and does not absorb `0044`.

Steps 5 and 6 also discharge the outstanding steps of
[`2026-09-24-mos16-constant-truncation.md`](2026-09-24-mos16-constant-truncation.md) (patch `0039`), whose
verification stalled because the installed toolchain predated it — the same rebuild carries both.

## 6. Risk

- **Assembly gets wordier.** Every far access in `-S` output and in `llvm-objdump` of 65816 code grows a
  `mos24(…)` wrapper. Deliberate: the bare form is wrong. The `> 0xFFFF` exemption keeps ordinary
  bank-non-zero disassembly (`lda $7e0000`) unchanged.
- **Third-party assemblers.** `mos24()` is llvm-mos syntax; ca65/asar do not understand it. Generated
  `.s` was already llvm-mos-specific (`mos16()`, `mos16hi()` are printed today), so this does not lose a
  property anything had.
- **Lit churn.** Existing 65816 MC tests use `$eaeaea`-style constants, which stay bare — expected churn
  is zero, but step 3 is what proves it.

---

## 7. Verification results

Toolchain rebuilt 2026-09-24 15:04 (`dev/run.sh toolchain`, rc=0):
`build/llvm-mos-install/bin/clang-23` mtime 10:44 → 15:04, size 124831424 → 124831592 B;
`build/llvm-mos-install/bin/llvm-mc` 2552536 → 2553008 B. That rebuild carries **both** `0039`
(previously only in the lit-tool `llvm-mc`) and `0044`.

### Step 1 — the parser already accepts every long form under `mos24()`

Pre-work, `build/llvm-mos/bin/llvm-mc` (the 11:44 lit-tool build, `0039` in, `0044` out):

```
	lda	mos24(sym)                      ; encoding: [0xaf,A,A,A]   fixup kind: Addr24
	sta	mos24(sym)                      ; encoding: [0x8f,A,A,A]   fixup kind: Addr24
	lda	mos24(sym),x                    ; encoding: [0xbf,A,A,A]   fixup kind: Addr24
	jmp	mos24(sym)                      ; encoding: [0x5c,A,A,A]   fixup kind: Addr24
	jsl	mos24(sym)                      ; encoding: [0x22,A,A,A]   fixup kind: Addr24
	lda	mos24(43981)                    ; encoding: [0xaf,0xcd,0xab,0x00]
	lda	mos24(sym+4)                    ; encoding: [0xaf,A,A,A]   fixup kind: Addr24
	adc	mos24(sym)                      ; encoding: [0x6f,A,A,A]   fixup kind: Addr24
	cmp	mos24(sym)                      ; encoding: [0xcf,A,A,A]   fixup kind: Addr24
```

**PASS** — `jmp mos24(sym)` reaches `$5c`, so `$5C` needs no mnemonic of its own.

### Step 2 — the new lit test, and that it fails pre-fix

Pre-fix, disassembling the test's own bytes and feeding the result straight back to the assembler
(`build/llvm-mos/bin/llvm-mc`, before the rebuild):

```
--- disasm (pre-fix) ---          --- reassembled (pre-fix) ---
	lda	240                       lda	240   ; encoding: [0xa5,0xf0]     <- was af f0 00 00
	sta	240                       sta	240   ; encoding: [0x85,0xf0]     <- was 8f f0 00 00
	lda	43981,x                   lda	43981,x ; encoding: [0xbd,0xcd,0xab]
	jmp	240                       jmp	240   ; encoding: [0x4c,0xf0,0x00] <- was 5c f0 00 00
	jsl	240                       jsl	240   ; encoding: [0x22,0xf0,0x00,0x00]
	lda	15395562                  lda	15395562 ; encoding: [0xaf,0xea,0xea,0xea]
	jmp	15395562                  jmp	15395562 ; encoding: [0x5c,0xea,0xea,0xea]
```

A far load became a **zero page** load. Running the new test's CHECK lines against that recorded
pre-fix output:

```
$ FileCheck llvm/test/MC/MOS/long-address-roundtrip-65816.s < prefix-disasm.txt
long-address-roundtrip-65816.s:14:10: error: CHECK: expected string not found in input
# CHECK: lda mos24(240)
```

Post-fix (`build/llvm-mos-install/bin/llvm-mc`, same input):

```
--- disasm ---                    --- reassembled ---
	lda	mos24(240)                lda	mos24(240)     ; encoding: [0xaf,0xf0,0x00,0x00]
	sta	mos24(240)                sta	mos24(240)     ; encoding: [0x8f,0xf0,0x00,0x00]
	lda	mos24(43981),x            lda	mos24(43981),x ; encoding: [0xbf,0xcd,0xab,0x00]
	jmp	mos24(240)                jmp	mos24(240)     ; encoding: [0x5c,0xf0,0x00,0x00]
	jsl	mos24(240)                jsl	mos24(240)     ; encoding: [0x22,0xf0,0x00,0x00]
	lda	15395562                  lda	15395562       ; encoding: [0xaf,0xea,0xea,0xea]
	jmp	15395562                  jmp	15395562       ; encoding: [0x5c,0xea,0xea,0xea]
```

**PASS** — every long encoding survives the round trip; the `> 0xFFFF` constants stay bare; nothing
double-wraps.

### Step 3 — `dev/run.sh lit`

```
Total Discovered Tests: 158
  Unsupported:   2 (1.27%)
  Passed     : 152 (96.20%)
  Failed     :   4 (2.53%)

Failed Tests (4):
  LLVM :: CodeGen/MOS/legalizer.mir
  LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll
  LLVM :: CodeGen/MOS/shift-rotate.ll
  LLVM :: MC/MOS/addressing-modes-65816.s
```

158 discovered, one more than the 157 recorded for `0039` — the new test, and it passes. The failure
set equals the recorded pre-existing four. `MC/MOS/addressing-modes-65816.s` still fails for its own
recorded reason (the bare-symbol operand width gap), unchanged by this patch:

```
addressing-modes-65816.s:70:22: error: CHECK: expected string not found in input
 lda addr24 ; CHECK: af 00 00 00
```

Nine lines of that test's `llvm-objdump` output do gain a `mos24(...)` wrapper, but none of them is
matched by a CHECK (the test checks byte columns and relocation names, not mnemonic text), and its
**object output is byte-identical** — see step 7.

**PASS**

### Step 4 — `dev/probe-far-roundtrip.sh`

Before (fixed `llvm-mc`, pre-`0044` clang) → after (rebuilt toolchain):

```
default 8-bit  -Os
  before: round-trip:  4 identical,  4 divergent, 18 skipped
            divergent: far-bank1.c:6  far_near_call.c:2  far-run.c:10  far_tail.c:16
  after : round-trip:  8 identical,  0 divergent, 18 skipped

+mos-a16 -Os
  before: round-trip: 18 identical,  8 divergent,  0 skipped
            divergent: far-bank1.c:6  farindex.c:26  far_near_call.c:2  far-run.c:10
                       farspill-probe.c:110  far_tail.c:16  packed24_e2e.c:6  packed24_table.c:6
  after : round-trip: 24 identical,  2 divergent,  0 skipped
            divergent: farindex.c:26  farspill-probe.c:110
```

**PASS** — every long-address fixture round-trips. The two that remain are exactly the audit's
16-bit-immediate set (§6.3), i.e. the sibling `[T4]` item, not this gap.

The compiler's own output, for the three shapes named in the TODO entry:

```
far_tail.s:68 	jmp	mos24(far_addk)      (was: jmp far_addk   -> reassembled $4c, wrong bank)
far_tail.s:70 	jmp	mos24(far_xork)
far_tail.s:77 	jmp	mos24(far_addk)
far-run.s:39  	lda	mos24(far_src)       (was: lda far_src     -> reassembled $ad, DBR-relative)
far-run.s:41  	sta	mos24(corpus_result) (was: sta corpus_result -> reassembled $8d)
```

### Step 5 — `dev/run.sh corpus`

Finished 15:18.

```
    ok  SPC700 IPL present and verified (sha1 97e352553e94242ae823547cd853eecda55c20f0, 64 B)
  ...
==> corpus: 80/80 passed
CORPUS rc=0
```

**PASS** — 80 programs, 80 `PASS` lines, no `FAIL`. (The plan's "7/7" in the older `0039` write-up is
the corpus size of an earlier era; the corpus is 80 programs today.)

### Step 6 — `dev/run.sh corpus-a16`

Finished 17:56. The four-way differential (host == default == `+mos-a16` == `+mos-xy16`, MAME + bsnes-jg):

```
==> corpus-a16: 79/79 passed, 0 xfail
CORPUSA16 rc=0
```

**PASS** — matches the last pre-`0044` run of the same gate (79/79, 0 xfail, 12:31 on the same day, on
the pre-`0039`/pre-`0044` toolchain), so neither `0039` nor `0044` moves the differential.

### Step 7 — object output unaffected

`R_MOS_ADDR24` relocation sets from the `-c` path and the `-S`-then-assemble path agree exactly:

```
far-run:        R_MOS_ADDR24 count=2   -c == -S   SAME
far_tail:       R_MOS_ADDR24 count=5   -c == -S   SAME
far_near_call:  R_MOS_ADDR24 count=2   -c == -S   SAME
```

And an object built from `MC/MOS/addressing-modes-65816.s` by the **pre-`0044`** assembler (10:52,
kept by the audit run) versus the same source through the rebuilt one:

```
sha256  19952436beb2d50d2cf8bd8db0e022c5c7937e6462266554e5b6dbea3f7cc8db  am2.obj   (pre-fix)
sha256  19952436beb2d50d2cf8bd8db0e022c5c7937e6462266554e5b6dbea3f7cc8db  am3.obj   (post-fix)
OBJECTS BYTE-IDENTICAL
```

**PASS** — consistent with the mechanism: `-filetype=obj` never runs the InstPrinter, and the `.td`
change only feeds the generated AsmWriter.

### Step 8 — `0002` regeneration excludes `0044`

Run with `P2` redirected to a scratch file, because `patches/llvm-mos/0002-321-accum16.patch` carries
another workstream's uncommitted edits and must not be overwritten.

```
    wrote .../0002-regen-scratch.patch (6478 lines, 38 files)
==> [verify] apply 0001 + new 0002 (+0003) to a fresh pristine worktree
==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir
RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)

$ grep -c 'printAddr24Operand\|long-address-roundtrip' .../0002-regen-scratch.patch
0
$ diff <(grep '^diff --git' regen-scratch) <(grep '^diff --git' patches/llvm-mos/0002-...)
(no output — same 38 files as the working-tree 0002)
```

**PASS** — `0044` reverse-applies cleanly out of the regeneration and does not leak into `0002`.

**All eight steps PASS.**

---

## 8. Not done / follow-ups

- **The upstream PR draft for `0044`.** The patch is upstream-clean (stock 65816; it touches no
  `+mos-a16` code and its lit test needs no fork patch), but the PR body / `docs/pr-preparations/`
  validation record is a separate task, exactly as `0043`'s was. Ranking is the orchestrator's call, so
  this plan does not write a `TODO.md` item for it.
- **The 16-bit-immediate sibling.** `farindex.c` and `farspill-probe.c` still diverge under `+mos-a16`
  (§7 step 4). That is the `[T4] AsmPrinter does not mark 16-bit immediates under +mos-a16` item; §3
  states the shape it should reuse.
- **Promoting the probe to a gate.** `dev/probe-far-roundtrip.sh` is still run by hand. With the
  long-address class fixed, its `-Os` (default 8-bit) run is now **0 divergent**, so the `[T2]` gate item
  can record a clean baseline for that mode and an expected-failure set of exactly two fixtures for
  `+mos-a16` until the sibling item lands.
- **`jml` for `$5C`.** Deliberately deferred, §2.

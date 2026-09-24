# Is 24-bit / far addressing complete? — a per-layer audit (#320)

**Asked:** after `mos24(1193046)` truncated to a one-byte direct-page operand (`a5 56`),
"is this because 24-bit support is not complete? do an audit of what's still missing."

**Date:** 2026‑09‑24 · **Branch:** `throwaway/mos24-completeness-audit` (worktree
`/home/will/llvm-mos-65816-mos24audit`, host-only hardlink recipe per
[howto-feature-worktree](../howto-feature-worktree.md)) · **Scope:** read + probe + report. No
code was changed.

---

## Short answer

**No — but not for the reason the reported symptom suggested.**

The reported symptom (`mos24(constant)` truncating to a zero-page operand) was a *parser*
width-arithmetic bug, generic across all modifier widths, and it is **fixed** — patch
[`0039`](../../patches/llvm-mos/0039-mos-asm-modifier-width.patch), commit `48595d47`,
[plan + recorded verification](../plans/2026-09-24-mos16-constant-truncation.md). That is done.

What the audit found is that **the layer *above* the parser is the incomplete one**: the
**AsmPrinter cannot express a 65816 long address in text at all.** Every long form the
compiler selects — `af`/`8f` (LDA/STA absolute long), `5c` (JML) — is printed as a bare
`lda sym` / `sta sym` / `jmp sym`, textually identical to its 16-bit sibling. Re-parsing
that text therefore silently produces the *near* instruction. The `-c` path and the
`-S`-then-assemble path disagree on real far code:

```
$ mos-clang --target=mos -mcpu=mosw65816 -Os -c          examples/65816/far-run.c
       0: af 00 00 00   lda $0        <- absolute long, bank byte present
       3: 8f 00 00 00   sta $0

$ mos-clang --target=mos -mcpu=mosw65816 -Os -save-temps -c examples/65816/far-run.c
       0: ad 00 00      lda $0        <- absolute, DBR-relative
       3: 8d 00 00      sta $0
```

`-save-temps` is a plain first-party flag with no hand-written assembly anywhere in the
picture, and it **silently changes the program**. For `far_tail.c` / `far_near_call.c` the
change is `5c` (JML, sets PB) → `4c` (JMP, keeps PB): the tail call lands in the **wrong
ROM bank**. This is the same defect family as `0039` — the assembler's operand-width
matching diverging from the compiler's intent — one layer up, and `0039` neither fixes it
nor makes it worse.

A second, independent and more severe instance of the same family exists on the `+mos-a16`
immediate path (see §6.2): a 16-bit immediate whose value is ≤ 255 prints as a bare `#N`
and reassembles 2 bytes instead of 3, **desynchronising the instruction stream** under M=0.

Everything else in the #320 stack that the audit could reach — the address-space model,
the legalizer bridges, static initialisation and relocations, the calling convention —
came back **Done and verified**, several of them beyond what `TODO.md` records.

---

## What I ran against (read this before trusting any number)

| tool | path | carries `0039`? |
|---|---|---|
| `mos-clang` / `clang-23` (integrated assembler) | `build/llvm-mos-install/bin`, `build/llvm-mos/bin` (same inode, 2026‑09‑24 10:44) | **NO** |
| `llvm-mc` (installed) | `build/llvm-mos-install/bin/llvm-mc` (2026‑09‑23 18:53) | **NO** |
| `llvm-mc` (lit-tool build) | `build/llvm-mos/bin/llvm-mc` (2026‑09‑24 11:44) | **YES** |

Verified directly:

```
$ build/llvm-mos-install/bin/llvm-mc -triple mos -mcpu=mosw65816 -show-encoding
	lda	mos24(1193046)   ; encoding: [0xa5,0x56]              <- pre-fix
$ build/llvm-mos/bin/llvm-mc      -triple mos -mcpu=mosw65816 -show-encoding
	lda	mos24(1193046)   ; encoding: [0xaf,0x56,0x34,0x12]    <- fixed
```

So **the shipped toolchain does not yet carry `0039`** — only the standalone `llvm-mc` in
the lit-tool build does. `0039` *is* correctly registered at
[`dev/toolchain.sh:193`](../../dev/toolchain.sh), so the next `dev/run.sh toolchain` picks
it up; until then the plan's steps 4–5 (`dev/run.sh corpus`, `corpus-a16`) genuinely have
not reached the fixed compiler. Every round-trip result below was produced with the
**fixed** `llvm-mc` unless stated, so none of the divergences reported here are the already-
fixed bug.

I did **not** run `dev/run.sh corpus` / `corpus-a16` / `lit` — no emulator or container
work was in scope, and the box was in use. Nothing below depends on them.

---

## 1. Assembler / parser — **mostly Done; one real gap, already tracked**

**Done.** `0039` fixed `MOSOperand::isImmInRange`'s constant exit. The width relation the
symbolic exit always applied now guards both exits; strictly a narrowing (12,045 probes,
0 rows became smaller, 0 rejected-then-accepted). `mos24($123456)` → `af 56 34 12`, and
`mos24(sym)`/`mos16(sym)` correctly force the wide candidate on both binaries:

```
	jmp	sym            ; encoding: [0x4c,A,A]
	jmp	mos24(sym)     ; encoding: [0x5c,A,A,A]
	sta	sym            ; encoding: [0x85,A]        <- DP! see below
	sta	mos24(sym)     ; encoding: [0x8f,A,A,A]
```

**Genuinely missing (already tracked — do not open a duplicate item).** A *bare* symbol
always matches the narrowest candidate, because the `isa<MCSymbolRefExpr>` exit in the same
function returns `true` for every width. An **undefined** symbol in `sta sym` selects
`$85` — direct page, one byte. A symbol defined in a known section is rescued afterwards by
`MOSAsmBackend`'s relaxation loop (DP → absolute → absolute-long), which is why the failure
usually presents as "too narrow by one step" rather than "catastrophically narrow".

This is the failing line in `MC/MOS/addressing-modes-65816.s`
(`lda addr24 ; CHECK: af 00 00 00`, actual `ad 00 00`). It is **upstream's own known gap**,
not something the fork introduced — the same test carries explicit `; TODO: lda addr16`,
`; TODO: lda addr16, x` and `; TODO: Immediate (16-bit)` markers on the neighbouring cases.
Fixing it needs a parse-time notion of a symbol's addressing width, which is a design
question, not width arithmetic.

→ stays with the existing `[T3] Vendor MOS lit suite has four failing tests` item
(`TODO.md`). My assessment: it is **low-severity in isolation** (relaxation covers the
defined-symbol case) but it is the *reason* the §6 printer gap cannot be worked around by
"just emit the bare symbol and let the assembler figure it out". Fixing §6 (print
`mos24(...)`) is the cheaper and more complete answer, and it does not require this.

**Confirmed still harmless — with a correction.** `MOSFixupKinds.cpp`'s `Infos[]` really
does have **14 initialisers for 15 enum kinds**; `AddrAsciz` reads a value-initialised
`{nullptr, 0, 0, 0}`:

```
enum kinds : 15 ['Imm8', 'Imm16', 'Addr8', 'Addr16', 'Addr16_Low', 'Addr16_High', 'Addr24',
                 'Addr24_Bank', 'Addr24_Segment', 'Addr24_Segment_Low',
                 'Addr24_Segment_High', 'Addr13', 'PCRel8', 'PCRel16', 'AddrAsciz']
initialisers: 14
MISSING     : ['AddrAsciz']
```

Correction to the earlier "unreachable" reading: the kind **is** reachable —
`.mos_addr_asciz <symbol>, N` → `MOSMCExpr::VK_ADDR_ASCIZ` → `MOSMCELFStreamer::emitMosAddrAsciz`
→ a `MOS::AddrAsciz` fixup (`MOSMCExpr.cpp:154`, `MOSMCELFStreamer.cpp:85`), and
`MOSAsmBackend::fixupNeedsRelaxationAdvanced` (`MOSAsmBackend.cpp:132`) does read
`Info.TargetSize` for it. It is nevertheless **harmless in effect**: `TargetSize == 0`
means "never relax", which is the correct behaviour for a data directive, and
`applyFixup`'s `case MOS::AddrAsciz` returns before the generic width switch. The relocation
path works (`MC/MOS/addr-asciz.s` passes). What is *not* harmless is that
`Info.Name == nullptr` and the table's own stated contract ("must be in the same order as
`MOSFixupKinds.h`") is silently violated — the next fixup kind appended to the enum inherits
the same bug. **A one-line hygiene fix, not a 24-bit gap.**

**Separate, incidental** (found while probing, not 24-bit-specific): `llvm-mc -show-encoding`
on a symbolic `.mos_addr_asciz` **crashes** — `LLVM ERROR: Don't know how to emit this
value.` (`VK_ADDR_ASCIZ` has no textual form and `evaluateAsInt64` is `llvm_unreachable`).
`MC/MOS/addr-asciz.s` only exercises `--filetype=obj`, so nothing catches it. Pristine
upstream defect; reported here for completeness, ranked low.

---

## 2. Codegen / instruction selection — **Done for correctness; measured gaps in coverage**

**Done.** The address-space model is built and load-bearing:
`MOSInstrInfo.h:164` — `enum AddressSpace { AS_Memory, AS_ZeroPage, AS_Far, AS_FarPacked, NumAddrSpaces }`.
`AS_Far` (2) is a 32-bit pointer; `AS_FarPacked` (3) is its 3-byte memory-only storage form
(`p3:24:8`), bridged to/from `AS_Far` by a 3×s8 merge/unmerge at every load/store/addrspacecast
(`MOSLegalizerInfo.cpp:76-79, 1962-1985, 2260, 2352, 2935-2945`). The `G_PHI(p2)` back-edge
case is custom-legalised (`0014`), `G_PTR_ADD {PF,S32}` carries through the bank byte
(`MOSLegalizerInfo.cpp:273-276`), far memops route to `__memset_far`/`__memcpy_far`/
`__memmove_far` (`0013`), and `isFarSymbol`/`buildFarAddrWords`/`selectAddr`
(`MOSInstructionSelector.cpp:1813-1903`) select `LDAbsLong`/`STAbsLong` for far globals.

**Deliberately deferred, verified empirically.** Far-pointer *storage* under default 8-bit
is un-legalized by design (a16-gated: a far pointer is a 32-bit value and the s32↔bytes
bridge is `hasAccum16`-gated). `TODO.md:207-213` closed this 2026‑06‑22 as "a16-gated by
design… a clean Legalizer `unable to legalize` rejection — no object, no miscompile".
Re-confirmed: compiling `examples/65816/far*.c` without `+mos-a16`, **18 of 26 fixtures**
fail with exactly that diagnostic, e.g.

```
far_store.c: fatal error: error in backend: unable to legalize instruction:
  %4:_(s32) = G_MERGE_VALUES %9:_(s8), %12:_(s8), %15:_(s8), %18:_(s8) (in function: main)
```

Clean rejection, no object, no silent wrong code. Verdict holds.

**Deliberately closed.** AS4 zero-bank — measured as bit-identical to a near pointer and
dominated by near + lazy cast on every axis; "not a gap, a decided non-goal"
(`TODO.md:215-218`, [plan](../plans/2026-06-22-320-zerobank-as4-measure-and-close.md)).

**Measured gap — missed optimisation, not a defect.** I censused which 65816 long/bank
opcodes codegen actually emits across all 112 `examples/65816/*.c` fixtures (~25 k
instructions each mode):

| mode | long opcodes emitted |
|---|---|
| default 8-bit (93 compiled) | `af`=4 `8f`=4 `22`=4 `5c`=4 `6b`=3 |
| `+mos-a16` (112) | `af`=4 `8f`=5 `a7`=34 `87`=7 `22`=6 `5c`=5 `6b`=5 |
| `+mos-xy16` (112) | `af`=4 `8f`=5 **`bf`=1** `a7`=34 `87`=7 `22`=6 `5c`=5 `6b`=5 |

So codegen reaches: absolute long (`af`/`8f`), direct-indirect long (`a7`/`87`), `jsl`/`jml`/`rtl`,
bank-register `phb`/`plb`/`phk`, and — only under `+mos-xy16` — `lda long,X` (`bf`).

**Never selected, across the whole fixture corpus:**

- **`[dp],Y` — indirect-long indexed (`b7`/`97`).** This is the natural far-pointer-plus-index
  form and it is the most interesting absence: `farindex.c` is literally a far array subscript
  test and emits 34× `lda [dp]` with a preceding 32-bit pointer add, and **zero** `lda [dp],y`.
  Folding the index into the addressing mode would remove the add entirely.
- **`sta long,X` (`9f`)** — the store mirror of the one `bf` that does fire.
- **Long-form arithmetic/compare** (`0f` ORA, `2f` AND, `4f` EOR, `6f` ADC, `cf` CMP, `ef` SBC
  absolute long, and their `,X` forms). The compiler always does `lda long` then a near op.
  Often correct (the value has to reach A anyway), but `cmp long` / `eor long` against a far
  operand would fold one instruction.
- **`mvn`/`mvp` block move** — supported at MC level (`0020` fixes the bank operand order)
  but not selected from C; the SNES platform's `clang.cfg` lists MVN/MVP as an
  instruction-selection concern, so this may be SDK-assembly-only by design.
- **Stack-relative (`a3`/`83`/`b3`/`93`).** **Deliberately deferred, not a gap** — the
  per-frame DP-window / stack-relative ABIs were built and measured as NULL on real code
  (0/13 functions profit; locals are `__rc`-resident), so the soft static stack stays by
  measurement. `TODO.md` *Upstream/Contribution* "#321 CC frame-ABI design note",
  [record](../plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).

**Caveat on the census:** the corpus is `examples/65816/*.c` — hand-written micro-fixtures
plus a few kernels, not a representative program mix. `b7`/`97` may fire on `examples/snes/`
or SDK code that I did not compile (those need platform configs). The absence of `[dp],Y`
in a corpus that contains a dedicated far-array-subscript fixture is nonetheless strong
evidence. Per governing lesson 2, none of these should be implemented without measuring —
a native long form is not automatically smaller.

---

## 3. Calling convention / ABI — **Done; `TODO.md` is stale**

The DP-pointer-argument crash (`addrspace(1)` pointer argument → illegal `(p1)=COPY $rs`)
is **fully resolved upstream**:

```
$ gh issue view 561 --repo llvm-mos/llvm-mos --json state
{"number":561,"state":"CLOSED", ...}
$ gh pr view 563 --repo llvm-mos/llvm-mos --json state,mergedAt
{"number":563,"state":"MERGED","mergedAt":"2026-07-13T23:09:40Z", ...}
```

Merged as `8be054612` (which is also the current `LLVM_MOS_PIN`), auto-closing #561. Fork
patch `0008` was retired and deleted;
[`upstream-contribution-status.md:109,204-211`](../upstream-contribution-status.md) records
this correctly.

**Finding: `TODO.md:1222` still reads `[wip T2] … **Awaiting upstream review.**`** — stale
by ~2 months, and it is the item the #320 residual list points at. A documentation defect,
not a code one, but it makes the #320 residual list look open when it is closed.

Far-pointer arguments/returns themselves are Done: the far CC (`0004`) passes a 32-bit far
pointer through `Imag32`, with `CCIfPtrAddrSpace` rules and four measured variants
(`farPtrCC()`, `MOSCallingConv.cpp:27-39`; `MOSISelLowering.cpp:112`). Far calls, far→near
thunks, far tail calls and far function pointers are all gated by dedicated
`dev/run.sh far_call | far_near_call | far_tail | far_fnptr | far_indir_tail` ROMs.

---

## 4. Linker / relocations / static init — **Done; verified beyond what TODO records**

`TODO.md` only documents the *packed-24 table* case (`0006`'s
`AsmPrinter::emitNonStandardSizedConstant` hook emitting the `ADDR24 SEGMENT_LO/HI/BANK`
triple). I extended the check to plain far pointers in every aggregate shape, at both
object and **linked-image** level. All correct, and identical under default 8-bit and
`+mos-a16` (there is no a16 gate on the data side):

Object level — sizes and relocations:

```
p_scalar      4 B   R_MOS_FK_DATA_4        far_obj+0
p_array      12 B   R_MOS_FK_DATA_4 ×3     far_obj, far_bss, far_obj
p_struct      5 B   R_MOS_FK_DATA_4 @ +1   far_obj+0      (unaligned, byte 1 of the struct)
p_packed      3 B   ADDR24_SEGMENT_LO / _HI / _BANK
p_packed_arr  6 B   the triple ×2          far_obj, far_bss
p_const       4 B   (no reloc — pure constant 0x7E1234)
```

Linked image (`--config mos-snes-far.cfg`, `far_obj` placed at `$018000`):

```
    80b0  p_scalar (4)   80b4  p_array (8)   80bc  p_struct (5)   80c1  p_packed (3)
000000b0: 0080 0100  0080 0100 0180 0100  07 00 8001  00  0080 01
          ^p_scalar  ^p_array[0] [1]       ^tag ^p_struct.p  ^p_packed
```

`$018000` and `$018001` land correctly, the bank byte survives, the 4th pad byte is zero,
and the 3-byte packed form is right. **Done.**

---

## 5. Testing coverage — **the weakest layer, as a category of its own**

| surface | coverage |
|---|---|
| assembler modifier widths | **strong, new** — `dev/probe-modifier-width.sh` (12,045 probes) + 3 lit tests (`MC/MOS/modifier-width*.s`) |
| assembler addressing modes | `MC/MOS/addressing-modes-65816.s` — comprehensive, but **currently failing** on the one active `addr24` bare-symbol line and carrying 3 more `; TODO:` gaps |
| far/packed-24 **codegen** | **zero lit coverage** |
| far runtime behaviour | ~17 dedicated emulator ROMs (`dev/run.sh far*`, `packed24*`, `farindex`, `mandel-far`, `blossom-grid`, `buddha-grid`) |
| far in **CI** | only `xcheck` (boots `hello` + `far-run` + `far-bank1`) and `corpus-a16` |
| round-trip (`-S` → reassemble) | **none existed** before this audit |

**Genuinely missing — coverage, not functionality:**

1. **No lit test anywhere uses `addrspace(2)` or `addrspace(3)`.** Grepping the entire
   `llvm/test` tree for those strings returns only AMDGPU/ARM files; `CodeGen/MOS/` uses
   `addrspace(1)` only (`dp-pointer-arg.ll`, `legalizer.mir`, …). Every far/packed-24
   correctness claim rests on emulator ROMs. The docs explain *why* nothing went upstream
   (AS2 isn't upstream-standalone-testable until the ABI is blessed —
   `upstream-contribution-status.md:260-262`), but that is an argument against *posting*
   such a test, not against having one in the fork, where the four existing CodeGen/MOS
   failures already show fork-local tests are normal.
2. **~15 of the ~17 far gates are manual.** CI runs two far ROMs. `far_indir`, `far_store`,
   `far_call`, `far_tail`, `far_fnptr`, `far_indir_tail`, `farindex`, `far_loop`,
   `far_memops`, `packed24`, `packed24_table` and the far demo gates are invoked by hand. A
   regression in, say, far tail calls would not be caught by `smoke.yml`.
3. **No round-trip gate at all** — §6.

---

## 6. Disassembly / round-trip — **the genuine functional gap**

### 6.1 The mechanism

I wrote [`dev/probe-far-roundtrip.sh`](../../dev/probe-far-roundtrip.sh): compile each
fixture twice with the *same* clang — once `-c` (the integrated emitter, the reference) and
once `-S` then standalone `llvm-mc` — and diff the `.text` bytes. Any divergence is a
printer/parser asymmetry.

**Root cause:** `MOSMCInstLower::wrapAbsoluteIdxBase` wraps a zero-page-matching *indexed*
base in `mos16(...)` precisely so re-parsing cannot pick `zp,X` — that protection exists and
(post-`0039`) now works. **No equivalent wrapper exists for the long forms.** A far load
prints as `lda far_src`, a far store as `sta corpus_result`, a far tail call as
`jmp far_pick` — each textually identical to its 16-bit sibling. Worse, `JMP_AbsoluteLong`
(`$5C`) is *defined* with the mnemonic `"jmp"` (`MOSInstrInfo.td:769`), the same string as
`JMP_Absolute` (`$4C`), and `jml` is **not** accepted for the absolute-long form (only for
the indirect `$DC`):

```
$ echo '	jml $123456' | llvm-mc -triple mos -mcpu=mosw65816
<stdin>:1:2: error: invalid instruction
```

so `$5C` has no unambiguous assembly spelling at all.

The assembler's own comment states the invariant it relies on
([`MOSAsmBackend.cpp:181-191`](../../vendor/llvm-mos/llvm/lib/Target/MOS/MCTargetDesc/MOSAsmBackend.cpp)):

> "the compiler emits the explicit long form … whenever it genuinely needs a far access, so
> a plain-symbol Absolute is **by construction** a near access"

That invariant holds in the `-c` path and is **false in the `.s` re-parse path**, because
the printer discards exactly the information the invariant assumes is present. The only
thing that rescues *some* cases is a section-name heuristic — bank relaxation fires for
symbols in a `.far*` section and nothing else:

```
	lda	in_far     ->  af 00 00 00   R_MOS_ADDR24   .far_rodata
	lda	in_plain   ->  ad 00 00      R_MOS_ADDR16   .rodata.plain
```

So a far object that happens to live in `.far_rodata` survives; a far object in ordinary
`.bss`/`.rodata` — e.g. an `address_space(2)` variable pointing into `$7E`/`$7F` WRAM, which
is the common SNES case — does not. `8d` uses the DBR, `8f` carries an explicit bank byte:
with DBR ≠ 0 the reassembled program reads and writes a different bank. Semantically the
same class as the `zp,X`-vs-`abs,X` wrap difference that motivated `0039`.

### 6.2 The measured damage

Round trip over `examples/65816/far*.c` + `packed24/*.c`, **fixed** `llvm-mc`, `+mos-a16 -Os`:

```
round-trip: 18 identical, 8 divergent, 0 skipped
  far-bank1.c:6  farindex.c:26  far_near_call.c:2  far-run.c:10
  farspill-probe.c:110  far_tail.c:16  packed24_e2e.c:6  packed24_table.c:6
```

Classified by what the reference emitted and the reassembly lost:

```
far-bank1.c       1 × 8f sta   ->  8d sta        far store loses its bank byte
far-run.c         1 × af lda   ->  ad lda        far load  loses its bank byte
                  1 × 8f sta   ->  8d sta
far_near_call.c   1 × 5c jmp   ->  4c jmp        far tail call -> WRONG BANK
far_tail.c        3 × 5c jmp   ->  4c jmp        far tail call -> WRONG BANK
packed24_*.c      1 × 8f sta   ->  8d sta
farindex.c       13 × #mos16 immediate collapse  (see below)
farspill-probe.c 55 × #mos16 immediate collapse
```

The same four far fixtures break under **default 8-bit** too, so this is pure #320 and not
an a16 artefact — and they break via `-save-temps`, i.e. through the compiler's own
integrated assembler, with no third-party tool involved:

```
far-run:        < af 00 00 00  lda $0      >  ad 00 00  lda $0
                < 8f 00 00 00  sta $0      >  8d 00 00  sta $0
far_near_call:  < 5c 00 00 00  jmp far_caller   >  4c 00 00  jmp far_caller
far_tail:       < 5c ... ×3                     >  4c ... ×3
                < f0 04 beq                     >  f0 03 beq   (displacement recomputed
                                                                over the shrunken code —
                                                                self-consistent, wrong program)
```

### 6.3 The second instance — 16-bit immediates under `+mos-a16`

The same printer gap exists on the immediate path and is **strictly worse**. Under M=0 the
compiler emits a 3-byte immediate; the printed assembly carries no width marker:

```
farindex.s:249    rep  #32          ; M=0 — accumulator is 16-bit
farindex.s:251    eor  __rc10
farindex.s:260    eor  #0           ; compiler's own object: 49 00 00 (Imm16 fixup)
farindex.s:262    sep  #32          ; reassembled:            49 00    (2 bytes)
```

`grep -c 'mos16(' farindex.s` → **0**. The compiler never prints `#mos16(...)`, so any
16-bit immediate whose value happens to be ≤ 255 collapses to 2 bytes. In M=0 mode the CPU
then consumes the next opcode byte (`sep`'s `$e2`) as the immediate's high byte and executes
`#$20` as an opcode — **complete instruction-stream desynchronisation**, not a subtle
difference. Values ≥ 256 are safe by accident (they can't fit 8 bits), which is why this
has gone unnoticed: it only bites on small constants.

`llvm-mc` handles `#mos16(27)` → `49 1b 00` correctly on **both** binaries, so this is
entirely a printer-side omission — the parser side is already right.

Scope, over all 112 `examples/65816/*.c` under `+mos-a16 -Os`:

```
round-trip identical : 76
round-trip divergent : 36      (32 %)
reference-side lines lost, by class:  imm16 = 97,  long-addr = 12,  other = 245*
```

\* "other" is dominated by cascading address/displacement shifts caused by the 97 + 12 real
shrinkages, not by additional independent defects.

### 6.4 Nothing tests this

No round-trip gate existed before this audit. `dev/probe-modifier-width.sh` sweeps the
assembler in isolation; nothing compares the compiler's two output paths against each other.
This is precisely the class of bug the original `mos24` report belongs to, so the absence is
structural rather than incidental.

---

## Ranked gaps — candidates for `TODO.md`

Tiers are **suggestions**, per the delegation scale. I have deliberately **not** written any
tier marker into `TODO.md` (the `rank-requires-fable.sh` hook reserves that for the
orchestrator). Ranking, severity and priority are the orchestrator's call.

| # | Gap | Severity | Suggested tier | Why |
|---|---|---|---|---|
| 1 | **AsmPrinter does not mark 16-bit immediates under `+mos-a16`** — print `#mos16(...)` (or a width directive) so a ≤ 255 immediate cannot collapse to 2 bytes. Reachable via plain `-save-temps`; causes instruction-stream desync. | **wrong code, severe** | **T4** | The fix is small but the *design* is not: `#mos16()` on every a16 immediate vs. emitting `.a16`/`.a8` mode directives vs. teaching the parser M-state tracking. Each has a different blast radius on assembly size, hand-written `asm`, and upstream acceptability. Needs measurement + a chosen shape. |
| 2 | **AsmPrinter does not mark long (24-bit) addresses** — far load/store and `$5C` tail jumps print identically to their 16-bit siblings; `-save-temps` silently retargets far accesses to the DBR and far tail calls to the wrong bank. | **wrong code, severe** | **T4** | Same design question one layer over. `mos24(...)` on far operands is the obvious fix and `0039` already makes the parser honour it — but `$5C` additionally has *no* mnemonic of its own (`MOSInstrInfo.td:769` spells it `"jmp"`), so this also asks whether to add `jml` as an alias. Cross-cutting: printer + `.td` + tests. |
| 3 | **A round-trip gate.** Promote `dev/probe-far-roundtrip.sh` to a committed gate (`dev/run.sh roundtrip`) over the 65816 corpus in all three modes, so #1/#2 can never regress and any future printer/parser asymmetry is caught. | coverage | **T2** | The script exists and works; turning it into a gate with a recorded expected-failure set is bounded. Best done *after* #1/#2 so the baseline is clean, or now with the current 36 divergences recorded as known. |
| 4 | **`TODO.md:1222` is stale** — the DP-arg CC item still says `[wip T2] … Awaiting upstream review`; #561 is CLOSED and #563 MERGED (2026‑07‑13, `8be054612`), patch `0008` retired. | docs | **T0/T1** | Two-line edit; `upstream-contribution-status.md` already has the correct text to copy. Absorb into any adjacent TODO pass. |
| 5 | **`MOSFixupKinds.cpp` `Infos[]` has 14 initialisers for 15 kinds** — add the `AddrAsciz` row. Currently benign (`TargetSize == 0` means "never relax", which is right for a data directive) but `Info.Name` is `nullptr` and the next kind appended inherits the bug. | hygiene | **T1** | One-line fix with an obvious correct value; pristine-upstream defect, so it is a clean standalone upstream artifact. |
| 6 | **`llvm-mc -show-encoding` crashes on a symbolic `.mos_addr_asciz`** (`LLVM ERROR: Don't know how to emit this value.`). `MC/MOS/addr-asciz.s` only covers `--filetype=obj`. | robustness | **T2** | Not 24-bit-related; needs a textual form for `VK_ADDR_ASCIZ` plus a `-show-encoding` RUN line. Upstream-postable. |
| 7 | **Far/packed-24 codegen has zero lit coverage** — add fork-local `CodeGen/MOS/far-*.ll` pinning `af`/`8f`/`a7`/`87`/`$5C` selection, the `p2↔s32` and `p3↔3×s8` bridges, and the `G_PHI(p2)` legalisation. | coverage | **T3** | Multi-file, against a settled design; the emulator gates already define the expected shapes. Keeps the fork's four known lit failures from growing to five. |
| 8 | **`[dp],Y` (`b7`/`97`) is never selected** — a far pointer plus a runtime index always materialises a 32-bit pointer add followed by `lda [dp]`, even in `farindex.c`. Also `sta long,X` (`9f`) and the long-form `cmp`/`eor`/`ora`/`and`/`adc`/`sbc`. | missed optimisation | **T4** (measure first) | Governing lesson 2 applies exactly: a native long form is **not** automatically smaller, and the win depends on operand residency and schedule. This should start as a measurement (does `[dp],Y` beat add + `[dp]` in realistic 16-bit-ambient context?) and only become an implementation if the number says so. Anything built must be gated so a misclassification can only miss a win. |
| 9 | **Bare-symbol operand width in the assembler** (`isa<MCSymbolRefExpr>` always matches the narrowest candidate). | correctness | — | **Already tracked**; do not add a duplicate. Folds into the existing `[T3] Vendor MOS lit suite has four failing tests` item. Note in that item that fixing #2 above removes the practical need for it. |

**Not gaps — decided non-goals, recorded so they are not re-opened:**
AS4 zero-bank (`TODO.md:215-218`); far-pointer storage under default 8-bit (`TODO.md:207-213`,
a16-gated, clean rejection re-verified here); stack-relative addressing / hardware-stack ABI
(measured NULL, 0/13 functions profit); `__far_packed` spelling (precondition unmet, revive
only via a shared `<mos.h>`).

---

## Unknown — stated rather than guessed

- **Whether `b7`/`97` or the long-form arithmetic opcodes appear in `examples/snes/*` or SDK
  code.** My census covered `examples/65816/*.c` only; the SNES sources need platform configs
  and were out of scope. The conclusion "never selected" is sound for the fixture corpus and
  strongly suggestive (a dedicated far-subscript fixture emits none), but is not a
  whole-codebase claim.
- **Whether the §6 divergences change observable behaviour on hardware/emulator.** I proved
  the *bytes* differ and named the semantic difference (DBR-relative vs explicit bank;
  PB-preserving vs PB-setting jump; 2-byte vs 3-byte immediate under M=0). I did **not**
  boot a `-save-temps`-built ROM in MAME/bsnes-jg to observe the failure — that needs the
  container and a quiet box. A `-save-temps` build of `far_tail.c` or `farindex.c` run
  through `dev/run.sh` would settle it, and would make a very sharp regression test.
- **Whether `0039` alone changes anything on the `corpus`/`corpus-a16` gates.** Untested here
  and untested by the fixing agent; the installed toolchain still predates it. The change is
  parser-only and the `-c` path never parses assembly, so the expectation is "no change", but
  that is reasoning, not evidence.
- **Whether `mvn`/`mvp` non-selection is deliberate.** `0020` fixes their bank operand order,
  and the SNES `clang.cfg` names them as an instruction-selection concern, but I found no
  plan or TODO entry recording a decision either way.

---

## Reproducing

```bash
# the round-trip probe (host-only, no container, no emulator)
dev/probe-far-roundtrip.sh --mc build/llvm-mos/bin/llvm-mc \
    --flags "-Xclang -target-feature -Xclang +mos-a16 -Os" -v

# the same defect through a first-party flag, no probe script involved
mos-clang --target=mos -mcpu=mosw65816 -Os -c            -o a.o examples/65816/far-run.c
mos-clang --target=mos -mcpu=mosw65816 -Os -save-temps -c -o b.o examples/65816/far-run.c
cmp a.o b.o     # differ

# the section-name heuristic that rescues only .far* symbols
printf '\t.text\n\tlda x\n\tlda y\n\t.section .far_rodata,"a",@progbits\nx:\t.byte 1\n\t.section .rodata.p,"a",@progbits\ny:\t.byte 1\n' \
  | build/llvm-mos/bin/llvm-mc -triple mos -mcpu=mosw65816 -filetype=obj -o /tmp/s.o
build/llvm-mos-install/bin/llvm-objdump -dr --triple=mos --mcpu=mosw65816 /tmp/s.o
```

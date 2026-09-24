# 0039 validation — explicit width modifiers on constant operands

**Patch:** [`patches/llvm-mos/0039-mos-asm-modifier-width.patch`](../../../patches/llvm-mos/0039-mos-asm-modifier-width.patch)
(189 lines, 4 files: one source file, three new tests).
**PR draft:** [`docs/upstream-asm-modifier-width-pr.md`](../../upstream-asm-modifier-width-pr.md).
**Plan:** [`docs/plans/2026-09-24-mos16-constant-truncation.md`](../../plans/2026-09-24-mos16-constant-truncation.md).
**Defect source:** the numeric controls in
[0036's validation](../2026-09-23/0036-validation.md#separate-constant-modifier-defect)
exposed it; the file it touches carries no other patch in the stack.

**Status: prepared, not posted. Posting is user-triggered.**

## What was built, and where

| | |
|---|---|
| Host build directory | `/home/will/llvm-mos-65816/build/llvm-mos` (mounted at `/work/build/llvm-mos`) |
| Source tree | `vendor/llvm-mos` at `LLVM_MOS_PIN` = `8be0546128a55e78c63ca571d466aa72a782cd36`, edited in place |
| Assembler under test | `build/llvm-mos/bin/llvm-mc`, rebuilt from the edited `MOSAsmParser.cpp` |
| Pre-fix reference | `build/llvm-mos-install/bin/llvm-mc` (installed 2026‑09‑23 18:53, before this change) |
| Configuration | Release, `MOS.cmake` cache, assertions off |

`MOSAsmParser.cpp` is byte-identical at the pin and at the validation tree
`742d554bf08042b8df93d791c335260fadd16643` in the region this patch touches
(their only difference in that file is the `MOSAsmParser` constructor signature,
~120 lines away), and `git apply --check` succeeds against a fresh worktree at
**both** bases. **No `-vendor` twin is required.**

**Not yet run:** a build of the validation tree (`742d554`, assertions on) with
this patch alone. The two existing 742d554 build trees
(`build/0029-cross-target-src`, `build/newton-postra-src`) both carry another
workstream's uncommitted state, so neither could be borrowed without disturbing
it. Everything below is measured on the pin build. This is the remaining
pre-posting step.

## 1. The defect, reproduced on the pre-fix assembler

```
$ build/llvm-mos-install/bin/llvm-mc -triple mos -mcpu=mosw65816 -show-encoding
	lda	mos16(240),x                    ; encoding: [0xb5,0xf0]
	lda	mos16(4660),x                   ; encoding: [0xb5,0x34]
	lda	4660,x                          ; encoding: [0xbd,0x34,0x12]
	lda	mos16(240)                      ; encoding: [0xa5,0xf0]
	lda	mos16(4660)                     ; encoding: [0xa5,0x34]
	lda	mos24(1193046)                  ; encoding: [0xa5,0x56]
	lda	mos24(1193046),x                ; encoding: [0xb5,0x56]
	sta	mos16(16),y                     ; encoding: [0x99,0x10,0x00]
```

`mos24` truncating `$123456` to a one-byte direct-page operand (`a5 56`) was not
in the original report; it is the same defect one width further out.
`sta mos16(16),y` is correct only by accident — there is no `STA zero page,Y`
opcode for it to be narrowed into.

## 2. The end-to-end consequence

```c
/* rt.c */
char f(char i) { return ((volatile char *)0xF0)[i]; }
```

The compiler wraps the base exactly as `MOSMCInstLower::wrapAbsoluteIdxBase`
intends:

```
$ mos-clang --target=mos -Os -S -o rt.s rt.c && grep -n mos16 rt.s
40:	lda	mos16(240),x
```

Assembling that `.s` and disassembling, against the object the compiler emits
directly:

```
=== .s assembled by PRE-FIX llvm-mc ===
00000000 <f>:
       0: aa           	tax
       1: b5 f0        	lda	$f0,x
       3: 60           	rts
=== .s assembled by FIXED llvm-mc ===
00000000 <f>:
       0: aa           	tax
       1: bd f0 00     	lda	$f0,x
       4: 60           	rts
=== direct -c object (reference) ===
00000000 <f>:
       0: aa           	tax
       1: bd f0 00     	lda	$f0,x
       4: 60           	rts
```

```
=== direct vs FIXED ===
  IDENTICAL
=== direct vs PRE-FIX ===
6,7c6,7
<        1: bd f0 00     	lda	$f0,x
<        4: 60           	rts
---
>        1: b5 f0        	lda	$f0,x
>        3: 60           	rts
```

`zero page,X` wraps inside page zero; `absolute,X` carries. At `base = $F0` the
two disagree for every `X >= $10`. With the fix the assembly path and the direct
path agree byte for byte.

## 3. Blast radius — 12,045 measured probes

`dev/probe-modifier-width.sh` (+ `tools/probe_modifier_width.py`) assembles every
combination of 8 CPUs × 10 instruction shapes (3 for SPC700) × 11 modifiers ×
15 operands with `-show-encoding`, once per assembler, and diffs.

```
$ dev/probe-modifier-width.sh build/0039-modifier-width/baseline.json
12045 probes -> build/0039-modifier-width/baseline.json  (11376 assembled, 669 rejected)
$ dev/probe-modifier-width.sh build/0039-modifier-width/fixed.json --mc "$PWD/build/llvm-mos/bin/llvm-mc"
12045 probes -> build/0039-modifier-width/fixed.json  (9857 assembled, 2188 rejected)
$ dev/probe-modifier-width.sh --diff build/0039-modifier-width/{baseline,fixed}.json
12045 probes, 2977 changed
```

Classified:

| outcome | probes |
|---|---:|
| unchanged | 9,068 |
| widened to a larger encoding | 1,458 |
| accepted before, now refused | 1,519 |
| **narrowed to a smaller encoding** | **0** |
| **refused before, now accepted** | **0** |
| changed rows with no modifier | **0** |
| changed rows whose operand is an unresolvable symbol | **0** |

The change is therefore **strictly a narrowing**: no input that the assembler
refused now assembles, and nothing that assembled now assembles smaller. A
misclassification can only produce a diagnostic, never a quieter encoding.

Changed rows by modifier — only the four that can exceed a candidate's width:

| modifier | fixup width | changed rows |
|---|---:|---:|
| `mos24` | 24 | 949 |
| `mos13` | 13 | 708 |
| `mos24segment` | 16 | 708 |
| `mos16` | 16 | 612 |

`mos8`, `mos16lo`, `mos16hi`, `mos24bank`, `mos24segmentlo`, `mos24segmenthi`
(all 8 bits wide) and unmodified operands move zero rows.

The 242 changed rows whose operand is a *symbol* are all `defsym = 240`, an
absolute assignment, which evaluates as a constant and takes the constant exit.
Every row using the undefined `extsym` — the genuinely symbolic exit — is
unchanged, which is the expected result of a change that only touches the
constant exit.

The 1,519 refusals fall into three groups, each of which previously assembled
with the address truncated to fit:

1. a 24-bit modifier on a CPU with no long addressing — `lda mos24($123456)` was
   `a5 56` on `mos6502`, `jmp mos24($123456)` was `4c ff ff`;
2. a wider-than-8-bit modifier on a direct-page indirect base — `lda (mos16($f0)),y`
   was `b1 f0`;
3. a wider-than-8-bit modifier on an 8-bit immediate — `lda #mos24($123456)` was
   `a9 56`.

The refusals carry the matcher's near-miss notes:

```
$ llvm-mc -triple mos -mcpu=mos6502
lda mos24($123456)
<stdin>:1:1: error: invalid instruction, any one of the following would fix this:
<stdin>:1:5: note: operand must be an 8-bit address
<stdin>:1:5: note: operand must be a 16-bit address
```

One behaviour worth naming: on `mosw65816`, `lda #mos13(5)` and
`lda #mos24segment(5)` move from `[0xa9,0x05]` to `[0xa9,0x05,0x00]`. That is
the treatment `#mos16(5)` **already** received before this change, through the
`MOS::Imm16` special case the fix generalises — verified against both binaries:

```
=== build/llvm-mos-install/bin/llvm-mc (pre-fix) ===
	lda	#mos16(5)                       ; encoding: [0xa9,0x05,0x00]
	lda	#mos13(5)                       ; encoding: [0xa9,0x05]
	lda	#mos24segment(5)                ; encoding: [0xa9,0x05]
=== build/llvm-mos/bin/llvm-mc (fixed) ===
	lda	#mos16(5)                       ; encoding: [0xa9,0x05,0x00]
	lda	#mos13(5)                       ; encoding: [0xa9,0x05,0x00]
	lda	#mos24segment(5)                ; encoding: [0xa9,0x05,0x00]
```

## 4. Tests

Three new files under `llvm/test/MC/MOS/`. Each **fails on the pre-fix
assembler** and passes on the fixed one — checked by running the pre-fix
`llvm-mc` through the same `FileCheck` script:

```
=== modifier-width.s on PRE-FIX llvm-mc ===
vendor/llvm-mos/llvm/test/MC/MOS/modifier-width.s:13:26: error: CHECK: expected string not found in input
 lda mos16(240) ; CHECK: encoding: [0xad,0xf0,0x00]
=== modifier-width-65816.s on PRE-FIX llvm-mc ===
vendor/llvm-mos/llvm/test/MC/MOS/modifier-width-65816.s:11:26: error: CHECK: expected string not found in input
 lda mos24(240) ; CHECK: encoding: [0xaf,0xf0,0x00,0x00]
=== modifier-width-errors.s on PRE-FIX ===
vendor/llvm-mos/llvm/test/MC/MOS/modifier-width-errors.s:10:10: error: CHECK: expected string not found in input
```

```
$ llvm-lit -v .../modifier-width.s .../modifier-width-65816.s .../modifier-width-errors.s
PASS: LLVM :: MC/MOS/modifier-width-65816.s (1 of 3)
PASS: LLVM :: MC/MOS/modifier-width-errors.s (2 of 3)
PASS: LLVM :: MC/MOS/modifier-width.s (3 of 3)
Total Discovered Tests: 3
  Passed: 3 (100.00%)
```

## 5. MOS lit suites

```
$ dev/run.sh lit
Total Discovered Tests: 157
  Unsupported:   2 (1.27%)
  Passed     : 151 (96.18%)
  Failed     :   4 (2.55%)

FAIL: LLVM :: CodeGen/MOS/shift-rotate.ll (1 of 157)
FAIL: LLVM :: CodeGen/MOS/legalizer.mir (2 of 157)
FAIL: LLVM :: MC/MOS/addressing-modes-65816.s (3 of 157)
FAIL: LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll (4 of 157)
```

These are exactly the four pre-existing failures tracked by the open
`[T3] Vendor MOS lit suite has four failing tests` item. One of them,
`MC/MOS/addressing-modes-65816.s`, lives in the same file this patch touches, so
it was checked explicitly: the `llvm-objdump` output it is `FileCheck`ed against
is **byte-identical before and after** the change (only the temporary object's
filename in the header line differs), and the failing line is the same one:

```
addressing-modes-65816.s:70:22: error: CHECK: expected string not found in input
 lda addr24 ; CHECK: af 00 00 00
```

That is a different defect in the same function: a bare `MCSymbolRefExpr` takes
the `return true` exit for every width, so a plain symbol always lands on the
narrowest candidate. The symbol there is `.text + 0x30303`, section-relative, so
the assembler genuinely does not know its value at parse time; fixing it needs a
notion of a symbol's addressing width, not width arithmetic. Deliberately out of
scope, and neither fixed nor worsened.

## 6. Patch-stack integration

- Registered in `dev/toolchain.sh` (applied after `0034`) and in
  `dev/regen-patch.sh`'s `STANDALONE_MOSDIR`; its three test files are listed in
  `TESTRELS` so they are copied into the generation tree and reversed back out.
- The `0002` regeneration was exercised with its output redirected to a scratch
  file, because `patches/llvm-mos/0002-321-accum16.patch` currently carries
  another workstream's in-flight edits and must not be overwritten:

```
    wrote .../0002-regen-scratch.patch (6478 lines, 38 files)
==> [verify] apply 0001 + new 0002 (+0003) to a fresh pristine worktree
==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir
RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)
```

  The regenerated `0002` contains **zero** occurrences of `MOSAsmParser` or
  `modifier-width`, i.e. `0039` is correctly excluded from it. Its only
  difference from the working-tree `0002` is the other workstream's uncommitted
  `MOSRegisterInfo.cpp` `hasTracksLiveness` edits, which are not ours to
  regenerate.

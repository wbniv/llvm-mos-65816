# Explicit `mos16(constant)` must not select a zero-page opcode

**TODO item:** "Explicit `mos16(constant)` can select a zero-page opcode and truncate the
address." (`[wip T4]`, M2 / #321 follow-ups).
**File:** `vendor/llvm-mos/llvm/lib/Target/MOS/AsmParser/MOSAsmParser.cpp` —
`MOSOperand::isImmInRange<Low, High>()`.
**Patch artifact:** new standalone `patches/llvm-mos/0039-mos-asm-modifier-width.patch`
(pristine stock-llvm-mos defect → standalone upstream-postable artifact, not folded into
`0002`). `0039` is the number a previous spike of this same defect reserved
(`build/0039-address-width/`, 2026‑09‑23) and then left as a gap in `patches/`; this
closes it. `0043` is already claimed by the in-flight inline-asm-physreg-width plan.

**No mockup section:** this change has no visible surface — it is an assembler operand
predicate whose only output is the selected opcode (or a `no matching instruction`
diagnostic).

---

## 1. The defect

`MOSOperand::isImmInRange<Low, High>()` is the operand-class predicate the generated
AsmMatcher calls to ask "can this parsed operand fill a candidate operand of width
[Low, High]?". `isAddr8()`/`isImm8()` instantiate it with `High = 255`, `isAddr16()` with
`High = 65535`, `isAddr24()` with `High = 0xFFFFFF`, `isImm3()`/`isImm4()` with `7`/`15`.

For an operand wrapped in a MOS modifier (`mos8(…)`, `mos16(…)`, `mos24(…)`, …) the
predicate takes the `MOSMCExpr` branch, which has two exits:

```cpp
if (const auto *ME = dyn_cast<MOSMCExpr>(Imm)) {
  const MOS::Fixups FixupKind = ME->getFixupKind();
  if (FixupKind == MOS::Imm16 && High < 0xFFFF)     // (a) one hard-coded special case
    return false;
  const MCFixupKindInfo &Info = MOSFixupKinds::getFixupKindInfo(FixupKind, nullptr);
  int64_t MaxValue = (1LL << Info.TargetSize) - 1;
  int64_t Value;
  if (ME->evaluateAsConstant(Value) && Value > 0)
    return Value <= MaxValue;                        // (b) constant: High is NEVER consulted
  return MaxValue <= High;                           // (c) symbolic: width vs width
}
```

Exit **(c)** is the correct rule: the *modifier's* width must fit the *candidate's* width.
Exit **(b)** drops it entirely and asks only whether the value fits the modifier's own
width — which it always does, because `MOSMCExpr::evaluateAsInt64` has already masked the
value to exactly that width. So **(b) is `return true` for every positive constant**, and a
16- or 24-bit modifier happily fills an 8-bit zero-page operand slot. The value is then
truncated by the code emitter with no fixup, no relaxation and no diagnostic.

Special case (a) covers only `MOS::Imm16`, the fixup for the *immediate-context* spelling
`#mos16(…)` (`VK_IMM16`). In an address context `mos16(…)` parses to `VK_ADDR16` →
`MOS::Addr16`, a different fixup kind, so (a) never fires for the address form.

### 1.1 Measured, on the current toolchain (pre-fix)

```
$ build/llvm-mos-install/bin/llvm-mc -triple mos -mcpu=mosw65816 -show-encoding
	lda	mos16(240),x                    ; encoding: [0xb5,0xf0]        <- zp,X
	lda	mos16(4660),x                   ; encoding: [0xb5,0x34]        <- zp,X, $1234 truncated
	lda	4660,x                          ; encoding: [0xbd,0x34,0x12]   <- correct, no modifier
	lda	mos16(240)                      ; encoding: [0xa5,0xf0]        <- zp
	lda	mos24(1193046)                  ; encoding: [0xa5,0x56]        <- zp, $123456 truncated
	lda	mos24(1193046),x                ; encoding: [0xb5,0x56]        <- zp,X
```

`mos24` truncating a 24-bit long address to a one-byte direct-page operand is the same
bug, one width further out, and was not in the original report.

### 1.2 Why it is a wrong-code bug, not a cosmetic one

`zp,X` and `abs,X` are not interchangeable: `zp,X` computes `(base + X) & 0xFF`, wrapping
inside page zero, while `abs,X` carries into the high byte. `MOSMCInstLower::wrapAbsoluteIdxBase`
(`llvm/lib/Target/MOS/MOSMCInstLower.cpp:54`) exists *specifically* to stop that, and says so:

> Instructions with indexed addressing must have zero page-matching bases wrapped in
> `mos16`. Otherwise, if the assembly were later parsed, the zero page indexed addressing
> mode might be selected, which has different semantics when Base + Idx >= 256;

The wrapper emits exactly `mos16(240)`, and the parser then ignores it. The protection is
a no-op. End to end, the same source compiled two ways disagrees:

```
$ cat rt.c
char f(char i) { return ((volatile char *)0xF0)[i]; }

$ mos-clang --target=mos -Os -S -o - rt.c      # the compiler's own output
	tax
	lda	mos16(240),x

$ mos-clang --target=mos -Os -c   ...          # object straight from the compiler
   1: bd f0 00      lda $f0,x                  <- absolute,X  (correct)

$ mos-clang --target=mos -Os -S ; assemble .s  # via assembly
   1: b5 f0         lda $f0,x                  <- zero page,X (wrong for X >= 0x10)
```

Any flow that round-trips through `.s` — `-save-temps`, a build that assembles separately,
inline `asm` written by hand, a disassemble-and-reassemble — silently changes semantics.

---

## 2. The fix

Hoist the width relation out of the symbolic exit so it guards **both** exits, and let it
subsume the hard-coded `Imm16` case:

```cpp
if (const auto *ME = dyn_cast<MOSMCExpr>(Imm)) {
  const MCFixupKindInfo &Info =
      MOSFixupKinds::getFixupKindInfo(ME->getFixupKind(), nullptr);
  const int64_t MaxValue = (1LL << Info.TargetSize) - 1;

  // A modifier states the operand width the programmer asked for, so it has to
  // fit the candidate operand's width whether or not the value is known now.
  if (MaxValue > High)
    return false;

  int64_t Value;
  if (ME->evaluateAsConstant(Value) && Value > 0)
    return Value >= Low && Value <= MaxValue;

  return true;
}
```

`MaxValue > High` with `MaxValue == 0xFFFF` is exactly `High < 0xFFFF`, so the removed
`FixupKind == MOS::Imm16` special case is the `Imm16` instance of the general rule; it is
deleted rather than kept alongside it.

### 2.1 Why this is conservative

The change is **strictly a narrowing**: it can only ever turn a `true` into a `false`,
never the reverse.

| branch | before | after | delta |
|---|---|---|---|
| constant, `Value > 0`, `MaxValue <= High` | `Value <= MaxValue` | `Value <= MaxValue` | none |
| constant, `Value > 0`, `MaxValue > High` | `Value <= MaxValue` (≈ always true) | `false` | **the fix** |
| constant, `Value == 0` | `MaxValue <= High` | `MaxValue <= High` | none |
| symbolic / unevaluatable | `MaxValue <= High` | `MaxValue <= High` | none |

So a misclassification can only ever *refuse to match* — a loud `no matching instruction`
at assembly time — never silently select a narrower opcode. That is the direction the
project's governing lesson 2 demands ("a misclassification must only ever miss a win,
never cause a regression"), transposed from codegen gating to operand matching.

It is also not a new rule: `MaxValue <= High` is the rule the symbolic exit has always
applied, and the existing test `MC/MOS/modifiers.s` already pins it —
`lda mos24segment(addr8)` assembles to `ad 00 00` (absolute), not `a5 00`, precisely
because the 16-bit modifier is refused for the 8-bit candidate. The fix makes constants
obey the rule symbols already obey.

### 2.2 The alternative that was rejected

**Reject only when the *value* exceeds `High`** (`Value <= High && Value <= MaxValue`).
That fixes `lda mos16(4660),x` (4660 > 255) but leaves `lda mos16(240),x` broken, since
240 does fit in a byte — and that is the case `wrapAbsoluteIdxBase` actually emits and the
one where the wrap-vs-carry semantic difference bites. A value test cannot express "the
programmer asked for 16 bits"; only a width test can. Rejected.

A second alternative, **exact width matching** (`MaxValue == High`), was also rejected: it
would additionally stop `mos8(sym)` from filling a 16-bit candidate, changing the long-
standing symbolic behaviour with no defect to justify it, and would break
`MC/MOS/modifiers.s`'s `lda mos16lo(addr16)` → `a5 00`.

### 2.3 Scope boundary — what this does *not* fix

`MC/MOS/addressing-modes-65816.s` currently fails its `lda addr24 ; CHECK: af 00 00 00`
line (it assembles to `ad 00 00`). That is a *different* defect in the same function: the
`isa<MCSymbolRefExpr>` exit returns `true` for every width, so a bare symbol always takes
the narrowest candidate and the assembler never consults the symbol's value. Fixing it
needs a parse-time notion of a symbol's addressing width (the operand there is
`.text + 0x30303`, section-relative, so the value genuinely is not known at parse time) —
a design question, not a width-arithmetic bug. It stays with the existing
`[T3] Vendor MOS lit suite has four failing tests` item, and this change neither fixes nor
worsens it (verified: the test's failure output is byte-identical before and after).

---

## 3. Measurement method

Predicting which `(cpu, instruction shape, modifier, operand)` combinations move is
exactly the kind of guess this project's governing lesson 1 forbids. So the delta is
measured: `dev/probe-modifier-width.sh` sweeps **12,045 probes** — 8 CPUs × 10 instruction
shapes (3 for SPC700) × 11 modifiers × 15 operands (13 constants straddling every width
boundary, plus a defined and an undefined symbol) — through `llvm-mc -show-encoding` and
records the selected encoding as JSON. The sweep is run against the pre-fix assembler and
again against the fixed one; `--diff` prints only the rows whose encoding or exit status
changed. Every changed row must be explainable as "a modifier wider than the candidate
operand is no longer accepted".

---

## 4. Work items

1. `dev/probe-modifier-width.sh` + `tools/probe_modifier_width.py` — the sweep (done first,
   so the baseline is captured against the unmodified assembler).
2. Edit `MOSOperand::isImmInRange` in `vendor/llvm-mos/…/MOSAsmParser.cpp` as in §2.
3. New tests in `vendor/llvm-mos/llvm/test/MC/MOS/`:
   - `modifier-width.s` — 6502-level: `mos16`/`mos24` constants must not take a zero-page
     opcode; `mos8` constants still must; symbolic forms unchanged; `mos16(-1)`.
   - `modifier-width-65816.s` — 65816: `mos24` constant → absolute long, `mos16` constant →
     absolute, both indexed and not; the exact `lda mos16(240),x` shape
     `wrapAbsoluteIdxBase` emits.
   - `modifier-width-errors.s` — the narrowing's loud failure mode: a modifier wider than
     every candidate for that mnemonic is a diagnostic, not a truncation.
4. Register the patch: `patches/llvm-mos/0039-mos-asm-modifier-width.patch`, add it to
   `dev/toolchain.sh`'s apply list and to `dev/regen-patch.sh`'s `STANDALONE_MOSDIR` (it
   lives inside `llvm/lib/Target/MOS`, so without that entry the next `0002` regeneration
   would absorb it) and its three test files to `TESTRELS`. Confirm no `-vendor` twin is
   needed: `MOSAsmParser.cpp` is byte-identical at `LLVM_MOS_PIN` (`8be0546`) and at the
   validation tree (`742d554`) except for a constructor signature ~100 lines away, so the
   upstream form applies at the pin.
5. `dev/regen-patch.sh` — confirm `0002` is unchanged by the edit.
6. Verification (§5).
7. `docs/upstream-asm-modifier-width-pr.md` + `docs/pr-preparations/2026-09-24/0039-validation.md`;
   mirror the queue entry into `docs/upstream-contribution-status.md`. **Posting is
   user-triggered — do not open the PR.**

---

## 5. Verification steps

1. `dev/probe-modifier-width.sh --diff build/0039-modifier-width/baseline.json
   build/0039-modifier-width/fixed.json` — every changed row is a wider-modifier-in-a-
   narrower-slot row; no row changes in the other direction (a rejection becoming an
   encoding, or an encoding becoming shorter); no row without a modifier changes; and no
   row whose operand is an *unresolvable* symbol changes. (A symbol given an absolute
   value by `=` evaluates as a constant and does take the constant exit, so those rows may
   move — that is the same rule, not an exception to it.)
2. `dev/run.sh lit` — the two MOS suites. Failure set must equal the recorded pre-existing
   four (`CodeGen/MOS/legalizer.mir`, `CodeGen/MOS/scavenger-p-undef-6502.ll`,
   `CodeGen/MOS/shift-rotate.ll`, `MC/MOS/addressing-modes-65816.s`) plus nothing, with the
   three new tests passing.
3. The end-to-end round trip of §1.2: `-c` and `-S`-then-assemble must now produce
   identical bytes for `rt.c`.
4. `dev/run.sh corpus` — 7/7.
5. `dev/run.sh corpus-a16` — the four-way differential (host == default == `+mos-a16` ==
   `+mos-xy16`, MAME + bsnes-jg) on the full corpus.
6. `dev/regen-patch.sh` — `0002` round-trips and does not absorb the parser change.

---

## 6. Verification results

### Step 1 — probe sweep diff

```
$ dev/probe-modifier-width.sh build/0039-modifier-width/baseline.json
12045 probes -> build/0039-modifier-width/baseline.json  (11376 assembled, 669 rejected)

$ dev/probe-modifier-width.sh build/0039-modifier-width/fixed.json \
    --mc "$PWD/build/llvm-mos/bin/llvm-mc"
12045 probes -> build/0039-modifier-width/fixed.json  (9857 assembled, 2188 rejected)

$ dev/probe-modifier-width.sh --diff build/0039-modifier-width/{baseline,fixed}.json
12045 probes, 2977 changed
```

Classified (`build/0039-modifier-width/diff.txt` has every row):

```
grew (narrow opcode -> wider opcode): 1458
accepted -> rejected:                 1519
SHRANK (BAD):                            0
REJECTED -> accepted (BAD):              0
unresolvable-symbol rows changed:        0   (242 changed rows use `defsym = 240`,
                                              an absolute assignment = a constant)
bare-operand (no modifier) rows changed: 0
changed by modifier: mos24 949, mos13 708, mos24segment 708, mos16 612
```

**PASS** — strictly a narrowing, confined to the four modifiers that can be wider than a
candidate operand.

### Step 2 — `dev/run.sh lit`

```
Total Discovered Tests: 157
  Unsupported:   2 (1.27%)
  Passed     : 151 (96.18%)
  Failed     :   4 (2.55%)

FAIL: LLVM :: CodeGen/MOS/shift-rotate.ll (1 of 157)
FAIL: LLVM :: CodeGen/MOS/legalizer.mir (2 of 157)
FAIL: LLVM :: MC/MOS/addressing-modes-65816.s (3 of 157)
FAIL: LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll (4 of 157)
```

The three new tests pass (`llvm-lit -v` on them alone: `Passed: 3 (100.00%)`), and each
fails on the pre-fix `llvm-mc`. `MC/MOS/addressing-modes-65816.s` produces byte-identical
`llvm-objdump` output before and after (only the temp filename in the header differs).

**PASS** — failure set equals the recorded four pre-existing failures.

### Step 3 — end-to-end round trip

```
--- compiler .s (the mos16 wrap) ---
40:	lda	mos16(240),x
=== .s assembled by PRE-FIX llvm-mc ===
       1: b5 f0        	lda	$f0,x
=== .s assembled by FIXED llvm-mc ===
       1: bd f0 00     	lda	$f0,x
=== direct -c object (reference) ===
       1: bd f0 00     	lda	$f0,x

=== direct vs FIXED ===
  IDENTICAL
=== direct vs PRE-FIX ===
<        1: bd f0 00     	lda	$f0,x
>        1: b5 f0        	lda	$f0,x
```

**PASS**

### Steps 4–5 — `dev/run.sh corpus` / `corpus-a16`

**RUN 2026-09-24 (corpus finished 15:18, corpus-a16 17:56)**, once `build/llvm-mos-install` was finally rebuilt (`dev/run.sh toolchain`,
rc=0, `clang-23` mtime 10:44 → 15:04 and `llvm-mc` 2552536 → 2553008 B, so the installed toolchain now
carries `0039` — until then only the lit-tool `llvm-mc` did). That rebuild also carried the adjacent
`0044` printer fix, so these two runs discharge both plans' emulator legs.

Step 4 — `dev/run.sh corpus`:

```
    ok  SPC700 IPL present and verified (sha1 97e352553e94242ae823547cd853eecda55c20f0, 64 B)
  ...
==> corpus: 80/80 passed
CORPUS rc=0
```

Step 5 — `dev/run.sh corpus-a16` (host == default == `+mos-a16` == `+mos-xy16`, MAME + bsnes-jg):

```
==> corpus-a16: 79/79 passed, 0 xfail
CORPUSA16 rc=0
```

**PASS** — identical to the last pre-`0039` run of the same gate (79/79, 0 xfail, 12:31 the same day),
which is the expected result: the change is parser-only and the `-c` path never parses assembly.

### Step 6 — `0002` regeneration

Run with its output redirected to a scratch file, because
`patches/llvm-mos/0002-321-accum16.patch` currently carries another workstream's
uncommitted edits and must not be overwritten.

```
    wrote .../0002-regen-scratch.patch (6478 lines, 38 files)
==> [verify] apply 0001 + new 0002 (+0003) to a fresh pristine worktree
==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir
RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)

$ grep -c "MOSAsmParser\|modifier-width" .../0002-regen-scratch.patch
0
```

Its only difference from the working-tree `0002` is the other workstream's uncommitted
`MOSRegisterInfo.cpp` `hasTracksLiveness` edits.

**PASS** — `0039` is correctly excluded from `0002`.

---

## 7. Not done

- ~~**Steps 4–5, the emulator differential (`dev/run.sh corpus`, `corpus-a16`).**~~ **DONE
  2026-09-24** — see §6. They had been deferred because `build/llvm-mos-install` still
  predated this patch and the box was occupied by another session's `corpus-a16` run; the
  toolchain rebuild that landed `0044` carried `0039` with it and both gates were then run
  on a quiet box. 80/80 and 79/79, 0 xfail.
- **A validation-tree (`742d554`, assertions on) build with this patch alone**, which the
  other upstream-bound PR records quote. Both existing 742d554 source trees
  (`build/0029-cross-target-src`, `build/newton-postra-src`) carry another workstream's
  uncommitted state, so neither could be borrowed without disturbing it. The patch is
  confirmed to `git apply --check` cleanly at that base.
- **Posting.** User-triggered, per this project's convention.

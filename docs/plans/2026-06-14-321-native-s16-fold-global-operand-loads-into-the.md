# #321 native s16 — fold global-operand loads into the 16-bit ALU (`lda/adc abs16`)

**Status: DONE (2026-06-14).** Combiner rule `alu16_absld` + `G_{...}16_ABSLD` pseudos +
`selectAlu16AbsLd` (clone of `selectAlu16Abs` ending in `STAImag16`). A multi-use `t = a16v + b16v`
now reads both globals directly — `clc; rep; lda b16v; adc a16v; sta __rc2; sep` — dropping the
~8-instruction byte-wise `Imag16` materialization. `a16loadfold.c` asserts `lda/adc abs/long`
(opcodes `af`/`6f`), no `adc zp`, and `0x2345` on both MAME and bsnes-jg. The `>1 use` guard means
single-store globals still fuse via `alu16_abs` (a16add/sub/bit stay green). Note: with `volatile`
operands each use is a separate single-use load, so `a16local`/`a16localsub`/`a16localbit` now fold
too (their gates were widened to accept zp-or-folded; results unchanged); pure-native `adc zp`
coverage remains via `a16localx`'s local-operand chain. Non-breaking: corpus 7/7, all 12 a16* tests
green; patch `0002` round-trips. Mixed (load+register) and single-use-non-store cases remain
follow-ups (see below).

## Context

The native s16 path (`selectAlu16Native`, MOSInstructionSelector.cpp) keeps a value in an `Imag16`
zero-page pair. When an operand is a **near-absolute global** (e.g. `t = a16v + b16v` with `t` reused,
so the 1b store-fused peephole can't fire), the global is first copied byte-wise into an `Imag16` pair
— `ldx a16v; ldy a16v+1; stx __rc2; sty __rc3` (×2 operands = 8 instrs) — and then read from zero page.
The 1b peephole already reads such globals directly via the 16-bit `LDAbs16`/`ADCAbs16` absolute forms;
this change brings that same load-fold to the **multi-use / register-result** case the peephole bails
on. Outcome: `t = a16v OP b16v` (reused) compiles to one bracket `rep; lda a16v; clc; adc b16v; sta
__rc; sep`, dropping the ~8-instruction operand materialization.

This is step 1 of the agreed optimization order (load-fold → 16-bit compares → inc/dec+shifts → arrays
→ A16-threading → cross-block mode-tracking → ABI). It completes "operand handling": after the
immediate fold (just landed), constant operands are optimal; this makes global operands optimal too.

**Pending:** the immediate-fold commit is staged-in-spirit but uncommitted (plan mode blocked it) —
land that commit first, then build this on top.

## Why the combiner, not the selector

A selector-side fold (in `selectAlu16Native`) would have to erase the operand's upstream
`G_MERGE_VALUES(G_LOAD_ABS @g, G_LOAD_ABS @g+1)`. Those byte-loads are **volatile** in the tests, so
`isTriviallyDead` won't auto-erase them (MachineInstr.cpp `hasOrderedMemoryRef`), and manually erasing
them mid-walk corrupts the `InstructionSelect` reverse-iterator (`MII` advances to exactly those
upstream instructions). The **combiner** runs pre-legalizer where the operand is still a single clean
s16 `G_LOAD`, `nearAbsLoad`/`nearAbsGlobalDef` (MOSCombiner.cpp:457-478) already match it, and erasure
is safe + volatile-correct via the `GISelChangeObserver` — exactly how `matchAlu16Abs` already folds
loads (MOSCombiner.cpp:491-599). So this mirrors the proven `alu16_abs` rule.

## Approach

A near-clone of the existing `alu16_abs` peephole, but producing a **register result** (the value stays
in `Imag16` for its multiple uses) instead of a fused store.

### Step 1 — new generic pseudos `G_{ADD,SUB,AND,OR,XOR}16_ABSLD` (MOSInstrGISel.td)

Mirror `G_ADD16_ABS` (same file) but with shape `(outs s16:$dst) (ins addr16:$a, $b)` where `$b` is a
near-abs global **or** a 16-bit immediate (same dual-form `selectAlu16Abs` already inspects via
`Rhs.isImm()`). These are MOS-specific generic opcodes (`isPreISelOpcode`, above
`PRE_ISEL_GENERIC_OPCODE_END`) so the legalizer **skips them by opcode-range** — register **no**
legalizer rule (the 1b finding: a rule corrupts the legalizer tables; see the comment at
MOSLegalizerInfo.cpp:75). They carry 2 memoperands (load-a, load-b) like `G_ADD16_ABS`.

### Step 2 — combiner rule `alu16_absld` (MOSCombine.td + MOSCombiner.cpp)

Add `matchAlu16AbsLd`/`applyAlu16AbsLd` beside `matchAlu16Abs` (MOSCombiner.cpp:491-599), reusing
`nearAbsLoad`/`nearAbsGlobalDef`. Root the rule at the ALU op (`G_ADD`/`G_SUB`/`G_AND`/`G_OR`/`G_XOR`),
not at `G_STORE`. Match when:
- operand A is a `nearAbsLoad` (for commutative ops, if only B is the load, swap so A is the load;
  for `G_SUB`, A must be the minuend load — no swap);
- operand B is a `nearAbsLoad` **or** a 16-bit `G_CONSTANT` immediate;
- **guard against stealing `alu16_abs`/`addchain16`'s cases:** fire only when the result is *not*
  single-use-into-a-foldable-store. Simplest safe guard: require the result to have **>1 use**
  (`!MRI.hasOneNonDBGUse(Dst)`); single-use results stay with the existing rules / current native path.

`applyAlu16AbsLd` builds `G_{OP}16_ABSLD %dst, @a, <@b|#imm>` with the loads' memoperands and erases the
consumed `G_LOAD`s (observer-safe). The `%dst` vreg keeps all its uses.

### Step 3 — selector `selectAlu16AbsLd` (MOSInstructionSelector.cpp)

Clone `selectAlu16Abs` (:1958-2034) — same `LDAbs16`/`ADCAbs16`/bitwise-abs emission, same `IsImm`
branch, same carry-init, same memoperand attachment — but the final store is **`STAImag16 %dst`**
(result into the `Imag16` pair, the op that already exists from the 1d-retry/imm-fold work) instead of
`STAbs16 @g`. The accumulator is still entered/left only via load/store (no `Ac16`↔8-bit COPY — the
invariant). Dispatch the new opcodes in `select()` beside the `G_*16_ABS` cases (:254-262).

### Step 4 — test

`examples/65816/a16loadfold.c`: `t = a16v + b16v; g16 = t; h16 = t; corpus_result = t;` with
`a16v=0x1234`, `b16v=0x1111` → `0x2345`, `t` multi-use (combiner store-fuse can't fire). `dev/run.sh
a16loadfold` (clone `dev/a16local.sh`) asserts the operands are **read directly** (`adc abs` opcode
`6d`, `lda abs` opcode `ad` present) with **no byte-wise `__rc` materialization** of `a16v`/`b16v`, one
rep/sep bracket, and `corpus_result == 0x2345` on **both** MAME and bsnes-jg. Wire into `dev/run.sh`
(top usage line + help block). Also confirm a bitwise multi-use-global case (`a & b` reused) folds
(quick asm probe; the code path is shared).

### Step 5 — regenerate patch + docs

Regenerate `patches/llvm-mos/0002-321-accum16.patch` via the isolated-worktree method (baseline =
pristine vendor HEAD + `0001` committed, overlay current MOS dir, `git diff --cached`), then verify
round-trip (apply `0001`+`0002` to a fresh pristine worktree, `diff -rq` the MOS dir == vendor).
Update the ROADMAP step-5 note, `TODO.md`, and add a short plan doc under `docs/plans/`.

## Out of scope (explicit follow-ups, same machinery)

- **Mixed operand** (`t = a16v + localvar`): one global load + one `Imag16` register. Needs the LDA/op
  to dispatch addressing mode per operand (load vs zp) — a follow-up that generalizes `selectAlu16AbsLd`
  or feeds the result back into `selectAlu16Native`.
- **Single-use-non-store** results (e.g. `return a + b` via register): the `>1 use` guard skips these;
  relax later.
- Chained multi-use load expressions (extend `addchain16` similarly).

## Critical files

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrGISel.td` — define `G_*16_ABSLD` (mirror `G_ADD16_ABS`).
- `.../MOSCombine.td` (rules at :65-79) + `.../MOSCombiner.cpp` (`matchAlu16Abs`/helpers at :457-599) —
  add `alu16_absld`.
- `.../MOSInstructionSelector.cpp` — `selectAlu16Abs` (:1958-2034) is the template; add
  `selectAlu16AbsLd` + dispatch (:254-262). `STAImag16`/`LDAbs16`/`ADCAbs16` already exist
  (MOSInstrLogical.td).
- `.../MOSLegalizerInfo.cpp` — **no** rule for the new opcodes (skip by range; see :75 comment).
- `examples/65816/a16loadfold.c` (new), `dev/a16loadfold.sh` (new), `dev/run.sh` (usage).
- `patches/llvm-mos/0002-321-accum16.patch` (regenerated); docs (ROADMAP, TODO, new plan doc).

## Verification

1. **Build:** `dev/run.sh toolchain` clean (tablegen for the new pseudos + selector/combiner `.cpp`).
2. **Fold fires:** `dev/run.sh a16loadfold` → disasm shows `lda a16v` / `adc b16v` (16-bit abs, opcodes
   `ad`/`6d`), **no** `ldx/ldy/stx/sty` materialization of the operands, one `rep #$20`/`sep #$20`,
   `corpus_result == 0x2345` on MAME **and** bsnes-jg; `main` is markedly smaller than the pre-fold
   native version.
3. **Non-breaking:** `dev/run.sh corpus` → 7/7; all native + peephole tests green
   (`a16 a16add a16sub a16bit a16imm a16chain a16local a16localx a16localsub a16localbit a16localimm`
   + new `a16loadfold`). Critically, `a16add`/`a16sub`/`a16bit` (single-store global peephole) must
   still fire via `alu16_abs` — proving the new rule's `>1 use` guard doesn't steal their cases.
4. **Patch integrity:** `0002` round-trips (applies on `0001`, reproduces vendor MOS dir exactly).

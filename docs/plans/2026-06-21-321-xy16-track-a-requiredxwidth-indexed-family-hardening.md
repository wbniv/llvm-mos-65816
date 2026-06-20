# #321 xy16 — Track A: `requiredXWidth` 8-bit-indexed-family hardening

**One line:** Close a latent gap in `MOSInsertREPSEP::requiredXWidth` — the broad 8-bit indexed/indirect
instruction family falls through to `XW_None` (X-passthrough) instead of `XW_X8`, so if the X-flag lattice ever
left X=16 ambient at one of them it would dereference a 16-bit index with a garbage high byte. Fix is
`HasIndex16`-gated and correctness-safe (only ever inserts a `sep #$10`).

**Status:** REVIEWED & PLANNED (2026-06-21). Implementation is a compiler change → do it on a throwaway
worktree off `main` ([`docs/howto-feature-worktree.md`](../howto-feature-worktree.md)), not on `main`'s hot
shared working copy.

**Supersedes** the sketch in [`2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md` §Track A](2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md)
(that plan resolved the *separate* seed 247/445 bug as Track B; Track A was carried as an unbuilt follow-up).
This plan is the implementation contract for Track A; it refines the recommended fix (memory-gated, to avoid a
real `T_A` edge the bare rule would hit).

> **Review note (2026-06-21).** The fix's two load-bearing correctness claims were checked against
> ground-truth (`build/.../MOSGenInstrInfo.inc` descriptor flags + the `MOSInstr*.td` operand classes), not
> taken on faith:
> 1. **Safety (cannot miscompile):** *all 32* instructions taking a 16-bit-index operand (`Xc16`/`Yc16`)
>    carry `XLow=1` → they return `XW_X16` at the `XLow` check, *before* the catch-all. ✔ The catch-all can
>    therefore only ever insert a `sep`, never `sep`-away a live 16-bit index.
> 2. **Coverage (not inert):** every member of the 8-bit-index family (`LDAAbsIdx`/`LDAZpIdx`/`STAbsIdx`/
>    `STZpIdx`/`LDIndirIdx`/`STIndirIdx`, the 18 ALU-indexed `{ADC,SBC,AND,ORA,EOR,CMP}{Abs,Zp,Indir}Idx`, the
>    4 RMW `{ASL,LSR,ROL,ROR}Idx`, and the 4 a16 `*Idx16` below) is `mayLoad`/`mayStore` **and** survives to
>    REPSEP (none are in `expandPostRAPseudo`). ✔ `T_A` (TXA/TYA) is `mayLoad=0`/`mayStore=0` → correctly
>    excluded by the gate.
>
> The review also **corrected three prose errors** in the original draft (§1 family list / safety-invariant
> wording — see the inline fixes) and **surfaced one residual the rule cannot reach** by construction:
> `JMPIdxIndir` (the `JMP (abs,X)` jump-table dispatch) reads an 8-bit X index but is a non-`mayLoad`
> *branch* → see **§3a** for the analysis and the recommended 2-line closure.

---

## 1. Background — what `requiredXWidth` is and why this gap exists

`MOSInsertREPSEP.cpp` runs after register allocation under `+mos-a16`/`+mos-xy16`. It tracks **two** parallel
mode lattices across the function — the **M flag** (accumulator 8/16) and, when `HasIndex16` is set, the
**X flag** (index registers X/Y 8/16) — and places the `rep`/`sep` instructions that switch them. The whole
pass early-returns unless `STI.hasAccum16()`, and the entire X-lattice is additionally `HasIndex16`-gated, so
**default (non-`+mos-a16`) and plain `+mos-a16` codegen are untouched by anything here.**

`static XWidth requiredXWidth(const MachineInstr &MI)` (`MOSInsertREPSEP.cpp`, grep the symbol — line numbers
drift) is the per-instruction classifier the X-lattice consults. It returns one of `XW_None` (X-agnostic —
inherit ambient), `XW_X8` (must run with X=8), or `XW_X16` (must run with X=16). Current structure, in order:

1. `isReturn()/isCall()` → `XW_X8` (ABI: 8-bit index across call boundaries).
2. `TSFlagXLow` → `XW_X16` — **the genuine 16-bit-index ops.** **The key safety invariant, stated precisely:
   every instruction that takes a *16-bit-index operand* (`Xc16`/`Yc16`) carries `XLow=1`** — verified 32/32
   against the `.td` (the `INX16`/`LDXAbs16`/`TXA16` value ops at ~1045–1168, **and** the indexed
   `LDAbsXIdx`/`STAbsXIdx`/`LDIndirYIdx`/`*XIdx16`/`*YIdx16` at ~760–798). So any op that legitimately uses a
   16-bit index returns here, *before* any catch-all below. **Caveat on naming (the `*Idx16` trap):** the
   suffix `16` denotes the *value* width, **not** the index width. Four `*Idx16`-named pseudos —
   `LDAbsIdx16`/`STAbsIdx16`/`LDIndirIdx16`/`STIndirIdx16` (`MLow=1`, 16-bit **accumulator**) — take an
   *8-bit* index (`Xc`/`Yc`, `XLow=0`) and are therefore **part of the gap below**, not this invariant.
3. `TSFlagXHigh` → `XW_X8` — the real `LDX/STX/LDY/STY`/`CPX/CPY_Immediate` instructions.
4. A `switch` over MC pseudos that lower to index ops only when their relevant operand is X/Y:
   `LD{Abs,Imag8,Imm}`/`STAbs`/`INC`/`DEC`/`STImag8`/`CMP{Imm,Imag8,Abs}`/`LDXIdx`/`LDYIdx`/`TA`/`TX`/`PH`/`PL`.
   (`TA`=TAX/TAY, `TX`=TXY/TYX → unconditional `XW_X8`. **`T_A`=TXA/TYA is deliberately *omitted*** — its width
   is M-governed and its X-read is a value, not an index; see §3.)
5. `isBranch()` → `XW_None`.
6. **default fall-through → `XW_None`.**

**The gap.** The broad 8-bit indexed/indirect family is none of the above — not `XLow`, not `XHigh`, not in the
switch — so it falls through step 6 to `XW_None`. The exact set (verified from the generated
`MOSGenInstrInfo.inc` flags + `.td` operand classes — the original draft's hand list had several wrong names,
which is itself evidence for the structural rule over enumeration, §3):

```
8-bit value, 8-bit index (Xc/Yc):
  LDAZpIdx  LDAAbsIdx               ; lda zp,X / abs,X / abs,Y      (dest A; mayLoad)
  STZpIdx   STAbsIdx                ; sta zp,X / abs,X / abs,Y      (mayStore)
  LDIndirIdx                        ; lda (zp),y                    (mayLoad; reads Y)
  STIndirIdx                        ; sta (zp),y                    (mayStore; reads Y)
  {ADC,SBC,AND,ORA,EOR,CMP}{Abs,Zp,Indir}Idx   ; ALU-indexed (18 pseudos; mayLoad)
  {ASL,LSR,ROL,ROR}Idx              ; RMW abs,X                     (mayLoad+mayStore)
16-bit value (a16), 8-bit index (Xc/Yc) — the "*Idx16" trap (XLow=0, MLow=1):
  LDAbsIdx16  STAbsIdx16            ; A16 = abs,X  /  abs,X = A16    (mayLoad / mayStore)
  LDIndirIdx16  STIndirIdx16        ; A16 = (zp),y /  (zp),y = A16   (mayLoad / mayStore)
```

**Not in the gap** (already correct, do not confuse): `LDAbsXIdx`/`STAbsXIdx`/`LDIndirYIdx`/`*XIdx16`/`*YIdx16`
are the *16-bit-index* xy16 forms (`Xc16`/`Yc16`, `XLow=1`) → already `XW_X16`. The names collide hard —
`LDIndirIdx` (8-bit Y, in the gap) vs `LDIndirYIdx` (16-bit Y, not in the gap). `LDIndir`/`STIndir` (plain
`(zp)`, no index) read no X/Y, so the catch-all leaves them `XW_None` — correct. `LDXIdx`/`LDYIdx` read an
8-bit index but are already `XW_X8` via the switch.

`XW_None` means "inherit the ambient X width." Each gap member uses X (or Y) as an **8-bit address index**. If the
lattice ever flows **X=16** into one — e.g. right after a 16-bit-indexed `*Idx16` load left `rep #$30` ambient,
with no intervening classified-X8 op on that edge — the op would read a **2-byte index** and dereference
`X.high:X.low`, where `X.high` is garbage relative to the 8-bit value the index actually holds. Wrong address →
wrong value or a wild store. This is exactly the failure class of the two already-fixed defects:

- `55ec505` — the same `requiredXWidth` switch omitted the index **value** ops (`CMPImm/CMPImag8/CMPAbs` of X/Y
  → `cpx/cpy`; `INC/DEC` → `inx/iny/dex/dey`). After a `rep #$30` ambient, `cpy #imm` read a 2-byte immediate
  and compared an uninitialized high byte → wrong loop bound → the pr49419 hang. **This plan closes the
  *addressing*-index sibling of that exact bug.**
- `4d8a2bd` — the same switch omitted the index **transfer/push** ops (`TA/TX`, `PH/PL` of X/Y).

So Track A is the third and broadest member of a known family of `requiredXWidth` omissions, all with the same
shape and the same `HasIndex16`-gated, sep-only, correctness-safe fix.

## 2. Why this is "hardening," not a live bug — and why we still do it

It is a **real latent defect** (an instruction class that *can* run in the wrong X width), but it does **not
fire in any current test**:

- The prior analysis (the §Track A canonical plan, findings 1–2) established by 3/3 independent verifiers that
  in seeds 247/445 — and across the csmith 101–500 sweep — **every** such indexed op is already **X8-pinned by
  an adjacent classified op** (`ldy #imm`/`iny`/`tyx`/JSR-return) on its incoming edge, so the lattice never
  actually flows X=16 into an unbracketed 8-bit indexed op. The genuine X=16 regions use the `XLow` `*Idx16`
  forms, which are correctly `XW_X16`.
- Consequence (and the *prediction* this plan's verification will confirm): the fix should be **byte-identical**
  on every existing test — there is no spot in the corpus where the new `XW_X8` disagrees with the
  already-X8 ambient. **Any** non-empty xy16 diff would therefore be a *live instance of the latent defect we
  just fixed* — investigate it as a confirmed bug-fix, not a size nit (§6).

We do it anyway because it is exactly the project's gate doctrine (governing lesson #2): a conservative
classifier whose misclassification can only ever *miss a forced-X8* and never *widen a real 16-bit value* is a
correctness floor. A future scheduling/lattice change, a new indexed pseudo, or a shape the corpus doesn't cover
could let X=16 leak into one of these ops; closing the gap structurally makes that class of miscompile
impossible by construction rather than by the accident of adjacent pinning.

## 3. The fix — memory-gated structural rule (recommended)

Add a single catch-all **after** the `XLow` check (step 2) and the value-op `switch` (step 4), **before** the
final `return XW_None`:

```cpp
// Structural catch-all for the 8-bit indexed/indirect family (lda abs,X / lda (zp),Y /
// sta zp,X / ALU abs,X / RMW abs,X / …). Any op that (a) touches memory and (b) reads an
// index register (X/Y) is using X/Y as an 8-bit ADDRESS index by construction — the genuine
// 16-bit-index forms are XLow=1 and already returned XW_X16 above. Force X8 so they can never
// dereference a 16-bit index with a garbage high byte in a stray X=16 ambient.
//
// Memory-gated on purpose: it must NOT catch the M-governed register transfer T_A (TXA/TYA),
// which reads X/Y as a *value* (not an index) and addresses no memory. Forcing a sep #$10
// before a T_A that reads a live 16-bit X would ZERO X's high byte (sep #$10 clears X/Y high)
// and corrupt the transfer — turning safe hardening into a regression. mayLoad/mayStore makes
// the rule's intent exact: "uses X/Y to address memory."
//
// Correctness-safe: only ever inserts sep #$10. After RA the index operand is the literal
// physical MOS::X/MOS::Y, so exact-match readsRegister(..., TRI) is sufficient; TRI is passed
// for alias-robustness against any future subreg-addressed pseudo.
if ((MI.mayLoad() || MI.mayStore()) &&
    (MI.readsRegister(MOS::X, TRI) || MI.readsRegister(MOS::Y, TRI)))
  return XW_X8;
```

**Threading `TRI`.** `requiredXWidth` is a free `static` function taking only `MI`; add a
`const TargetRegisterInfo *TRI` parameter. The three call sites are all members of `MOSInsertREPSEP`
(`placeIntraBlock`, `placeLegacy`, and the block-width dataflow pass — grep `requiredXWidth(`); add a
`const TargetRegisterInfo *TRI = nullptr;` member set once in `runOnMachineFunction` from
`STI.getRegisterInfo()` (alongside the existing `TII = STI.getInstrInfo();`), and pass it at each call.
*Acceptable simplification:* pass `nullptr` and skip the signature churn — given the `mayLoad/mayStore` gate and
post-RA physical registers, the index operand is the literal `MOS::X`/`MOS::Y` and exact-match suffices. Prefer
threading `TRI` for robustness; if it adds noise to the diff, `nullptr` is a defensible fallback.

### Why memory-gated, not the bare `readsRegister` rule the canonical plan sketched

The canonical §Track A sketch was `readsRegister(X/Y) → XW_X8` with no memory gate, asserting "forcing X8 only
inserts `sep #$10` — never miscompiles." Reading the code shows one exception that breaks that assertion:
**`T_A` (TXA/TYA) reads X/Y but is M-governed and is *deliberately* `XW_None`** (the existing comment at the
`TA/TX` case spells this out). The bare rule would catch `T_A` and force X8 before it. On an edge where X holds a
live 16-bit value, the inserted `sep #$10` zeroes X's high byte *before* the transfer (sep #$10 clears the high
bytes of X/Y) — a **correctness regression**, not a size nit. The same hazard applies to any surviving
physical-`COPY` of `$a = $x` if one reaches REPSEP.

The `mayLoad() || mayStore()` gate makes the rule's intent exact — "uses X/Y to *address memory*" — which is
precisely the indexed/indirect family and **excludes** every register-only X/Y reader (`T_A`, copies,
register-form ALU). It is therefore *both* safer (no `T_A` false-positive) *and* still structural (robust to new
indexed pseudos, including the ALU-indexed ones that live in indented TableGen multiclasses a top-level `^def`
grep misses — the reason a hand-enumeration was rejected). Every member of the family in §1 is `mayLoad` (loads,
ALU-indexed reads, compares), `mayStore` (indexed stores), or both (RMW `ASL/…Idx`), so the gate loses none of
them.

### Alternatives considered (rejected)

- **Hand enumeration** of the family in the `switch`: fragile — the ALU-indexed pseudos are generated by
  indented multiclasses and are easy to miss; a new indexed pseudo silently re-opens the gap. Rejected for the
  structural rule.
- **Bare `readsRegister(X/Y)` + explicit `case MOS::T_A: return XW_None;` carve-out**: works, but enumerates the
  *exclusions* instead of the inclusions and is brittle to other M-governed X/Y readers (copies). The
  memory-gate is the same idea expressed positively and needs no carve-out. Keep as the fallback if the
  memory-gate is ever found to miss a family member (it shouldn't — verify in §5/§6).

## 3a. Residual the memory-gate cannot reach: `JMPIdxIndir` (the `JMP (abs,X)` jump-table dispatch)

Surfaced in review. `JMPIdxIndir` is the indexed-indirect jump the legalizer emits for a `switch` whose jump
table has **≤128 entries** when `hasJMPIdxIndir()` is set — and it **is** set on the 65816
(`has65C02() || hasSPC700()`). It reads **X as an 8-bit table index** (`Xc:$idx`), and it **survives to REPSEP
as a pseudo** (it is *not* in `expandPostRAPseudo` — it lowers via late `PseudoInstExpansion`). So it is a
*bona fide* member of the same latent class: in a stray X=16 ambient it would index the jump table with a
garbage X-high byte → **wild jump** (control-flow hijack — arguably worse than a bad load).

But the memory-gated catch-all **provably cannot reach it**: `JMPIdxIndir` is `mayLoad=0`/`mayStore=0` (modeled
as a pure branch) — confirmed in `MOSGenInstrInfo.inc` — so `(mayLoad()||mayStore())` is false, and it then
hits the `isBranch() → XW_None` fall-through (step 5). The compare-and-branch indexed pseudos
(`CmpBr{Zp,Abs,Indir}Idx`) are *not* a concern: they are expanded in `expandPostRAPseudo` **before** REPSEP, so
REPSEP sees their `CMP*Idx` component (which the memory catch-all *does* catch) followed by a plain branch.

**Closure (2 lines, same safety proof) — CONFIRMED IN SCOPE (2026-06-21).** Add an index-reading-branch rule
**immediately before** the existing `isBranch() → XW_None`:

```cpp
// Index-reading branch — JMP (abs,X) jump-table dispatch (JMPIdxIndir): reads X as an
// 8-bit table index, but is a non-mayLoad branch the memory catch-all above can't reach.
// Force X8 so it can't index the table with a garbage X-high byte in a stray X=16 ambient.
// Same safety floor as the memory rule: no branch carries XLow=1, so this only ever seps.
if (MI.isBranch() &&
    (MI.readsRegister(MOS::X, TRI) || MI.readsRegister(MOS::Y, TRI)))
  return XW_X8;
```

It is exactly as safe as the memory catch-all (the `XLow` invariant means no 16-bit-index branch exists; the
only index-reading branch is `JMPIdxIndir`), and it makes §7's "closes the last known omission" literally true.
**Decision:** this strictly-additive second clause **ships with Track A** (user-confirmed 2026-06-21) — closing
the jump-table residual by construction in the same pass rather than leaving it as a documented follow-up. The
memory catch-all (§3) is unchanged; this clause is independent and verified the same way (§6 step 3).

## 4. Effort & risk

~10–20 lines in one file (`MOSInsertREPSEP.cpp`) plus the `TRI` threading. No TableGen, no selection, no new
pseudos. Risk is bounded by the `HasIndex16` gate (a16/default provably untouched) and the sep-only property
(can't widen a value). The only non-mechanical part is the verification proof and the (hard) RED-test attempt.

## 5. The RED-test problem & micro-test attempt

A RED regression test is **hard**, for two compounding reasons documented on the two prior `requiredXWidth`
fixes:

1. **The gap is X8-pinned everywhere in real code** (§2) — there is no existing program where it fires, so no
   existing test flips RED→GREEN with the fix.
2. **LTO narrows small indices back to X8.** The differential harness links via `--config` (LTO); a provably
   small global/pointer index narrows to 8-bit X, erasing the X=16 ambient. Only a genuinely-16-bit index kept
   alive through LTO (the `pr49419` double-indirect computed-chase pattern) survives as `*Idx16`.

To get a RED test, a synthetic function must reach an 8-bit `(zp),Y`/`abs,X` op on an edge **out of an X16
region** with **no intervening classified-X8 op**, while keeping a genuinely-16-bit index live so LTO can't
narrow it. Attempt it (model on `pr49419` + `examples/65816/xy16spillr.c`): a computed 16-bit index chase that
stays 16-bit, followed on one control-flow edge by an 8-bit indexed access of a *different* array with an 8-bit
index, no `ldy/iny/jsr` between them. If it can be made to fire (`examples/65816/xy16trackA.c` +
`dev/xy16trackA.sh`, wired into `dev/run.sh`, 4-way differential per the micro-test pattern in
[`docs/agent-handoff.md`](../agent-handoff.md)), it is the regression guard.

**If it cannot be made to fire** (the likely outcome — both prior `requiredXWidth` fixes shipped without a
standalone micro-test for reason 2): land Track A as **code-inspection-confirmed hardening**, with the
regression guard being (a) the structural-safety argument, (b) the byte-identical a16/default + xy16 proof
(§6), and (c) the full xy16/c-torture/csmith/fuzz suites staying green. **Document the test gap explicitly** in
the commit and TODO — do not claim a RED test that doesn't exist.

## 6. Verification — run each step, paste raw output in a code block below it, mark PASS/FAIL

> Keep these steps verbatim; they are the spec. Paste evidence under each, then promote the TODO item.

1. **Build the toolchain after the edit:** `dev/run.sh toolchain`. Confirm the rebuild actually took —
   `build/llvm-mos-install/bin/clang-23` mtime advanced (the stale-symlink gotcha).

2. **a16/default non-regression (the gating proof):** for a representative spread of the a16 suite
   (`a16loop`, `a16cmpidx`, `a16absidx`, `a16ptr`, `a16indiry`, …), disassemble the `+mos-a16` and the
   **default** (non-a16) builds pre-fix vs post-fix and diff. **Must be byte-identical** — proves the
   `HasIndex16`/`hasAccum16` gating holds and nothing leaked into the 8-bit paths.

3. **xy16 inertness / latent-defect check:** disassemble the xy16 suite (`xy16basic`, `xy16ops`,
   `xy16indiry`, `xy16spill`, `xy16spillr`) **and** csmith seeds 247 + 445 under `+mos-xy16`, pre-fix vs
   post-fix, and diff. **Expected: byte-identical** (§2 — the gap is X8-pinned everywhere). If a diff appears,
   the **only** legal change is an **added `sep #$10`** immediately before either (a) a genuine 8-bit
   indexed/indirect op (`abs,X`/`(zp),Y`/`zp,X`/ALU-indexed/RMW) — the §3 memory rule — or (b) a `JMP (abs,X)`
   jump-table dispatch (`JMPIdxIndir`) — the §3a branch clause. Both are **live instances of the latent defect
   now fixed**: confirm by inspection that the op was reaching an X=16 ambient, and record as a bug-fix. A
   `sep` before a `T_A`/transfer/non-memory op, or before any **non-index-reading branch**, is a FAIL (a gate
   misfired — investigate).

4. **Track A micro-test (if constructible):** `dev/run.sh xy16trackA` — the forced-X16→8-bit-indexed-op gate
   passes 4-way (host == default == `+mos-a16` == `+mos-xy16` on MAME + bsnes-jg). If not constructible, record
   "test gap — landed as code-inspection hardening" with the §5 rationale.

5. **No xy16 functional regression:** `for t in xy16basic xy16ops xy16indiry xy16spill xy16spillr; do
   dev/run.sh "$t"; done` all PASS; `dev/run.sh k_isort` xy16 leg agrees (default == a16 == xy16 == host).

6. **No a16/default functional regression:** the a16 suite green (`for f in dev/a16*.sh; do dev/run.sh
   "$(basename "$f" .sh)"; done`); `dev/run.sh corpus` → 7/7; `dev/run.sh fuzz --gen csmith 200 101` and
   `… 200 301` → 0 mismatch / 0 crash (modulo any independently-open seed).

7. **c-torture clean (the standing xy16 regression guard):** `dev/run.sh torture 60` — no FAIL; the
   de-XFAIL'd xy16 rows (`pr49419`, `doloop-1`, `20041011-1`, `va-arg-22`) stay XPASS; `xfails.tsv` still has no
   data rows.

8. **MIR-verify + patch hygiene:** the build ran with `-verify-machineinstrs` clean; regenerate
   `dev/regen-patch.sh` and confirm `0002` round-trips with **no foreign hunks**
   (`git diff` the patch; `grep -c <foreign-symbol> patches/llvm-mos/0002-*.patch` for any concurrent work's
   symbols).

### §6 results — verification run 2026-06-21 (worktree `wt/321-track-a`, clang-23 c798c31416f7)

All 8 steps ✅ **PASS** (step 4 = documented test-gap per §5/precedent). Raw evidence per step:

**Step 1 — rebuild took.** clang-23 mtime advanced; build clean in 27 s.
```
pre:  2026-06-20 22:04:26   post: 2026-06-21 01:32:03   (build/llvm-mos-install/bin/clang-23)
```
**Step 2 — gating proof (a16/default byte-identical).** Disasm of all 75 `examples/65816/*.c`, pristine
(`main`) vs fixed (worktree) toolchain:
```
default-build diff: PASS — byte-identical 75/75   (no leak into the 8-bit paths)
a16-build  diff:    PASS — byte-identical 75/75   (HasIndex16 gating holds)
```
**Step 3 — xy16 inertness.** Same 75 examples under `+mos-xy16` **+** csmith seeds 247/445 linked-ROM
(`--config` LTO), pristine vs fixed:
```
xy16-build diff:        PASS — byte-identical 75/75   (gap is X8-pinned everywhere, as §2 predicts)
csmith 247 default/xy16: ROM BYTE-IDENTICAL (32768 B)
csmith 445 default/xy16: ROM BYTE-IDENTICAL (32768 B)
```
No `sep` was added anywhere → zero live latent-defect instances in the corpus (consistent with the prior
3/3-verifier X8-pinned finding). The change is pure hardening.

**Step 4 — RED micro-test: NOT CONSTRUCTIBLE → documented test gap** (per §5; both prior `requiredXWidth`
fixes `55ec505`/`4d8a2bd` shipped this way — `55ec505` added no standalone test, only de-XFAIL'd torture rows).
A purpose-built candidate (pr49419-style 16-bit struct chase + an 8-bit-indexed tail) compiled **ROM
byte-identical** pre/post **and** LTO narrowed its index to 8-bit (`rep #16` count = 0) — the §5 catch-22 (a
16-bit index that survives LTO can't also be the 8-bit-indexed tail). The pr49419 disasm confirms every 16-bit
region is tightly `sep`-bracketed, so no unpinned 8-bit-indexed op reaches an X=16 ambient. **No micro-test was
fabricated** (a byte-identical "test" would assert nothing). Regression guard = the structural-safety proof +
the byte-identical proof + the c-torture suite (step 7).

**Step 5 — xy16 functional (both emulators).**
```
xy16basic ✓0x0042  xy16ops ✓0x2A42  xy16indiry ✓0x7E5A  xy16spill ✓compile  xy16spillr ✓0x3457
k_isort ✓ (default == +mos-a16 == host, both emulators)
```
**Step 6 — a16/default functional + fuzz.**
```
corpus: 7/7 PASS
a16 spread: a16loop/a16cmpidx/a16absidx/a16ptr/a16indiry all PASS (both emulators)
fuzz --gen csmith 200 101: 182/200 PASS, 0 mismatch, 0 crash, 0 error  (18 legit skip: corpus_result GC'd)
fuzz --gen csmith 200 301: 185/200 PASS, 0 mismatch, 0 crash          (14 legit skip)
   — 1 transient "error" (seed 488 MAME TimeoutExpired) was QUIET-box contention (a concurrent far-cc fuzz);
     re-ran seed 488 in isolation → 1/1 PASS, all agree (0xB961). 0 real mismatch across all 400 seeds.
```
**Step 7 — c-torture (the standing xy16 regression guard).**
```
torture-run: 60 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 60)
   — the de-XFAIL'd rows (pr49419, doloop-1, 20041011-1, va-arg-22) all stay XPASS; xfails.tsv still 0 data rows.
```
**Step 8 — MIR-verify + patch hygiene.**
```
-verify-machineinstrs: clean across all xy16+a16 examples (114/116 combos); the 2 fails (a16regpress,
   a16scavnz) are PRE-EXISTING register-pressure/scavenging stress cases — identical error count pre & post
   (not dev/run.sh suite targets, byte-identical output), so unrelated to this change.
dev/regen-patch.sh: RESULT PASS — 0002 round-trips (reapplied MOS dir == live vendor).
foreign-hunk guard: 0 +added far-cc/frameabi content lines; total 0002 content delta vs main = EXACTLY the
   MOSInsertREPSEP.cpp change (MOSInstrLogical.td +/- content byte-identical; only @@ line numbers normalized
   to the current 0001 baseline — main's committed 0002 had drifted behind far-cc's far-pointer growth).
```

## 7. Landing & bookkeeping

- **Worktree, not `main`** (compiler change on a hot shared tree): `wt/321-track-a` off `main` HEAD; warm-copy
  the prebuilt `build/` subdirs (`cp -al`) per [`docs/howto-feature-worktree.md`](../howto-feature-worktree.md)
  rather than a cold rebuild. The fix lands in `patches/llvm-mos/0002-321-accum16.patch`.
- **Stage only your files**, explicitly: the regenerated `0002`, this plan, the micro-test
  (`examples/65816/xy16trackA.c` + `dev/xy16trackA.sh` + the `dev/run.sh` wiring) if built, and the TODO/handoff
  edits. Never stage `vendor/` (gitignored), a foreign patch, or `docs/transcripts/`. Verify
  `git diff --cached --name-only` is exactly that set.
- **On completion:** promote the Track A TODO item (`TODO.md`, the M2 "xy16 — Track A" entry) to `[x]` /
  Done with a one-line summary; this plan is its link. Update the §Track A pointer in
  [`2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md`](2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md)
  to "DONE — see this plan." With the §3a branch clause shipping alongside the §3 memory catch-all, this closes
  the **last known `requiredXWidth` index-width omission, full stop** — every X/Y-reading op that reaches REPSEP
  (indexed load/store, ALU-indexed, RMW, the a16 `*Idx16` forms, **and** the `JMP (abs,X)` jump-table dispatch)
  is now structurally pinned to its correct width.
- Commit message ends with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Push only
  when asked / after coordinating (`main` may carry unpushed work).

## 8. References

- Latent-defect analysis & the X8-pinned finding: [§Track A of the seed 247/445 plan](2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md).
- Closest prior art (same classifier, same fix shape):
  [`2026-06-19-321-xy16-xflag-lattice-fix.md`](2026-06-19-321-xy16-xflag-lattice-fix.md) (`55ec505`, CPX/CPY +
  INC/DEC value ops) and [`2026-06-18-repsep-x-annotation-for-x-governed-transfers-push.md`](2026-06-18-repsep-x-annotation-for-x-governed-transfers-push.md)
  (`4d8a2bd`, TA/TX + PH/PL transfers).
- Code: `MOSInsertREPSEP.cpp` `requiredXWidth` (the classifier) and `placeIntraBlock`/`placeLegacy`/the
  block-width dataflow (the call sites). XLow invariant: `MOSInstrLogical.td` (`*Idx16` forms, `XLow = 1`).
- Build/test mechanics, the micro-test pattern, the QUIET-box rule, the LTO-narrows-small-index gotcha:
  [`docs/agent-handoff.md`](../agent-handoff.md).

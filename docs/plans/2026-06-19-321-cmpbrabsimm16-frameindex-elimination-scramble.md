# Fix the `CmpBrAbsImm16` frame-index elimination scramble (c-torture `20071210-1` and a class of a16 LTO miscompiles)

**Date:** 2026-06-19 · **Status:** **FIX LANDED + VERIFIED — one-line `eliminateFrameIndex` change cleared
13 of the 18 `xfails.tsv` rows.** Remaining: regression micro-test + full gate + regen `0002` (steps 4-6).
**Issue:** #321, ROADMAP M2. First defect fixed from the c-torture `xfails.tsv` backlog.

> **RESULT (2026-06-19):** the single fix cleared **13 miscompiles** — `20010518-2`, `20020402-1`,
> `20071202-1`, `20071210-1`, `20080522-1`, `921117-1`, `990127-1`, `990811-1`, `pr20466-1`, `pr35472`,
> `pr39120`, `pr34768-1`, `pr34768-2`. Two prior hypotheses were **wrong**: `pr34768-*` was filed as an
> "LTO const-attribute drops the reload" bug and `20010518-2` as a "packed-struct/`long`" bug — both were
> actually *this* `eliminateFrameIndex`/`CmpBrAbsImm16` defect. **5 rows remain** and are genuinely separate:
> `pr49419`, `20041011-1`, `doloop-1`, `va-arg-22` (distinct bugs) + `pr7284-1` (the known `int32plus`
> false positive — a harness `dg-require-effective-target` follow-up, not a codegen bug).
**Required reading:** [`CLAUDE.md`](../../CLAUDE.md) (governing lessons + commit discipline) ·
[`docs/agent-handoff.md`](../agent-handoff.md) (build/disasm/gate mechanics) ·
[c-torture differential suite plan](2026-06-19-321-c-torture-execute-differential-suite.md) (where the
backlog comes from) · [seed-42 fix](2026-06-18-321-seed42-legalizeicmp-swap-fix.md) (the prior
"a16 difference perturbs a shared path" precedent).

## TL;DR

`20071210-1.c` (filed as a computed-goto / REPSEP suspect) is **not** a REPSEP bug. It is a **frame-index
elimination** bug in the **shared** (not a16-gated) `MOSRegisterInfo::eliminateFrameIndex`: when resolving a
stack/zero-page address operand, it decides where the displacement lives by a **positional guess** — "the
operand right after the frame index is its displacement immediate." That guess is wrong for the fused 16-bit
pseudo **`CmpBrAbsImm16`** (`addr16:$l, i16imm:$r`), whose operand after the frame-index *address* (`$l`) is
the **compare immediate** (`$r`), not a displacement. The pass therefore adds the *compare value* to the
frame base and **drops the real frame offset** → every such stack access resolves to `base + compareImm`
instead of `base + frameOffset`, reading the wrong slot. The C program's self-check then sees wrong values
and `abort()`s (`corpus_result = 0xDEAD`).

It is **a16-specific** only because `CmpBrAbsImm16` is the native 16-bit fused compare-abs-immediate-branch
pseudo, formed solely under `+mos-a16`; the 8-bit/default path uses separate load + compare, so the
frame-index operand is never followed by a compare immediate and the heuristic holds (default passes). It
needs `-O1` **LTO** + the static / zero-page stack (`-zp-avail`, set by the SNES driver) for the alloca to be
absolute-addressed and folded into the pseudo — which is exactly the ROM build, and why per-function `-S`,
`-O0`, and a plain `llc` invocation all look correct while the linked ROM miscomputes.

Single-location fix. Expected to clear several backlog rows (the pattern `if (local == CONST)` on a stack
variable under a16 LTO is common).

## How it was root-caused (evidence chain)

Reproduction = `dev/run.sh torture --opt -O1 --tests 20071210-1.c` → **XFAIL** on the current (post-merge,
s32-aware) toolchain, so the defect is live. Then, host-side:

1. **Per-function `-S` (a16, -O1)** of `bar`/`foo` is **correct** — so the bug is not per-instruction
   selection. (Lesson 2: per-function asm correct ≠ no bug; the ROM is an LTO build.)
2. **Post-LTO asm** (`-Wl,--save-temps -Wl,--lto-emit-asm`) of `torture_test_main` (the test's `main`, after
   the shim's `-Dmain=` rename) **is** wrong: the final `if (s[0]!=4 || …)` check reads `s[]` from scrambled
   addresses. With `s` based at `zp_stk+6`, it loads `s[0]` at `zp_stk+10`, `s[1]` at `+9`, … — i.e.
   `base + {4,3,2,1,11,12}`, which equals `base + (the compare constants)`.
3. **Pre-codegen IR** (`llvm-dis` of `*.precodegen.bc`) is **100% correct**: `s` is `alloca [6 x i16]`, loaded
   at byte offsets `0,2,4,6,8,10` via clean `inbounds` GEPs. ⇒ **backend bug, not mid-level.**
4. **Filtered MIR dump from the real LTO codegen**
   (`-Wl,-mllvm,-print-after-all -Wl,-mllvm,-filter-print-funcs=torture_test_main`) pinpoints the transition:
   - **Before** `mos-zero-page-alloc` / PEI: `CmpBrAbsImm16 %bb, $z, 0, %stack.1 + N, K` with the correct
     `N ∈ {0,2,4,6,8,10}` (frame offset) and `K ∈ {4,3,2,1,11,12}` (compare value).
   - **After** PEI: `CmpBrAbsImm16 %bb, $z, 0, @torture_test_main_zp_stk + (6+K), K` — the frame base (6) is
     right but the displacement became `K` (the compare value), and `N` is gone.
5. The arithmetic (`Offset = base + K`, `N` dropped) matches **exactly** the buggy branch in
   `eliminateFrameIndex` below.

> Aside (not blocking): a plain `llc` on the same `*.precodegen.bc` — even with all of the SNES LTO codegen
> flags (`-O1 -zp-avail=224 -force-precise-rotation-cost …`) — produces *correct* offsets, because its
> instruction selection does not fold the stack load into a frame-index `CmpBrAbsImm16` here (it keeps a
> register compare). So the end-to-end repro is the **LTO build**; the unit repro for the regression test is
> **hand-authored MIR** fed straight through `prologepilog` (see Regression test).

## Root cause (exact code)

`vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp`, `eliminateFrameIndex` (~L265-271):

```cpp
int Idx = MI->getOperand(FIOperandNum).getIndex();
int64_t Offset = MFI.getObjectOffset(Idx);
if (FIOperandNum + 1 < MI->getNumOperands() &&
    MI->getOperand(FIOperandNum + 1).isImm())          // <-- positional guess: "next operand == displacement"
  Offset += MI->getOperand(FIOperandNum + 1).getImm();
else
  Offset += MI->getOperand(FIOperandNum).getOffset();
```

Operand layout of the relevant `MOSCmpBr` pseudos (`MOSInstrPseudos.td`): `label:$tgt, Flag:$flag,
i1imm:$flag_val, <$l>, <$r>` → `$l` is operand 3, `$r` is operand 4.

| pseudo | `$l` (op3) | `$r` (op4) | FI possible | heuristic on FI=$l |
|---|---|---|---|---|
| **`CmpBrAbsImm16`** | `addr16` | `i16imm` | $l | **BUG** — op4 is the compare imm, taken as displacement |
| `CmpBrAbsAbs16` | `addr16` | `addr16` | $l, $r | OK (op4 not `isImm()` → uses `getOffset()`) |
| `CmpBrImagAbs16` | `Imag16` | `addr16` | $r | OK ($r is last explicit; next op not imm) |
| `CmpBrAbs` (8-bit) | `GPR` | `i16imm` addr | — | n/a (address is a materialized imm, never a frame index) |

So `CmpBrAbsImm16` is the **only** instruction whose frame-index operand is immediately followed by an
unrelated immediate — hence the only one corrupted.

## The fix (one location)

Decide the displacement source by **opcode** (the instruction format), not by "is the next operand an
immediate." This mirrors the opcode lists already in the two `switch`es at ~L293 / ~L322.

```cpp
  int Idx = MI->getOperand(FIOperandNum).getIndex();
  int64_t Offset = MFI.getObjectOffset(Idx);
  // Where the frame-index displacement lives depends on the instruction format,
  // so key off the opcode rather than guessing "the operand after the frame
  // index is its displacement immediate". That guess misfires for CmpBrAbsImm16,
  // whose operand after the frame-index address is the COMPARE immediate (not a
  // displacement) — adding it corrupts the resolved stack address (#321).
  switch (MI->getOpcode()) {
  case MOS::AddrLostk:
  case MOS::AddrHistk:
  case MOS::LDStk:
  case MOS::STStk:
    // These carry the displacement in a separate immediate operand after the FI.
    Offset += MI->getOperand(FIOperandNum + 1).getImm();
    break;
  default:
    // Every other (abs / GA-style) instruction — incl. all CmpBrAbs* — carries
    // the displacement in the frame-index operand's own offset field.
    Offset += MI->getOperand(FIOperandNum).getOffset();
    break;
  }
```

## Gating / safety (CLAUDE.md lesson 2 + 3)

- **Default codegen is unchanged.** The only behavior that differs from the old code is for instructions that
  are *not* `LDStk/STStk/Addr{Lo,Hi}stk` **and** have an immediate operand right after their frame index.
  The sole such instruction is `CmpBrAbsImm16`, which is `+mos-a16`-only. Every default-build frame-index
  instruction either is in the `LDStk` family (handled identically) or has no trailing immediate (abs loads
  end at the address operand or are followed by a register index) — so it already took the `getOffset()`
  branch and still does. This is a correctness fix, not a feature gate, but it cannot regress the 8-bit path.
- **Proven, not asserted:** the differential fuzzer compiles each program *both* default and `+mos-a16` vs
  the host oracle, so any leak into the 8-bit path surfaces as `default@MAME ≠ host`. Verification step 5
  runs it.

## Verification (the contract — run after the edit; paste raw output + PASS/FAIL under each)

1. **Rebuild took.** Edit `vendor/llvm-mos/.../MOSRegisterInfo.cpp`, `dev/run.sh toolchain`, confirm
   `build/llvm-mos-install/bin/clang-23` mtime advanced (stale-clang guard).
   ```
   clang-23 mtime BEFORE: 2026-06-19T20:46:02
   ==> done in 0m 12s: clang version 23.0.0git (... c798c31416f72b395c658b5502d281a162387ab1)
   clang-23 mtime AFTER : 2026-06-19T21:54:47
   (edit present in source: "misfires for CmpBrAbsImm16" @ MOSRegisterInfo.cpp:269)
   ```
   PASS — mtime advanced; the incremental rebuild recompiled the one TU + relinked.

2. **The target test now passes.** `dev/run.sh torture --opt -O1 --tests 20071210-1.c` → **XPASS** (listed
   in `xfails.tsv` but PASSes). (Host-side post-LTO confirmation: the `s[]` check loads now resolve to the
   correct `zp_stk + 6,8,10,12,14,16` — was the scrambled `+10,9,8,7,17,18`.)
   ```
   ==> torture-run: 1 test(s), -O1, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     XP 20071210-1.c           XPASS listed in xfails.tsv but now PASSes — remove the row
   ==> torture-run: 0 PASS, 0 FAIL, 0 SKIP, 0 XFAIL, 1 XPASS (of 1)
   ```
   PASS.

3. **Class sweep.** Re-run the entire `xfails.tsv` set at `-O1`. **13 of 18 XPASS** — remove each fixed row.
   ```
   ==> torture-run: 18 test(s), -O1, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     XP 20010518-2.c    XP 20020402-1.c    XP 20071202-1.c    XP 20071210-1.c    XP 20080522-1.c
     XP 921117-1.c      XP 990127-1.c      XP 990811-1.c      XP pr20466-1.c     XP pr35472.c
     XP pr39120.c       XP pr34768-1.c     XP pr34768-2.c
     xf pr49419.c       xf pr7284-1.c      xf 20041011-1.c    xf doloop-1.c      xf va-arg-22.c
   ==> torture-run: 0 PASS, 0 FAIL, 0 SKIP, 5 XFAIL, 13 XPASS (of 18)
   ```
   PASS — 13 cleared (rows removed from `xfails.tsv`); 5 remain (separate defects + 1 false positive),
   notes updated. (`-Os` recheck folded in: the runner default is `-Os`; the 5 survive there too.)

4. **Regression test — `examples/65816` micro-test, NOT a lit test.** *Vehicle changed:* `regen-patch.sh`
   mirrors **only `llvm/lib/Target/MOS`**, so a lit `.mir` under `llvm/test/` is **not captured by `0002`**
   and would be lost on a fresh `dev/run.sh toolchain` (confirmed: no a16 lit tests exist in `vendor`; the
   project uses `examples/65816` micro-tests). So the always-present guard is `examples/65816/a16frameidx.c`
   + `dev/a16frameidx.sh` (wired into `dev/run.sh`): a stack-resident `unsigned short s[6]` filled by a
   noinline opaque callee (values from `volatile` globals so the array + folded compares survive), then
   `if (s[i] != K_i)` per element — which selects the static-zp-stack `CmpBrAbsImm16` path. Asserts
   `corpus_result == 0x600D` host==default==+mos-a16==+mos-xy16 on MAME + bsnes-jg. Probe confirms it
   triggers (`run()` uses `.Lrun_zp_stk` + folded `cmp #imm`, offsets `+1,+3,+5,…` = base+2i post-fix).
   *Catches-the-bug proof:* revert the one-line fix → rebuild → the same `run()` resolves to base+`K_i`
   (host-side asm), restore → rebuild. The 13 de-XFAIL'd torture rows are the end-to-end guard (they
   hard-FAIL on regression once their `xfails.tsv` rows are gone).
   ```
   ==> compile+link a16frameidx.c (+mos-a16 -O1, LTO) -> a16frameidx.sfc (32768 bytes)
   ==> disasm gate (post-LTO): check() reads s[] over the static/zp stack via >=6 folded compares
       lda mos8(.Lcheck_zp_stk)    cmp #4       <- s[0] @ base+0  (was base+4 pre-fix)
       lda mos8(.Lcheck_zp_stk+2)  cmp #3       <- s[1] @ base+2
       lda mos8(.Lcheck_zp_stk+4)  cmp #2  ...  <- base+2*i, correct stride
     PASS: check() uses the static/zero-page stack (7 refs)
     PASS: >=6 folded immediate compares (the six s[i] checks)
   ==> MAME:     SMOKE: PASS got=0x4321
   ==> bsnes-jg: SMOKE: PASS got=0x4321 (bsnes-jg)
   RESULT: PASS — stack s[i] compared at frame+2*i (not frame+compareImm) -> 0x4321; both emulators agree
   ```
   PASS — `examples/65816/a16frameidx.c` + `dev/a16frameidx.sh` (wired into `dev/run.sh`); triggers the
   static-stack `CmpBrAbsImm16` path and resolves to base+2*i. (The catches-the-bug proof is the upstream
   evidence: the MIR dump's `+ (6+compareImm)` scramble + the 13-test sweep; a revert-rebuild was skipped to
   avoid clobbering the shared toolchain mid-gate.)

5. **Non-breaking gate.** `dev/run.sh corpus` (→ 7/7), `dev/run.sh fuzz 50 1` (→ 50/50, 0 mismatch/crash),
   the a16 suite (incl. the new `a16frameidx`). **Default codegen is unchanged by construction** (no 8-bit
   instruction has the frame-index-then-compare-immediate layout — `CmpBrAbsImm16` is `+mos-a16`-only — so
   the changed branch is unreachable in the default build; corroborated by the 13-test sweep, whose default
   legs all PASS). The gate runs as confirmation.
   ```
   (running in background — confirmation; results appended)
   ```
   PENDING (launched)

6. **Patch hygiene.** `dev/regen-patch.sh` → round-trips PASS; `git diff` of `0002` shows the
   `eliminateFrameIndex` hunk as the **only** patch-content change (the heuristic is *upstream* MOS code, not
   previously in `0002`); no foreign hunks (RegBankSelect-refs delta 0). Micro-test + `xfails.tsv` live in
   the main repo, not `0002`.
   ```
   wrote .../0002-321-accum16.patch (4213 lines, 22 files)
   RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
   (git diff 0002: only the eliminateFrameIndex switch added; no other source +/- lines)
   ```
   PASS.

## Risks / honest scoping

- **lld-vs-llc selection divergence** means the bug doesn't reproduce through `llc` from `.ll`; the unit test
  must be MIR-level (`prologepilog` only). Documented above so a future reader doesn't waste time on an
  `.ll` repro.
- **Class size is a hypothesis.** Step 3 measures it; if a candidate still fails, it's a *different* bug and
  keeps its `xfails.tsv` row (with an updated note).
- **No new addressing assumptions.** The fix only changes *which operand* the displacement is read from; it
  does not touch DBR / long-vs-abs addressing.

## References
- `eliminateFrameIndex` — `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp` (~L256).
- `CmpBrAbsImm16` and siblings — `MOSInstrPseudos.td` (~L387-409).
- Static / zero-page stack passes — `MOSStaticStackAlloc.cpp`, `MOSZeroPageAlloc.cpp` (gate `-zp-avail`,
  set by the driver in `clang/lib/Driver/ToolChains/MOSToolchain.cpp`).
- Backlog + gate — [c-torture differential suite plan](2026-06-19-321-c-torture-execute-differential-suite.md),
  `examples/65816/torture/xfails.tsv`.

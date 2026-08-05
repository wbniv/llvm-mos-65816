# Third-party validation of llvm-mos PR #585 (`G_ASHRE` ASR legalization)

**Date:** 2026-08-05 · **Plan:** [`plans/2026-08-05-585-gashre-validation.md`](../plans/2026-08-05-585-gashre-validation.md) ·
**Status-doc row:** 22 (`#585 watch — G_ASHRE ASR legalization (mlund)`) ·
**Draft comment:** [`upstream-585-validation-comment.md`](../upstream-585-validation-comment.md) (**not posted**)

**PR:** [llvm-mos/llvm-mos#585](https://github.com/llvm-mos/llvm-mos/pull/585), head
`4fb170fd9d357e453c5f3bc9421caa70b8bbb337`, base `1f334fef02b55440d118680d852e95d23eff21ab`.

**Worktree:** `/home/will/llvm-mos-65816-585val` on branch `throwaway/585-validation` — **left standing**.

---

## Verdict

| | |
|---|---|
| Applies to our patch stack | **Cleanly — zero conflicts**, offsets only |
| Correctness (emulator differential) | **No change** — identical corpus PASS set |
| lit `CodeGen/MOS` | **No change** — identical failing set; the PR's `asr-65ce02.ll` and `combiner.mir` pass |
| mlund's byte table | **7 of 8 rows reproduce exactly**; `int32_t >> 1` understates the win (−10, not −8) |
| Inertness for non-65CE02 CPUs | ❌ **Violated** — a size regression, root-caused and fixed below |

The one substantive finding is a **size/performance regression on every non-65CE02 CPU**, caused by an
incomplete opcode migration in `MOSCombinerImpl::getDemandedBits`. It is not a miscompile. A one-arm
addition restores byte-identical output while keeping all of the PR's 65CE02 wins.

---

## 1. Setup and attribution

Compiler-changing throwaway worktree per
[`howto-feature-worktree.md`](../howto-feature-worktree.md): real-copied `vendor/llvm-mos` +
`vendor/llvm-mos-sdk` + warm `build/` (12 GB, 43 s), hardlinked `vendor/bsnes-jg` and `dev/roms`.
`vendor/c-torture` was not present in `main`, so `dev/fetch-torture.sh` fetched it (1862 tests, sha256-verified).
`main` and the shared `vendor/` were never modified.

Three toolchains were built and kept side by side, so any measurement can be repeated:

| install prefix | contents |
|---|---|
| `build/llvm-mos-install-BASE585` | fork, **no** #585 (the baseline; `clang-23` mtime `2026-08-04 22:11:33`) |
| `build/llvm-mos-install-585ONLY` | fork + #585 **exactly as submitted** (`2026-08-05 00:06:33`) |
| `build/llvm-mos-install` | fork + #585 + the `getDemandedBits` fix (`2026-08-05 00:14:27`) |

**Attribution is clean.** The PR's base `1f334fe` is three commits ahead of our vendor pin `8be0546`
(#563), and none of the three touches the MOS backend:

```
$ git diff --stat 8be0546128a5 1f334fef02b5 -- llvm/lib/Target/MOS/ llvm/test/CodeGen/MOS/
(empty)
```

So every conflict is fork-vs-PR, never upstream drift — which is what makes the conflict log below useful
rebase intel.

### Apply log — zero conflicts

`git apply --check -v` reported every hunk applying, with line-offset drift only. No fuzz, no rejects, no
manual resolution:

| file | hunks | max offset |
|---|---:|---:|
| `MOSCombine.td` | 2 | 0 (fork does not touch this file) |
| `MOSCombiner.cpp` | 2 | +33 |
| `MOSInstrGISel.td` | 1 | +143 |
| `MOSInstrLogical.td` | 1 | +17 |
| `MOSInstructionSelector.cpp` | 4 | **+593** |
| `MOSLegalizerInfo.cpp` | 3 | **+235** |
| `MOSMCInstLower.cpp` | 2 | 0 |
| `MOSTargetMachine.cpp` | 1 | +13 |
| the 3 test files | — | clean |

That is a notable result: the fork adds ~1422 lines to `MOSInstructionSelector.cpp` and ~1171 to
`MOSLegalizerInfo.cpp`, and #585 still lands without collision. The change is well localized.

The stale-build gotcha was checked behaviourally, not just by mtime — after the rebuild,
`-mcpu=mos65ce02` on `signed char f(signed char a){return a>>1;}` emits `asr; rts` where the baseline
emitted `cmp #128; ror; rts`.

---

## 2. The finding — `getDemandedBits` has no `G_ASHRE` arm

### Symptom

Byte-identity sweep (§3) flagged exactly one `mosw65816` object changing:
`examples/snes/corpus/sbitfld_sim.c`, whose `sb_step` grew `0x292 → 0x298` (+6 B). Reduced from there.

### Minimal reproducer

```c
#include <stdint.h>
typedef struct { int16_t height:5, slope:4, flow:4; uint16_t mat:3; } C;
void step(C *c){ c->flow = (int16_t)(c->flow >> 1); }
```

`-mcpu=mos6502 -Os -S`, pre-#585 → #585-as-submitted:

```diff
 	rol
 	cmp	#128
 	ror
-	lsr
-	lsr
+	cmp	#128
+	ror
+	cmp	#128
+	ror
 	lsr
 	and	#30
```

Two 1-byte `lsr` became 3-byte `cmp #128; ror`. `.text.step` 47 → 51 (`mos6502`), 40 → 44 (`mosw65816`).
A denser signed-bitfield kernel goes **132 → 169 B on `mos6502` (+28%)**.

### Root cause

`MOSCombinerImpl::getDemandedBits` (`MOSCombiner.cpp`, the `switch (MI.getOpcode())` over *users*) has arms
for `G_LSHRE` and `G_SHLE` only. `G_ASHRE` falls to `default:` → `APInt::getAllOnes(Size)`.

Before #585 an arithmetic right shift became `G_LSHRE` and had a precise rule. After #585 it becomes
`G_ASHRE`, demanded-bits propagation stops dead, and `matchShiftUnusedCarryIn` — which #585 *does* extend to
`G_ASHRE` — can no longer prove bit 7 dead, so the sign carry-in is never elided.

Over-approximating demanded bits is the safe direction, so this is a pessimization, not a miscompile.

The shape needs a **chain** of shifts: a lone `a >> 1` feeding a full-width store does not regress, because
nothing downstream queries demanded bits. Signed bitfield access is the natural generator, since
`G_SEXT_INREG` lowers to a `shl`/`ashr` pair.

### Fix, and proof it is the cause

```cpp
case MOS::G_ASHRE: {
  // As G_LSHRE, except $dst's bit 7 comes from $src's bit 7 (the sign is
  // replicated) rather than from $carry_in. $carry_in is still reported as
  // demanded when bit 7 is: the ROR fallback consumes it on every CPU that
  // does not select the native ASR.
  APInt DstDemandedBits = getDemandedBits(MI.getOperand(0).getReg(), Cache);
  if (Use.getOperandNo() == 2) {
    APInt CarryOutDemanded = getDemandedBits(MI.getOperand(1).getReg(), Cache);
    DemandedBits |= DstDemandedBits << 1 | CarryOutDemanded.zext(8) |
                    (DstDemandedBits & APInt::getSignMask(8));
  } else {
    assert(Use.getOperandNo() == 3);
    DemandedBits |= DstDemandedBits.lshr(7).trunc(1);
  }
  break;
}
```

The `& APInt::getSignMask(8)` term is load-bearing: plain fall-through to the `G_LSHRE` arm would
**under**-approximate (missing that `$src` bit 7 is needed when `$dst` bit 7 is demanded), which is the
unsafe direction.

The rule has to be the **union over both possible selections**, because the combiner runs before selection
and `G_ASHRE` lowers two different ways:

| | `$dst` bit 7 comes from | `$carry_in` used? |
|---|---|---|
| native `ASR` (65CE02, live result) | `$src` bit 7 | no |
| `ROR` fallback (everywhere else) | `$carry_in` | yes |

So the arm demands `$src` bit 7 (needed by the ASR form) **and** `$carry_in` (needed by the ROR form)
whenever `$dst` bit 7 is demanded. Each term over-approximates for one selection and is exact for the
other — over-approximation is the safe direction, so the rule is sound for both without needing to know the
subtarget.

`.text.step` across all three toolchains, for the 3-line reducer above and for the denser signed-bitfield
kernel (`r0`, the reduction of `sb_step`):

| CPU | reducer: base / #585 / +fix | kernel: base / #585 / +fix |
|---|---|---|
| `mos6502` | 47 / **51** (+4) / **47** | 132 / **169** (+37) / **132** |
| `mos65c02` | 40 / **44** (+4) / **40** | 137 / **140** (+3) / **137** |
| `mosw65816` | 40 / **44** (+4) / **40** | 137 / **140** (+3) / **137** |
| `mos65ce02` | 40 / 38 (−2) / 38 | 137 / 137 / 137 |

Every non-65CE02 cell regresses under #585 and is restored exactly by the fix; the `mos65ce02` −2 win is
kept.

With the fix the emitted instruction stream is byte-identical to pre-#585 (`diff` on the `-S` output is
empty).

**Fork-independent.** Our fork does not touch `getDemandedBits`; the `G_LSHRE`/`G_SHLE` switch is verbatim
upstream. Confirmed by `git diff 8be0546 -- MOSCombiner.cpp`, whose only hunks are three unrelated
near-abs-global helpers plus the #585 hunks themselves.

### The other two un-migrated `G_LSHRE` sites are fine

- `MOSCombiner.cpp` `applyExtractLowBit` — builds a `G_LSHRE` from a genuine `G_LSHR`. Unrelated to ashr.
- `MOSLegalizerInfo.cpp` (the `G_ROTR` arm of `legalizeShiftRotate`) — uses a `G_LSHRE` purely as a low-bit
  carry extractor.

`getDemandedBits` is the only place the migration is incomplete.

---

## 3. Byte-identity sweep

`dev/sweep-585.sh` (new, in the worktree) compiles 1540 translation units — 132 `examples/65816`, the
`examples/snes/corpus` slices, and the 1288 in-scope gcc c-torture `execute` rows — at `-Os` across seven
target/feature combos, hashing each object. 10 780 (file, combo) pairs per run.

| combo | compared | identical (#585) | differ (#585) | identical (#585+fix) | differ (#585+fix) |
|---|---:|---:|---:|---:|---:|
| `mos6502` | 1250 | 1250 | 0 | 1250 | 0 |
| `mos65c02` | 1250 | 1250 | 0 | 1250 | 0 |
| `mosw65816` default | 1442 | 1441 | **1** | 1442 | **0** |
| `mosw65816 +mos-a16` | 1468 | 1468 | 0 | 1468 | 0 |
| `mosw65816 +mos-a16 +mos-xy16` | 1468 | 1468 | 0 | 1468 | 0 |
| `mos65ce02` | 1250 | 1234 | 16 | 1234 | 16 |
| `mos45gs02` | 1250 | 1234 | 16 | 1234 | 16 |

Two readings matter:

1. The fork's `+mos-a16` / `+mos-xy16` paths are **completely unaffected** by #585 — our a16 s16 shift
   lowering returns before the code #585 changes, so `G_ASHRE` never reaches it.
2. **The `mos6502`/`mos65c02` zeros are a coverage artifact, not evidence of inertness.** The one corpus
   file carrying the offending shape (`sbitfld_sim.c`) does not build for those CPUs. The targeted reducer
   shows `mos6502` is in fact the *worst* affected. This is why the sweep alone would have under-reported
   the finding.

### 65CE02 win on real code

Across the same 1250 programs, 16 changed on `mos65ce02`, totalling **−529 bytes** (−1.4 % on the affected
files):

```
20020108-1.c  -224   ashrdi-1.c   -105   rcundef.c     -62   rdiff_sim.c  -36
20020508-2.c   -16   20020508-3.c  -16   pr40386.c     -16   pr70429.c    -14
20010116-1.c   -12   20051110-2.c  -11   20100209-1.c   -8   pr78617.c     -6
pr33779-2.c     -5   20011019-1.c   -2   920501-3.c     -2   20051110-1.c  +6
TOTAL (16 files)  38165 -> 37636  = -529
```

The fix does not cost any of these — all 16 remain after applying it.

---

## 4. Reproducing mlund's byte table

`dev/asr-bytetable-585.sh` (new) measures each row of the PR's table as `.text` size of a leaf function.
Seven of eight rows reproduce exactly, identically on `mos65ce02` and `mos45gs02`:

| C operation | PR before | PR after | PR Δ | ours before | ours after | ours Δ |
|---|---:|---:|---:|---:|---:|---:|
| `int8_t x = x >> 1` | 4 | 2 | −2 | 4 | 2 | −2 |
| `int8_t x = x >> 2` | 7 | 3 | −4 | 7 | 3 | −4 |
| `int8_t x = x >> 3` | 10 | 4 | −6 | 10 | 4 | −6 |
| `int16_t x = x >> 1` | 12 | 8 | −4 | 12 | 8 | −4 |
| `int16_t x = x >> 2` | 17 | 11 | −6 | 17 | 11 | −6 |
| `int32_t x = x >> 1` | 20 | 12 | −8 | **22** | 12 | **−10** |
| `uint8_t x = x >> 1` | 2 | 2 | · | 2 | 2 | · |
| `int16_t g; g >>= 1` (store-folded) | — | — | · | 21 | 21 | · |

`mos6502` and `mosw65816` show `·` on all eight rows — the table's inertness claim holds at this
granularity; the regression in §2 needs a shift *chain*, which none of these leaf shapes has.

The `int32_t` discrepancy is in the *before* column only. Measured on the **stock unpatched llvm-mos** in
the dev container (`/opt/llvm-mos`, a pristine build at `8be0546` — identical to the PR's merge base across
the whole of `llvm/lib/Target/MOS/`), `long f(long a){return a>>1;}` is `0x16` = 22 bytes, not 20. So it is
not our fork; the PR understates that row's saving.

---

## 5. Differential battery

Paired runs, same harness and tree, only `MOS_TOOLCHAIN` differing:

```
=================== TOOLCHAIN BASE585 ===================
build exit=1
corpus exit=1 : corpus: 42/63 passed
=================== TOOLCHAIN 585ONLY ===================
build exit=1
corpus exit=1 : corpus: 42/63 passed
=== PASS-set diff (baseline vs 585) ===
IDENTICAL PASS SETS
```

**42/63 on both, with the identical PASS set** — no correctness change. Each corpus entry is itself a
four-way differential (host oracle == default == `+mos-a16` == `+mos-xy16`) on MAME and bsnes-jg, so a PASS
is a real agreement claim.

The 21 non-passing rows are **not** a #585 effect: `dev/run.sh build` fails identically in both runs on
missing generated asset headers (`seamdemo-data.h`, `snes-video-bench-assets.h`,
`snes-video-reel-assets.h`) that a fresh worktree does not carry, and the dependent ROMs then fail to link
(`undefined symbol: main`). This is a worktree-provisioning gap, symmetric across both legs. It does mean
the corpus number here is **not** comparable to `main`'s headline figure.

### gcc c-torture, sampled

`dev/run.sh torture --sample 40 --sample-seed 585` (seeded, reproducible subset), paired:

```
BASE585  ==> torture-run: 40 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 40)
585ONLY  ==> torture-run: 40 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 40)
=== per-test status diff ===
IDENTICAL PER-TEST STATUS
```

Each row is a four-way runtime differential (`default == +mos-a16 == +mos-xy16` against the host oracle, on
MAME + bsnes-jg). **40/40 clean on both legs**, no status change on any individual test.

---

## 6. lit — `llvm/test/CodeGen/MOS`

`llc` was rebuilt explicitly at each source state (the documented second gotcha: `dev/run.sh toolchain`
does not rebuild it).

| state | discovered | passed | failed |
|---|---:|---:|---:|
| BASE (no #585) | 85 | 77 | 7 |
| #585 as submitted | 86 | 78 | 7 |
| #585 + fix | 86 | 78 | 7 |

**The failing set is byte-identical across all three states**, so none of the 7 is attributable to #585 or
to the fix:

```
indexiv.ll  indvar-simplify-20230930.ll  leaf-20231021.ll  legalizer.mir
nonreentrant.ll  nonreentrant-nointerrupts.ll  shift-rotate.ll
```

These are pre-existing fork divergences (our fork rewrites legalization and shift handling substantially).

Of the PR's own three test files: **`asr-65ce02.ll` passes** (it is the +1 discovered/+1 passed) and
**`combiner.mir` passes**. **`legalizer.mir` fails — but it fails at BASE too**, so we cannot confirm or
refute the PR's additions to that file; the fork's own legalizer divergence masks it. Stated plainly: that
part of the PR is **unverified here**, not failed.

---

## 7. What was not covered

- ~~**65CE02 execution.**~~ **CLOSED — see §10.** The native `ASR` path is now validated by execution on
  xemu's Commodore 65 target, not only by inspection.
- **Csmith.** `vendor/csmith` is not present in `main` and would need building from source; skipped for
  budget, as the plan permitted. The 1288 c-torture rows in the sweep give comparable breadth at
  compile level.
- **`legalizer.mir`** — masked by a pre-existing fork failure, see §6.
- **Stock-upstream build of #585.** Everything ran on the fork stack. The main finding's mechanism is in
  unmodified upstream code and the reducer is fork-independent in shape, but we did not build pristine
  upstream + #585 to confirm the exact byte counts there.

## 8. Residual risk

The claim I am least sure of is that the §2 regression is *only* a size effect. The argument is that
over-approximating demanded bits cannot change semantics, which is sound in principle; what would confirm it
independently is a Csmith run on `mos6502` comparing #585 against baseline, which we did not do.

Second, `matchFoldShift`'s `G_ASHRE` arm computes `Val->Value.ashr(1)` ignoring `$carry_in`, relying on the
invariant that `$carry_in` is the source sign bit — while `matchShiftUnusedCarryIn` may itself rewrite that
operand to 0. We could not construct an observable divergence (both paths need bit 7 already proven dead)
and are raising it as a robustness question only.

## 9. 65CE02 execution (added after the initial pass)

The original write-up recorded "no 65CE02 emulator" as the main gap. That was wrong, and the correction is
worth stating plainly: **no copyrighted ROM of any kind is needed.** xemu's C65 target loads *any* exactly
0x20000-byte file as its system ROM with no checksum or version check, so we hand it 128 KiB of our own
code and let the 4510 reset through it. Full recipe and pitfalls:
[`howto-testing-65ce02-code.md`](../howto-testing-65ce02-code.md).

`dev/c65asr/asrkernel.h` folds every arithmetic-right-shift shape — all widths, all shift amounts, both
signs, the multi-byte carry chain, store-folded/dead-result shapes, and signed bitfield read-back — into one
16-bit checksum, shared verbatim between the host oracle and the target. Built with `dev/c65asr/build.sh`,
run with `dev/c65asr/run-xemu.sh`:

| build | native `asr` | `cmp #128` | image | executed result |
|---|---:|---:|---:|---|
| host oracle (`gcc -O2`) | — | — | — | **`0xE0E8`** |
| pre-#585 @ `mos65ce02` | 0 | 18 | 1168 B | **`0xE0E8`** |
| #585 @ `mos65ce02` | 15 | 6 | 1068 B | **`0xE0E8`** |
| #585 + `getDemandedBits` fix | 15 | 6 | 1068 B | **`0xE0E8`** |

Four-way agreement. The `asr` counts are the important control: the #585 rows really did execute the new
native-`ASR` path (15 instances, against 0 at baseline) rather than silently falling back to `cmp #128; ror`
and passing for the wrong reason. #585 also takes 100 bytes off this kernel on 65CE02.

**On `mos45gs02`:** not separately executed, and it does not need to be. It rides the same
`STI.has65CE02()` gate and selects the same instruction, and the sweep shows #585 changing **exactly the
same 16 files** on `mos45gs02` as on `mos65ce02`. (The two CPUs' output is not byte-identical to each
other — it differs on all 1250 objects — but that is equally true pre-#585 and is unrelated to this
change.)

MAME's `c65` driver was tried first and does **not** work — it deliberately does not hook up the `$E000`
ROM window (*"rom8 / roma / rome all causes bootstrap issues if hooked up"*) and is flagged `preliminary`.
Its NOP-sled probe also produced a convincing false positive; both are documented in the HOWTO so the next
person does not repeat them.

## 10. Artifacts

| path | what |
|---|---|
| `/home/will/llvm-mos-65816-585val` | the worktree, left standing (branch `throwaway/585-validation`) |
| `…/dev/sweep-585.sh` | byte-identity sweep harness |
| `…/dev/asr-bytetable-585.sh` | byte-table reproduction harness |
| `…/build/sweep585/{base,base-ce02,post,postfix}.tsv` | raw sweep hashes |
| `…/build/llvm-mos-install-{BASE585,585ONLY}` | the two comparison toolchains |
| `dev/c65asr/{build.sh,run-xemu.sh}` | bare-metal 65CE02 image builder + xemu C65 execution harness |
| `dev/c65asr/asrkernel.h` | the shared ASR kernel (host oracle `0xE0E8`) |
| `/tmp/xemu` (rebuildable in ~1 min) | `make -C /tmp/xemu TARGETS=c65 ARCH=native` |

# DRAFT review comment — llvm-mos PR #585 (`[65CE02] Legalize arithmetic right shifts`)

> ## ⛔ DO NOT POST — user approval required
> This is a **draft**. Posting is user-triggered, per `CLAUDE.md` ("Upstream contributions are queued in
> `docs/upstream-contribution-status.md`… Posting is **user-triggered**"). Nothing below has been sent to
> `llvm-mos/llvm-mos`.
>
> **Exact command to post, once approved:**
>
> ```bash
> awk 'f{print} /^<!-- COMMENT BODY BELOW -->$/{f=1}' \
>   docs/upstream-585-validation-comment.md > /tmp/585-comment.md
> gh pr comment 585 -R llvm-mos/llvm-mos --body-file /tmp/585-comment.md
> ```
>
> (The `^…$` anchors matter — this banner quotes the marker too, but as a blockquoted `> ` line, so only
> the real marker matches.)
>
> Full evidence and method: [`investigations/2026-08-05-585-gashre-validation.md`](investigations/2026-08-05-585-gashre-validation.md).
> Validated against PR head `4fb170fd9d357e453c5f3bc9421caa70b8bbb337`; **re-run before posting if the PR is
> force-pushed.**

---

<!-- COMMENT BODY BELOW -->

Hi @mlund — we ran #585 through the differential battery of a downstream fork and thought the results were
worth sharing, since this PR lands squarely in code we modify heavily. One actionable finding, plus some
corroboration.

**Disclosure on method.** We maintain [wbniv/llvm-mos-65816](https://github.com/wbniv/llvm-mos-65816), an
out-of-tree fork adding 16-bit-accumulator codegen for the WDC 65816. Everything below was measured with
#585 applied **on top of our fork's patch stack**, not on stock llvm-mos, so please read the absolute
baseline numbers with that caveat. Where it matters I've said explicitly whether the fork could be
implicated — for the main finding it cannot, because the code involved is unmodified upstream code.

We have no 65CE02 hardware or emulator, so we could not *execute* 65CE02 output. What we could test is the
CPU-independent half of the change (legalization, the multi-byte split, the combines, CSE) plus codegen-level
inspection of the 65CE02 half.

---

## Finding: `MOSCombinerImpl::getDemandedBits` has no `G_ASHRE` arm, which pessimizes every non-65CE02 CPU

The PR says other CPUs "retain the existing `CMP #128` + `ROR` lowering". That is true at *selection*, but
codegen still changes, because a combiner **analysis** silently stops seeing through the new opcode.

`MOSCombinerImpl::getDemandedBits` switches on the user opcode and has arms for `G_LSHRE` and `G_SHLE`
([`MOSCombiner.cpp`](https://github.com/llvm-mos/llvm-mos/blob/main/llvm/lib/Target/MOS/MOSCombiner.cpp),
in the `switch (MI.getOpcode())` inside `getDemandedBits`). It has none for `G_ASHRE`, so a `G_ASHRE` user
falls to `default:` and yields `APInt::getAllOnes(Size)`.

Before #585 an arithmetic right shift became `G_LSHRE` and had a precise rule. After #585 it becomes
`G_ASHRE`, demanded-bits propagation stops dead there, and `matchShiftUnusedCarryIn` — which the PR itself
extends to `G_ASHRE` — can no longer prove bit 7 is dead. So the sign carry-in is never elided and a 1-byte
`lsr` stays a 3-byte `cmp #128; ror`.

It is a size/performance regression, not a miscompile: over-approximating demanded bits is safe, just
pessimistic.

### Minimal reproducer

```c
#include <stdint.h>
typedef struct { int16_t height:5, slope:4, flow:4; uint16_t mat:3; } C;
void step(C *c){ c->flow = (int16_t)(c->flow >> 1); }
```

`-mcpu=mos6502 -Os -S`, before → after #585:

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

`.text.step` grows 47 → 51 bytes on `mos6502` and 40 → 44 on `mosw65816`. A denser signed-bitfield kernel
(three signed fields, read-modify-write) grows **132 → 169 bytes on `mos6502`, +28%**.

The shape needs a *chain* of shifts — a single `a >> 1` into a full-width store does not regress, because
nothing downstream asks for demanded bits. Signed bitfield access is the natural generator, since
`G_SEXT_INREG` lowers to a `shl`/`ashr` pair.

### Suggested fix

Adding the missing arm restores byte-identical output. `$dst`'s bit 7 comes from `$src`'s bit 7 rather than
from `$carry_in`, so it is `G_LSHRE`'s rule plus one term:

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

Note the extra `& APInt::getSignMask(8)` term is load-bearing — falling through to the plain `G_LSHRE` arm
would *under*-approximate (it would miss that `$src` bit 7 is needed when `$dst` bit 7 is demanded), which
is the unsafe direction.

With this applied, our whole-corpus sweep goes back to **byte-identical on every non-65CE02 CPU**, and all
16 of the 65CE02 improvements are retained.

**This is fork-independent.** Our fork does not touch `getDemandedBits` at all — the `G_LSHRE`/`G_SHLE`
switch is verbatim upstream, and the only delta we introduced there is the arm above.

We also checked the other two `G_LSHRE` sites the PR does not extend; both are correct as-is (one builds a
`G_LSHRE` from a genuine `G_LSHR` in `applyExtractLowBit`, the other uses one purely as a `G_ROTR` carry
extractor). `getDemandedBits` is the only place the migration is incomplete.

---

## Corroboration

**Whole-corpus byte-identity sweep.** 1540 C translation units (our 65816 examples and corpus slices plus
the 1288 in-scope gcc c-torture `execute` rows), compiled `-Os` before and after #585 across seven
target/feature combinations, comparing object hashes:

| combo | compared | identical | differ |
|---|---:|---:|---:|
| `mos6502` | 1250 | 1250 | 0 |
| `mos65c02` | 1250 | 1250 | 0 |
| `mosw65816` (default) | 1442 | 1441 | **1** |
| `mosw65816 +mos-a16` | 1468 | 1468 | 0 |
| `mosw65816 +mos-a16 +mos-xy16` | 1468 | 1468 | 0 |
| `mos65ce02` | 1250 | 1234 | 16 |
| `mos45gs02` | 1250 | 1234 | 16 |

The single `mosw65816` difference is the regression above. The `mos6502`/`mos65c02` zeros are a coverage
artifact, not evidence of inertness — the one corpus file that carries the offending shape does not build
for those CPUs, which is why the targeted reproducer matters more than the sweep row.

**65CE02 win, measured on real code.** Across the same 1250 programs, 16 changed on `mos65ce02`, totalling
**−529 bytes** (−1.4% on the affected files). Largest wins `20020108-1.c` −224 B, `ashrdi-1.c` −105 B,
`rcundef.c` −62 B. One file regressed slightly: `20051110-1.c` +6 B.

**Your byte table reproduces.** Seven of the eight rows match exactly, on both `mos65ce02` and `mos45gs02`:

| C operation | your Δ | our Δ |
|---|---:|---:|
| `int8_t x = x >> 1` | −2 | −2 |
| `int8_t x = x >> 2` | −4 | −4 |
| `int8_t x = x >> 3` | −6 | −6 |
| `int16_t x = x >> 1` | −4 | −4 |
| `int16_t x = x >> 2` | −6 | −6 |
| `int32_t x = x >> 1` | −8 | **−10** |
| `uint8_t x = x >> 1` | · | · |
| `int16_t g; g >>= 1` (store-folded) | · | · |

The `int32_t` row looks like it understates your own win: we measure the *before* at 22 bytes, not 20
(after matches at 12). We confirmed 22 on **stock unpatched llvm-mos** — a pristine build at `8be0546`,
which is identical to your merge base across the whole of `llvm/lib/Target/MOS/` — so it is not our fork;
possibly a different `-O` level or an older base. Worth re-checking before the table lands in history.

**Differential battery — no correctness change.** Both of these run every program four ways (host oracle ==
default == `+mos-a16` == `+mos-xy16`) on MAME *and* bsnes-jg, paired against a pre-#585 baseline built from
the same tree with only the compiler differing:

- **gcc c-torture**, seeded 40-test sample: `40 PASS, 0 FAIL, 0 SKIP, 0 XFAIL` on both legs, with an
  identical per-test status set.
- **Our SNES corpus**: identical PASS set to baseline. (Absolute counts are depressed equally in both runs
  by unrelated missing generated assets in our scratch worktree, so only the comparison is meaningful.)

**lit `CodeGen/MOS`.** We ran the suite at three source states — baseline, #585 as submitted, and #585 plus
the fix above — rebuilding `llc` at each. The failing set is **identical in all three** (7 tests, all
pre-existing divergences from our own fork), so #585 neither introduces nor fixes a lit failure here. Your
`asr-65ce02.ll` and `combiner.mir` both **pass** on top of our fork. Your `legalizer.mir` additions we
genuinely **could not verify**: that file already fails on our tree pre-#585 because of our own legalizer
changes, so it is unverified rather than failing.

**Merge mechanics, as rebase intel.** #585 applies to our patch stack with **zero conflicts** — every hunk
lands on pure line-offset drift, up to +593 lines in `MOSInstructionSelector.cpp` and +235 in
`MOSLegalizerInfo.cpp`. Given that we add ~1400 and ~1170 lines to those two files respectively, that is a
nicely localized change.

---

## Minor note

`matchFoldShift`'s new `G_ASHRE` arm computes `Val->Value.ashr(1)` and ignores `$carry_in`, relying on the
documented invariant that `$carry_in` *is* the source sign bit. But `matchShiftUnusedCarryIn` can itself
rewrite that operand to constant 0 when bit 7 is dead, so after that combine the invariant no longer holds
for the instruction — and on a non-65CE02 CPU selection then emits `LSR` (bit 7 = 0) while the constant fold
would have said bit 7 = sign.

We could not construct a case where this is observable, since both paths are only reachable once
demanded-bits has proven bit 7 dead, and we are flagging it as a robustness question rather than a bug. An
assert or a comment on `G_ASHRE`'s definition recording that `$carry_in` may legitimately be 0 once bit 7 is
dead would make the contract easier to keep.

---

Happy to re-run any of this, share the sweep harness, or test a revision. Thanks for the change — the 65CE02
win on real code is clearly worth having.

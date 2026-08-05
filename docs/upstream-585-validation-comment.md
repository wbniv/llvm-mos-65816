# DRAFT review comment — llvm-mos PR #585 (`[65CE02] Legalize arithmetic right shifts`)

> ## ⛔ DO NOT POST — user approval required
>
> Reviewed 2026-08-05 against unchanged PR head
> `4fb170fd9d357e453c5f3bc9421caa70b8bbb337`. The PR remains open with no comments or reviews;
> macOS, Ubuntu, and Windows CI are green. Re-check the head before posting.
>
> Full evidence: [`investigations/2026-08-05-585-gashre-validation.md`](investigations/2026-08-05-585-gashre-validation.md);
> 65CE02 execution recipe: [`howto-testing-65ce02-code.md`](howto-testing-65ce02-code.md).
>
> **Exact command to post, once approved:**
>
> ```bash
> awk 'f{print} /^<!-- COMMENT BODY BELOW -->$/{f=1}' \
>   docs/upstream-585-validation-comment.md > /tmp/585-comment.md
> gh pr comment 585 -R llvm-mos/llvm-mos --body-file /tmp/585-comment.md
> ```

---

<!-- COMMENT BODY BELOW -->

Hi @mlund — I tested #585 against a downstream MOS corpus. The 65CE02 code-size win is real, but I found
one non-65CE02 pessimization caused by an incomplete `G_LSHRE` → `G_ASHRE` migration in demanded-bits
analysis.

`MOSCombinerImpl::getDemandedBits` handles `G_LSHRE` and `G_SHLE`, but not `G_ASHRE`. A `G_ASHRE` use
therefore falls through to `APInt::getAllOnes(Size)`. In a chain of arithmetic shifts, this prevents
`matchShiftUnusedCarryIn` from proving that a preceding shift's bit 7 is dead. On CPUs without native
`ASR`, an otherwise removable `cmp #128; ror` consequently remains instead of becoming `lsr`.

This is safe but pessimistic: demanded bits are over-approximated, so I found no correctness failure.

Minimal C reproducer (`-mcpu=mos6502 -Os -S`):

```c
#include <stdint.h>
typedef struct { int16_t height:5, slope:4, flow:4; uint16_t mat:3; } C;
void step(C *c) { c->flow = (int16_t)(c->flow >> 1); }
```

Before → after #585:

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

`.text.step` grows 47 → 51 bytes on `mos6502` and 40 → 44 on `mosw65816`. A denser signed-bitfield
kernel grows 132 → 169 bytes on `mos6502` (+28%). A single full-width `a >> 1` does not expose this;
the reproducer needs a shift chain whose high result bits are discarded.

The missing demanded-bits rule is the `G_LSHRE` rule plus source-sign propagation:

```cpp
case MOS::G_ASHRE: {
  APInt DstDemandedBits = getDemandedBits(MI.getOperand(0).getReg(), Cache);
  if (Use.getOperandNo() == 2) {
    APInt CarryOutDemanded =
        getDemandedBits(MI.getOperand(1).getReg(), Cache);
    DemandedBits |= DstDemandedBits << 1 | CarryOutDemanded.zext(8) |
                    (DstDemandedBits & APInt::getSignMask(8));
  } else {
    assert(Use.getOperandNo() == 3);
    DemandedBits |= DstDemandedBits.lshr(7).trunc(1);
  }
  break;
}
```

The sign-mask term is necessary: when destination bit 7 is demanded, `G_ASHRE` also needs source bit 7.
Reusing the plain `G_LSHRE` rule without it would under-approximate demanded bits, which is unsafe.
The carry-in rule remains the same because the non-65CE02 `ROR` fallback consumes carry-in whenever
destination bit 7 is live.

The existing `shift_unused_carry_in` addition does not catch this omission: its `G_ASHRE` result is masked
directly, so `getDemandedBits` never has to traverse through a `G_ASHRE` user. I suggest adding a chained
case such as:

```yaml
%a:_(s8), %ca:_(s1) = G_ASHRE %src, %sign
%b:_(s8), %cb:_(s1) = G_ASHRE %a, %ca
%mask:_(s8) = G_CONSTANT i8 63
%result:_(s8) = G_AND %b, %mask
G_STORE_ABS %result, 1234
```

Without the new arm, the first `G_ASHRE` retains `%sign`; with it, both dead high-bit carry-ins reduce to
zero. That pins the analysis path responsible for the C regression.

I applied the arm locally and rebuilt. The C reducers return byte-for-byte to their pre-#585 output on
`mos6502`, `mos65c02`, and `mosw65816`, while the 65CE02 improvements remain. In a 10,780-object comparison,
all non-65CE02 differences disappeared after the fix; all 16 changed 65CE02 objects retained their wins
(−529 bytes total). A paired emulator differential and the CodeGen/MOS failing set were unchanged.

I also executed the new path rather than only inspecting it. A kernel covering every arithmetic-right-shift
shape I could think of — all widths and shift amounts, both signs, the multi-byte carry chain,
store-folded/dead-result shapes, and signed bitfield read-back — folds into one 16-bit checksum, built
bare-metal for `-mcpu=mos65ce02` and run on xemu's Commodore 65 target. Host oracle, pre-#585, #585, and
#585-plus-the-arm all return `0xE0E8`. The #585 builds contain 15 native `asr` instructions against 0 at
baseline, so they genuinely exercised the new selection rather than falling back and passing for the wrong
reason; #585 also takes 100 bytes off that kernel. `mos45gs02` I checked at codegen level only — running a
45GS02 build on a 4510 would not be sound.

One small measurement note: I reproduced seven of the eight rows in the PR description exactly. For
`int32_t x = x >> 1`, I measure 22 → 12 bytes (−10), rather than 20 → 12 (−8), on stock llvm-mos at the
PR's merge-base-equivalent MOS backend. That appears to make the improvement slightly larger than stated.

The reducer, focused MIR regression, and proposed patch are included above.

# Reconciling with llvm-mos-sdk#415 (the existing SNES target PR)

**Date:** 2026-06-15 · **Status:** strategy note (no code yet)

## What #415 is

[llvm-mos-sdk#415 "[SNES] Add target"](https://github.com/llvm-mos/llvm-mos-sdk/pull/415) — a **draft
PR** by **@Phillip-May**, opened 2025-10-29, **stalled since** (reviewed once by @asiekierka the next
day). One commit (`e6a5c17`, "Initial draft of snes sdk", 2662 additions, 16 files). It is the SDK
**scaffolding** for a SNES target, derived from his portable "snes xc" libraries — and he has **shipped
a real game on it** (a Celeste demake/port). It is rough-draft (`cgramtest.c.c` typo; no `-mcpu`).

It is **8-bit / emulation-mode only**: `clang.cfg` is just `-mlto-zp=224 -D__SNES__` (no
`-mcpu=mosw65816`), `startup.s` is a plain 6502 `jsr`-chain (no XCE / native mode). It touches **zero**
llvm-mos backend code — it rides the existing 6502 codegen.

## Guiding principle: build on #415, do not throw it away

Phillip is the **engaged SNES person** in this ecosystem (working target + a shipped port). Discarding
his work to land a competing SDK target would be wasteful, duplicative, and bad community form. The
right posture is **additive**: credit and reuse what he built, and contribute *only the layer that is
missing* — the optimizing 65816 codegen, which is the part nobody else has done.

## Overlap vs. divergence (his #415 vs. our `mos-platform/snes`)

| Aspect | #415 (Phillip) | Ours (this fork) | Reconciliation |
|---|---|---|---|
| crt0 / startup | 6502 `jsr`-chain, **emulation mode** | **65816 native mode** (XCE, 16-bit stack) — prereq for 16-bit codegen | **Contribute on top:** a native-mode variant/option for #415 |
| `-mcpu` | none (pure 6502) | `-mcpu=mosw65816` | **Fix in #415** (asiekierka already asked) |
| linker script | multi-bank LoROM (8 banks) | 32 KiB LoROM + `snes-far` 64 KiB | **Reuse his** multi-bank layout; keep our far-bank example |
| register header | mature **multi-compiler** `snesxc` lib (REG_*) | minimal `snes.h` | **Reuse his** (with credit); it's real-game-tested |
| ROM header / checksum | (in PR) | `tools/snes-checksum.py` | keep ours as a build step if useful |
| test bench / CI | none | MAME + bsnes-jg dual-emulator harness | **Contribute on top:** offer our CI to #415 |
| **compiler codegen** | **none** (stock 6502 backend) | **#320 far + #321 16-bit (ours)** | **Keep entirely separate** — lands in `llvm-mos`, not the SDK |

## Contribute-on-top vs. keep-separate — the split

**Keep separate (these are the contribution; they live in `llvm-mos`, not `llvm-mos-sdk`):**
- The backend codegen: #320 far-pointer load/store; #321 16-bit accumulator (REP/SEP bracketing,
  native ALU + load/imm folds, native unsigned compares). None of this depends on whose SDK target
  merges — it targets *any* SNES platform that sets `-mcpu=mosw65816`.

**Contribute on top of #415 (SDK-side, additive to Phillip's work):**
- A **native-mode crt0** (XCE + 16-bit stack + native vectors) as the bring-up that *unlocks* the
  16-bit codegen — offered as an option/variant on his target, not a replacement.
- The **dual-emulator CI harness** (MAME + bsnes-jg) as the regression bench his PR lacks — the thing
  that would help his stalled PR actually land.
- Our **far-bank example** / `snes-far` layout if his linker script doesn't already cover >64 KB.

**Reuse from #415 (adopt, with credit):**
- His `snesxc` register definitions (richer than our `snes.h`) and multi-bank linker layout.

**Net:** we overlap only on throwaway scaffolding (which *he already did well enough*), so we drop our
duplicate scaffolding in favor of his, and we keep the part only we have. M0 was always just the test
bench — if #415 supplies the SDK target, we win by focusing on the codegen.

---

# Positioning note — tier-1 exists, tier-2 is ours (raw material for the #321 thread)

> Drafted as talking points for eventually engaging @asiekierka on the
> [#321](https://github.com/llvm-mos/llvm-mos/issues/321) thread. Not yet posted.

**The framing.** "65816 optimization" in llvm-mos today splits into two tiers, and they are routinely
conflated:

- **Tier 1 — 65816 *instructions* in 8-bit codegen (exists upstream).** Behind `HasW65816`, the
  existing backend already emits direct `TXY`/`TYX` (X↔Y without laundering through A —
  `MOSLateOptimization.cpp:239,331`, `MOSInstrInfo.cpp:629`), long jumps (`JSL`/`JML`/`BRL`), block
  moves (`MVN`/`MVP`), `PEA`/`PEI`/`PER`, etc. This is what `-mcpu=mosw65816` buys you today — and
  what asiekierka rightly told #415 it was leaving on the floor. **But it is instruction-set sugar:
  the spirit of a 65C02-style bump, not the architectural leap the "16" in 65816 implies.**

- **Tier 2 — 16-bit *register* / 24-bit *address* codegen (does not exist upstream).** Actual 16-bit
  arithmetic (REP/SEP-bracketed `lda/adc/cmp` on a 16-bit accumulator), >64 KB far pointers. This is
  the chip's headline advantage, and it is **the void**. asiekierka's own word — "*some*
  65816-specific optimizations" — quietly concedes the ceiling: even with the flag, you only get
  tier 1, because tier 2 isn't implemented.

**What we have built (tier 2), code-first, dual-emulator-verified (MAME + bsnes-jg):**
- A late `MOSInsertREPSEP` pass that brackets width-tagged (`MLow`) ops in `rep #$20 … sep #$20`.
- Native s16 ALU — add / sub / and / or / xor — with the value resident in zero-page `Imag16` pairs
  (the GISel-native path past the original `A16`-aliasing register-coalescer crash, now solved by
  keeping the value in `Imag16` and never COPYing the accumulator to/from an 8-bit reg).
- Operand optimizations: constant operands fold to `adc #imm16`; near-abs global operands fold to
  `lda/adc abs16` (combiner rule).
- Native unsigned 16-bit **comparisons** (`< <= > >=`) → one `rep; lda; cmp; sep; bcc` instead of the
  multi-block 8-bit `cpx/cpy` chain.
- Gated on a **separate** `+mos-a16` feature (not implied by `W65816`), so default builds stay 8-bit
  and the 6502 regression corpus is green at every step.

**The ask / opening.** asiekierka is the design owner of #320/#321 and is *actively reviewing SNES
work right now* (#415). The tier-2 codegen he scoped in those issues is the unclaimed layer; we have a
running, verified slice of it. The natural move is to bring it to the #321 thread as the layer that
sits on top of whatever SDK target (likely #415) merges — co-ordinated, code-first, with the design
he already wrote.

# Far (addrspace 2) rodata read produces wrong data in the title VRAM upload — under realistic pressure

**Status:** ✅ **RESOLVED 2026-07-26** — root cause was `MOSZeroPageAlloc`'s CSR renaming missing the
fork's `Imag32` quad (see §RESOLUTION at the bottom; the "under pressure" framing in the title/body was
the working hypothesis, superseded). Found 2026-07-26 while trying to keep the 4 KB `FONT16` table on
`mandel-double` by parking it in bank `$01` far rodata
([plan](../plans/2026-07-26-font16-far-rodata-keep-fonts-everywhere.md)).

## Symptom

Build any `title_layer.h` demo with `-DTITLE_FONT16_FAR` (font table moved to `.far_rodata`) on the
`snes-far` platform and the 16×16 line-1 glyphs come out wrong. The corpus/gate CRC still **passes** —
`corpus_result` is computed from the demo's own math, never from the title — so **only a visual check
catches this.**

| ROM | line 0 (8×8, near `FONT8`) | line 1 (16×16, far `FONT16`) |
|---|---|---|
| `fft` + `TITLE_FONT16_FAR` | renders correctly | **missing entirely** |
| `mandel-double` + `TITLE_FONT16_FAR` | renders correctly | **solid bars** (all-set pixels) |

## Isolation — what is and isn't implicated

Each row is a build actually run and rendered on bsnes-jg, changing one variable:

| # | build | result |
|---|---|---|
| 1 | `fft`, `snes` platform, near font (baseline) | ✅ title correct |
| 2 | `fft`, **`snes-far`** platform, **near** font | ✅ title correct — **platform is not the cause** |
| 3 | `fft`, `snes-far`, **far** font | ❌ line 1 missing |
| 4 | `mandel-double`, `snes-far`, far font | ❌ line 1 solid bars |

So the fault is specific to **reading the table from far rodata**, not to `snes-far` itself.

**But synthetic far reads all pass.** Standalone ROMs with a 4 KB `const FAR uint16_t T[2048]` in
`.far_rodata`, read on bsnes-jg:

- constant indices (`T[0]`, `T[2047]`) → `0xACDB`, matches host oracle. PASS.
- **nested loops with a computed index of the exact font shape** (`T[(g*32)+(tile*8)+r]`, 64×4×8) folded
  to a CRC → `0x2776`, matches host oracle exactly. PASS.
- same loop **plus an interleaved `volatile` store** each iteration (standing in for `REG_VMDATA`) →
  `0x2776`. PASS.

Data placement is also correct: the map puts `FONT16` at `0x18000` size `0x1000`, and the ROM bytes at
file offset `0x8000` are the real glyph data (`0f00 0f00 …` = `0x000F` LE, the `'!'` glyph).

The emitted code for the upload loop looks correct on inspection, too — two 8-bit `lda [__rc20]`
indirect-long byte loads assembled into `__rc24`/`__rc25`, then `rep #32` and a 16-bit `sta 8472`
(`$2118`). Nothing obviously wrong in the sequence.

## Hypothesis

The difference between the passing synthetic cases and the failing real one is **register pressure**. A
far pointer needs a 4-byte `Imag32` quad of consecutive `__rc` bytes; the synthetic repros are tiny leaf
loops with the whole zero page free, while the real upload runs inside `_title_reserve` (0x57b bytes)
within a large program. This is the project's Lesson 1 exactly — *measure in realistic ambient context,
not isolated leaf functions* — and it matches the family of far-pointer/pressure defects already fixed
here (`0009` a16 pressure, `0011` scavenger, `0015` coalesce-rc-undef).

That the two demos fail *differently* (missing vs solid bars) also points at allocation/layout rather
than a fixed logic error.

## Repro

```sh
# broken (line 1 missing):
mos-clang --config build/install/bin/mos-snes-far.cfg -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -DTITLE_FONT16_FAR -Os \
  -o build/fft_far.sfc examples/snes/fft.c
build/jgxcheck build/fft_far.sfc vendor/bsnes-jg/Database 0x20 2 0x0 130 build/fft-far-title.png

# control (identical but near font — renders correctly):
mos-clang --config build/install/bin/mos-snes-far.cfg -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os \
  -o build/fft_farplat.sfc examples/snes/fft.c
```

Requires `TITLE_FONT16_FAR` support in `examples/snes/font16.h` (the `FONT16_STORAGE` macro).

## Next steps — dispositioned 2026-07-26 (see §RESOLUTION; this section predates it)

1. ~~cvise-reduce `fft` + `TITLE_FONT16_FAR` to a minimal failing case~~ — **SUPERSEDED, never
   needed**: the failing binary's disassembly (`lda [$14]` with defs at `$c4..$c7`) led straight to
   `MOSZeroPageAlloc` without reduction. **Residual:** the fix has no dedicated lit test (guarded
   today by the demo renders + fork gates); an upstream-shaped test (`llc -zp-avail=…` forcing the
   CSR rename over a live far quad) rides Wave-5 series prep in the
   [submission campaign](../plans/2026-07-26-upstream-submission-campaign.md).
2. ~~Confirm/refute the pressure hypothesis~~ — **DONE, hypothesis REFUTED**: single-function `llc`
   replay (correct) vs full-module (broken) isolated the delta to the `-mlto-zp` zp budget — CSR
   renaming, not RA spilling.
3. ~~Check `-verify-machineinstrs` on the failing build~~ — **DONE**: clean on the failing build
   (the bug is post-verifier, in the MC-lowering rename map) and clean ×2 on the fixed builds.

## Practical consequence

Do **not** rely on far rodata for data read by a CPU loop inside a large function until this is
root-caused. For bulk VRAM data specifically there is a better route regardless: **DMA straight from the
far bank** (`REG_A1B0` takes a source bank, as `mode7.h` already does), which avoids CPU far loads
entirely and is much faster than a per-word loop.

## RESOLUTION (2026-07-26) — fixed; the hypothesis was wrong in an instructive way

**Not RA spilling — `-mlto-zp` CSR renaming.** The "register pressure" correlation was real but the
mechanism was `MOSZeroPageAlloc` (the LTO zero-page pass, enabled by `mos-snes.cfg`'s `-mlto-zp=224`):
it "silently renames" callee-saved imaginary registers to zp-static-stack slots via `CSRZPOffsets`,
which `MOSMCInstLower` consults per operand. The pass predates the fork's `Imag32` quad: it renamed the
far pointer's four **bytes** (`rc20..rc23` → `$c4..$c7`) but had no entry for the **quad super-register
`RL5`**, so `LDA_IndirectLong [RL5]` fell through to the imag-symbol path and kept reading `[$14]` —
defs renamed, use stale. Proven by the failing binary (`lda [$14]` with **zero** writes to `$14..$17`)
and by single-function `llc` replay being correct (no module zp budget → pass idle). Synthetic repros
passed because tiny programs keep the far pointer in caller-saved quads the pass never touches.

**Fix** (`MOSZeroPageAlloc.cpp`, mirrors the existing Imag16-pair idiom; carried in `0002`): (a) a
live-use Imag32 quad becomes one atomic **size-4 candidate** (guarantees 4 consecutive slots, which
`[dp]` requires); (b) the offset-recording arm enters the quad, both `sublo16`/`subhi16` pairs, and all
four bytes into `CSRZPOffsets`, so every operand width is rewritten consistently. Verification battery
(all PASS, incl. byte-level near-code inertness and a second silent victim, `mandel-oop`, now green):
[fix plan](../plans/2026-07-26-zp-alloc-imag32-csr-rename-fix.md).

**Consequence:** `TITLE_FONT16_FAR` works; `mandel-double` ships the real Waldo font from bank `$01`,
and the `TITLE_FONT16_OFF` legacy path is deleted.

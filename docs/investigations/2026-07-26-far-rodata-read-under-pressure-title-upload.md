# Far (addrspace 2) rodata read produces wrong data in the title VRAM upload — under realistic pressure

**Status:** open, reproducible. Found 2026-07-26 while trying to keep the 4 KB `FONT16` table on
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

## Next steps (not done)

1. cvise-reduce `fft` + `TITLE_FONT16_FAR` to a minimal failing far-read-under-pressure case, the way
   the xy16 seed-445 miscompile was reduced.
2. Confirm/refute the pressure hypothesis directly — compare `_title_reserve`'s `__rc` allocation in the
   passing (synthetic) vs failing (real) builds, and check whether the far pointer's `Imag32` quad
   overlaps something live across the loop.
3. Check `-verify-machineinstrs` on the failing build.

## Practical consequence

Do **not** rely on far rodata for data read by a CPU loop inside a large function until this is
root-caused. For bulk VRAM data specifically there is a better route regardless: **DMA straight from the
far bank** (`REG_A1B0` takes a source bank, as `mode7.h` already does), which avoids CPU far loads
entirely and is much faster than a per-word loop.

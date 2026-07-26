# Keep the 16×16 title font on every demo — move `FONT16` to far ROM

**Status:** in progress (2026-07-26).

## Why

`mandel-double` could not fit the shared title layer's 4 KB `FONT16` Waldo table in its 32 KB LoROM
bank, because its double soft-float library alone is ~20 KB (`__adddf3` 6728 B + `__muldf3` 5431 B +
the float twin's `__addsf3` 3179 B + `__mulsf3` 2311 B + helpers). The earlier fix (commit `0467e5b`)
resolved that by having the demo self-declare **`TITLE_FONT16_OFF`**, dropping to the legacy path that
pixel-doubles the 8×8 font into chunky 16×16 glyphs.

**That was the wrong trade.** Per the user: *"i always want the fonts included"* — and the 32 KB ceiling
is not a hardware limit on cartridge size (SNES carts reach 4 MB+). Losing the real Waldo font on one
demo to save 4 KB is not an acceptable outcome when the platform can simply address more ROM.

**The precise constraint** (worth stating, because "just make the ROM bigger" is not quite it): the
32 KB is the **near-code window** `$8000–$FFAF`, which *is* fixed by the LoROM/HiROM bank mapping. You
do not grow it — you grow *past* it by **banking**, which this project already supports (#320 far
pointers, `address_space(2)`). `FONT16` is pure `const` rodata that is read exactly once at title
upload, so it is an ideal candidate to live in a far bank.

## Mechanism (verified before designing around it)

`platforms/snes-far/link.ld` provides `rom_1` = bank `$01` (`$018000–$01FFFF`, 32 KB) with a
`.far_rodata` section, and its own comment names this exact remediation: *"move code to .far_text /
data to .far_rodata in bank $01"*. Precedent already in-tree: `examples/65816/farindex.c` reads a
**192 KiB** `const FAR uint16_t tbl[]` spanning banks `$C1..$C3` as a passing gate.

Standalone spike run 2026-07-26 (4 KB table, the same size as `FONT16`):

```c
#define FAR __attribute__((address_space(2)))
__attribute__((section(".far_rodata")))
const FAR uint16_t TBL[2048] = { [0]=0x1234, [1]=0x5678, [2047]=0xBEEF };
...
h ^= (uint16_t)TBL[0]; h ^= (uint16_t)TBL[2047];   /* expect 0x1234^0xBEEF = 0xACDB */
```

```
corpus_result @ WRAM 0x200  (expect 0xACDB = 0x1234^0xBEEF)
SMOKE: PASS off=0x200 len=2 got=0xACDB (ran 120 frames, bsnes-jg)
```

**PASS** — compiles, links to a 64 KB ROM, and the bank-`$01` reads are correct on the cycle-accurate
core. Indexing a far-qualified array needs no source contortion; the compiler emits the 24-bit loads.

## Design

1. **`examples/snes/font16.h`** — make `FONT16`'s storage conditional. Under `TITLE_FONT16_FAR`, define
   it `__attribute__((section(".far_rodata")))` + `address_space(2)`; otherwise byte-for-byte as today.
   The table *data* is untouched either way.
2. **`examples/snes/snesgfx/title_layer.h`** — the upload loop indexes `FONT16[...]` and needs no change
   (a far-qualified array indexes identically). **Delete the `TITLE_FONT16_OFF` legacy path outright**
   (user-directed, in scope): the `#ifndef` around the `font16.h` include, the `_title_expand_byte`
   pixel-doubler, and the `#else` upload branch all go. Leaving a working "drop the font" switch in the
   tree is what allowed the font to be silently dropped in the first place; with it gone there is no
   font-less path to fall into, and a size-tight demo must use far ROM instead.
3. **`examples/snes/mandel-double.c`** — replace the `TITLE_FONT16_OFF` self-declare (from `0467e5b`)
   with `TITLE_FONT16_FAR`, and mark the demo as needing the `snes-far` platform.
4. **Platform selection must not re-introduce build-path drift.** This is the trap `0467e5b` just fixed:
   a per-demo fact that lives in only one build script is invisible to the others. A linker config is
   *not* expressible as a `#define`, so it needs a **source marker** that every path greps — exactly how
   `dev/build.sh` already detects `mos-a16-only`. Add a `snes-far-platform` marker comment and honour it
   in **all three** paths: `dev/build.sh`, `dev/rebuild-web-roms.sh`, `dev/mandel-double.sh`.
5. **Manifest** — `corpus_result`'s WRAM offset may move; re-read it from the `.map` and update
   `public/play/roms/manifest.json`'s selfcheck if it changed.

## Verification

1. Spike: far 4 KB table reads correctly on bsnes-jg — **done, PASS (`0xACDB`)**, above.
2. `dev/run.sh mandel-double` — gate green with the **real** font: `host==+mos-a16==0x0EDF`, disasm
   shape unchanged (`__muldf3=8`, `__add/subdf3=12`).
3. Title capture — confirm the rendered title shows real Waldo glyphs with drop-shadow, not the chunky
   pixel-doubled 8×8.
4. `dev/run.sh build` — still builds every program (232), no link errors.
5. **No-growth proof for the other 80+ demos.** The `font16.h`/`title_layer.h` edits must be *inert*
   for every demo that does not opt in — the removed legacy branch was already not compiled for them, so
   their ROMs should come out **byte-identical**. Check by rebuilding an unrelated demo and comparing
   its sha256 against the pre-change build (`cpu6502` is ideal: its ROM is known byte-identical to the
   copy in production, `c0df7cfd…`), plus confirming every non-`mandel-double` ROM is still 32768 bytes.
6. Republish to biohack.net and confirm the live page serves the new ROM.

## Constraint: no other demo may grow

Far ROM is **opt-in per demo** (`TITLE_FONT16_FAR` + the `snes-far-platform` marker), and only
`mandel-double` sets either. Every other demo keeps `static const uint16_t FONT16[]` in near rodata on
the plain `snes` platform and stays a 32 KB single-bank ROM — pushing the font to a second bank in a
demo that already fits would double its ROM for no benefit (and inflate the download on every published
page). This is a **requirement, not an expectation**, so it is verified empirically in step 5 below
rather than argued from the code.

## Out of scope

- Moving other demos to far ROM. Only `mandel-double` needs it; the rest fit comfortably — and must not
  grow (see above).

## COMPLETED (2026-07-26, second pass — after the codegen fix)

The first pass landed the infrastructure but hit the `[dp]` read-garbage bug and reverted the demo flip.
With the root cause fixed ([zp-alloc Imag32 CSR-rename plan](2026-07-26-zp-alloc-imag32-csr-rename-fix.md),
commit `2bfe4f3`), the plan completed end-to-end (`db6660a`):

1. Spike far-table read — **PASS** (`0xACDB`, first pass).
2. `dev/run.sh mandel-double` with the real font — **PASS**, `0x0EDF`, disasm shape unchanged.
3. Title capture — **PASS**: "MANDELBROT" in true shadowed 16×16 Waldo (`build/md-title-fixed.png`).
4. `dev/run.sh build` — **232 programs**, no link errors.
5. No-growth proof — **PASS**: pre/post hash diff shows exactly one demo ROM changed (`mandel-oop`,
   from the compiler fix itself — its gate green `0x204F`); every other demo ROM byte-identical and
   32768 B; `mandel-double` is the sole 64 KB ROM.
6. Republished — biohack.net `v1.0.255` (ROM `aae8b971…`, 65536 B; manifest selfcheck unchanged).

`TITLE_FONT16_OFF` deleted outright per the user's direction — there is no font-less path left.

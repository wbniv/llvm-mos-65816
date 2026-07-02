# cpu6502 — full-screen layout redesign (#102)

**Status:** ✅ **IMPLEMENTED + gate-green (2026-07-02).** Rewrote the display layer as a full-screen BG3
glyph tilemap (approach A). Gate CRC unchanged `0xAC8A`; `host==default==+mos-a16==+mos-xy16` on MAME +
bsnes-jg, `-verify` clean. Full 256×224 now in use: 12-line Waldo disassembly (left) with `#$`/`$`
operands, 8 schematic ALU gates (right, lit per instruction), register + status bars. Highlighted line
matches the lit gate; the ahead-window follows `JMP` so the loop body shows (not BRK filler). Corpus
symbol moved to WRAM `$0ADD` (bigger App). Re-publish to /snes/cpu6502/ pending.

**Mockup:** [`docs/plans/cpu6502-fullscreen-mockup.html`](cpu6502-fullscreen-mockup.html) — open in a
browser; 8 frames (one per ALU gate), 256×224 at 3×, real Waldo-16 + font8 + the corrected palette.

## Context

The shipped cpu6502 demo ([/snes/cpu6502/](https://biohack.net/snes/cpu6502/)) draws into the snesgfx
**128×128 `BitmapCanvas`**, which occupies only the centre **quarter** of the 256×224 SNES screen — the
surrounding ~75% is black margin. Inside that quarter it shows just **4 disassembly lines** (top 64 px)
over an 8-gate panel (bottom 64 px). There is no reason to leave the screen mostly empty: the same
information (and a *lot* more disassembly context) fits comfortably at full resolution.

**Goal:** use the whole 256×224 screen. Grow the disassembly window from **4 → 12 lines** (Waldo 16×16),
move the gate diagram + registers to a right rail, and add title/status bars — so the viewer sees the
running program in context, not a peephole.

This is a **display-layer rewrite only.** The simulator core (`examples/65816/cpu6502.h`) and the gate
CRC are unchanged → the differential gate stays green (`0xAC8A`); the change is purely visual.

## New layout (256×224 — see the HTML mockup)

```
┌──────────────────────────────────────────────────────────┐ 256×224
│ 6502/65C02 CPU SIM                            PC:000F     │  title bar (font8, y=0..13)
├────────────────────────────────────────────┬─────────────┤
│  0008  LDA  42                              │ ALU         │
│  000A  STA  FF                              │ )AND        │  right rail (x=184..255):
│  000C  LDX  08                              │ )OR         │   8 ALU gate icons, one
│ >000F  ADC  01   ← current (bright)         │ )XOR        │   lit for the executed
│  0011  AND  FF                              │ [ADD]* lit  │   instruction (schematic
│  0013  EOR  FF                              │ [SUB]       │   AND/OR/XOR silhouettes;
│  0015  ORA  FF                              │ [SHL]       │   ADD/SUB/SHL/SHR/CMP
│  0017  ASL                                  │ [SHR]       │   blocks)
│  0018  LSR                                  │ [CMP]       │
│  0019  CMP  FF                              │             │
│  001B  DEX                                  │ A:43        │  register readout
│  001C  BNE  000E                            │ X:08 Y:00   │
├────────────────────────────────────────────┴─────────────┤
│ ADC IM 01  A = A + M + C          P N.-...C               │  status bar (font8, y=211..223)
└──────────────────────────────────────────────────────────┘
```

- **Left rail (x=2..180):** 12-line disassembly window, Waldo 16×16 (built-in SE drop-shadow). Format
  per line: 4-hex address + 3-char mnemonic (both Waldo) + operand (font8, to fit). Current instruction
  bright (palette 3); context dim (palette 2); drop-shadow dark (palette 1) on every line. Window tracks
  the PC: 3 prior instructions, the current one, 8 ahead.
- **Right rail (x=184..255):** the 8 ALU gate symbols stacked in one column with labels; the gate for the
  just-executed instruction is lit (filled palette 3). Below the gates, the live register readout
  (A/X/Y, and SP/flags in the status bar).
- **Title bar:** demo name + `PC:$xxxx`. **Status bar:** the decoded current instruction + flag bits.

### Disassembly syntax — standard 6502 (`#$`/`$`), not the shipped "IM"/bare hex

The shipped demo renders immediates as `IM 42` and operands as bare hex (`FF`, `000E`) **only because
`font8.h` ships `#` (0x23) and `$` (0x24) as blank glyphs.** That reads wrong. The redesign uses proper
6502 assembler syntax:

| Mode | Render | Example |
|------|--------|---------|
| immediate | `#$nn` | `LDA #$42` |
| zero-page / abs operand (a value) | `$nn` / `$nnnn` | `AND $FF`, `STA $0400` |
| branch / jump target | `$nnnn` | `BNE $000E`, `JMP $0008` |
| address column (the instruction's location) | bare hex | `000F  ADC #$01` |

The address gutter stays bare (it's a location label, per convention — da65/monitor style); every
**operand value** carries `$`, immediates `#$`. **Requires adding `#` and `$` glyphs to `font8.h`**
(author them in `tools/gen-font8.py` and regenerate; the mockup embeds authored bitmaps for both). If the
address gutter should also carry `$`, a 16×16 `$` must be added to `font16.h`/`gen-font16.py` too — the
mockup keeps the gutter bare. This syntax fix applies to the shipped demo regardless of the full-screen
work; fold it into this rewrite.

## Implementation approach

The 128×128 `BitmapCanvas` is a fixed snesgfx structure (16×16 tiles, a 4 KB WRAM chr shadow). Two ways
to go full-screen:

**(A) Recommended — full-screen BG3 tilemap "text terminal" + a small gate bitmap.**
The disassembly, registers, title and status are all **text** → render them as a **32×28 BG3 tilemap of
glyph tiles** (the Waldo 16×16 glyphs are 2×2 tiles each; font8 glyphs are 1 tile). The glyph tiles are
uploaded to VRAM **once**; each step only rewrites the **tilemap entries** (which glyph sits in each
cell) — ~a few hundred 2-byte words, trivially within one v-blank, and it scrolls for free. The 8 gate
icons live in a small dedicated tile band (pre-authored "unlit"/"lit" tile pairs, or a compact
`BitmapCanvas` region in the right rail) whose few tiles swap per step.
- **Why:** avoids a full-screen pixel bitmap. A 256×224 2bpp bitmap shadow is 14 KB — over the low-WRAM
  budget ([[snes-demo-ram-budget]]) — whereas a tilemap is 32×28×2 = 1792 B and the glyph tiles are a
  one-time VRAM upload. DMA per step is tiny; no multi-frame streaming needed.
- **Cost:** a real rewrite of the display layer (new `snesgfx` "TextGrid" drawable, or extend
  `text_layer.h` from 2 HUD rows to a full-screen grid). The simulator core is untouched.

**(B) Alternative — enlarge the bitmap to full-screen.**
A 32×28-tile `BitmapCanvas` (896 tiles) with direct chr writes, like today but bigger. Simpler code
(reuse the current `pix`/`canvas_char*` renderers) but the 14 KB chr shadow must live in **high WRAM**
($7E2000+) accessed via far pointers, and a full redraw DMAs ~14 KB → ~4 v-blanks of streaming (fine at
~1.5 s/instruction, but heavier). Keep as fallback if the tilemap drawable proves fiddly.

Recommend **(A)**. Ship a reusable `snesgfx/text_grid.h` (full-screen glyph tilemap) — future text-heavy
demos (VM disassemblers, tracers) reuse it.

## Files

| File | Change |
|------|--------|
| `examples/snes/snesgfx/text_grid.h` | **New** — full-screen BG3 glyph tilemap (Waldo-16 + font8 cells), scroll/rewrite per step |
| `examples/snes/cpu6502.c` | Rewrite the display layer against the new layout; drop the 128×128 BitmapCanvas centring |
| `examples/65816/cpu6502.h` | **Unchanged** (simulator core + gate CRC) |
| `dev/cpu6502.sh` / `dev/cpu6502.lua` | Unchanged except possibly the screenshot frame |
| `docs/plans/cpu6502-fullscreen-mockup.html` | The layout mockup (this plan) |

## Verification

1. `dev/run.sh cpu6502` → **RESULT: PASS**, gate CRC still `0xAC8A` (display-only change;
   `host==default==+mos-a16==+mos-xy16` on MAME + bsnes-jg, `-verify` clean).
2. Visual: `build/cpu6502-jg.png` shows the **full 256×224** in use — 12-line Waldo disassembly on the
   left, lit gate + registers on the right, title/status bars, no black margins.
3. MAME render matches bsnes-jg pixel-for-pixel at the capture frame.
4. Re-publish to [/snes/cpu6502/](https://biohack.net/snes/cpu6502/) (`/snes-rom-page`; page path
   `src/pages/snes/cpu6502.astro`), refresh the preview PNG + the plan screenshot.

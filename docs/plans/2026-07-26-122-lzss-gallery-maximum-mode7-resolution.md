# #122 — LZSS Gallery: Maximum Mode 7 Artwork Resolution

**Status:** IMPLEMENTED (2026-07-26), superseding the 128-pixel-wide image-size decision in demo
#119. Its 31-color measurements are superseded by the full-color corpus in
[#125](2026-07-26-125-lzss-gallery-full-mode7-color.md).

## Problem

The first LZSS gallery build derives every artwork at 128 pixels wide and scales it 2×. That fills
the screen geometrically, but it does **not** use Mode 7's available image resolution. The
128×84–96 frames consume only 176–192 unique tiles out of the 256 tile indices.

The new rule is:

> Preserve the complete original artwork and its original aspect ratio first. Within that
> constraint, use the largest raster that fits Mode 7's tile-index space and the available
> scanlines—not a fixed 128-pixel source width and not a crop chosen to fill the screen.

The visible artwork is uniformly scaled to **fit** the complete rectangle above the caption.
Landscape works may leave small top/bottom margins; square and portrait works leave centered side
margins. Never stretch X and Y independently, and never crop merely to eliminate a margin.

## Fixed screen budget

The screen is 256×224. The lower Mode 1 region contains only:

- artist: one or two 16-pixel Waldo lines;
- work title: one or two 8-pixel font8 lines; and
- status/progress: one 8-pixel font8 line.

No padding line is reserved. Therefore the artwork gets:

| Caption shape | Caption/status | Artwork display rectangle |
|---|---:|---:|
| 1 artist + 1 title + status | 32 px | **256×192** |
| 1 artist + 2 titles + status | 40 px | **256×184** |
| 2 artists + 1 title + status | 48 px | **256×176** |
| 2 artists + 2 titles + status | 56 px | **256×168** |

The HDMA Mode 7→Mode 1 boundary is exactly the artwork display height in this table.

## Mode 7 capacity rule

Mode 7 has 256 8×8 character indices. Reserve tile 0 as a genuinely blank surround/padding tile;
the artwork may use at most **255 unique tiles**:

```text
ceil(source_width / 8) × ceil(source_height / 8) <= 255
```

Choose source dimensions jointly rather than fixing either axis first:

1. maximize used artwork pixels;
2. stay at or below 255 tiles, including partially occupied edge tiles;
3. match the pinned source artwork's width:height ratio as closely as integer pixels allow;
4. use one uniform Mode 7 scale for both axes;
5. center the fitted result within the 256×available-height artwork region; and
6. never crop, stretch, wrap, or overwrite the caption/status region.

This reserves one blank tile and still uses 234–252 artwork tiles, or 92–99% of the usable tile
indices.

## New per-work dimensions

These dimensions are derived from each pinned museum source's full-image aspect ratio. “Rendered”
is the uniformly scaled rectangle on the SNES; margins are centered within the available artwork
region.

| Work | Original ratio source | New Mode 7 source | Tiles | Rendered above caption | Centered margin |
|---|---:|---:|---:|---:|---:|
| Great Wave | 1280×885 | **151×104** | 19×13 = 247 | 256×176 | none |
| Bedroom | 1280×1013 | **142×112** | 18×14 = 252 | 223×176 | 16/17 px sides |
| Grande Jatte | 1280×1280 | **120×120** | 15×15 = 225 | 184×184 | 36 px sides |
| Two Sisters | 1280×1589 | **112×139** | 14×18 = 252 | 135×168 | 60/61 px sides |
| Water Lilies | 1280×1232 | **125×120** | 16×15 = 240 | 200×192 | 28 px sides |
| Basket of Apples | 1280×1020 | **141×112** | 18×14 = 252 | 242×192 | 7 px sides |
| Stack of Wheat | 1280×901 | **148×104** | 19×13 = 247 | 256×180 | 6 px top/bottom |
| Self-Portrait | 1280×1623 | **112×142** | 14×18 = 252 | 139×176 | 58/59 px sides |
| Paris Street | 1280×994 | **144×112** | 18×14 = 252 | 226×176 | 15 px sides |
| Poppy Field | 1280×833 | **152×99** | 19×13 = 247 | 256×167 | 12/13 px top/bottom |

These candidates total **154,840 raw bytes**, 32.6% larger than #119. The generator's capacity
solver is authoritative and must independently reproduce them from the source dimensions and
`ceil(w/8) × ceil(h/8) <= 255`; a disagreement is a build failure, not permission to crop.

Do not fall back to a blanket 2× matrix. Generate one uniform per-slide matrix scale plus centered
X/Y offsets from the source dimensions and available display rectangle.

## Implementation changes

### Asset generator

- Replace `height` plus global `W=128` with generated `source_width`, `source_height`,
  `display_width=256`, and `display_height`.
- Derive display height from artist/title row counts; fail if a manifest value disagrees.
- Assert artwork tiles are 1–255 and tile 0 remains reserved.
- Generate per-slide tile columns, tile rows, matrix X/Y, raw length, and maximum literal-stream
  length.
- Re-derive from each complete pinned source image; remove the aspect-filling center crops from
  #119 and do not upscale from the old indexed frames.
- Permit only source-defined non-image borders to be trimmed. Any such trim must be recorded and
  must not remove painted/printed artwork content.
- Emit old/new comparison crops and a contact sheet at actual SNES display size.
- Recompute compressed streams, checksums, corpus oracle, size report, and generated header.

### Runtime and VRAM

- Make tile upload stride use the descriptor's generated width, not hard-coded 128.
- Number artwork tiles from 1; keep tile 0 blank and clear the rest of the map to 0.
- Generate the identity map using each slide's tile columns/rows.
- Handle partial right/bottom tiles with palette index 0.
- Use one generated uniform Mode 7 scale and centered offsets so the complete artwork fits without
  leaking into the Mode 1 rows.
- Recenter spinout around the actual source midpoint.
- Preserve the HDMA `$2105`/`$212C` split and the Waldo/font8/status layout.

### WRAM and cartridge layout

The maximum raw frame grows from 12,288 to 15,808 bytes. Recalculate every high-WRAM region:

- decoded A;
- worst-case literal LZSS output (`raw + ceil(raw/8)`);
- decoded B;
- hash heads; and
- 4,096-entry predecessor ring.

Add linker/build assertions proving no overlap and no range crossing beyond `$7E:FFFF`. Do not
quietly lower a frame size to retain the old addresses.

Recompress all ten images before deciding whether the existing one-image-per-bank layout still
fits. Each bank must retain explicit free-space accounting. If any stream plus palette exceeds a
bank, change the generated bank allocation rather than reducing resolution.

## Benchmark consequences

This is a deliberately larger benchmark corpus: 154,840 raw bytes, 32.6% more work than #119.
Regenerate and publish:

- per-work raw/compressed sizes and reduction;
- literal/match counts;
- decompression, recompression, and verification frames;
- effective KiB/s;
- aggregate min/median/max across three complete measured runs;
- final cartridge size and bank-by-bank contents; and
- new corpus checksum/oracle.

The progress meter remains based on bytes/units of work, so it automatically reflects the larger
inputs. Never reuse #119's `0x29AF`, timing table, ROM checksum, SHA-256, or web self-check offsets.

## Measured implementation results

The capacity solver independently selected the planned full-image dimensions. No image is cropped;
all report crops are `[0, 0, source_width, source_height]`.

| Work | Source raster | Displayed fit | Tiles | Raw | LZSS | Reduction |
|---|---:|---:|---:|---:|---:|---:|
| Great Wave | 151×104 | 254×175 | 247 | 15,704 | 9,047 | 42.39% |
| Bedroom | 142×112 | 223×175 | 252 | 15,904 | 9,029 | 43.23% |
| Grande Jatte | 120×120 | 183×183 | 225 | 14,400 | 8,171 | 43.26% |
| Two Sisters | 112×139 | 135×167 | 252 | 15,568 | 10,436 | 32.97% |
| Water Lilies | 125×120 | 200×192 | 240 | 15,000 | 9,192 | 38.72% |
| Basket of Apples | 141×112 | 240×191 | 252 | 15,792 | 8,772 | 44.45% |
| Stack of Wheat | 148×104 | 256×179 | 247 | 15,392 | 8,944 | 41.89% |
| Self-Portrait | 112×142 | 138×175 | 252 | 15,904 | 11,551 | 27.37% |
| Paris Street | 144×112 | 226×175 | 252 | 16,128 | 9,024 | 44.05% |
| Poppy Field | 152×99 | 256×166 | 247 | 15,048 | 7,684 | 48.94% |
| **Corpus** |  |  |  | **154,840** | **91,850** | **40.68% weighted** |

The new full-corpus target oracle is **`0xDAED`**. First complete 70,000-frame bsnes-jg
measurement:

| Work | Unpack frames / KiB/s | Repack frames / KiB/s | Verify frames / KiB/s |
|---|---:|---:|---:|
| Great Wave | 310 / 2.97 | 4,706 / 0.20 | 400 / 2.30 |
| Bedroom | 315 / 2.96 | 4,833 / 0.19 | 404 / 2.31 |
| Grande Jatte | 286 / 2.96 | 4,141 / 0.20 | 368 / 2.30 |
| Two Sisters | 323 / 2.83 | 4,260 / 0.21 | 415 / 2.20 |
| Water Lilies | 304 / 2.90 | 4,604 / 0.19 | 390 / 2.26 |
| Basket of Apples | 310 / 2.99 | 4,964 / 0.19 | 398 / 2.33 |
| Stack of Wheat | 309 / 2.92 | 4,763 / 0.19 | 397 / 2.28 |
| Self-Portrait | 336 / 2.78 | 4,344 / 0.21 | 433 / 2.16 |
| Paris Street | 316 / 3.00 | 4,719 / 0.20 | 407 / 2.33 |
| Poppy Field | 292 / 3.02 | 5,416 / 0.16 | 374 / 2.36 |
| **Corpus** | **3,101 / 2.93** | **46,750 / 0.19** | **3,986 / 2.28** |

Total measured codec/check work is 53,837 frames, about 14m56s of SNES time at 60.0988 Hz.

The cartridge remains 512 KiB. Measured bank occupancy after the aspect-preserving relink:

| Bank | Used | Contents |
|---:|---:|---|
| `$00` | 23,397 | code/startup/navigation 16,941 + metadata/fonts/tables 6,376 + header/vectors 80 |
| `$01` | 9,111 | Great Wave stream + palette |
| `$02` | 9,093 | Bedroom stream + palette |
| `$03` | 8,235 | Grande Jatte stream + palette |
| `$04` | 10,500 | Two Sisters stream + palette |
| `$05` | 9,256 | Water Lilies stream + palette |
| `$06` | 8,836 | Basket of Apples stream + palette |
| `$07` | 9,008 | Stack of Wheat stream + palette |
| `$08` | 11,615 | Self-Portrait stream + palette |
| `$09` | 9,088 | Paris Street stream + palette |
| `$0A` | 7,748 | Poppy Field stream + palette |
| `$0B`–`$0F` | 0 | reserved |

High WRAM is now explicitly non-overlapping: decoded A at `$7E:2000`, 18,144-byte worst-case
recompression buffer at `$7E:6000`, decoded B at `$7E:A800`, hash heads at `$7E:E800`, and the
8,192-byte predecessor ring in bank `$7F:0000`.

## Visual gates

1. Produce emulator captures for all four caption shapes.
2. Pixel-check all four fitted artwork edges and the expected centered margins.
3. Assert the first Mode 1 scanline is exactly `display_height`.
4. Assert no Mode 7 pixel enters artist/title/status rows.
5. Assert tile 0 is blank and unused by artwork.
6. Assert no repeated tile-0 checkerboard surrounds the picture during rest or spinout.
7. Compare old/new captures at 1:1 output size; the new raster must show materially more source
   detail and more of the original composition, rather than merely different scaling.
8. Overlay each derived frame against the full source at matched scale and assert there is no
   composition crop or aspect-ratio distortion.
9. Run the full target recompress/golden/decode/checksum/byte-compare gate for all ten works.

## Publication

After the new ROM passes:

1. update the measured tables in this plan and #119's implementation record;
2. replace the ROM and preview on biohack.net and indri.studio;
3. update both manifests with the new self-check offset/oracle/frame budget;
4. rebuild and deploy both sites;
5. compare local and both live ROM SHA-256 values; and
6. retain the ten ArtIC/CC0 credits unchanged.

## Definition of done

- Every slide uses the maximum aspect-preserving raster selected by the capacity solver, not 128
  pixels by habit.
- Every artwork preserves its full original composition and aspect ratio.
- Artwork is uniformly scaled and centered in the available rectangle; margins are intentional.
- The raster uses no more than 255 artwork tiles and tile 0 is truly blank.
- Captions and work-based status remain readable and untouched in Mode 1.
- The larger ten-work LZSS corpus passes exact host/target stream and round-trip verification.
- Measured benchmark and bank tables replace all old figures.
- Both live sites serve the exact final verified cartridge.

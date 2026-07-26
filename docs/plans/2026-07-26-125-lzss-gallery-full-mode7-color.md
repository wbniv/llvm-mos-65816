# #125 — LZSS Gallery: Full Mode 7 Color

**Status:** IMPLEMENTED AND VERIFIED (2026-07-26); publication in progress. Corrective follow-up to
[#122](2026-07-26-122-lzss-gallery-maximum-mode7-resolution.md) and
[#124](2026-07-26-124-lzss-gallery-priority-navigation.md).

## Goal

Use Mode 7's 8bpp color capacity instead of limiting each artwork to 31 colors, while preserving
stable palettes for the Mode 1 Waldo captions, 8×8 title/status text, and OBJ navigation
chevrons.

The first maximum-resolution build exposed bright cyan pixels inside most artworks. This is not an
intentional margin or source color. The generator quantized 32 artwork colors, shifted every pixel
index by one to reserve index 0, and therefore emitted indices 1–32 while uploading only CGRAM
entries 0–31. Pixels with index 32 read unrelated stale CGRAM data.

Changing the quantizer to 31 colors prevents the invalid index, but it is only an emergency
diagnostic fix. Mode 7 supports 256 indexed colors; the final fix should use nearly all entries not
owned by captions or sprites.

## CGRAM ownership

Allocate all 256 CGRAM entries explicitly:

| Indices | Count | Owner |
|---:|---:|---|
| 0 | 1 | transparent/black artwork surround and padded tile pixels |
| 1–27 | 27 | artwork |
| 28–31 | 4 | Mode 1 BG3 palette 7: 8×8 work title, progress, and status |
| 32–111 | 80 | artwork |
| 112–127 | 16 | Mode 1 BG2 palette 7: 16×16 Waldo artist text |
| 128–143 | 16 | OBJ palette 0: left/right chevrons |
| 144–255 | 112 | artwork |

This gives every work **219 artwork colors**, plus the reserved black surround.

Keep the conservative whole-palette reservations even though the fonts and chevrons currently use
only a few nonzero pens. It makes CGRAM ownership obvious and prevents a later font glyph or sprite
change from silently borrowing an artwork color.

Generated constants must describe these ranges. Do not scatter numeric palette boundaries between
the asset generator and SNES runtime.

## Sparse artwork-index generation

Quantize each resized full-composition source image to at most 219 colors. Convert the quantizer's
dense indices through this ordered allowed-index table:

```text
1..27, 32..111, 144..255
```

Requirements:

- no artwork pixel may use 0 or any caption/OBJ-reserved entry;
- right/bottom partial-tile padding and the out-of-image surround must use index 0;
- generate a complete 256-entry, 512-byte BGR555 palette for each work;
- reserved entries in the generated palette must be deterministic zeros because the runtime
  replaces them with UI colors;
- assert every pixel index is in the allowed artwork set;
- assert every used artwork index has a generated palette value;
- assert index 0 is BGR555 black; and
- record color count, used-index range/set, and palette SHA-256 in `report.json`.

The quantizer, sparse remapping, BGR555 conversion, and all assertions run in the existing project
container. Install nothing on the host.

## Runtime palette upload

For every newly selected work, while force-blanked:

1. upload all 512 bytes of its generated CGRAM palette;
2. explicitly restore BG3 palette 7 at indices 28–31;
3. explicitly restore BG2 palette 7 at indices 112–127;
4. explicitly restore OBJ palette 0 at indices 128–143; and
5. show the work only after palette, Mode 7 characters, tilemap, captions, and OAM are complete.

Set the 8×8 title/status tilemap to BG3 palette 7. Retain BG2 palette 7 for Waldo. Retain OBJ palette
0 for the chevrons.

Use a 16-bit loop counter or two 256-byte DMA operations for the 512-byte upload; an 8-bit counter
must not wrap and skip half the palette. UI palette restoration must happen on every slide, not
only at boot, because the full artwork upload covers those CGRAM addresses.

Navigation cancellation during a force-blanked palette upload must leave the screen blank and
restart the requested slide cleanly. Never reveal a half-old/half-new CGRAM state.

## Codec and cartridge consequences

The indexed raster dimensions and raw byte counts do not change, but higher color entropy will
change:

- every raw-frame checksum;
- every compressed stream and compressed size;
- literal/match statistics;
- recompression and verification timings;
- the final corpus oracle;
- ROM checksum and SHA-256; and
- bank occupancy, because each per-work palette grows from 64 to 512 bytes.

Rebuild the host golden streams and generated header. Verify that the largest stream plus its
512-byte palette still fits its assigned 32 KiB LoROM bank. Keep the recompression buffer sized for
worst-case LZSS expansion, not merely the largest observed compressed stream.

Update the #122 measured table with the final 219-color sizes and timings rather than leaving the
temporary 31-color numbers as current results.

## Visual verification

Generate two deterministic references:

- a contact sheet rendered directly from the sparse indexed pixels and generated palettes; and
- native 256×224 emulator captures after SNES BGR555 conversion.

For all ten works:

1. assert the derived frame contains no forbidden palette index;
2. compare every derived RGB pixel with a decode through the emitted BGR555 palette;
3. inspect for cyan/magenta/green speckles, red bias, missing colors, banding, or stale palette
   regions;
4. inspect black margins and partial tiles separately from pixels inside the artwork;
5. verify the full original composition and aspect ratio remain unchanged;
6. verify Waldo artist text, 8×8 title/status text, and gold chevrons retain their intended colors;
7. navigate Left and Right between works with very different palettes and check that no colors
   leak from the previous work; and
8. capture landscape, square, and portrait examples at rest.

Add a machine gate that fails if the emulator capture contains the known invalid-index cyan value
at pixels whose source artwork index was formerly 32. Visual inspection remains required because
the legitimate source art may contain cyan-like colors elsewhere.

## Benchmark and navigation verification

- Host `-O0` and `-O2` compressors must emit identical streams.
- Each host stream must round-trip to its 219-color indexed frame.
- The SNES must decode, display, recompress, compare the exact golden stream, decode again,
  checksum, and byte-compare every work.
- The canonical ten-work oracle must pass after uninterrupted sequential playback and after
  out-of-order Left/Right browsing.
- Left/Right cancellation must work during palette/tile upload without recording a timing or
  failure for the canceled work.
- Re-run and publish all unpack, repack, and verification frame measurements after the palette
  change.

## Documentation and publication

After the final ROM passes:

1. mark this plan implemented with per-work color counts, raw/LZSS sizes, reductions, checksums,
   timings, and bank occupancy;
2. update #119 and #122 so the obsolete 32/31-color design is clearly superseded;
3. update both web galleries to describe full-color Mode 7 artwork and Left/Right navigation;
4. replace the ROM, preview/contact sheet, manifest offset, oracle, and frame budget on
   biohack.net and indri.studio;
5. build both sites in their existing containers;
6. commit and push all three repositories through their normal release workflows; and
7. compare the local ROM SHA-256 with both repository copies and both live downloads.

## Measured implementation

The sparse layout uses all 219 available artwork indices in every derived image. Index 0 and all
three UI palette ranges are absent from the artwork pixels. The indexed preview contact sheet and
native bsnes-jg Bedroom capture show no invalid-index cyan holes.

| Work | Colors | Raw | LZSS | Reduction | Indexed checksum |
|---|---:|---:|---:|---:|---:|
| Great Wave | 219 | 15,704 | 15,259 | 2.83% | `0x427F` |
| Bedroom | 219 | 15,904 | 15,836 | 0.43% | `0x8EE4` |
| Grande Jatte | 219 | 14,400 | 14,846 | −3.10% | `0x360D` |
| Two Sisters | 219 | 15,568 | 16,055 | −3.13% | `0x8046` |
| Water Lilies | 219 | 15,000 | 14,958 | 0.28% | `0xB55A` |
| Basket of Apples | 219 | 15,792 | 15,200 | 3.75% | `0x318B` |
| Stack of Wheat | 219 | 15,392 | 15,699 | −1.99% | `0xAED8` |
| Self-Portrait | 219 | 15,904 | 16,922 | −6.40% | `0x7A9B` |
| Paris Street | 219 | 16,128 | 15,171 | 5.93% | `0x5E5C` |
| Poppy Field | 219 | 15,048 | 14,815 | 1.55% | `0x1B97` |
| **Corpus** |  | **154,840** | **154,761** | **0.05% weighted** | |

The near-zero aggregate reduction is intentional benchmark evidence: a 219-color dithered corpus
has much higher entropy than the former 31-color corpus. LZSS expansion on four individual works
is valid and retained rather than hiding difficult inputs. The new canonical oracle is
**`0xBFAB`**.

The uninterrupted 75,000-frame bsnes-jg run passed `corpus_result == 0xBFAB`. Measured stage
times:

| Work | Unpack frames | Repack frames | Verify frames |
|---|---:|---:|---:|
| Great Wave | 346 | 6,195 | 465 |
| Bedroom | 353 | 6,238 | 475 |
| Grande Jatte | 322 | 5,713 | 434 |
| Two Sisters | 347 | 6,324 | 467 |
| Water Lilies | 334 | 5,740 | 449 |
| Basket of Apples | 350 | 5,883 | 469 |
| Stack of Wheat | 344 | 6,212 | 464 |
| Self-Portrait | 355 | 6,736 | 481 |
| Paris Street | 355 | 6,032 | 476 |
| Poppy Field | 335 | 5,746 | 449 |
| **Corpus** | **3,441** | **60,819** | **4,629** |

Total measured codec/check work is 68,889 frames. The final cartridge remains 512 KiB:

| Bank | Used | Contents |
|---:|---:|---|
| `$00` | 23,498 | code/startup/navigation 17,042 + metadata/fonts/tables 6,376 + header/vectors 80 |
| `$01` | 15,771 | Great Wave stream 15,259 + palette 512 |
| `$02` | 16,348 | Bedroom stream 15,836 + palette 512 |
| `$03` | 15,358 | Grande Jatte stream 14,846 + palette 512 |
| `$04` | 16,567 | Two Sisters stream 16,055 + palette 512 |
| `$05` | 15,470 | Water Lilies stream 14,958 + palette 512 |
| `$06` | 15,712 | Basket of Apples stream 15,200 + palette 512 |
| `$07` | 16,211 | Stack of Wheat stream 15,699 + palette 512 |
| `$08` | 17,434 | Self-Portrait stream 16,922 + palette 512 |
| `$09` | 15,683 | Paris Street stream 15,171 + palette 512 |
| `$0A` | 15,327 | Poppy Field stream 14,815 + palette 512 |
| `$0B`–`$0F` | 0 | reserved |

Final local ROM header checksum is `0xE19A`; SHA-256 is
`340e48d1f3c62c0dc8288c6c613530044dda644b4a2b12473257436264e2ac74`.

## Definition of done

- No artwork pixel can reference an absent or UI-owned palette entry.
- Each work may use up to 219 artwork colors, not 31 colors.
- Index 0 remains a deterministic black surround/padding color.
- Fonts and sprite chevrons retain fixed, readable colors across every artwork.
- No bright-cyan invalid-index artifacts remain inside any image.
- Exact host/SNES LZSS round trips and the full corpus oracle pass.
- Final size, compression, timing, checksum, and bank reports describe the 219-color build.
- biohack.net and indri.studio serve the exact verified final ROM and current metadata.

# #126 — Add Nine Public-Domain Masters to the Mode 7 LZSS Gallery

**Status:** IMPLEMENTED AND PUBLISHED (2026-07-26). Extends the ten-work gallery from
[#119](2026-07-26-119-snes-lzss-gallery-carousel.md), using the 219-color CGRAM
layout from [#125](2026-07-26-125-lzss-gallery-full-mode7-color.md).

Mockups: [nine-work contact sheet and 19-work player](2026-07-26-126-lzss-gallery-nine-public-domain-masters/gallery-expansion-mockups.html)

## Goal

Add nine visually distinct, royalty-free masterworks to the existing Mode 7
LZSS gallery without replacing its current ten works. The finished cartridge
contains **19 works**, each rendered from the complete uncropped composition at
the largest aspect-preserving Mode 7 raster that fits 256 tiles and quantized
to at most **219 artwork colors**.

Publish the exact same verified ROM, poster/contact sheet, work order,
attribution, and metadata on biohack.net and indri.studio.

## Agreed additions and order

Append these works after the existing ten in this order:

| # | Slug | Artist | Work | Preferred source |
|---:|---|---|---|---|
| 11 | `earthly-delights` | Hieronymus Bosch | *The Garden of Earthly Delights* | Museo Nacional del Prado |
| 12 | `the-scream` | Edvard Munch | *The Scream* | National Museum of Norway |
| 13 | `third-of-may` | Francisco de Goya | *The Third of May 1808* | Museo Nacional del Prado |
| 14 | `the-kiss` | Gustav Klimt | *The Kiss (Lovers)* | Belvedere, Vienna |
| 15 | `view-of-delft` | Johannes Vermeer | *View of Delft* | Mauritshuis |
| 16 | `wijk-windmill` | Jacob van Ruisdael | *The Windmill at Wijk bij Duurstede* | Rijksmuseum |
| 17 | `flower-still-life` | Ambrosius Bosschaert the Elder | *Flower Still Life* | Rijksmuseum |
| 18 | `tableau-vii` | Piet Mondriaan | *Tableau No. VII* | public-domain museum/Commons scan |
| 19 | `ice-skaters` | Hendrick Avercamp | *Winter Landscape with Ice Skaters* | Rijksmuseum |

Use the Rijksmuseum’s public-domain c. 1608 Avercamp image, object
`SK-A-1718`, not a similarly titled canal scene or a cropped detail. The
full-resolution reference is 6278×3626:

- [Rijksmuseum object record](https://www.rijksmuseum.nl/en/collection/object/Winter%2BLandscape%2Bwith%2BIce%2BSkaters--918895dc18da94e357c6763adda8882f)
- [public-domain full-resolution file](https://commons.wikimedia.org/wiki/File:Hendrick_Avercamp_-_Winterlandschap_met_ijsvermaak.jpg)

Picasso, Dalí, and Joan Miró are deliberately excluded: the desired works are
not clean worldwide public-domain additions. Do not silently substitute a
portrait. The Dutch group is landscapes/still life only.

## Rights and source provenance

Before downloading an image, record one canonical object page and one original
image URL. Accept only a source whose object record explicitly labels the work
and digital image public domain, CC0, or an equivalently unrestricted public
domain mark. Artist death date alone is not enough to establish the scan’s
reuse status.

Extend `assets/snes/lzss-gallery/sources.json` so licensing is per work rather
than incorrectly implying that every source comes from the Art Institute of
Chicago:

```json
{
  "slug": "ice-skaters",
  "title": "Winter Landscape with Ice Skaters",
  "artist": "Hendrick Avercamp",
  "provider": "Rijksmuseum",
  "object_url": "...",
  "image_url": "...",
  "license": "Public Domain",
  "license_url": "https://creativecommons.org/publicdomain/mark/1.0/",
  "accessed": "2026-07-26"
}
```

Keep the original source files immutable. Store a SHA-256, pixel dimensions,
MIME type, and attribution string for each download. The asset build must fail
if a download is HTML, unexpectedly tiny, missing its recorded hash, or cannot
be decoded in the project container.

Where several versions exist, choose the named museum’s straight, full-frame
reproduction. Do not use colorized, AI-upscaled, framed, watermarked, poster,
detail, or perspective-corrected third-party derivatives. For *The Scream*,
pin the exact version selected in metadata rather than treating the title as a
unique image.

## Composition and 219-color conversion

Use the #122 maximum-resolution solver independently for each source:

1. remove only reproduction borders outside the painted object when the museum
   scan includes them;
2. never crop painted content to fill the SNES screen;
3. preserve source aspect ratio;
4. find the largest integer raster whose ceil-divided 8×8 tile grid contains
   no more than 256 tiles;
5. resize with the existing deterministic high-quality filter;
6. quantize to at most 219 artwork colors;
7. remap into #125’s allowed CGRAM indices `1..27, 32..111, 144..255`;
8. use index 0 only for tile padding and the black surround; and
9. emit the indexed raster, 512-byte BGR555 palette, LZSS stream, report entry,
   and rendered reference.

The new corpus intentionally exercises different failure modes:

- Bosch and Avercamp contain many tiny figures and high-frequency detail;
- Munch and Goya contain dark gradients and strong local contrast;
- Klimt tests gold/yellow texture;
- Vermeer and Ruisdael test subtle sky and water gradients;
- Bosschaert tests saturated small features against a dark ground; and
- Mondriaan tests hard edges, flat fields, and unusually high compression.

Do not reduce these additions to 31 colors. Reports and gallery copy must say
“up to 219 artwork colors.”

## Nineteen-work cartridge scaling

The current ten-work runtime uses 16-bit completion and failure masks. Nineteen
assets cannot be represented by `1u << i` on the 16-bit SNES target. Replace
the masks with bounded per-work state arrays plus explicit counters:

```c
static uint8_t gallery_done[GALLERY_ASSET_COUNT];
static uint8_t gallery_failed[GALLERY_ASSET_COUNT];
static uint8_t gallery_completed_count;
```

The canonical corpus oracle must still fold every work exactly once in fixed
manifest order, independent of browse order. Re-visiting an already completed
work must not increment the count or change its recorded timing/oracle result.
Canceled work remains incomplete.

Extend generated asset tables, bank-section names, and the linker map from ten
through nineteen works. Keep one work’s compressed stream and 512-byte palette
together in a known LoROM bank when possible. Add generated assertions for:

- every section exists and maps to the intended ROM bank;
- no stream or palette crosses an illegal bank boundary;
- all far pointers have the expected bank;
- the ROM size/header match the expanded image;
- the largest recompression result fits the WRAM buffer; and
- `GALLERY_ASSET_COUNT == 19`.

If nineteen dedicated banks do not fit the present cartridge layout, increase
the smallest valid LoROM size and update its header rather than packing data
across banks ad hoc. Record occupied/free bytes per gallery bank in
`report.json` and the linker map.

Navigation remains circular:

```text
Left from work 1  -> work 19
Right from work 19 -> work 1
```

Waldo captions and the small title/status layer must accept all new artist and
work names without overflow. Prefer two intentional lines over abbreviation;
use `MONDRIAAN` in the displayed artist name. Show position as `11/19` through
`19/19` and keep progress/timing text clear of the chevrons.

### Display-layer contract

The current gallery intentionally uses a scanline split:

- across the artwork band, HDMA selects Mode 7 and enables Mode 7 BG1 plus OBJ;
- across the caption band, HDMA selects Mode 1 and enables BG2, BG3, plus OBJ.

Thus the artwork band has one Mode 7 background layer and sprite chevrons. The
caption/status backgrounds are real BG layers, but only after the raster
switches to Mode 1 near the bottom of the frame; they are not additional
independent Mode 7 planes.

The SNES can expose Mode 7 EXTBG as a second-priority view of the same Mode 7
pixel/tile data, but it is not an independent second tile layer and this gallery
does not enable it. Keep that design unchanged for this expansion. Verify the
HDMA split position against the tallest/widest new compositions so caption BGs
never cover painted content unexpectedly.

## Visual mockup contract

The linked mockup defines two acceptance views:

1. a 3×3 addition sheet that makes the exact selected works and order
   unmistakable; and
2. the on-cartridge experience at work 19, with preserved landscape aspect
   ratio, black surround, two-line caption, `19/19`, and left/right controls.

The mockup uses stylized stand-ins, not source reproductions. Generated
references during implementation must use the licensed scans and actual
BGR555 output.

## Verification

### Asset and codec gates

- Validate every source hash and rights record.
- Assert every derived raster uses only index 0 or the 219 allowed indices.
- Assert index 0 appears only outside the artwork or in partial-tile padding.
- Round-trip every one of the 19 streams with host `-O0` and `-O2` compressors.
- Assert both compressors emit identical bytes.
- Decode emitted indices through the emitted BGR555 palette and compare with
  the deterministic reference.
- Regenerate the contact sheet and report from scratch in the container.

### SNES gates

- Decode, upload, display, recompress, byte-compare, and checksum all 19 works.
- Run the uninterrupted canonical 19-work oracle.
- Re-run after adversarial Left/Right navigation, wraparound, cancellation,
  and repeated visits.
- Capture work 11, work 18, and work 19 at native 256×224.
- Inspect all additions for crop, aspect distortion, forbidden-color speckles,
  banding, stale palettes, caption overlap, and incorrect black padding.
- Verify the detailed Bosch and Avercamp images remain readable enough at rest
  to justify their chosen raster dimensions.

### Website parity

- Copy the exact verified ROM and generated poster/contact sheet to both sites.
- Update both descriptions to say 19 works and up to 219 artwork colors.
- Add all nine titles/artists and the source/license attribution to both pages.
- Keep the Mode 7 badge/filter behavior unchanged.
- Build both sites in their existing containers.
- Compare SHA-256 for the source ROM, both repository copies, and both live
  downloads.
- Compare the ordered 19-work metadata rendered by biohack.net and indri.studio.

## Publication and documentation

After the ROM passes:

1. update #119, #122, and #125 with the final 19-work measurements;
2. record source and derived hashes, dimensions, colors used, raw/LZSS sizes,
   reduction, timings, checksums, and bank occupancy for every addition;
3. replace both sites’ ROM, poster/contact sheet, cache-busting metadata, and
   manifest offsets;
4. commit and push the source and both website repositories through their
   normal release workflows; and
5. verify both production deployments in the browser.

## Definition of done

- The original ten works remain and the agreed nine are appended in the stated
  order.
- The cartridge and both websites expose the same 19 works.
- Every new scan has explicit reusable public-domain provenance and a pinned
  source hash.
- Every complete composition preserves aspect ratio and may use up to 219
  artwork colors.
- Nineteen-work completion, failure, timing, cancellation, wraparound, and
  oracle logic work without a 16-bit mask.
- All 19 host/SNES LZSS round trips and visual gates pass.
- Captions, position, chevrons, Mode 7 badge/filter, and fixed UI colors remain
  correct.
- Both live ROM hashes equal the locally verified ROM hash.

## Implementation record

**Verification: PASS.**

Implemented as a 1 MiB LoROM with nineteen dedicated artwork banks. The final
corpus is 295,880 indexed bytes and 288,631 LZSS bytes (2.45% reduction), with
oracle `0x9497` and ROM SHA-256
`8b551b9228a2ea3457fdb324a33f91a3ccbe3ea73151b782c06c8f90459388ab`.
All nineteen host `-O0`/`-O2` streams match exactly, and bsnes-jg reached the
oracle after 150,000 frames.

The nine additions occupy banks `$0B`–`$13`; the largest new section is
`$424B` bytes, safely below the `$8000`-byte LoROM bank boundary. Native
captures were inspected for Bosch, Mondriaan, and Avercamp. The Avercamp
capture is the new gallery poster.

The web player now treats touch input on the left/right half of the canvas as
a momentary SNES Left/Right press, including in fullscreen. Both sites expose
the nineteen-work attribution table and generated contact sheet.

Publication:

- biohack.net commit `40d4590`, tag `v1.0.271`;
- indri.studio commit `118988d`, tag `v0.1.97`.

Both deployment workflows passed. The two live ROM downloads match the local
SHA-256 above, and both live cache-busted player scripts contain the touch
navigation handler.

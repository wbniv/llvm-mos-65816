# #119 — SNES LZSS Mode 7 Gallery Carousel

> **Resolution update:** the original 128×84–96 cropped corpus documented below has been superseded
> by [#122](2026-07-26-122-lzss-gallery-maximum-mode7-resolution.md). The implemented gallery now
> preserves each complete artwork and its original aspect ratio, using 225–252 artwork tiles per
> slide. Keep #119's old measurements as the baseline, not as current cartridge figures.

**Status:** IMPLEMENTED / PUBLISHED (2026-07-26). Demo **#119**, following the drafted Round 6 battery through
#118. The ten-work cartridge, host oracle, on-SNES codec, HDMA display split, captions, work meter,
per-stage frame counters, reproducible gate script, and both website gallery integrations are
implemented. Both production site builds and deployments pass, and both live sites serve the exact
verified cartridge.
This is a new showcase/stress demo, not a replacement for #49 `lzdec`.

## Goal

Build a self-running SNES gallery that:

1. carries ten legally reusable, provenance-pinned images in the ROM;
2. decompresses each image with an LZSS decoder;
3. recompresses the decoded image **on the SNES**, then decompresses it again and verifies the
   round trip;
4. presents the images as a Mode 7 carousel with Mode 7 rotation/zoom transitions; and
5. publishes the ROM and matching gallery entry to both `biohack.net` and `indri.studio`.

The **ultimate purpose is an on-hardware LZSS compression/decompression benchmark**. The art gallery
is its attractive, legible workload and presentation shell. Each work is a separate realistic corpus
member with different entropy and match structure; the carousel makes the benchmark results visible
instead of hiding them in a serial log.

The primary compiler stress is the **complete LZSS codec**, especially the target-side compressor:
hash-chain match search, sliding-window indices, flag-byte packing, overlapping back-references,
far-WRAM buffers, and deterministic tie-breaking. The gallery is the visible proof that the codec
continues to produce usable data while it runs.

## Relationship to demo #49

`lzdec` (#49) remains intact as the small, portable, five-way decoder regression. It decodes one
56-byte synthetic stream and deliberately exercises copies from the decoder's own output.

`lzss-gallery` adds the missing half:

- a real compressor running on the 65816;
- ten photographic/painted inputs rather than one synthetic cell image;
- kilobyte-scale far-WRAM buffers;
- deterministic target output compared with host-generated golden streams;
- repeated decode → compress → decode round trips; and
- a true Mode 7 presentation.

Reuse the existing #49 token format unless measurement finds a correctness defect. Do not invent an
incompatible second format merely to rename it LZSS.

## Licensed image set

Use the following ten works from the Art Institute of Chicago. Every linked object page explicitly
marks the image **CC0 Public Domain Designation** and exposes an IIIF manifest. CC0 is stronger and
clearer than the ambiguous marketing term “royalty-free”: there is no royalty or attribution
condition, though the demo and websites will still credit the artist and museum.

| # | Work | Artist | ArtIC object / IIIF manifest |
|---:|---|---|---|
| 1 | Under the Wave off Kanagawa (“The Great Wave”) | Katsushika Hokusai | [object 24645](https://www.artic.edu/artworks/24645/under-the-wave-off-kanagawa-kanagawa-oki-nami-ura-also-known-as-the-great-wave-from-the-series-thirty-six-views-of-mount-fuji-fugaku-sanjurokkei) · [manifest](https://api.artic.edu/api/v1/artworks/24645/manifest.json) |
| 2 | The Bedroom | Vincent van Gogh | [object 28560](https://www.artic.edu/artworks/28560/the-bedroom) · [manifest](https://api.artic.edu/api/v1/artworks/28560/manifest.json) |
| 3 | A Sunday on La Grande Jatte — 1884 | Georges Seurat | [object 27992](https://www.artic.edu/artworks/27992/a-sunday-on-la-grande-jatte-1884) · [manifest](https://api.artic.edu/api/v1/artworks/27992/manifest.json) |
| 4 | Two Sisters (On the Terrace) | Pierre-Auguste Renoir | [object 14655](https://www.artic.edu/artworks/14655/two-sisters-on-the-terrace) · [manifest](https://api.artic.edu/api/v1/artworks/14655/manifest.json) |
| 5 | Water Lilies | Claude Monet | [object 16568](https://www.artic.edu/artworks/16568/water-lilies) · [manifest](https://api.artic.edu/api/v1/artworks/16568/manifest.json) |
| 6 | The Basket of Apples | Paul Cézanne | [object 111436](https://www.artic.edu/artworks/111436/the-basket-of-apples) · [manifest](https://api.artic.edu/api/v1/artworks/111436/manifest.json) |
| 7 | Stack of Wheat | Claude Monet | [object 111318](https://www.artic.edu/artworks/111318/stack-of-wheat) · [manifest](https://api.artic.edu/api/v1/artworks/111318/manifest.json) |
| 8 | Self-Portrait | Vincent van Gogh | [object 80607](https://www.artic.edu/artworks/80607/self-portrait) · [manifest](https://api.artic.edu/api/v1/artworks/80607/manifest.json) |
| 9 | Paris Street; Rainy Day | Gustave Caillebotte | [object 20684](https://www.artic.edu/artworks/20684/paris-street-rainy-day) · [manifest](https://api.artic.edu/api/v1/artworks/20684/manifest.json) |
| 10 | Poppy Field (Giverny) | Claude Monet | [object 4783](https://www.artic.edu/artworks/4783/poppy-field-giverny) · [manifest](https://api.artic.edu/api/v1/artworks/4783/manifest.json) |

Record this exact selection in `assets/snes/lzss-gallery/sources.json`. Each row must contain the
ArtIC artwork ID, title, artist, date, object URL, IIIF manifest URL, resolved IIIF image URL,
`license: "CC0-1.0"`, the CC0 URL, acquisition date, source SHA-256, and the checked-in crop/focal
rectangle. A refresh must fail if the current object record no longer says it is public domain.

Do not fetch images during a normal ROM or website build. Asset refresh is an explicit, networked
developer operation; the deterministic derived assets needed by ordinary builds are committed.

## Image preparation and ROM budget

> **Superseded color decision:** #119's 32-color limit is replaced by the 219-artwork-color sparse
> CGRAM allocation in [#125](2026-07-26-125-lzss-gallery-full-mode7-color.md).

Mode 7 uses an 8bpp character plane even when only a small palette is populated. Use the largest
image rectangle the 256×224 display permits after reserving only the artist/title lines actually
needed by that slide. Derive each work as:

- a hand-reviewed center/focal crop;
- **128 pixels wide and 84–96 pixels high**, displayed at 2× by the Mode 7 matrix to occupy the
  full 256-pixel screen width and 168–192 display pixels vertically;
- per-slide source height selected from 84, 88, 92, or 96 pixels according to its artist/title rows
  plus one dedicated eight-pixel progress/status row;
- at most **32 indexed colors per image**, with palette index 0 reserved for the surround;
- deterministic median-cut (or an equally pinned deterministic quantizer);
- optional deterministic ordered dithering, selected per image in the manifest; and
- SNES BGR555 palette values produced by one checked-in conversion routine.

The largest raw frame is 12,288 bytes; the ten-image corpus will be roughly 108–120 KiB before
compression depending on the reviewed caption heights. Each palette is 64 bytes, so all palettes
total 640 bytes. This deliberately requires a real banked-asset design and gives the compressor a
substantially more meaningful corpus than a thumbnail gallery.

The Mode 7 character plane stores `16 × ceil(source_height/8)` unique 8×8 tiles: 176 tiles at
128×84 through 192 tiles at 128×96, below Mode 7's 256-tile limit. Pad only the unused rows of the
last tile row with palette index 0; those padding pixels remain outside the visible image rectangle.

The asset tool must emit a report containing, for every image:

- source and derived SHA-256;
- crop coordinates and quantizer settings;
- number of colors used;
- raw size, compressed size, literal count, match count, longest match, and ratio;
- host decode round-trip result; and
- a contact sheet for visual review.

Do not silently reduce resolution, color count, or replace an image to make the link fit. If the
measured streams do not fit, add ROM asset banks and a bank-aware stream reader. Keep a build-time
size assertion for every bank and for the whole ROM.

## LZSS wire format

Retain the proven #49 stream shape:

```
flag byte: 8 tokens, least-significant bit first
  flag bit 0: one literal byte follows
  flag bit 1: two-byte match follows

match:
  12-bit backward distance, valid range 1..4095
  4-bit length field, decoded length = field + 3 (3..18)
```

Specify byte order and nibble placement once in the shared codec header and assert it in host tests.
The decoder must preserve the defining LZSS behavior: match bytes are copied one at a time from
already-decoded output, so source and destination may overlap.

The target compressor uses a deterministic bounded hash-chain matcher:

- three-byte rolling hash;
- one head per hash bucket and a 4,096-entry predecessor ring;
- at most 64 candidates examined for each input position;
- maximum distance 4,095 and maximum match 18;
- emit a match only at length 3 or greater;
- choose the longest match, then the smallest backward distance;
- reserve/backpatch one flag byte for each group of eight tokens; and
- return an explicit status on output exhaustion or invalid parameters.

The bounded chain makes execution time predictable on a 3.58 MHz CPU while leaving substantial
16-bit indexing, comparison, pointer, and bit-packing pressure. The host encoder must implement the
same policy and produce byte-identical output.

## Runtime codec pipeline

Reserve non-overlapping high-WRAM regions sized for the 12,288-byte maximum frame (the 12,800-byte
allocation retains guard/headroom), finalized only
after inspecting the linker map:

```
$7E:2000  decoded_a[12800]       canonical stream decode / compressor input
$7E:5200  recompressed[14400]    literals + one flag/8 bytes, rounded up
$7E:8B00  decoded_b[12800]       second decode / verification
$7E:BD00  hash_head[...]         compressor match index
$7E:C000  hash_prev[4096]        predecessor chain (16-bit entries)
```

Use named linker/platform symbols rather than unexplained address literals in the codec. Assert that
the maximum literal-only stream (`12800 + ceil(12800/8)`, plus any terminator/header) fits the
14,400-byte output buffer, and assert that every high-WRAM range ends before `$7F:0000`.

For each slide, in this visible order:

1. Decode the ROM's canonical compressed stream into `decoded_a`.
2. Verify its length and checksum against the original derived-image checksum stored in metadata.
3. Upload `decoded_a` to the Mode 7 character plane and **display the image first**.
4. While that displayed image remains on screen, run the **LZSS compressor on the SNES** over the
   same `decoded_a` framebuffer; show `CHECKING` in the font8 status field.
5. Require the emitted bytes to equal the deterministic host golden stream byte-for-byte.
6. Decode the SNES-produced `recompressed` stream into `decoded_b`.
7. Checksum `decoded_b` and require it to equal both the checksum of `decoded_a` and the stored
   checksum of the original derived image. Also require `decoded_a == decoded_b` byte-for-byte so a
   checksum collision cannot hide corruption.
8. Change the visible state to `VERIFIED` (or a sticky red `FAILED`) and fold lengths, token
   statistics, all three checksums, and mismatch/status bits into the demo gate.

The host encoder creates the ROM stream and oracle, but it does not satisfy this requirement: every
gallery image must be recompressed and checked by code executing on the 65816 after the image becomes
visible.

Run compression incrementally with a state struct and a per-frame work budget. The carousel must keep
animating/responding while the compressor searches; it must not sit frozen for several seconds.
Expose `init`, `step(work_budget)`, and `finish` around the same codec core used by the one-shot host
test. An optional font8 status field changes from `PACK` to the measured ratio when a slide completes.

On any codec mismatch, set a sticky failure result, color the surround red, and keep the failing slide
number/status on screen. Never continue with unverified bytes as though the demo passed.

## Mode 7 carousel

This is a true Mode 7 demo and therefore must use the Mode 7 title transition:

```c
m7title_show("LZSS GALLERY", "PACK / UNPACK / VERIFY", ...);
```

Use `examples/snes/snesgfx/m7title.h` (or its current equivalent after the title-screen sweep), so
the title exits through the shared Mode 7 zoom/spinout. Do not use the Mode 7 spinout on non-Mode-7
demos.

### Artwork and artist identification

Every resting slide must identify both:

- the **artist in the real 16×16 Waldo font**; and
- the **name of the work in the 8×8 font**.

Use uppercase ASCII display strings in the ROM (`CEZANNE`, not a corrupted or missing `É` glyph), but
retain the correctly accented/full museum metadata on both websites and in `sources.json`.

At 256 pixels wide, leave an eight-pixel margin on each side. The 8×8 work-title compositor therefore
has **30 columns**. Wrap only at spaces, center each resulting line, and use these reviewed ROM display
titles:

| # | ROM display title | 8×8 wrap at 30 columns | Lines / height |
|---:|---|---|---:|
| 1 | `UNDER THE WAVE OFF KANAGAWA` | `UNDER THE WAVE OFF KANAGAWA` | 1 / 8 px |
| 2 | `THE BEDROOM` | `THE BEDROOM` | 1 / 8 px |
| 3 | `A SUNDAY ON LA GRANDE JATTE - 1884` | `A SUNDAY ON LA GRANDE` / `JATTE - 1884` | 2 / 16 px |
| 4 | `TWO SISTERS (ON THE TERRACE)` | `TWO SISTERS (ON THE` / `TERRACE)` | 2 / 16 px |
| 5 | `WATER LILIES` | `WATER LILIES` | 1 / 8 px |
| 6 | `THE BASKET OF APPLES` | `THE BASKET OF APPLES` | 1 / 8 px |
| 7 | `STACK OF WHEAT` | `STACK OF WHEAT` | 1 / 8 px |
| 8 | `SELF-PORTRAIT` | `SELF-PORTRAIT` | 1 / 8 px |
| 9 | `PARIS STREET; RAINY DAY` | `PARIS STREET; RAINY DAY` | 1 / 8 px |
| 10 | `POPPY FIELD (GIVERNY)` | `POPPY FIELD (GIVERNY)` | 1 / 8 px |

**Decision:** reserve two 8×8 rows (**16 pixels**) for the work name. None of the selected concise,
unambiguous titles needs a third 8×8 row. Do not reserve 24 pixels or shrink the art for a case the
selected corpus does not contain. The very long catalogue expansion of the Hokusai title remains in
the source record/web credit; `UNDER THE WAVE OFF KANAGAWA` is the museum title's identifying primary
clause, while “The Great Wave” may appear in the web description.

The 16×16 artist font allows **15 columns** inside the same margins. Several artists consequently need
two rows:

| Artist display string | 16×16 layout | Rows / height |
|---|---|---:|
| `KATSUSHIKA HOKUSAI` | `KATSUSHIKA` / `HOKUSAI` | 2 / 32 px |
| `VINCENT VAN GOGH` | `VINCENT` / `VAN GOGH` | 2 / 32 px |
| `GEORGES SEURAT` | `GEORGES SEURAT` | 1 / 16 px |
| `PIERRE-AUGUSTE RENOIR` | `PIERRE-AUGUSTE` / `RENOIR` | 2 / 32 px |
| `CLAUDE MONET` | `CLAUDE MONET` | 1 / 16 px |
| `PAUL CEZANNE` | `PAUL CEZANNE` | 1 / 16 px |
| `GUSTAVE CAILLEBOTTE` | `GUSTAVE` / `CAILLEBOTTE` | 2 / 32 px |

Do not reserve unused identity rows. Add exactly one dedicated eight-pixel progress/status row after
the artist and work title. The combined lower band is therefore 32, 40, 48, or 56 pixels high, and
the Mode 7 art takes every remaining scanline:

| Artist rows | Work rows | Status rows | Lower band | Visible Mode 7 art | Derived indexed frame |
|---:|---:|---:|---:|---:|
| 1 | 1 | 1 | 32 px | 256×192 | 128×96 |
| 1 | 2 | 1 | 40 px | 256×184 | 128×92 |
| 2 | 1 | 1 | 48 px | 256×176 | 128×88 |
| 2 | 2 | 1 | 56 px | 256×168 | 128×84 |

This is why the asset crop is per-slide rather than one square thumbnail size. The art always begins
at scanline 0. An **HDMA raster split changes video mode at its bottom edge**; the caption is not part
of Mode 7 and is not made from sprites.

### HDMA Mode 7 → Mode 1 split

Use two HDMA channels with per-slide tables:

- channel A writes `$2105` (`BGMODE`): Mode 7 above the split, Mode 1 below it;
- channel B writes `$212C` (`TM`): BG1 only above the split, BG2+BG3 below it.

At the split scanline (176, 184, 192, or 200), H-blank changes `BGMODE` from 7 to 1 and the main-screen
mask from `BG1` to `BG2|BG3`. Thus:

- **top:** Mode 7 BG1 contains only the artwork;
- **bottom BG2:** the artist, rendered with the repository's actual shadowed **16×16 Waldo font**;
- **bottom BG3:** the work name, rendered with the actual **8×8 font**.

Because one HDMA line-count byte covers at most 127 scanlines, encode the top span as two consecutive
repeat entries with the same Mode 7/BG1 values, then the bottom entry with Mode 1/BG2+BG3 values.
Regenerate both tables when the slide changes. Verify the switch occurs in H-blank immediately before
the first caption scanline with no one-line mode tear.

Set `BG2SC`, `BG3SC`, `BG12NBA`, and `BG34NBA` once for non-overlapping Mode 1 caption tilemaps and
character data in the upper half of VRAM. The lower 32 KiB Mode 7 interleaved tilemap/character region
remains dedicated to the picture. Budget and assert space for:

- all 64 four-tile Waldo-16 glyphs, including their real drop shadows;
- the font8 glyph set;
- one 32×4 caption tilemap area; and
- the Mode 7 map/character data.

The Mode 1 backgrounds use transparent palette index 0 over a dark fixed-color/backdrop caption
field. The artist uses a warm Waldo face plus its authored dark shadow; the work title uses a
high-contrast font8 palette. No browser/system font substitution is permitted in the ROM.

Disable the split HDMA channels while `m7title` owns the full screen. Enable them only after the title
spinout finishes and the first gallery slide is ready. During slide transitions, blank BG2/BG3 by
switching to empty caption tilemaps, update the text maps during vblank, and reveal the new caption
when the incoming Mode 7 art settles. HDMA continues to protect the caption scanlines from the Mode 7
rotation throughout the transition.

BG3 font8 owns one dedicated final row for codec stage and progress. The work title remains visible
above it throughout compression and comparison.

### Visible codec stage indicator

The automatic run must visibly explain what the SNES is doing. Use the dedicated final font8 row and
advance through:

1. `UNPACK` while the ROM stream is decoded;
2. the normal work title when the decoded image first appears (`DISPLAY`);
3. `REPACK` while the on-SNES compressor processes that displayed framebuffer;
4. `COMPARE` during golden-stream, second-decode, byte, and checksum comparison;
5. `VERIFIED` in green on success, or sticky `FAILED` in red on any mismatch; then
6. keep the work title above a compact `VERIFIED [##########]` status for the viewing hold.

During `REPACK`, the row contains a real input-position meter, for example
`REPACK [######....] 61%`; it advances from the compressor's processed-byte count, not an unrelated
frame timer. During `COMPARE`, it advances from bytes actually compared. Meter completion therefore
means the named work has completed; slowing or pausing the codec also slows or pauses the meter.
`UNPACK` may use decoded bytes in the same way.

Independently record elapsed duration for each stage using an NMI/vblank frame counter:

- unpack/decode frames;
- initial VRAM upload/display frames;
- on-SNES repack/compress frames; and
- second decode + byte/checksum comparison frames.

After verification, alternate the status row between `VERIFIED [##########]` and a compact timing
summary such as `UNP 3F REP 47F CMP 2F`. Store the raw frame counts in a near-WRAM result table so the
emulator gate can extract them. The generated verification report converts frames to milliseconds
using the measured target's NTSC frame rate, while retaining raw frames as the reproducible value.
Timing is informational and must never enter `corpus_result` or change pass/fail.

The artist stays visible in Waldo-16 throughout. A stage change is committed to the Mode 1 BG3
tilemap during vblank, so the status never tears and the Mode 7 picture remains displayed during
`REPACK` and `COMPARE`.

### Layout mockups

Interactive, pixel-grid mockups are checked in beside this plan:

- [gallery caption mockups](2026-07-26-119-snes-lzss-gallery-carousel/lzss-gallery-caption-mockups.html)

They show (A) a one-row artist/one-row work title with 192-pixel-high art, (B) a two-row artist/two-row
work title with 168-pixel-high art—the maximum selected lower band—and (C) the transition state with the
caption BGs blank. The dashed boundary is the HDMA Mode 7 → Mode 1 switch. The mockups are schematic
layout proofs; implementation captures must use the actual generated 16×16 Waldo and 8×8 font
bitmaps and replace the color-field stand-ins with derived art.

The gallery itself uses:

- Mode 7 BG1 with a 128×88–100 indexed image in a 16×11–13-tile identity map;
- per-slide 32-color CGRAM palette;
- a neutral dark surround in color 0;
- a full-width 256×168–192 pixel image at rest, leaving only the actual identity rows plus the
  dedicated eight-pixel meter;
- a gentle, bounded idle yaw/zoom that does not make paintings unreadable;
- a faster rotate-and-recede transition for the outgoing slide;
- blanked/vblank-bounded palette and character upload;
- reverse spin/zoom for the incoming slide; and
- no red palette tint: generated BGR555 palettes are checked against a rendered reference contact
  sheet and emulator captures.

Only the matrix changes during the visible transition. The image swap occurs while the old image is
edge-on/small or while forced blank is asserted, preventing half-uploaded art from showing.

Keep full catalogue titles/credits in provenance and on the web gallery pages even where the
screen uses the reviewed concise display title. Controls: Left/Right select, A pauses automatic
advance, B toggles the caption/status strip, and Start restarts at slide 1. Without input, hold each
verified image long enough to read its identification and view it before advancing.

## Shared codec and source layout

Prefer a reusable codec rather than embedding compressor logic in the ROM:

| File | New/modified | Purpose |
|---|---|---|
| `examples/65816/lzss.h` | new | Wire format, deterministic compressor/decompressor, state/status structs, hash/token stats |
| `examples/65816/lzdec.h` | modified only if safe | Adapt #49 to the shared decoder without changing its stream, result, or published behavior |
| `examples/snes/lzss-gallery.c` | new | Mode 7 carousel, Mode 1 caption layer, HDMA split, input, incremental codec scheduling |
| `examples/snes/lzss-gallery-assets.h` | generated | Stream descriptors, far pointers/banks, palette and source metadata |
| `assets/snes/lzss-gallery/sources.json` | new | Provenance, CC0 declarations, hashes, crops, quantizer settings |
| `assets/snes/lzss-gallery/derived/` | new | Deterministic maximum-size indexed frames, palettes, compressed streams, contact sheet/report |
| `tools/lzss-gallery-assets.py` | new | Explicit fetch/verify/derive/pack tool |
| `tools/lzss-gallery-sim.c` | new | Host golden encoder/decoder and full ten-image oracle |
| `examples/snes/corpus/lzss_sim.c` | new | Small near-memory portable corpus for all compiler modes |
| `dev/lzss-gallery.sh` / `.lua` | new | Build, disassembly, emulator, screenshot, determinism gates |
| `Taskfile.yml` | modified | Build/play/verify and container-only asset-refresh tasks |
| container definition/lockfile | modified if needed | Pin image tooling without changing the host |
| `THIRD_PARTY_ASSETS.md` | new/modified | Human-readable image credits and CC0 provenance |
| `TODO.md`, plan index | modified | Track #119 implementation/publication |
| `docs/plans/2026-07-26-119-snes-lzss-gallery-carousel/lzss-gallery-caption-mockups.html` | new | 256×224 caption, maximum-wrap, and transition layout proofs |

Do not install Python packages, image libraries, or other dependencies on the host. If the existing
development container lacks the required image decoder/quantizer, update its container definition
and lock/pin the dependency there. Both asset generation and its determinism check run in that
container.

## ROM/linker design

Start by measuring the generated streams, not guessing. The implementation may use the existing far
ROM region only if all ten streams, palettes, descriptors, and code fit with explicit headroom.

If they do not:

1. add a gallery-capable LoROM layout with enough 32 KiB banks;
2. keep each compressed stream wholly inside one bank when practical;
3. represent stream locations as `{bank, address, length}` rather than relying on C arrays crossing a
   bank boundary;
4. add a bank-aware byte reader shared by compressor-golden comparison and decoder;
5. checksum/fill every declared ROM bank; and
6. verify the final SNES header size and checksum fields.

Do not weaken the existing `snes-far` ABI for other demos. A new platform/linker variant is preferable
to changing all current ROM layouts.

## Compiler stress and differential gates

There are two complementary gates.

### Portable codec corpus

Use small generated fixtures in near memory to run the same codec under:

- host `-O0`;
- host `-O2`;
- target default;
- target `+mos-a16`; and
- target `+mos-xy16`.

Fixtures must cover literals only, a run with overlapping copies, distances around 255/256, maximum
length 18, full eight-token flag groups, a partial final group, incompressible input, output
exhaustion, invalid/truncated input, and compressor tie-breaks. The result folds encoded bytes,
decoded bytes, lengths, token counts, and expected error statuses.

### Full gallery gate

The ROM's `+mos-a16` far-memory gate processes all ten frames. It must not publish `corpus_result`
until every slide has passed canonical decode, target recompression, exact golden-stream comparison,
and second decode. Fold all ten per-slide results into one documented 16-bit expected value.

Set a generous but measured emulator frame limit. The gate script prints progress or reads a
separate `gallery_progress` byte so a timeout identifies the slow slide rather than reporting only
zero.

Disassembly probes should demonstrate, without overfitting exact instruction counts:

- compressor and decoder symbols are present and referenced;
- 16-bit match/window comparisons survive;
- far loads and stores occur in the full ROM;
- flag shifts/rotates occur;
- match-copy code is not optimized into a non-overlap-only copy; and
- no unexpected divide/modulo libcalls appear in the hot matcher.

Run `-verify-machineinstrs` on default, a16, and xy16 portable corpus builds and on the a16 gallery
ROM.

## Benchmark results

Record and publish, for every work:

- original indexed-image bytes;
- canonical compressed bytes and reduction percentage;
- host compression and decompression time (informational);
- SNES unpack frames and effective KiB/s;
- SNES repack frames and effective KiB/s;
- SNES second-decode/compare frames and effective KiB/s;
- literal count, match count, longest match, and average match length;
- original, first-decode, and second-decode checksums; and
- verification result.

Also report aggregate corpus totals, weighted compression ratio, total compressor/decompressor frames,
and effective throughput. Raw frame counts are authoritative; derived milliseconds and KiB/s use the
documented NTSC frame rate. Run a warm-up pass and at least three measured passes, report min/median/max,
and exclude title/hold/transition time. Benchmarking must not change codec decisions or verification
results.

The on-screen status alternates between identity, live work progress, and a compact result such as
`LZ 6337/12288 48%  REP 42F`. The full table belongs in the generated report, plan, and both websites.

### Measured asset and cartridge sizes

These are generated measurements, not estimates. “Original” is the complete indexed Mode 7 frame
fed to both codecs (one byte/pixel); source dimensions identify the pinned museum image used to
derive it. Each bank also carries its work's 64-byte BGR555 palette.

| Bank | Work | Source px | Mode 7 px | Original bytes | LZSS bytes | Reduction |
|---:|---|---:|---:|---:|---:|---:|
| `$01` | Under the Wave off Kanagawa | 1280×885 | 128×88 | 11,264 | 6,661 | 40.86% |
| `$02` | The Bedroom | 1280×1013 | 128×88 | 11,264 | 6,753 | 40.05% |
| `$03` | A Sunday on La Grande Jatte — 1884 | 1280×1280 | 128×92 | 11,776 | 6,768 | 42.53% |
| `$04` | Two Sisters (On the Terrace) | 1280×1589 | 128×84 | 10,752 | 7,581 | 29.49% |
| `$05` | Water Lilies | 1280×1232 | 128×96 | 12,288 | 7,498 | 38.98% |
| `$06` | The Basket of Apples | 1280×1020 | 128×96 | 12,288 | 7,145 | 41.85% |
| `$07` | Stack of Wheat | 1280×901 | 128×96 | 12,288 | 7,277 | 40.78% |
| `$08` | Self-Portrait | 1280×1623 | 128×88 | 11,264 | 7,731 | 31.37% |
| `$09` | Paris Street; Rainy Day | 1280×994 | 128×88 | 11,264 | 6,704 | 40.48% |
| `$0A` | Poppy Field (Giverny) | 1280×833 | 128×96 | 12,288 | 6,337 | 48.43% |
|  | **Corpus** |  |  | **116,736** | **70,455** | **39.65% weighted** |

The finalized cartridge is **524,288 bytes (512 KiB)**. Its LoROM header declares size byte `$09`;
the relinked checksum/complement are `$9996/$6669`, and the current ROM SHA-256 is
`c8b55a787f7ec649ba994d63dcad56dab6f2d9b3f65c5afac592cc342090a4e1`.

| Bank | Used bytes | Contents |
|---:|---:|---|
| `$00` | 20,117 | 13,742 bytes code/startup + 6,295 bytes descriptors, strings, Waldo/font8 and sine table + 80-byte header/vectors |
| `$01` | 6,725 | Great Wave stream 6,661 + palette 64 |
| `$02` | 6,817 | Bedroom stream 6,753 + palette 64 |
| `$03` | 6,832 | Grande Jatte stream 6,768 + palette 64 |
| `$04` | 7,645 | Two Sisters stream 7,581 + palette 64 |
| `$05` | 7,562 | Water Lilies stream 7,498 + palette 64 |
| `$06` | 7,209 | Basket of Apples stream 7,145 + palette 64 |
| `$07` | 7,341 | Stack of Wheat stream 7,277 + palette 64 |
| `$08` | 7,795 | Self-Portrait stream 7,731 + palette 64 |
| `$09` | 6,768 | Paris Street stream 6,704 + palette 64 |
| `$0A` | 6,401 | Poppy Field stream 6,337 + palette 64 |
| `$0B`–`$0F` | 0 each | Reserved for five later corpus works |

The live SNES benchmark table is populated from `gallery_unpack_frames`,
`gallery_repack_frames`, and `gallery_verify_frames`. Frame counts are generated by a minimal NMI
clock and exclude the title, one-second viewing hold, three-second results hold, VRAM upload, and
Mode 7 transition. Emulator min/median/max and effective KiB/s will be inserted here only after the
full ten-work gate completes three times; they are deliberately not inferred from host timings.
The documented full-corpus oracle is **`0x29AF`** (rotate/XOR fold of each original checksum and
canonical stream length); the first complete bsnes-jg pass produced exactly `0x29AF`.

First complete bsnes-jg measurement (NTSC 60.0988 frames/s; the ROM was compiled `-Os`, with only
the two codec loops `optnone` as a documented workaround for the branch's MOS late-optimizer crash):

| Work | Unpack frames / KiB/s | Repack frames / KiB/s | Verify frames / KiB/s |
|---|---:|---:|---:|
| Great Wave | 224 / 2.95 | 3,244 / 0.20 | 289 / 2.29 |
| Bedroom | 226 / 2.93 | 3,166 / 0.21 | 292 / 2.26 |
| Grande Jatte | 234 / 2.95 | 3,222 / 0.21 | 301 / 2.30 |
| Two Sisters | 226 / 2.79 | 2,846 / 0.22 | 291 / 2.17 |
| Water Lilies | 248 / 2.91 | 3,685 / 0.20 | 320 / 2.25 |
| Basket of Apples | 244 / 2.96 | 3,749 / 0.19 | 315 / 2.29 |
| Stack of Wheat | 248 / 2.91 | 3,635 / 0.20 | 318 / 2.27 |
| Self-Portrait | 235 / 2.81 | 2,930 / 0.23 | 304 / 2.17 |
| Paris Street | 225 / 2.94 | 3,143 / 0.21 | 290 / 2.28 |
| Poppy Field | 238 / 3.03 | 4,224 / 0.17 | 305 / 2.36 |
| **Corpus** | **2,348 / 2.92** | **33,844 / 0.20** | **3,025 / 2.26** |

The measured codec/check work is 39,217 frames (about 10m53s of SNES time) for one corpus pass.
Two complete 45,000-frame bsnes-jg executions, including the final Waldo/font-plane relink, produced
the same `0x29AF` result. The planned three-pass min/median/max publication table still requires one
more complete timing capture; the current per-stage figures must not be mislabeled as a distribution.

## Growth beyond ten images

Treat ten as the first corpus, not a fixed program limit:

- generate `GALLERY_ASSET_COUNT` and loop over it instead of hard-coding `10`;
- generate descriptors, checksums, captions, reports, and linker-section assignments from
  `sources.json`;
- keep codec buffers sized by the maximum generated frame with link/build assertions;
- the initial 512 KiB LoROM reserves banks `$0B`–`$0F` for five more one-image banks;
- when those fill, grow to the next power-of-two cartridge and generate additional bank regions;
- never make adding an image require hand-editing the compressor, carousel state machine, or
  benchmark table; and
- keep per-bank ownership explicit so the final report always says which images occupy each bank.

An asset-refresh/build must fail with an actionable capacity message if a compressed image exceeds
one bank or the configured cartridge has too few banks.

## Visual and emulator verification

1. Container asset refresh succeeds and a second run produces byte-identical derived files.
2. All ten source records still report public-domain/CC0 and match the pinned hashes.
3. Host compressor output is deterministic at `-O0` and `-O2`; every stream round-trips.
4. Portable corpus is five-way equal and machine-verifier clean.
5. Full target gate processes all ten slides and equals the host expected result.
6. Run on both bsnes-jg and MAME where the repository harness supports them; three repeated bsnes-jg
   runs produce the same result and captures.
7. Capture the title, a landscape, a portrait, and a transition on both emulators.
8. Pixel-check captures for a red-channel/palette bias, blank frame, corrupt tile, half-upload,
   one-line raster tear, wrong mode below the split, or Mode 7 pixels leaking into the caption.
9. Manually inspect all ten slides at rest; the subject/focal crop must use the available
   128×84–96 frame well, every artist must use the actual 16×16 Waldo face, every work title must use the actual
   8×8 face, and no caption may clip or wrap differently from the reviewed table.
10. Verify controls and automatic wrap from slide 10 to slide 1.
11. Verify ROM checksum/header, bank size assertions, and reproducible ROM SHA-256.

## Publication

After the ROM and visual gates pass:

1. add/update the `biohack.net` SNES demo page and ROM manifest;
2. add/update the `indri.studio` LLVM-MOS app gallery and ROM manifest;
3. include the same ten credits, ArtIC object links, and CC0 notice on both sites;
4. publish the contact-sheet preview plus representative emulator capture;
5. copy the exact verified `.sfc` to both repositories;
6. regenerate self-check offsets from the final relinked ROM;
7. build both sites in their containers;
8. deploy both sites through their existing workflows; and
9. compare local, repository, and live-served ROM SHA-256 plus both live manifests/pages.

The task is not complete when only the ROM builds locally. Completion requires both live sites to
serve the exact verified ROM and current gallery metadata.

### Publication evidence

- implementation commit: `5cea8ec` (`llvm-mos-65816` `main`);
- biohack.net commit/tag: `4f80e24` / `v1.0.266`, production workflow `30223110493` passed;
- indri.studio commit/tag: `0330f3e` / `v0.1.92`;
- local, biohack.net live, and indri.studio live ROM SHA-256 are identical:
  `c8b55a787f7ec649ba994d63dcad56dab6f2d9b3f65c5afac592cc342090a4e1`;
- biohack.net production page: `https://biohack.net/snes/lzss-gallery/`;
- indri.studio production page:
  `https://indri.studio/apps/llvm-mos-65816/snes/lzss-gallery/`.

## Implementation order

1. Freeze `sources.json`, verify CC0 status, pin IIIF responses/source hashes, and review crops.
2. Add/pin container-only image tooling and generate the deterministic maximum-size asset report/contact
   sheet.
3. Specify the reused LZSS format with exhaustive host unit tests.
4. Implement the deterministic host/target compressor and defensive decoder; keep #49 green.
5. Measure streams and finalize the ROM-bank/linker layout.
6. Add high-WRAM buffers and the full ten-image target round-trip gate.
7. Build the Mode 7 carousel, HDMA Mode 7/Mode 1 split, real Waldo/font8 caption BGs, shared Mode 7
   title spinout, controls, and incremental scheduling.
8. Add portable differential, disassembly, emulator, reproducibility, and visual gates.
9. Perform a final clean relink and verify all ten images on hardware-accurate emulators.
10. Publish the same verified ROM/assets to `biohack.net` and `indri.studio`, then verify live hashes.

## Definition of done

- Ten pinned CC0 images are present with machine-readable and human-readable provenance.
- Ordinary builds are offline and reproducible; no tooling was installed on the host.
- The SNES performs both LZSS compression and decompression for every image after that image is
  visible, and the recompressed round trip's checksum matches the stored original-image checksum.
- Target compressor bytes exactly equal the host goldens, and both decode passes match the raw frame.
- The portable codec is five-way equal; the full far-WRAM gallery gate passes.
- All slides render with correct, non-red-biased palettes and clean Mode 7 transitions.
- The demo uses the Mode 7 title zoom/spinout because it is actually a Mode 7 demo.
- Both emulator legs pass to the extent supported by the repository, with documented non-blocking
  infrastructure skips only.
- The exact final relinked ROM, metadata, credits, and gallery previews are live and hash-matched on
  both `biohack.net` and `indri.studio`.

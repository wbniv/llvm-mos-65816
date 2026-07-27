# #127 — LZSS Gallery: Repack Explainer

**Status:** PLAN (2026-07-26). Supersedes the minimal run-outline visualization
specified in [#126](2026-07-26-126-lzss-gallery-nine-public-domain-masters.md).

## Goal

Make on-SNES recompression visually explain LZSS rather than merely indicating
that compression is active.

During `REPACK`, a viewer should be able to answer:

1. Which artwork pixels are being encoded now?
2. Is the next token a literal or a dictionary match?
3. For a match, where is the earlier source sequence?
4. How many bytes are copied and how far backward is the reference?
5. Is this artwork compressing or expanding, and why?

The benchmark remains authoritative. Visualization must not change token
selection, emitted bytes, checksums, the `0xB5D7` corpus oracle, or Left/Right
cancellation semantics.

## Visual design

[Open the native-screen mockup and sprite vocabulary](2026-07-26-127-lzss-repack-explainer/repack-explainer-mockup.html).

### Match token

Show four related elements at once:

- **Earlier source span:** a gold bracket over the pixels at
  `source_offset = current_offset - distance`.
- **Current destination span:** a bright site-color bracket over the pixels
  covered by the new match.
- **Copy progress:** fill or brighten the destination bracket from left to
  right as match bytes are compared/copied.
- **Connector:** a sparse dotted path from the earlier source to the current
  destination. Arrow direction always points toward the destination.

The source and destination brackets must be visibly different even on a
grayscale display: source uses inward cap notches; destination uses outward
caps plus the progressive fill.

If either span crosses a raster row, split it at the edge and continue on the
next row. Never draw through the centered black surround or across the Mode
7/Mode 1 boundary.

The connector is explanatory rather than geometrically dense. Use at most
eight evenly spaced 4×4 dots plus one arrowhead selected from a fixed OBJ tile
vocabulary. A bounded integer interpolation is sufficient; do not spend
benchmark time drawing a perfect line.

### Literal token

A literal has no false dictionary source:

- put a bright diamond/crosshair on the current pixel;
- pulse it once;
- label it `LIT $xx`; and
- add one compact literal cell to the recent-token strip.

Do not show a source bracket or connector for a literal.

### Recent-token strip

Reserve one 8-pixel telemetry row for the most recent 12–16 tokens:

```text
L  M18  L  M04  M12  L  L  M07  >
```

- `L` is a one-cell literal marker.
- `Mnn` is a match whose bar width or shade represents length 3–18.
- The rightmost cell is newest.
- Old cells shift left only when a representative token becomes visible.
- Use pictograms where possible; do not attempt to print every token byte.

The strip explains local compressibility: long repeated match cells should
dominate easy regions, while literal-heavy dither appears visibly noisy.

## Native-screen layout

Keep the artwork as large as the caption budget permits while reserving:

```text
ARTIST / WORK / DATE              existing metadata
REPACK  RAW 08432  PACK 08190     work-based progress
MATCH   L18 D0421  COPY 11/18     current token
RATIO   97.1%  LIT 6112 M 0734    live totals
[L M18 L M04 M12 L L M07 ...]     recent-token strip
```

The exact row count remains artwork-dependent. Prefer four repack rows and
reduce to three only for a two-line artist plus two-line title. In the compact
case, combine progress and ratio; never remove current-token semantics or the
token strip.

Recompute each work's available Mode 7 height through the asset capacity
solver. Continue to preserve the complete composition and original aspect
ratio. A visualization improvement must not reintroduce cropping or stretching.

## Instrumentation contract

Expose one small volatile record owned by the compressor:

```c
typedef struct {
  uint16_t sequence;
  uint16_t current_offset;
  uint16_t source_offset;
  uint16_t raw_done;
  uint16_t packed_done;
  uint16_t literals;
  uint16_t matches;
  uint16_t distance;
  uint8_t  kind;          // literal, match, canceled
  uint8_t  value;         // literal byte
  uint8_t  length;        // selected match length
  uint8_t  copy_progress; // 0..length
} RepackVisual;
```

Foreground compressor code writes fields first and increments `sequence`
last. The NMI/renderer reads `sequence`, copies the record, and checks
`sequence` again; mismatched reads are discarded. No lock or interrupt
disable may extend the measured hot loop.

Update `copy_progress` inside the existing match-byte comparison/copy path so
the destination bracket can advance during a long match. Update raw/packed
counts only after their corresponding token state is valid.

## Sampling and time behavior

The compressor remains free-running. It must never wait for the visualization.

- At most one representative event is consumed per video frame.
- If multiple tokens occur between frames, show the newest complete event.
- Long matches may remain visible across several frames because their
  `copy_progress` changes.
- Retain the completed event for at least two frames so literals do not become
  invisible flashes.
- Token-strip history is presentation state; it is not written into the codec
  buffers or checksum.
- When compression finishes, hold the last token view briefly, then return to
  normal arrows and result telemetry.

Record both token throughput and visible-event throughput so documentation is
honest about coalescing.

## Coordinate projection

Use the same generated width, height, `matrix_scale`, centered margins, and
HDMA split as the displayed artwork.

For a linear index:

```text
x = offset % raster_width
y = offset / raster_width
screen_x = left_margin + floor(x * 256 / matrix_scale)
screen_y = top_margin  + floor(y * 256 / matrix_scale)
```

Project the exclusive end separately so a span never collapses to zero width.
Clip only after splitting at raster rows. Add host tests for landscape,
square, and portrait works, both margins, row wrap, final partial tile, and
maximum length 18.

## Sprite vocabulary and limits

Generate fixed 2bpp/4bpp OBJ tiles for:

- source left/middle/right bracket;
- destination left/middle/right bracket;
- progressive destination fill;
- connector dot and arrowhead;
- literal crosshair/diamond;
- recent-match bar lengths or reusable segments; and
- the existing navigation chevrons.

Keep navigation arrows in dedicated OAM entries. Compression overlay entries
start after them and are cleared as one bounded range outside `REPACK`.

Budget per frame:

| Element | Maximum OBJ |
|---|---:|
| Navigation chevrons | 2 |
| Source spans, including row wrap | 12 |
| Destination spans/fill, including row wrap | 12 |
| Connector dots + arrow | 9 |
| Current literal marker | 1 |
| Short fading history | 16 |
| Safety total | **52** |

Also enforce the SNES 32-OBJ-per-scanline limit. Current source/destination
spans have priority, followed by arrowhead, connector dots, then history.
Drop history first and dots second; never drop the current token markers.

## Site colors

Retain the two site-specific variants:

| Site | Destination/current color | Source color |
|---|---|---|
| biohack.net | neon cyan | gold |
| indri.studio | indri-eye neon green | gold |

Use only reserved OBJ palette entries. Do not overwrite any of the 219
artwork indices. Source/destination distinction must also survive hue changes,
so shape—not color alone—carries meaning.

## Navigation priority

Left/Right remains higher priority than all visualization and codec work.

On accepted input:

1. NMI latches navigation and sets cancellation.
2. Compressor exits at its next existing bounded cancellation point.
3. Mark the visual record `canceled`.
4. Clear compression overlay OAM on the next vblank.
5. Continue the selected chevron's loading animation.
6. Decode the requested work from a clean stage.

Canceled work publishes no timing, token totals, ratio, failure color, or
corpus contribution. A canceled token may disappear abruptly; responsiveness
is more important than completing its animation.

## Benchmark integrity

Provide two builds from the same source:

- `VISUAL=1`: shipping explainer and measured presentation overhead.
- `VISUAL=0`: headless codec reference.

For every work, both builds must produce identical:

- compressed size and bytes;
- literal/match counts and longest match;
- second decode and raw byte comparison;
- indexed checksum; and
- canonical corpus oracle.

Report per-work and aggregate frame deltas. The shipping UI may increase
wall-clock repack time through NMI work, but the timing table must say so
explicitly. Do not subtract visualization cost from the displayed benchmark.

## Mockup gates

Review the HTML mockup before implementation, then replace its illustrative
art with native emulator captures.

Required states:

1. literal over a landscape work;
2. short same-row match;
3. length-18 match;
4. source and destination on distant rows;
5. row-wrapped source and/or destination;
6. portrait work with wide side margins;
7. ratio above 100% for an expanding work;
8. navigation cancellation during a visible match; and
9. final verified result with overlays cleared.

## Automated verification

- Unit-test offset projection and row splitting on the host.
- Assert every OAM entry stays in its assigned range.
- Assert no scanline exceeds 32 visible sprites in worst-case generated states.
- Assert overlay CGRAM writes touch only reserved UI entries.
- Script Left and Right during literal and match events.
- Compare `VISUAL=0` and `VISUAL=1` compressed buffers for all twenty works.
- Run the full host `-O0`/`-O2` stream oracle.
- Run the canonical bsnes-jg corpus gate.
- Capture at least one literal, long match, distant connector, and expanding
  ratio state at native 256×224 resolution.
- Verify both site-color variants independently.

## Files

| File | Change |
|---|---|
| `examples/snes/lzss-gallery.c` | Visual record, projection, OAM renderer, token strip, cancellation cleanup |
| `examples/65816/lzss.h` | Optional instrumentation hook with no codec-semantic changes |
| `tools/lzss-gallery-assets.py` | Recomputed caption/display budget if the strip adds a row |
| `tools/lzss-gallery-sim.c` | Visual/headless byte-equality oracle |
| `dev/lzss-gallery.sh` | Dual-build comparison and scripted visual captures |
| `docs/plans/.../repack-explainer-mockup.html` | Reviewed visual contract |

## Publication

After all gates pass:

1. update this plan with captures, timing overhead, and hashes;
2. relink both site-color 8 Mbit (1 MiB) cartridges;
3. update previews and explanatory copy on both galleries;
4. update manifest offsets only if the relink moved them;
5. build, commit, tag, and deploy both sites; and
6. compare both live ROM hashes with their corresponding verified artifacts.

## Definition of done

- A viewer can visually distinguish literals from matches without reading text.
- Every match visibly relates earlier source pixels to the current destination.
- Copy length and progress are legible.
- The token strip makes compressible versus incompressible regions apparent.
- Artwork remains uncropped, aspect-correct, and unobscured outside the bounded
  current-token overlay.
- Left/Right cancels immediately and clears all compression sprites.
- Visual and headless builds emit identical LZSS bytes and `0xB5D7`.
- Measured overhead, captures, and both published ROM hashes are documented.

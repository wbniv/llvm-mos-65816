# 133 — Rijksmuseum Gallery Expansion

**Status:** Ready to implement
**Surfaces:** SNES LZSS gallery, biohack.net, indri.studio
**ROM:** regenerate from sources, linker map, and first-fit-decreasing placement
**Mockup:** [rijksmuseum-expansion-mockups.html](2026-07-27-133-rijksmuseum-gallery-expansion/rijksmuseum-expansion-mockups.html)

## Goal

Fill the next tranche of the 1 MiB gallery cartridge with ten visually distinct, non-portrait
paintings from the Rijksmuseum's open collection. Preserve the gallery as a useful 219-colour
compression, decompression, verification, timing, Mode 7, and ROM-packing test battery.

## Selection

The current cartridge already contains Hendrick Avercamp's *Winter Landscape with Ice Skaters* and
Jacob van Ruisdael's *The Windmill at Wijk bij Duurstede*. Do not duplicate those compositions.

The first Rijksmuseum expansion targets:

| Slot | Artist | Subject target |
|---:|---|---|
| 1 | Aert van der Neer | moonlit river |
| 2 | Jacob van Ruisdael | waterfall landscape |
| 3 | Meindert Hobbema | wooded road or watermill |
| 4 | Jan van Goyen | river or coastal landscape |
| 5 | Salomon van Ruysdael | river ferry |
| 6 | Willem van de Velde | seascape |
| 7 | Pieter de Hooch | courtyard or domestic interior |
| 8 | Pieter Saenredam | church interior |
| 9 | Rachel Ruysch | flower still life |
| 10 | Jan Davidsz. de Heem | fruit or flower still life |

Substitution within an artist's Rijksmuseum holdings is allowed when the preferred work lacks an
explicit reusable master, has an unsuitable reproduction, duplicates an existing composition, or
quantizes poorly. Portraits are excluded.

## Rights and provenance gate

Every accepted work must record:

- canonical Rijksmuseum object URL or persistent identifier;
- exact title, artist, and displayed year/range;
- Rijksmuseum as provider;
- Public Domain Mark or CC0 statement from the object/data record;
- exact image URL or pinned Wikimedia Commons filename;
- downloaded source SHA-256;
- derived indexed-image and palette hashes.

The build must remain offline and deterministic after sources are checked in. Automated discovery
may suggest a file, but no unpinned search result may become part of a normal ROM build.

## Image and caption contract

- Preserve the complete source aspect ratio; do not crop paintings to fill the display.
- Quantize artwork into the gallery's 219 reserved colour indices.
- Retain the black status/caption region and the established Mode 7 presentation.
- Artist names remain on one line. Use mixed 8×8 given-name text and 16×16 surname text when it
  fits; fall back to the complete name in 8×8 when mixed text would exceed 256 pixels.
- Titles may use one or two 8×8 rows.
- Display the painted year or date range.
- Preserve Previous/Next keyboard and bounded pointer hit areas.

## Test-battery value

The batch deliberately spans:

- dark, low-contrast moonlight;
- high-frequency waterfall foam;
- foliage and fine branches;
- broad sky and water gradients;
- rigging and ship silhouettes;
- architectural perspective and straight edges;
- indoor light and shadow;
- dense flower/still-life colour boundaries.

Record raw bytes, LZSS bytes, ratio, token counts, longest match, first-frame timing, repack timing,
verification timing, and host-generated oracle values for every work.

## Cartridge placement

Treat every LZSS stream and every 512-byte palette as independent placement items. Run William B.
Norris IV's romopt strategy:

1. sort items largest to smallest;
2. place each item into the first 32 KiB bank where it fits;
3. create another bank only when no existing bank fits;
4. continue until all items are placed.

Do not manually assign art to banks. Linker sections must be emitted from this placement result.

After linking, regenerate `assets/snes/lzss-gallery/derived/rom-map.md` from the actual linker map.
The cartridge document must include:

- 1 MiB cartridge/root capacity and total occupied/padding bytes;
- four 256 KiB Mermaid treemap quadrants;
- every physical 32 KiB LoROM bank;
- every stream and palette placed in each bank;
- byte size of every item and free bytes per bank;
- source manifest order independent of physical placement;
- a warning if generated placement and linker-map placement differ.

The generated cartridge layout is a required build artifact and acceptance gate, not optional
documentation.

## Mockups

The interactive mockup contains:

1. a 256×224 gallery-frame preview showing the caption, date, timing rows, and chevrons;
2. a ten-work contact-sheet layout emphasizing composition variety;
3. a four-quadrant cartridge treemap showing how new streams occupy formerly empty banks;
4. a source/rights inspection table.

Mockup paintings are abstract colour/composition stand-ins. The generated contact sheet becomes the
authoritative visual review once real sources are processed.

## Implementation

1. Add the ten accepted source records to `sources.json`.
2. Download and check in the pinned public-domain masters.
3. Generate indexed images, palettes, LZSS streams, hashes, report, and contact sheet.
4. Regenerate the C asset header and independent stream/palette bank sections.
5. Build the ROM and run the full gallery verification gate.
6. Generate the cartridge map from the final linker map and confirm placement parity.
7. Copy the exact ROM and manifest metadata to biohack.net and indri.studio.
8. Build both sites and verify the live gallery controls and ROM hashes.

## Verification

- all source records pass the explicit public-domain/CC0 gate;
- all ten images use at most 219 artwork colours;
- all LZSS streams round-trip byte-for-byte on the host;
- artist/title/date text stays within its allocated rows;
- contact-sheet inspection finds no severe crop, blank image, corrupt palette, or illegible subject;
- complete emulator batch reaches PASS with no image corruption;
- linker sections stay within 32 KiB banks;
- generated cartridge map matches the linked ROM;
- both site builds pass;
- both deployed sites serve the same ROM SHA-256.

## Delivery

1. Commit the plan, mockup, sources, generated assets, ROM, report, and cartridge map.
2. Commit exact ROM/manifest updates in biohack.net and indri.studio.
3. Push all repositories.
4. Publish patch releases for both sites.
5. Wait for both deployment workflows and verify live ROM hashes.

## Acceptance

- ten new, non-portrait Rijksmuseum works appear in gallery order;
- the new works expand visual and compression coverage rather than duplicate existing slides;
- source, rights, dates, and hashes are auditable;
- the complete test battery passes;
- the linker-derived Mermaid cartridge layout documents every bank and item;
- biohack.net and indri.studio publish the identical expanded cartridge.

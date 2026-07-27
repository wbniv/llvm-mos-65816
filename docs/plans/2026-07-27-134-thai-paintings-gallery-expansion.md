# 134 — Thai Paintings Gallery Expansion

**Status:** Queued behind tranche #133; do not implement until its corpus, ROM map, and website
publication are complete
**Depends on:** [#133 — Rijksmuseum Gallery Expansion](2026-07-27-133-rijksmuseum-gallery-expansion.md)
**Surfaces:** SNES LZSS gallery, biohack.net, indri.studio
**Corpus role:** the tranche immediately following the currently selected Rijksmuseum works
**Release policy:** rolling publication; publish each eligible painting at the earliest safe pipeline
stage instead of waiting for the complete tranche

## Goal

Add a visually and culturally distinct group of eligible Thai paintings after the current tranche
has been incorporated. The work includes the cartridge corpus, benchmark/oracle data, ROM layout,
generated contact sheet, and full image-bearing gallery sections on both websites.

Thai temple and narrative painting is especially useful to the benchmark: gold detail, repeated
architectural motifs, foliage, figures, borders, flat colour, weathered surfaces, and dense
high-frequency line work exercise substantially different LZSS behavior from the current European,
American, Chinese, and Japanese works.

## Sequencing gate

Before changing `sources.json` for this tranche:

1. finish #133 and record its final enabled-work count;
2. publish and verify its ROM on biohack.net and indri.studio;
3. regenerate its linker-derived ROM map;
4. record its final occupied bytes and remaining banks; and
5. branch this work from that exact verified corpus state.

Do not estimate Thai-tranche bank addresses against the pre-#133 layout. Source-manifest order and
physical romopt placement are independent.

Once #133 clears this sequencing gate, Thai works do not wait for one another. Process and publish
them independently in selection order whenever possible.

## Rolling-publication pipeline

The eight-work tranche is a planning and final-verification unit, not a release barrier. Every work
moves through independently visible stages:

| Stage | Minimum gate | Publish immediately |
|---|---|---|
| Candidate | Canonical page found | No production claim; candidate may appear only in this plan |
| Rights-cleared source | Underlying work and reproduction rights verified; title, painter, date, source dimensions, and source SHA-256 pinned | Add the real image, source link, attribution, and “queued for cartridge” status to both webpages |
| Derived preview | Aspect-preserving raster, palette, thumbnail, caption fit, and visual inspection pass | Publish optimized thumbnail, derived dimensions, colour count, and preliminary host compression figures |
| Host-verified asset | Host encode/decode is byte-identical and deterministic | Publish final host compression measurements and include the work in generated reports/contact sheet |
| Playable ROM increment | Asset packs and links; per-work SNES decode/display/recompress/checksum/byte-compare passes; navigation and display-quality smoke pass | Publish the expanded ROM, manifest, checksum, work count, capacity, and regenerated linker-derived map on both sites |
| Corpus-verified | Full uninterrupted oracle and cross-work navigation pass | Promote status to verified and publish final corpus totals/timings |

Do not hold a rights-cleared image card for ROM work, and do not hold a per-work verified ROM for
the remaining paintings. If works 1–3 are ready while work 4 is blocked, publish 1–3 and continue.

Every production state must remain internally truthful:

- webpage status distinguishes queued, host verified, playable, and corpus verified;
- the displayed work count says whether it means website sources or works in the current ROM;
- preliminary measurements are labeled preliminary;
- the download checksum and cartridge map always describe the ROM actually served;
- both sites receive the same completed increment before work proceeds to the next publishable
  increment; and
- superseded thumbnails, ROMs, manifests, and maps are cache-busted together.

Batch adjacent ready changes into one deployment only when doing so saves a currently running build;
never delay a ready increment merely to make a round-number tranche.

## Proposed selection

Use eight works initially. The first three provide distinct compositions; the remaining five form a
small Ramakien sequence without allowing one mural cycle to dominate the tranche.

| Slot | Display title | Artist display | Provider/source | Rights evidence |
|---:|---|---|---|---|
| 1 | Buddhist Temple Painting | UNKNOWN THAI ARTIST | [The Metropolitan Museum of Art, 59.179.1](https://www.metmuseum.org/art/collection/search/38063) | Object page says Public Domain and provides a downloadable image |
| 2 | Buddha Descending at Sankissa | UNKNOWN THAI ARTIST | [The Metropolitan Museum of Art, 64.115](https://www.metmuseum.org/art/collection/search/38070) | Object page says Public Domain and provides a downloadable image |
| 3 | Naresuan's Elephant Duel | CHAN CHITTRAKON | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Naresuan_of_Ayutthaya_Elephant_Duel_with_Mingyi_Swa_of_Toungoo_Painting.jpg) | Page identifies the 1931 painter and marks the two-dimensional work/reproduction Public Domain |
| 4 | Ravan in His Palace | UNKNOWN THAI ARTISTS | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Ramakien_00.jpg) | Original mural described as 18th century; source photograph is CC0 |
| 5 | Surasa Challenges Hanuman | UNKNOWN THAI ARTISTS | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Ramakien_02.jpg) | Original mural described as 18th century; source photograph is CC0 |
| 6 | Hanuman — Ramakien | UNKNOWN THAI ARTISTS | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Ramakien_06.jpg) | Original mural described as 18th century; source photograph is CC0 |
| 7 | Hanuman Destroys Longka | UNKNOWN THAI ARTISTS | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Ramakien_09.jpg) | Original mural described as 18th century; source photograph is CC0 |
| 8 | Ravana Prepares for War | UNKNOWN THAI ARTISTS | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Ramakien_12.jpg) | Original mural described as 18th century; source photograph is CC0 |

### Alternates

Use these only if a preferred master fails the rights, resolution, visual, quantization, or packing
gate:

| Priority | Display title | Artist display | Source | Notes |
|---:|---|---|---|---|
| A | Mural at Wat Phumin | UNKNOWN THAI ARTIST | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Wat_Phumin_2018-07-30_(18).jpg) | CC0 photograph; large portrait composition |
| B | Ramakien Chariot Scene | UNKNOWN THAI ARTISTS | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:WatPhraKeaw_Ramayana_Chariot.JPG) | Public-domain mural/reproduction; landscape composition |
| C | Wat Pho Chai Mural | UNKNOWN THAI ARTIST | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Wat_Pho_Chai_mural,_Bangkok,_Thailand_-_20101028.jpg) | CC0 photograph |
| D | Mural at Lhong | UNKNOWN THAI ARTIST | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Mural_drawing_at_Lhong,_Thailand,_renovated_but_presumaky_originally_drawn_in_1850.jpg) | CC0 photograph; reported circa-1850 origin needs verification |

The early-20th-century Met acquisition numbered 2025.571 is excluded: its object page currently
says that the image cannot be downloaded. Do not substitute a screenshot.

## Rights, provenance, and attribution gate

Eligibility requires both the underlying painting and the exact reproduction file to be reusable.
For each accepted work, record:

- canonical object or Commons file-page URL;
- exact title, culture, artist attribution, and creation date from the source;
- provider and object/accession identifier where available;
- underlying-work rights statement;
- reproduction-file license and license URL;
- exact original-image download URL;
- original pixel dimensions, MIME type, byte count, and SHA-256;
- source-page retrieval date;
- derived raster, palette, LZSS stream, and thumbnail hashes; and
- a short note when the English display title is editorially shortened.

Do not label a photographer as the artist. The cartridge artist line describes the painter:
`UNKNOWN THAI ARTIST(S)` when the painter is not documented. Website attribution separately credits
the museum/provider and photographer when the reproduction license requires it.

CC BY and CC BY-SA files are not automatic substitutes for the proposed Public Domain/CC0 set.
They require an explicit attribution design and review before acceptance.

## Image-processing contract

- Preserve the complete artwork and its source aspect ratio; never crop merely to fill Mode 7.
- Remove only photographic borders or surrounding architecture when the source clearly identifies
  the painting boundary and the crop remains a faithful reproduction.
- Keep a record of the crop rectangle and both pre-crop and post-crop hashes.
- Fit the largest possible aspect-preserving indexed raster above the non-Mode-7 caption/status
  region.
- Use no more than the established 219 artwork colours and keep UI palette indices reserved.
- Inspect gold leaf, black line work, faces, and weathered wall texture after quantization.
- Reject a source if glare, perspective distortion, pillars, visitors, or restoration seams obscure
  too much of the painting.
- Generate individual web thumbnails from the same pinned master, not from emulator screenshots.

## Caption and metadata contract

- Artist uses the established mixed Waldo font treatment when it fits on one line.
- Title uses one or two 8×8 rows; three rows require explicit layout review.
- Show the source-supported date or century.
- Transliterate names consistently in ASCII for the ROM, while the webpages may additionally show
  Thai script when an authoritative source supplies it.
- Preserve source title, display title, and shortened ROM title as separate fields.

Before asset generation, render every proposed caption through the actual font-width code and
record the row count. Long titles above are intentionally shortened for the ROM; the full canonical
titles remain on the webpages.

## Build and benchmark work

Repeat the following loop for each painting rather than waiting to ingest all eight:

1. Add one disabled candidate record to `assets/snes/lzss-gallery/sources.json`.
2. Run its rights and caption audit.
3. Check in its pinned source master and hash, then publish its source-backed webpage card.
4. Generate its aspect-preserving indexed image, 512-byte palette, LZSS stream, web thumbnail,
   report data, and contact-sheet update; publish the derived preview when it passes inspection.
5. Run host compression/decompression byte-equality checks at both optimization levels and publish
   the host measurements.
6. Enable the work, rerun romopt, build both site-colour ROM variants, and regenerate the actual
   linker-derived map.
7. On SNES, decode, display, recompress, checksum, byte-compare, and retain stage timings for the
   new work.
8. Run the bounded release smoke, then publish this playable ROM increment immediately.
9. Verify Left/Right cancellation at every stage and wraparound across the expanded corpus.
10. Record per work:
   - source dimensions and bytes;
   - derived raster dimensions and raw indexed bytes;
   - compressed bytes and percentage reduction;
   - token/literal/match counts and longest match;
   - decode, display, recompress, checksum, and total timings; and
   - host and SNES checksum/oracle results.
11. Continue long full-corpus/oracle verification after publication; promote the live status when it
    passes, or roll back the affected increment if it exposes a real regression.

Compression percentage must update during repacking, and work-count progress—not elapsed
time—remains the progress-meter basis.

## Cartridge sizing and romopt placement

Leave bank `$00` for runtime/shared content. Feed every stream and every 512-byte palette from banks
`$01` onward into the established romopt first-fit-decreasing placement:

1. sort indivisible items largest first;
2. place each in the first 32 KiB bank where it fits;
3. add a bank only when no existing bank fits; and
4. emit linker sections from the placement result.

After #133, calculate the smallest conventional physical ROM configuration that safely contains the
complete linked corpus. Cartridge capacity is elastic: increase it whenever the packed assets,
runtime, linker padding, or a later accepted tranche no longer fits. Describe capacity in megabits
first.

The cartridge model must represent the SNES's conventional two-mask-ROM option rather than assuming
one power-of-two ROM:

- ROM 1 and ROM 2 have independent power-of-two capacities;
- either device may be absent;
- each device may be as large as **32 Mbit (4 MiB)**;
- total logical capacity may therefore be a sum such as **24 Mbit (3 MiB = 16 + 8)**,
  **48 Mbit (6 MiB = 32 + 16)**, or **64 Mbit (8 MiB = 32 + 32)**; and
- select the smallest supported one- or two-device combination with adequate space.

Capacity policy:

- retain **8 Mbit (1 MiB)** only while the complete linked corpus fits safely;
- grow through valid single- or dual-ROM combinations as required;
- at or below **32 Mbit (4 MiB)**, retain the existing LoROM mapping when the generated image and
  hardware mapping remain valid;
- above **32 Mbit (4 MiB)**, do not merely append bytes to the current LoROM. Implement and verify an
  extended mapping and decoder model—normally official map Mode `$25`/ExHiROM—before using the
  second 32 Mbit address region; and
- never delete an accepted work, crop more aggressively, reduce Mode 7 resolution, reduce colour
  quality, or weaken verification merely to preserve the previous cartridge size.

The official internal header exposes one logical ROM-size code; it does not independently describe
the two physical devices. Consequently the generated reports and webpages must record both:

1. total logical cartridge size; and
2. the physical decomposition, for example **48 Mbit (6 MiB), ROM 1: 32 Mbit + ROM 2: 16 Mbit**.

Treat a capacity increase within an already implemented mapping as an ordinary generated build
result. Crossing the 32 Mbit mapping boundary is a real implementation change: update the linker
script, far-address asset tables, reset/header/vector placement, map-mode and ROM-size header bytes,
checksum/complement, emulator configuration, romopt address model, and cartridge-map renderer.
Update manifests, download metadata, webpages, reports, and every displayed capacity in either
case.

References for this sizing rule:

- [Nintendo Super NES Development Manual, Book I](https://gamingdoc.org/technical-documentation/consoles/super-nintendo/official/sdk/book-i/)
  documents the official map modes and ROM-size header;
- [SNESdev ROM file formats](https://snes.nesdev.org/wiki/ROM_file_formats) records that a logical
  image may be the sum of two power-of-two ROM sizes and describes ExHiROM continuation above
  4 MiB; and
- [SNESdev map-mode table](https://wiki.superfamicom.org/map-mode-table) identifies official Mode
  `$25` as ExHiROM.

The generated map must use linker addresses, show every bank and item, separate used space from
padding, and draw a visible divider at every 1 MiB boundary. Regenerate both
`assets/snes/lzss-gallery/derived/rom-map.md` and the saved HTML/visual renderer output.

## Website implementation

The webpages must contain the images, not merely a textual attribution list.

For both biohack.net and indri.studio:

1. replace the ROM, manifest metadata, cache-busting hash, work count, cartridge capacity, and
   benchmark totals;
2. publish the new generated contact sheet;
3. append an individual responsive thumbnail/card for every Thai work;
4. make each image and title link to its canonical museum/object or Commons file page;
5. show full title, painter attribution, date, culture, provider, and license beside each image;
6. link the license and credit the reproduction photographer when required;
7. use checked-in optimized thumbnails with width/height attributes, meaningful alt text, lazy
   loading, and no third-party hotlinking;
8. preserve gallery order and use the same metadata source to generate both sites;
9. keep player controls, Mode 7 badge/filtering, phone chevron hitboxes, and existing page layout
   behavior unchanged; and
10. include the Thai additions in any image count, corpus summary, and ROM-layout link.

The generated contact sheet is a summary; it does not replace the individual linked images.
Website thumbnails must preserve aspect ratio and must not use decorative crops that misrepresent
the paintings.

## Verification

### Sources and visuals

- every enabled work has auditable underlying-work and reproduction rights;
- every download matches its pinned SHA-256;
- all complete compositions preserve aspect ratio;
- captions fit their assigned rows in the real fonts;
- visual inspection finds no glare-dominated, blank, badly cropped, palette-corrupt, or illegible
  image;
- the Thai tranche adds at least three materially different composition types.

### ROM and emulator

- all host and SNES LZSS round trips are byte-identical;
- displayed recompression percentages and timings agree with recorded results;
- navigation preempts work immediately without stale sprites, HDMA, palette, or background data;
- the SNES display-quality gate passes;
- every asset fits within its assigned 32 KiB bank;
- the generated placement and actual linker map agree;
- the final checksum, oracle, ROM size, and per-bank breakdown are recorded.

### Websites and deployment

- both site builds pass in their existing containers;
- every Thai card renders its actual thumbnail and all image/title/license links resolve;
- desktop and phone layouts preserve aspect ratio without overflow;
- ordered work metadata matches the ROM manifest;
- local, repository, deployed, and live-download ROM SHA-256 values agree for each site variant;
- the live pages show the updated work count, megabit-first cartridge size, contact sheet, individual
  Thai images, and cartridge-map link.

## Delivery

For each work:

1. publish its rights-cleared image card at the source stage;
2. publish its optimized thumbnail and preliminary measurements at the derived stage;
3. commit source records, pinned master, generated asset, reports, ROM increment, and map as soon as
   their corresponding gates pass;
4. commit corresponding webpage, thumbnail, ROM, and manifest changes in biohack.net and
   indri.studio;
5. push all repositories and publish through their normal workflows without waiting for the rest of
   the tranche;
6. wait for both deployments and verify the live page, links, images, and ROM hashes; and
7. record per-work measurements, commit IDs, deployment identifiers, and current verification stage
   in this plan.

After all eight, update this plan with the final selection, substitutions, corpus totals, and
uninterrupted full-oracle result.

## Definition of done

- #133 was incorporated and published before this tranche began.
- Eight eligible Thai paintings are appended without replacing existing works.
- Each painting was published incrementally at its earliest safe source, preview, host-verified, and
  playable-ROM stages; no completed work waited for the full tranche.
- Artist attribution distinguishes painters from reproduction photographers.
- Every source, license, hash, crop, caption, and derived asset is auditable.
- Full-aspect Mode 7 images pass the host/SNES compression and display battery.
- romopt and the linker agree, bank `$00` remains reserved, and the smallest suitable cartridge is
  reported in megabits first with its one- or two-ROM physical decomposition; the cartridge grows
  whenever required rather than sacrificing corpus or image quality.
- Any corpus above 32 Mbit passes the extended-map linker, header, reset/vector, far-address,
  checksum, emulator, and cartridge-map gates before publication.
- Both websites show every Thai painting as an individual linked image with complete attribution,
  in addition to the regenerated contact sheet.
- Both deployed players serve the verified expanded ROM variant and expose the updated ROM map.

## Implementation record — 2026-07-27

The curated **62-work** corpus includes all eight Thai additions and removes six earlier works:
Two Sisters (On the Terrace), Still Life with Flowers on a Marble Tabletop, Interior with Women
beside a Linen Cupboard, Still Life with Flowers in a Glass Vase, East Hampton Beach, Long Island,
and The Bedroom.

- raw indexed corpus: **957,841 bytes**;
- host LZSS streams: **914,349 bytes**;
- weighted reduction: **4.54%**;
- streams plus 62 palettes: **946,093 bytes**;
- romopt result: 31 asset banks, `$01–$1F`;
- final Bank `$1F`: 24,663 bytes used, **8,105 bytes free**; romopt places
  `FONT16` in `$14` and `FONT8` in `$07`;
- final cartridge: **8 Mbit (1 MiB) LoROM**;
- checksum/complement: `$75F4` / `$8A0B`;
- WRAM corpus oracle: `$5CF0` at `$0376`;
- ROM SHA-256: `a5887f9b9940e0bb8137b1a0292f1173cbc615c1f72f847cda0aee98a0bb6268`;
- 1,000-frame bsnes-jg first-image/viewport smoke gate: pass;
- 150,000-frame run: clean display but corpus not yet complete (`$0000`), proving that the former
  default was too short rather than reporting an oracle mismatch;
- complete gate updated to the manifest-aligned **200,000 frames** and pending;
- biohack.net: `v1.0.306`, deployed successfully;
- indri.studio: `v0.1.119`, deployment triggered;
- generated visual ROM map:
  `/home/will/tmp/rom-map.html`.

The asset generator now prunes stale `.idx`, `.lz`, `.pal`, and web-preview files before emitting
the manifest-defined corpus. This prevents removed works from leaking into wildcard host-oracle
runs. Both websites use the generated catalog and individual aspect-preserving indexed previews;
the old duplicate contact sheet is no longer rendered beneath the cards.

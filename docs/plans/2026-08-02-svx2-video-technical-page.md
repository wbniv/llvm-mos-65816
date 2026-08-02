# SVX2 Video Demo Technical Page

**Date:** 2026-08-02  
**Status:** Ready to implement  
**Target:** `https://biohack.net/snes/svx2-fastrom-video/`  
**Depends on:** `2026-08-01-svx2-60-fps-full-pipeline.md` and
`../investigations/2026-08-01-svx2-60-fps-pipeline-profile.md`

## Goal

Turn the playable ROM page into a technical case study that explains how a stock SNES presents
SVX2 video, why SVX2 was selected over the smaller and more general alternatives, and what the
measured 60-packet/s result does and does not prove. Keep the emulator first so a visitor can play
immediately, then make the implementation and benchmark evidence readable without opening the
repository.

[Open the desktop and phone mockups](2026-08-02-svx2-video-technical-page/mockups.html).

## Truthful headline and terminology

- Keep `SVX2 60 FPS FastROM Video` as the gallery label, but use **60 packets/s** or **one unique
  packet per NTSC VBlank** in technical claims.
- State next to the primary result that the checked-in source material was recoded to 59.94 fps
  only if the published ROM actually contains the 1,800-frame reel. If the live artifact remains
  the 900-frame 30 fps master played at one packet/VBlank, label it as a throughput proof running
  at twice authored motion speed.
- Distinguish display refresh, packet decode/presentation cadence, and native temporal sampling.
- Never imply that gallery LZSS is the video format. It is a comparison-only independent-frame
  baseline and is far too slow for this workload.
- Explicitly state that no *Duck and Cover* or animated turtle material is present.

## Page structure

### 1. Playable proof

Retain the current hero, provenance sentence, controls, emulator, fidelity button, and
cartridge-native dashboard explanation. Add a compact result strip immediately below the player:

| Result | Published value |
|---|---:|
| Presentation cadence | 3,822 / 3,822 eligible intervals |
| Deadline slips / decoder errors | 0 / 0 |
| Visible frame | 80 × 56, 8-bit indexed Mode 7 |
| Frame payload | 4,480 bytes / 70 tiles |
| Cartridge | 32 Mbit (4 MiB) Fast HiROM |

The values must come from a small checked-in data object used by both prose and tables; do not
duplicate benchmark literals in hand-maintained HTML.

### 2. How one frame moves

Add an accessible HTML/CSS pipeline diagram, with an equivalent ordered list for narrow screens:

```text
FastROM packet table
        │ active display: DMA packet into $7F WRAM
        ▼
staged SVX2 payload ──► 65816 span decoder ──► in-place 4,480-byte framebuffer
                                                        │
                              VBlank: WRAM-to-VRAM DMA  ▼
                                              70 Mode 7 tiles
                                                        │ HDMA split
                                              BG3 text dashboard
```

Explain the two SVX2 commands in plain language: replacement spans copy changed bytes from the
staged packet; copy spans retain bytes already in the in-place framebuffer. Sequential playback
uses deltas across cuts and a dedicated loop delta. Boot and random access use separate keyframes,
so seeking remains bounded without placing slow keyframes on the real-time path.

Also document:

- FastROM execution and packet reads, with DMA staging into bank `$7F`;
- the 4,480-byte tile-major framebuffer and a single VBlank presentation DMA;
- Mode 7 on scanlines 0–191 and the Mode 1 BG3 dashboard below it;
- automatic joypad latching via `$4218/$4219`, sampled off the decode-critical path;
- cut metadata, palette changes, transport, seek keyframes, and the 899→0 loop delta; and
- the assembly ABI issue (`__rc0`) and distinct-bank `MVN` encoder bug found by the end-to-end
  cartridge work, linked to their investigation/upstream records rather than retold as folklore.

### 3. Why SVX2

Publish the representative real-camera/Floyd results, clearly separating size and speed:

| Codec/path | Packed size | Raw ratio | Measured decode rate |
|---|---:|---:|---:|
| Raw blocks | 1,368,600 B | 101.83% | 87.6 fps copy baseline |
| Gallery LZSS | 747,548 B | 55.62% | 2.1–2.3 fps |
| SVC1 | 755,658 B | 56.22% | 0.6 fps |
| SVX1 XOR + PackBits | 705,621 B | 52.50% | 15.6–34.3 fps |
| **SVX2 replacement/copy** | **766,569 B** | **57.04%** | **60.8–69.4 fps decode-only** |

Add a short conclusion directly under the table: SVX1 wins size, while SVX2 is the smallest tested
format whose target-native decoder clears the measured cadence requirement. Include Floyd versus
Bayer PSNR/ratio only in a secondary disclosure so the main comparison remains legible.

### 4. Full-pipeline benchmark

Show both the isolated codec gate and the integrated player profile. The full pipeline is the
headline result:

| Phase after in-place optimization | p50 PPU dots | p99 | Maximum |
|---|---:|---:|---:|
| FastROM stage | 8,192 | 10,240 | 11,264 |
| SVX2 decode | 64,512 | 69,632 | 254,976 keyframe |
| VRAM presentation | 10,240 | 10,240 | 10,240 |
| **Combined** | **83,968** | **89,088** | **275,456 keyframe** |

Annotate the NTSC interval at 89,342 PPU dots. Explain why the maximum is not part of sequential
playback: independent keyframes were moved to the seek table; the continuous stream uses deltas.
Then show the integrated endurance evidence: 3,822 presentations in 3,822 eligible intervals of a
4,000-frame run, zero deadline slips and zero decode errors. Do not turn the decode-only 60.8 fps
number into an integrated-player claim.

Use simple horizontal CSS bars normalized to the 89,342-dot interval. Tables remain the semantic
source and must be readable with CSS disabled.

### 5. Cartridge layout and verification

Add a compact ROM map for code, sequential packets, palettes/segment metadata, seek keyframes, and
the loop packet. Exact offsets must be generated from the published artifact's map/manifest rather
than copied from an old build.

List the reproducible gates and commands:

- host round-trip of every packet and seek keyframe;
- target byte/CRC gates over the complete 4,480-byte output;
- cadence and deadline counters under bsnes-jg;
- rendezvous captures on both videos and across the cut;
- blank-scan/composite-health verification; and
- controller replay for pause, step, seek, shuttle, resume, and loop.

Show the published ROM SHA-256 and identify which benchmark dataset and source commit produced it.
The page must fail its site build if the displayed ROM checksum differs from the manifest.

### 6. Sources and deeper reading

Link to the NASA source records, the codec format note, the complete corpus benchmark, the 60 fps
pipeline profile, source files for the C scheduler and assembly decoder, and the upstream compiler
regressions. Prefer stable repository permalinks once the implementation commit exists.

## Data and implementation design

- [ ] Add a checked-in `svx2-fastrom-video` technical-data module or JSON document containing
  artifact identity, frame geometry, codec corpus rows, phase profile, cadence result, and links.
- [ ] Validate nonnegative values, ratios, phase totals, unique codec IDs, and the published ROM
  hash during the Astro build.
- [ ] Extend the generic SNES detail-page schema with an optional structured technical-case-study
  field, or create a dedicated Astro page if the diagram/tables would make generic `doc` HTML
  brittle. Keep the existing player component and manifest contract either way.
- [ ] Render real `<table>`, `<figure>`, `<details>`, and `<code>` elements; avoid encoding the
  technical page as one enormous JSON HTML string.
- [ ] Keep all charts CSS-only and respect reduced motion. Do not add a charting dependency.
- [ ] At phone width, stack pipeline stages, make tables horizontally scrollable with an explicit
  affordance, and keep every number/label available without hover.

## Verification gates

1. Astro content validation and production build pass.
2. Every displayed figure matches the checked-in benchmark and profile reports.
3. The current public ROM hash matches the page, manifest, and downloaded artifact.
4. Desktop captures at 1440 and 1024 pixels match the information hierarchy in the mockup.
5. Phone captures at 390 and 360 pixels have no clipped pipeline labels, controls, or tables.
6. Keyboard-only traversal reaches the emulator, technical sections, disclosures, and source links
   in document order; visible focus is retained.
7. Screen-reader landmarks, table captions, and diagram alternative text convey the same result.
8. Live deployment smoke test confirms the page, ROM, controls, and technical links all load.

## Deliverables

- a structured, evidence-backed technical case study below the live emulator;
- responsive pipeline, codec comparison, timing profile, and cartridge-layout visuals;
- direct benchmark/provenance/source links and artifact checksum enforcement;
- desktop and phone screenshots from the production build; and
- updated video/codec documentation pointing readers to the published case study.

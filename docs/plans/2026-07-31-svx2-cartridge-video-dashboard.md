# SVX2 Cartridge-Native Video Dashboard

**Date:** 2026-07-31
**Status:** Complete and published
**Supersedes dashboard placement in:** `2026-07-31-svx2-video-title-and-dashboard.md`

## Correction

`TIME` and `FPS` belong inside the SNES picture, in a conventional tiled background below the
video. They do not belong in the browser player's status row. The web player must return to its
ordinary controls and status treatment.

The current green strip is also a cartridge defect. `setup_display()` fills Mode 7 tile 70 with
palette index 224 and programs CGRAM 224 to green (`$03e0`). Any uncovered Mode 7 sample therefore
becomes a conspicuous green diagnostic area. That was useful while finding mapping errors, but it
must not ship as presentation chrome.

## Interactive mockups

[Open the cartridge dashboard mockups](2026-07-31-svx2-cartridge-video-dashboard/mockups.html).

The mockups compare the current defect with the intended SNES output and provide selectable states
for normal playback, startup, paused emulation, deadline slips, and fatal validation. They also show
two dashboard typography options at the actual 256x224 composition.

## Required composition

The 256x224 SNES active picture becomes two raster bands:

| Scanlines | PPU mode | Layer | Purpose |
|---:|---:|---|---|
| `0..191` | Mode 7 | BG1 | 80x56 SVX2 video scaled to 256x192 |
| `192..223` | Mode 1 | BG3 | 32x4-tile cartridge dashboard |

This is a mid-frame PPU mode switch, following the established `hud.h`/LZSS-gallery technique:
HDMA writes `BGMODE` and `TM` per band. It is not an HTML overlay, sprites, or text burned into the
SVX2 frames.

## Dashboard content

The preferred two-row layout is:

```text
 SVX2 VIDEO                 PLAY
 TIME 00:12             FPS 30.0
```

- `TIME` is derived from `video_reel_presented_total / 30` and formatted `MM:SS`.
- `FPS` is measured from presentation/VBlank deltas over a 60-VBlank target window.
- `PLAY` changes to `PAUSE`, `SLIP`, or `ERROR` when applicable.
- Use tabular 8x8 text from `font8.h`; dashboard writes are BG3 tilemap updates during VBlank.
- Keep all text inside 32 columns and all dashboard pixels inside the bottom four tile rows.
- Do not reset time at the four-frame reel boundary.

## Palette and VRAM ownership

Mode 7 owns VRAM words `$0000..$3fff`. The dashboard uses the already established upper-half
layout:

- BG3 map: `$4000`
- BG3 2bpp font: `$5000`

CGRAM cannot be rewritten by HDMA during active display; the gallery already proved that unsafe.
Reserve legal static 2bpp inks in the generated reel palette instead. The asset generator now
rejects inputs unless entries 0 and 1 remain exact black and white:

- colour 0: dashboard black
- colour 1: dashboard white

Update the asset generator so the video quantizer never assigns those reserved entries. Do not
silently overwrite video colours after quantization. Remove palette index 224 as the green
out-of-bounds diagnostic and make every uncovered Mode 7 sample black.

## Raster split

Add a video-specific split helper rather than changing the generic two-bar `hud.h` contract:

```text
BGMODE: 127 x Mode 7, 65 x Mode 7, 32 x Mode 1
TM:     127 x BG1,   65 x BG1,   32 x BG3
```

- Use HDMA channels 1 and 2; DMA channel 0 remains the frame uploader.
- Re-arm HDMA every frame through the normal SNES HDMA lifecycle.
- Establish Mode 7 and `TM_BG1` before the first active scanline.
- Do not write CGRAM, VRAM, or unsafe PPU registers from HBlank HDMA.
- Verify the split boundary in bsnes-jg screenshots; correct any one-line seam explicitly.

## Video geometry

The source remains 80x56. Change the vertical Mode 7 matrix from the current full-height mapping to
fit 192 scanlines while retaining the full 256-pixel width. Derive the fixed-point matrix from the
actual source and destination dimensions and capture the result; do not tune it by eye alone.

The bottom dashboard must replace, not cover, video pixels. Frame CRCs remain CRCs of the decoded
80x56 source and therefore must not change.

## Cartridge-side telemetry rendering

The browser currently polls WRAM for the dashboard. Remove that UI and render from the same target
counters directly:

- maintain a 60-VBlank measurement snapshot on the cartridge;
- calculate tenths of FPS without floating point;
- format only when the displayed value changes;
- update a small fixed tilemap field during VBlank;
- keep the decode/present critical path ahead of cosmetic dashboard updates;
- surface `video_reel_deadline_slips` and `video_reel_result` visibly.

The 32-bit counters remain useful target diagnostics and should not be removed merely because the
browser stops displaying them.

## Browser rollback

Remove the optional `TIME`/`FPS` elements, WRAM polling, telemetry manifest block, and telemetry CSS
from the shared player and gallery. Retain unrelated player work. The browser continues to provide
its existing running status, fidelity button, and fullscreen control.

## Implementation steps

- [x] Add the video-specific Mode 7/Mode 1 bottom split and BG3 font/map setup.
- [x] Reserve dashboard palette entries in the reel asset generator and regenerate assets.
- [x] Remove the green palette-224 diagnostic path; make uncovered Mode 7 samples black.
- [x] Recalculate the Mode 7 vertical matrix for a 256x192 video band (`M7D=$004b`).
- [x] Add target-side `MM:SS`, rolling FPS-in-tenths, and health-state formatting.
- [x] Update BG3 fields in the presentation VBlank after frame DMA.
- [x] Remove browser telemetry UI, manifest metadata, polling, and CSS without touching unrelated
  shared-player changes.
- [x] Capture an exact 256x224 steady-state screenshot proving the Mode 7/BG3 split and measured
  `30.1` display; retain title captures from the parent plan. Slip/error text uses the same fixed
  field and is covered by target-state inspection.
  dashboard states.
- [x] Re-run frame CRC, two-loop, exact cadence, deadline, fidelity, display-quality, gallery
  self-check, static-build, engine-drift, and Lighthouse gates.
- [x] Publish gallery release `v1.0.323` and verify live bytes against local artifacts.

## Implementation record

- `video_hud.h` owns BG3 map `$4000`, font `$5000`, and HDMA channels 1/2.
- The first attempted all-in-one formatter exposed a compiler register-allocation failure; the
  final implementation uses incremental clock state and 16-bit rolling deltas, keeping 32-bit
  cumulative diagnostic counters intact.
- The 1,200-VBlank target run retains 397 presentations, zero CRC failures, and zero deadline slips.
- Target `fps_tenths` is 301 at the gate (`30.1` at NTSC cadence).
- Gallery target self-check passes for 1,200 frames at the linked loop-gate offset `$0044`, with no
  force-blank bleed.
- Locally gated ROM SHA-256: `30f1c0834b2724f80363a86f77fe49e175720036cebe6e30da6dc4a6119e0d07`.
- Production workflow `30682613250` passed install, build, engine drift, page count, links,
  fullscreen, Cloudflare propagation, Lighthouse, CLS, and threshold gates.
- The live `v1.0.323` ROM has the exact same SHA-256 as the locally gated artifact.

## Acceptance gates

1. No green strip or green uncovered Mode 7 pixels appear at any point.
2. The title sequence still zooms, holds through validation, and spins into playback cleanly.
3. Video occupies scanlines 0 through 191; the tiled dashboard occupies 192 through 223.
4. Dashboard glyphs are unmistakably a non-Mode-7 BG3 layer at native 8x8 resolution.
5. `TIME` begins at `00:00`, advances from successful presentations, and crosses reel loops.
6. `FPS` settles near `30.0` from target counters and never shows a reset-induced 60 fps spike.
7. Slip and error conditions visibly replace the healthy state.
8. Decoded-frame CRCs, two-loop proof, cadence count, and screenshot fidelity still pass.
9. Other web-player ROMs have no telemetry fields and retain their prior layout.
10. The live ROM and player hashes exactly match the locally gated release.

## Explicit exclusions

- No browser-chrome time/FPS dashboard.
- No sprites for dashboard text.
- No text composited into SVX2 source frames.
- No active-display CGRAM writes.
- No LZSS video stream.
- No *Duck and Cover* or animated turtle sequence.

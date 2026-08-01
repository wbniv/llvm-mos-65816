# SVX2 Video Title Sequence and Player Dashboard

**Date:** 2026-07-31
**Status:** Implemented and locally verified
**Parent:** `2026-07-31-svx2-animated-video-cartridge.md`

## Goal

Finish the animated-video presentation around the verified SVX2 cartridge:

1. show an immediate animated title sequence instead of a black boot-validation interval; and
2. add elapsed video time (`MM:SS`) and measured frames per second to the web player's dashboard.

The title and dashboard must describe the real running cartridge. They must not weaken, bypass, or
replace the existing target CRC, two-loop, exact-cadence, and screenshot gates.

## Interaction mockups

[Open the interactive title and dashboard mockups](2026-07-31-svx2-video-title-and-dashboard/mockups.html).

The mockup provides selectable states for title zoom, validation hold, spin-out, healthy video,
paused playback, and a deadline slip. It also shows the responsive dashboard reflow separately so
the telemetry remains a stable unit on narrow screens.

## Title-screen sequence

Use the existing Mode 7 Waldo-font title system rather than introducing another font or splash
implementation.

- Primary line: `SVX2 VIDEO`
- Secondary line: `FASTROM 30 FPS`
- Enter with the existing zoom/fade animation.
- Keep the title visible while the cartridge performs its deliberately slow four-frame CRC and
  keyframe-reset validation.
- If validation fails, force blank and retain the existing nonzero diagnostic result; never spin
  into playback.
- Once validation passes, hold briefly, perform the existing 360-degree spin/zoom exit, rebuild the
  video Mode 7 state under force blank, and present frame zero on a fresh VBlank.
- Start playback-time and cadence accounting at the first video presentation, not at reset and not
  at title entry.

The title sequence adds startup VBlanks. Recalculate the 1,200-VBlank expected presentation count
from the NMI counter and update the regression to its new exact value. Do not merely increase the
test timeout or replace an exact assertion with a nonzero assertion.

## Dashboard ownership

Put the requested clock and FPS in the browser player's dashboard below the canvas, not inside the
80x56 video raster. Burning a HUD into the ROM would consume scarce image pixels/palette entries,
change every decoded CRC, and mix player instrumentation with the source footage.

The dashboard should read cartridge telemetry. It must not infer playback progress solely from
`requestAnimationFrame`, page wall time, or the nominal `30 fps` label.

## Telemetry contract

Expose stable target symbols and publish their WRAM offsets in the ROM manifest:

| Field | Width | Meaning |
|---|---:|---|
| `video_reel_presented_total` | 32 bit | Frames successfully DMA-presented since playback began |
| `video_reel_vblanks` | 32 bit | NMI/VBlank count; used for measured cadence |
| `video_reel_deadline_slips` | 16 bit | Presentation deadlines missed since playback began |
| `video_reel_frame` | 8 bit | Current embedded reel-frame index |
| `video_reel_result` | 8 bit | Existing runtime result/error state |

Use 32-bit cumulative counters so the dashboard remains correct beyond the roughly 36-minute wrap
of a 16-bit frame counter at 30 fps. Read each multi-byte counter coherently: either publish a
sequence byte around updates or read twice and accept only two identical snapshots.

## Time display

Display elapsed video time as `MM:SS`:

```text
TIME 03:27
```

- Compute media seconds as `presented_total / 30`, because the clock represents successfully
  presented video frames rather than time spent paused, backgrounded, validating, or on the title.
- Begin at `00:00` on the first presented video frame.
- Continue across the short embedded reel's loop boundary; do not reset every four frames.
- Support at least `00:00` through `99:59`; after that, retain a stable documented representation
  rather than overflowing into malformed text.
- Freeze when emulation is paused or the tab suspends the core, naturally following the cartridge
  counter.

## FPS display

Display a measured rolling presentation rate:

```text
FPS 30.0
```

- Sample `presented_total` and `video_reel_vblanks` together.
- Calculate FPS over a rolling interval of at least 30 VBlanks and preferably 60:
  `delta_presented * NTSC_VBLANK_HZ / delta_vblanks`.
- Use the actual NTSC rate configured by the player/core, not an assumed browser refresh rate.
- Show `—` until a complete measurement window exists.
- Show `0.0` or `PAUSED` when counters stop advancing; do not leave a stale live-looking rate.
- If `deadline_slips` becomes nonzero or `video_reel_result` becomes nonzero, surface that state
  beside the rate instead of continuing to show an unqualified healthy `30.0`.

The static title text may say `30 FPS` because 30 fps is the selected cadence. The dashboard value
is deliberately measured and may briefly vary during startup, throttling, or emulator slowdown.

## Web-player layout

Extend the existing status row without reducing the canvas or moving the fidelity button:

```text
running svx2-fastrom-video.sfc     TIME 00:12   FPS 30.0
[Verify fidelity] [Fullscreen]
```

On narrow screens, allow the telemetry fields to wrap as a unit below the running status. Use
tabular numerals so the dashboard does not jitter as digits change. Keep the telemetry accessible
as text and give updates an appropriate non-disruptive live-region policy.

The manifest should opt a ROM into this dashboard by declaring telemetry offsets and nominal
cadence. Other gallery ROMs must continue to work with no new required fields.

## Implementation steps

- [x] Integrate `m7splash_begin()` before target validation and `m7splash_end()` after validation.
- [x] Confirm NMI remains safe while the title is visible and the staged decoder temporarily
  changes CPU bank state.
- [x] Rebuild the ROM and record the new exact 1,200-VBlank presentation count: 397 (`0x018d`).
- [x] Capture title zoom, title hold, title spin-out, and first-video-frame screenshots.
- [x] Expand the cumulative presentation and VBlank counters to 32 bits without slowing the decode
  deadline path materially.
- [x] Add optional telemetry metadata to the gallery manifest; absent metadata remains supported.
- [x] Add reset-aware WRAM polling and rolling FPS calculation to the shared web player.
- [x] Add `MM:SS` and measured FPS fields to the dashboard with responsive styling.
- [x] Exercise time/FPS startup, ROM reset, paused, health, and missing-metadata paths in the local
  browser integration; reset windows are discarded rather than displayed as unsigned-rate spikes.
- [x] Run the ROM CRC/two-loop/cadence/fidelity suite and the complete gallery build/self-check.
- [x] Replace the published ROM and deploy the updated player only after every gate passes
  (gallery release `v1.0.320`).

## Verification record

- ROM SHA-256: `8d31ca0bf52c9efffd0afe39c97b72ff81b7b5b788a80f949e853f84ef8dc0bf`
- 1,200-VBlank target run: result `0`, loop gate `0`, CRC failures `0`, deadline slips `0`,
  presentations `397` (`0x018d`).
- Frame-zero fidelity: exact pixel agreement `90.4402%`, mean absolute error `2.0452`.
- Gallery self-check: `svx2-fastrom-video PASS (1200 frames, want 0x00)`.
- Gallery static build: 122 pages built successfully.
- Production deployment: release `v1.0.320`, workflow `30681155267`; engine drift, links,
  propagation, Lighthouse, CLS, and threshold gates all passed.
- Live ROM and player bytes exactly match the committed release artifacts.
- Dashboard reset regression: a cartridge reset returns to `TIME 00:00 / FPS —`; it cannot turn
  a decreasing 32-bit counter into a false multi-billion-frame delta.

## Acceptance gates

1. A clean boot shows title pixels promptly; the slow validation interval is never a black screen.
2. The title visibly zooms in, remains readable during validation, spins out, and hands off without
   a stale title tile, palette flash, or black-frame gap.
3. The first video frame still passes its decoded CRC and host screenshot comparison.
4. Two complete reel loops pass with zero CRC failures and zero deadline slips at 30 fps.
5. The new exact presentation count is stable across three clean 1,200-VBlank emulator runs.
6. `TIME` advances from successful presentations, freezes while paused, and does not reset on a
   reel loop.
7. `FPS` converges to the measured 30 fps cadence and reports pause/error/slip states honestly.
8. ROMs without telemetry metadata retain the existing dashboard and behavior.
9. The exact locally verified ROM hash matches the live gallery download.

## Explicit exclusions

- No *Duck and Cover* or animated turtle material.
- No LZSS video stream.
- No dashboard burned into the source raster.
- No FPS derived only from browser animation callbacks.
- No claimed 60 fps until the full stage/decode/present scheduler reaches zero deadline slips.

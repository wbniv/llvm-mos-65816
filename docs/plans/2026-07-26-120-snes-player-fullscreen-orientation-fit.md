# #120 — SNES player fullscreen orientation fit

**Status:** IMPLEMENTED, LOCAL VALIDATION COMPLETE (2026-07-26). The shared marked controller is
installed in both site player copies; JavaScript syntax, byte-identical controller parity, and both
Astro production builds pass. Physical-phone rotation smoke testing and deployment remain.

Mockups: [responsive fullscreen fit](2026-07-26-120-snes-player-fullscreen-orientation-fit/fullscreen-orientation-mockups.html)

## Goal

Make the shared bsnes-jg player show the complete 256×224 SNES picture in fullscreen at every phone
orientation. Rotating a fullscreen phone from landscape to portrait must resize and recenter the
canvas; it must never crop the top or bottom, stretch the 8:7 picture, or place pixels under a notch,
home indicator, or browser overlay. Apply the same behavior to `biohack.net` and `indri.studio`.

## Current failure

The fullscreen CSS injected by `biohack.net/public/play/app.js` makes the canvas `height:100%` and
only constrains `max-width:100vw`:

```css
.rp-screen:fullscreen canvas {
  width: auto;
  height: 100%;
  max-width: 100vw;
}
```

That happens to fit a landscape viewport because height is usually the limiting dimension. After a
phone rotates to portrait, width becomes the limiting dimension, but the declared full-height canvas
does not recompute as a single aspect-ratio-preserving fit. Depending on the mobile fullscreen
implementation, the result is an over-tall replaced element or a stale pre-rotation size centered
inside a shorter visual viewport. Both clip the top and bottom.

There are two additional drift hazards:

- `100vh` describes the layout viewport on several mobile browsers, not necessarily the currently
  visible fullscreen area. The visual viewport changes during rotation and browser chrome
  transitions.
- The installed player files have diverged. biohack.net owns a fullscreen controller in `app.js`;
  indri.studio has a Fullscreen button but its installed `app.js` does not contain the same
  controller. A fix copied into only one site will regress again.

This is a presentation bug, not a bsnes framebuffer crop bug. Keep the shared eight-row bsnes-jg
overscan crop unchanged.

## Layout contract

Fullscreen is a black fitting stage. The SNES frame is a centered, undistorted rectangle entirely
inside the stage's usable visual viewport.

Given usable width `W`, usable height `H`, source width `SW=256`, and source height `SH=224`:

```text
scale = min(W / SW, H / SH)
canvasWidth  = floor(SW * scale)
canvasHeight = floor(SH * scale)
```

The calculation must use the wrapper's measured content box after safe-area padding, not an assumed
screen orientation and not `screen.width/screen.height`.

- Portrait: width normally limits; black letterbox space remains above and below.
- Landscape: height normally limits; black pillarbox space remains left and right.
- Square/split-screen/foldable: the same `min()` rule applies without a named orientation.
- If the viewport is smaller than 256×224, downscale. Otherwise upscale as far as the limiting
  dimension permits.
- Preserve exactly `256 / 224 == 8 / 7`; a one-pixel floor from integer CSS sizing is acceptable.
- The full canvas must remain inside `env(safe-area-inset-*)`.

## Implementation

### 1. Make one fullscreen controller authoritative

Move the fullscreen behavior in `public/play/app.js` into named, testable helpers rather than a
one-off injected CSS string:

- `enterPlayerFullscreen(wrapper)`
- `exitPlayerFullscreen()`
- `fitFullscreenCanvas()`
- `scheduleFullscreenFit()` (one `requestAnimationFrame`, coalescing duplicate events)

Keep standard and WebKit API aliases. Fullscreen continues to target `.rp-screen`, not the canvas,
so the black stage fills the display and owns safe-area padding.

The installed copies must be updated together:

- `biohack.net/public/play/app.js`
- `indri.studio/public/apps/llvm-mos-65816/play/app.js`

Prefer promoting the player asset to one canonical source plus a checked sync command. If that is
too large for this patch, add a byte-for-byte/fullscreen-block parity assertion to both existing
sync/build checks so the copies cannot silently diverge.

### 2. Use a safe fullscreen stage

Inject or ship equivalent unscoped rules:

```css
.rp-screen:fullscreen,
.rp-screen:-webkit-full-screen {
  box-sizing: border-box;
  display: grid;
  place-items: center;
  width: 100%;
  height: 100%;
  margin: 0;
  padding:
    env(safe-area-inset-top, 0px)
    env(safe-area-inset-right, 0px)
    env(safe-area-inset-bottom, 0px)
    env(safe-area-inset-left, 0px);
  overflow: hidden;
  background: #000;
  border: 0;
  border-radius: 0;
}

.rp-screen:fullscreen canvas,
.rp-screen:-webkit-full-screen canvas {
  display: block;
  flex: none;
  width: var(--bjg-fs-width, auto);
  height: var(--bjg-fs-height, auto);
  max-width: 100%;
  max-height: 100%;
  image-rendering: pixelated;
}
```

Do not use `width:100vw`, `height:100vh`, or `height:100%` on the canvas. The wrapper supplied by
the Fullscreen API is already the stage; measured dimensions are more reliable than viewport units.

### 3. Refit on every visual-viewport change

While fullscreen is active, `fitFullscreenCanvas()`:

1. reads `wrapper.clientWidth/clientHeight`;
2. subtracts computed padding for all four safe-area edges;
3. computes the contained 8:7 size with the formula above;
4. writes integer-pixel `--bjg-fs-width` and `--bjg-fs-height` properties; and
5. leaves the backing canvas at 256×224 (or the core's current output dimensions). Only CSS display
   size changes.

Schedule a refit on:

- `fullscreenchange` and `webkitfullscreenchange`;
- `window.resize`;
- `visualViewport.resize` when available;
- `visualViewport.scroll` while fullscreen, because iOS can move the visible viewport without a
  layout resize; and
- `orientationchange` as a compatibility signal.

Run one fit immediately on entry and one on the next two animation frames. Some mobile browsers
report the old dimensions for the fullscreen-change event and settle after rotation; the
requestAnimationFrame coalescer prevents event storms. Remove listeners and the two CSS properties
on exit so normal embedded sizing remains untouched.

Do not restart the emulator, recreate the canvas, or alter its backing dimensions during a fit.
Rotation must not reset game state, audio, controller state, or the fidelity check.

### 4. Handle fullscreen lifecycle details

- Keep the button label synchronized after browser-initiated exit.
- Hide the button when neither standard nor WebKit fullscreen is supported.
- Treat a rejected fullscreen promise as a no-op and restore the button label.
- Never lock orientation; portrait and landscape are both supported layouts.
- Prevent body scrolling only through fullscreen-stage containment; do not leave global body styles
  behind after exit.
- Preserve keyboard controls and future touch-control overlays. If touch controls are later placed
  inside `.rp-screen`, reserve their measured region before fitting instead of overlaying them on
  the SNES picture.

## Mockup decisions

The linked HTML mockup shows:

1. landscape fullscreen with the full picture height visible and symmetric side bars;
2. portrait fullscreen with the full picture width visible and symmetric top/bottom letterboxing;
3. a notched portrait viewport where the fit uses only the safe rectangle; and
4. a test-only video-extent frame drawn outside the canvas; and
5. the incorrect old `height:100%` portrait result for direct comparison.

The black bars are intentional. Filling every viewport edge would require either cropping or
distorting an 8:7 image, both explicitly rejected.

## Test-only video extent frame

Add an opt-in fullscreen diagnostic that makes the exact CSS canvas bounds
unambiguous on a physical phone. Enable it with a stable player query parameter
such as `?video-frame=1`; normal embeds remain visually unchanged.

When enabled in fullscreen:

- draw one-pixel, high-contrast cyan rules immediately **outside** the top and
  bottom canvas edges, so the diagnostic never replaces an SNES pixel;
- add subtler one-pixel side rules as well, making all four extents measurable
  while keeping top/bottom visually dominant;
- keep the rules attached to the fitted canvas box so they move on every
  orientation/safe-area refit;
- render above the black fullscreen stage but below any future touch controls;
- do not alter the canvas backing resolution, contained-size calculation,
  emulator output, pointer coordinates, or screenshot/fidelity hashes; and
- expose the diagnostic identically on biohack.net and indri.studio.

The frame must disappear on fullscreen exit and must never appear without the
explicit test flag. It is a player overlay for layout testing, not a border
drawn by the ROM.

## Verification

### Automated layout test

Extract the pure fit calculation and test at least:

| Viewport / usable box | Expected contained result |
|---|---|
| 844×390 | 445×390 (height-limited, allowing integer floor) |
| 390×844 | 390×341 (width-limited) |
| 393×852 with 59px top + 34px bottom | 393×343 inside the 759px safe height |
| 320×320 | 320×280 |
| 240×180 | 205×180 |

For every case assert:

- `canvasWidth <= usableWidth`;
- `canvasHeight <= usableHeight`;
- neither edge is negative after centering;
- aspect-ratio error is at most one CSS pixel; and
- rotating twice returns to the original dimensions without accumulating rounding error.

Add a browser test using a mocked Fullscreen API and mutable `visualViewport`. Start in landscape,
rotate to portrait, and assert that the canvas's bounding box stays wholly within the wrapper on
both axes. Assert that emulator boot/load is called zero times during the rotation.

With `video-frame=1`, also assert the diagnostic bounds equal the fitted
canvas bounds on entry and after both rotation directions. Verify the rules
remain outside the canvas content box and that disabling the query flag
produces no diagnostic element or style.

### Manual device matrix

Test a live ROM that draws on the first and last visible scanlines:

- iPhone Safari, portrait → landscape → portrait while remaining fullscreen;
- Android Chrome, the same rotation sequence;
- Android Firefox if Fullscreen API support is exposed;
- desktop Chrome, Firefox, and Safari at tall, wide, and resized fullscreen windows;
- a device with a notch/home indicator; and
- exit/re-enter fullscreen after rotation.

At every stop, the top and bottom SNES scanlines must be visible, the picture must remain 8:7, and
the ROM must continue from the same frame.

## Acceptance criteria

- No clipping on any edge after entering fullscreen or rotating in fullscreen.
- No stretching; the SNES image remains 8:7.
- The opt-in fullscreen extent frame exposes the exact top, bottom, left, and
  right video boundaries without covering output pixels.
- Safe-area insets are respected.
- Portrait and landscape refit without leaving fullscreen or restarting the core.
- Normal inline player layout is unchanged.
- Fullscreen behavior and installed player code are equivalent on biohack.net and indri.studio.
- Both site builds and fullscreen-handler contract checks pass.
- Production smoke test confirms the same ROM and orientation sequence on both sites.

## Rollout

1. Implement and test in the canonical player asset.
2. Sync the asset into both site repositories.
3. Build both sites.
4. Deploy one site and perform the phone rotation smoke test.
5. Deploy the second site and repeat the same test.
6. Add the parity check before considering the issue closed.

## Implementation record

Implemented in:

- `biohack.net/public/play/app.js`
- `indri.studio/public/apps/llvm-mos-65816/play/app.js`

Both files contain the same 110-line block delimited by `BEGIN SHARED FULLSCREEN CONTROLLER` and
`END SHARED FULLSCREEN CONTROLLER`. The implementation:

- replaces the old `height:100%` canvas sizing;
- measures the fullscreen wrapper after safe-area padding;
- writes contained integer CSS width/height variables without changing the 256×224 backing store;
- responds to standard/WebKit fullscreen, resize, orientation, and Visual Viewport events;
- performs three animation-frame fits to cover stale dimensions during mobile rotation;
- cleans up listeners when Astro loads a replacement player script; and
- restores normal embedded sizing on fullscreen exit.

Validation completed:

- `node --check` passes for both installed `app.js` files;
- extracted marked blocks compare byte-for-byte;
- `git diff --check` passes in both site repositories;
- biohack.net Astro production build passes (117 pages); and
- indri.studio Astro production build passes (132 pages).

Still required before marking the issue closed: the manual device matrix above, especially
landscape → portrait while remaining fullscreen on iPhone Safari and Android Chrome.

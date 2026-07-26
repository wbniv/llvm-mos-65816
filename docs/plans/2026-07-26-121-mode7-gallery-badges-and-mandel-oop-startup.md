# #121 — Mode 7 gallery badges and a responsive `mandel-oop` startup

**Status:** IMPLEMENTED LOCALLY (2026-07-26)

Mockups: [Mode 7 badges and `mandel-oop` startup storyboard](2026-07-26-121-mode7-gallery-badges-and-mandel-oop-startup/mode7-gallery-and-startup-mockups.html)

## Goal

Make Mode 7 visible as a first-class capability in both SNES galleries, and repair the published
Mode 7 Mandelbrot (OOP) experience:

1. every gallery screenshot for a demo that genuinely drives Mode 7 carries a compact `7` badge;
2. `mandel-oop` always shows and completes its Mode 7 title sequence;
3. after the title, the ROM immediately shows animated progress instead of a long black screen;
4. the Mandelbrot is progressively calculated and revealed without weakening its OOP verification
   purpose or its `corpus_result == 0x204F` differential gate; and
5. rebuilt ROMs, previews, metadata, and gallery UI remain equivalent on `biohack.net` and
   `indri.studio`.

## Audit findings

### Mode 7 inventory

Do not infer Mode 7 from a title, category, screenshot, or filename. The source audit found these
nine published programs that call `m7_begin()`, `m7splash()`, or directly select `BGMODE_7`:

| Source | Published slug | Why it qualifies |
|---|---|---|
| `examples/snes/avalanche.c` | `avalanche` | Mode 7 matrix display |
| `examples/snes/blossom.c` | `blossom` | Mode 7 plot band with HDMA mode split |
| `examples/snes/buddha.c` | `buddhabrot` | Mode 7 density buffer |
| `examples/snes/julia.c` | `julia` | Mode 7 fractal and affine animation |
| `examples/snes/lzss-gallery.c` | `lzss-gallery` | Mode 7 artwork with HDMA caption split |
| `examples/snes/mandel-display.c` | `mandel-display` | canonical Mode 7 fixed-point Mandelbrot |
| `examples/snes/mandel-double.c` | `mandel-double` | Mode 7 double-precision Mandelbrot |
| `examples/snes/mandel-float.c` | `mandel-float` | Mode 7 soft-float Mandelbrot |
| `examples/snes/mandel-oop.c` | `mandel-oop` | Mode 7 implemented as a `Drawable` |

This list is intentionally narrower than “graphics demos.” For example, a bitmap canvas or a title
card rendered by the ordinary BG title system does not make the demo a Mode 7 demo. A Mode 7 title
alone is also insufficient; the demo display itself must use Mode 7.

### Gallery data currently has no display-mode field

The galleries already render screenshot overlays such as the centered play affordance and
indri.studio's top-right `bug found` badge, but neither metadata model records the SNES background
mode:

- biohack.net defines its gallery records inline in `src/pages/snes/index.astro`;
- indri.studio defines `SnesDemo` records in `src/data/snes-demos.ts`.

Adding the badge independently from two hard-coded slug sets would create another drift point.
Record the capability in metadata and render from that field.

### `mandel-oop` blocks under force-blank

The current startup sequence is:

```text
m7splash(...)                         title owns Mode 7
display_init(...)                     force-blank and reset PPU
display_add(MandelLayer)
  -> _mandel_reserve(...)
       setup Mode 7
       compute all 64×56 cells         3,584 mandel_cell() calls
       CRC the full far buffer
       upload all rows
first display_frame()                 finally release force-blank
```

`Drawable::reserve()` is therefore doing slow application work that must finish before the screen
can unblank. The result is indistinguishable from a hang after the title. It also contradicts the
published gallery copy, which says `mandel-oop` “reveals coarse-to-fine.”

The title and post-title problems must be tested separately. The shared `m7splash()` is used
successfully by other Mode 7 demos, so do not rewrite `m7title.h` based only on the black compute
period. First capture the current ROM at title, handoff, early-compute, and final frames to determine
whether the title is genuinely absent/corrupt in the failing published ROM or merely followed by
such a long blank that the whole startup reads as broken.

## Part 1 — gallery `7` badge

The linked mockup shows the badge in both site card treatments, including the worst-case card with
both the top-left `7` badge and indri.studio's top-right `bug found` badge. Treat its positions,
minimum sizes, and non-overlap behavior as the visual acceptance reference.

### Metadata

Add an explicit optional field to both gallery record shapes:

```ts
displayMode?: 7
```

Use a number rather than `mode7: true` so the data can later represent other noteworthy hardware
modes without adding one boolean per mode. Set `displayMode: 7` on exactly the nine audited slugs.
Omit it everywhere else.

For indri.studio, update `SnesDemo` and its generated/static records. For biohack.net, update the
inline `demos` record type/data. Longer-term, the gallery metadata should have one canonical
machine-readable source, but that migration is not required to ship this focused change.

Add a repository check that compares the `displayMode: 7` slug set against the source audit or a
committed expected list. The two website sets must also compare equal after applying the
`buddha.c` → `buddhabrot` publishing rename.

### Badge presentation

Render the badge inside the screenshot wrapper, not in the card body:

```astro
{d.displayMode === 7 && (
  <span class="gl-mode7-badge" title="Mode 7 display" aria-label="Mode 7 display">7</span>
)}
```

Visual contract:

- a square or softly rounded `7`, not the text `Mode 7`;
- top-left, 6–8 CSS pixels from both edges;
- at least 24×24 CSS pixels on desktop and 22×22 on the smallest cards;
- dark translucent/navy background, bright cyan or mint numeral, and a one-pixel high-contrast
  border;
- subtle backdrop blur is optional, but the badge must remain legible without it;
- no animation at rest;
- `z-index` above the screenshot and hover shade;
- the centered play overlay remains centered and unobstructed;
- indri.studio's `bug found` badge remains top-right, so a card may show both without collision; and
- the numeral remains visible when the image is still loading by giving the screenshot wrapper its
  own positioning context and badge background.

Use identical dimensions and semantic labeling on both sites while allowing colors to map to each
site's existing design tokens.

### Gallery acceptance

- Exactly nine cards show a `7`.
- No non-Mode-7 card shows one.
- `buddhabrot`, not the non-published source slug `buddha`, receives the badge.
- Cards with both `7` and `bug found` remain readable at the narrowest gallery breakpoint.
- Keyboard/screen-reader link names do not redundantly read the numeral; the badge supplies
  `aria-label="Mode 7 display"`.
- Existing category filters, horizontal shelves, play overlays, lazy-loaded images, and card links
  remain unchanged.

## Part 2 — reproduce and pin the `mandel-oop` startup defect

Before changing the ROM:

1. Build `mandel-oop` using `dev/run.sh mandel-oop`.
2. Capture emulator frames at several semantic points rather than only the current 5,800-frame final
   screenshot:
   - early title zoom-in;
   - title at rest;
   - title spin-out;
   - immediately after title handoff;
   - one second after handoff; and
   - the first visible Mandelbrot frame.
3. Record elapsed SNES frames and host wall time from title completion to first visible content.
4. Compare the freshly built ROM with both deployed ROM files by SHA-256:
   - `biohack.net/public/play/roms/mandel-oop.sfc`
   - `indri.studio/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc`
5. Run the same capture through the browser WASM core to exclude a stale-ROM/cache-busting problem.

Add a timed-capture mode to `dev/mandel-oop.sh` or `jgxcheck` if necessary. A final screenshot and a
CRC at frame 5,800 prove eventual correctness but cannot prove a usable startup.

The regression must distinguish:

- title absent or corrupt;
- title completes, then black compute gap;
- no eventual output;
- output appears but the gallery poster masks/replaces the wrong frames; and
- deployed ROM differs from the verified build.

## Part 3 — repair the Mode 7 OOP title sequence

Keep the shared Mode 7 title API and the no-bare-register client discipline. The desired lifecycle is
explicit:

```text
App boot
  -> title begin
  -> title hold
  -> full spin/zoom/fade exit
  -> reset/reinitialize PPU for MandelLayer
  -> show loading scene on first display frame
  -> incremental Mandelbrot work
  -> final animated fractal
```

Implementation requirements:

1. Replace the convenience call in `main()` with an `App`-level method or explicit
   `m7splash_begin()` / `m7splash_end()` sequence only if timed captures prove the wrapper is the
   failing seam. Do not duplicate title animation code.
2. Keep all bare `REG_*`, `snes_*`, Mode 7 setup, and upload details inside the drawable/library
   boundary. `main()` remains a construction/run loop.
3. After `m7splash_end()`, perform a complete, deterministic handoff:
   - force-blank is active;
   - HDMA is disabled;
   - NMI ownership is known;
   - VRAM/CGRAM are reset or overwritten before use;
   - Mode 7 matrix/center/scroll are initialized;
   - `Display.tm` and hardware `TM` agree; and
   - the first `display_frame()` releases blank with valid loading art already present.
4. Add a title-timeline test that asserts non-black/title pixels during the title window and asserts
   that the title is gone before loading begins.
5. Preserve the shared title's visual language: `OOP DRAWABLE` / `MANDELBROT`, zoom-in, hold, full
   spin-out, and clean fade/handoff.

If the fresh ROM already shows the title correctly, do not manufacture a title-library rewrite.
Treat the verified title timeline plus corrected immediate post-title loading scene as the fix, and
replace stale deployed ROMs.

## Part 4 — immediate feedback and incremental calculation

### Move computation out of `reserve()`

`_mandel_reserve()` must become bounded setup only:

- configure Mode 7;
- clear/initialize tilemap and palette;
- install a small deterministic loading texture;
- initialize the far framebuffer and work-state metadata;
- set the matrix/center/scroll;
- return quickly enough that the first `display_frame()` unblanks immediately.

It must not compute the full 64×56 grid, CRC the final buffer, or upload all seven final tile rows.

Add an explicit `MandelBuild` state owned by `MandelLayer` or `MandelApp`:

```c
typedef enum {
  MANDEL_LOADING_COARSE,
  MANDEL_LOADING_MEDIUM,
  MANDEL_LOADING_FINE,
  MANDEL_LOADING_FINAL,
  MANDEL_READY
} MandelBuildPhase;

typedef struct {
  MandelBuildPhase phase;
  uint8_t x, y;
  uint16_t cells_done;
  uint16_t cells_total;
  uint16_t crc;
} MandelBuild;
```

Keep this a real object/method seam. The hot `mandel_cell()` loop remains static dispatch; the
drawable virtual call remains coarse-grained.

### Feedback design

Show valid output on the first post-title display frame. Use two layers of feedback:

1. **Animated loading field:** a tiny prebuilt Mode 7 checker/radar/tunnel pattern already in VRAM.
   Animate it using the same matrix/palette machinery the final demo is meant to prove. A gentle
   pulse/rotation makes it obvious that the console and emulator are alive even before one fractal
   row completes.
2. **Progressive fractal reveal:** calculate and upload increasingly refined previews:
   `8×7 → 16×14 → 32×28 → 64×56`, matching the canonical procedural demo's published behavior.
   Completed cells/rows replace the loading texture. Never clear back to black between passes.

The animation must continue during every compute phase. Avoid a textual “loading” screen that itself
freezes; motion is the feedback.

The linked storyboard is the visual contract for the transition: title at rest → full geometric
title exit → immediate animated loading field → coarse preview growing over that field → final
Mandelbrot. It deliberately contains no black panel between title exit and loading.

Optional status treatment, if it fits without weakening the Mode 7 demonstration:

- reserve one small sprite or Mode 1 HDMA band for `CALC 25%`; or
- encode an eight-step progress rail into a fixed Mode 7 tile row.

The visual animation and progressive reveal are required; text is not.

### Work budgeting

Do not guess the number of cells per frame. Instrument `mandel_cell()` cost on the emulator and choose
a budget that:

- returns to `display_frame()` frequently enough for visibly continuous motion;
- never performs PPU writes during active display;
- uses the existing fresh-vblank queue/flush rules;
- completes materially sooner than the current perceived hang; and
- reaches the final CRC comfortably before the published fidelity-check frame.

Start measurement with 1–4 final-resolution cells per update and a larger budget for coarse passes.
If one cell can exceed a frame, “60 fps” is not a meaningful target; instead require a visible matrix
or palette update at least every 100–150 ms. Record measured worst-case cadence and total
time-to-first-preview/time-to-final-frame in the plan's implementation record.

Use a persistent upload buffer. When a row or tile row becomes ready, enqueue only that completed
region for the next vblank. Never point an upload queue entry at stack storage.

### Finalization

When the 64×56 pass completes:

1. finish the CRC over the canonical row-major far buffer;
2. latch `corpus_result == 0x204F`;
3. switch to `MANDEL_READY`;
4. remove any loading/status artifact;
5. keep the final Mode 7 spin, zoom breathing, and palette cycling running forever.

The final framebuffer bytes and CRC must be identical to the current oracle. Only scheduling and
presentation change.

## OOP and correctness constraints

- `main()` gains no bare `REG_*`, `snes_*`, `upq_*`, `vram_*`, or scene internals.
- No virtual dispatch is added per pixel or per Mandelbrot iteration.
- The render layer remains a `Drawable`.
- Loading/build state is owned, initialized, and advanced through object methods.
- The far buffer remains at its platform-defined high-WRAM location and continues exercising far
  stores and loads.
- Default build remains unsupported where far pointers require `+mos-a16`; do not weaken the gate by
  moving the framebuffer near merely to simplify loading.
- `-verify-machineinstrs` and the indirect-dispatch audit remain clean.
- Host oracle, target CRC, and final visual output remain unchanged.

## Website copy and preview updates

The current gallery key line for `mandel-oop` claims “reveals coarse-to-fine, then spins and zooms,”
which the source does not presently do. After implementation it should become accurate. Update both
sites to describe the visible startup explicitly, for example:

> Self-running — animated build, coarse-to-fine reveal, then Mode 7 spin and zoom

Regenerate `mandel-oop.png` from the final ready state, not the loading scene. The `7` badge is HTML
UI and must not be burned into the PNG.

Rebuild and sync `mandel-oop.sfc` to both sites. Recompute:

- ROM content hashes/cache-busters;
- manifest `selfcheck.off` from the new map;
- `selfcheck.frames` if the incremental schedule changes latch time; and
- indri.studio's mirrored/generated demo metadata.

Never update the offset from a map unless the built ROM is byte-identical to the ROM copied into the
site.

## Verification matrix

### ROM gates

- Host oracle still returns `0x204F`.
- `dev/run.sh mandel-oop` passes `+mos-a16` on bsnes-jg.
- MAME passes when the external SPC700 IPL is available.
- Three final captures are byte-identical.
- `-verify-machineinstrs` passes.
- No-bare-functions audit passes.
- Indirect-call count remains within the intended coarse OOP design.

### Startup/timeline gates

Capture and assert all of:

| Window | Expected screen |
|---|---|
| title zoom-in | readable title pixels, changing scale |
| title hold | `OOP DRAWABLE` / `MANDELBROT` at rest |
| title exit | rotating/shrinking title, not gameplay |
| first post-title frame | non-black animated loading field |
| early compute | loading motion plus partial coarse preview |
| refinement | monotonically increasing fractal detail |
| ready | complete Mandelbrot, continuous spin/zoom/palette cycle |

Add a simple frame-difference assertion during loading: at least two captures before the first
preview must differ, proving that the feedback is genuinely animated. Add a coverage assertion that
the first and last image rows eventually become non-loading pixels.

### Website gates

- Exactly nine `7` badges on each gallery.
- Badge slug sets match between sites.
- Both Astro builds pass.
- Both deployed `mandel-oop` ROMs match the verified build SHA-256.
- Both manifests verify `0x204F` at their declared offset/frame.
- Browser smoke test sees title → loading animation → progressive image → ready animation.
- Cache-busted ROM and preview URLs change in the built HTML.

## Files expected to change

### Compiler/demo repository

- `examples/snes/mandel-oop.c`
- possibly a focused loading/progress helper under `examples/snes/snesgfx/`
- `dev/mandel-oop.sh`
- `dev/jgxcheck.cpp` only if timed multi-frame capture support is missing
- `docs/plans/2026-07-26-121-mode7-gallery-badges-and-mandel-oop-startup.md`

### biohack.net

- `src/pages/snes/index.astro`
- `src/pages/snes/mandel-oop.astro`
- `public/play/roms/mandel-oop.sfc`
- `public/play/roms/manifest.json`
- `public/play/preview/mandel-oop.png`
- gallery metadata/parity tests

### indri.studio

- `src/data/snes-demos.ts`
- `src/pages/apps/llvm-mos-65816/snes/index.astro`
- `public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc`
- `public/apps/llvm-mos-65816/play/roms/manifest.json`
- `public/apps/llvm-mos-65816/play/preview/mandel-oop.png`
- gallery metadata/parity tests

## Rollout

1. Capture and classify the current `mandel-oop` failure.
2. Implement bounded reserve, the loading animation, and incremental passes.
3. Prove the title/loading/final timeline and the unchanged `0x204F` gate.
4. Add `displayMode: 7`, the badge, and the nine-slug assertions to both galleries.
5. Rebuild the ROM and ready-state preview once.
6. Copy identical assets and synchronized manifest values to both sites.
7. Build and verify both sites locally.
8. Deploy one site, perform a cold-cache browser timeline test, then deploy the other.
9. Record measured title duration, time to first visible loading frame, time to first coarse preview,
   time to final frame, ROM SHA-256, and production release tags in this plan.

## Acceptance criteria

- Both galleries show an accessible `7` badge on exactly the nine audited Mode 7 screenshots.
- The two badge sets cannot silently drift.
- `mandel-oop` visibly shows and completes the shared Mode 7 title sequence.
- The first post-title frame is visible and animated; there is no prolonged black interval.
- The fractal visibly refines from coarse to final resolution.
- Final animation remains the current spin/zoom/palette cycle.
- Final framebuffer and `corpus_result == 0x204F` remain unchanged.
- The OOP/no-bare-functions verification purpose remains intact.
- Both sites ship byte-identical verified ROMs and equivalent metadata/UI.

## Implementation record

- `mandel-oop` now leaves `reserve()` after painting a Mode 7 checker field; its drawable advances
  one source row per display frame through `8×7 → 16×14 → 32×28 → 64×56`.
- The shared `m7splash("OOP DRAWABLE", "MANDELBROT", 90)` title lifecycle remains intact; the
  post-title force-blank compute gap was the broken seam.
- `dev/run.sh mandel-oop` passes `-verify-machineinstrs`, the single coarse indirect-dispatch gate,
  and bsnes-jg at 5,800 frames with `corpus_result == 0x204F`.
- Verified ROM SHA-256: `98d39a8b69f45b5845f24f047ed3603584ea723d43f7258822bcb85f5f5172bf`.
- `corpus_result` moved to WRAM offset `0x895`; both manifests and indri.studio metadata use that
  offset and retain the 5,800-frame fidelity check.
- Both galleries carry `displayMode: 7` on exactly the nine audited slugs and render the accessible
  top-left badge. Both Astro production builds pass.
- MAME remains skipped because the external SPC700 IPL is not installed.

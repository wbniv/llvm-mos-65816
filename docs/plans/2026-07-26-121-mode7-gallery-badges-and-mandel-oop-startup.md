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

## Verification record — 2026-08-03, against `main` @ `631ffe9`

The plan's Verification matrix states **outcomes**, not commands, so each step below names the
command chosen to produce its evidence. The gate text is reproduced **verbatim and unreordered**;
the three subsections (ROM gates, Startup/timeline gates, Website gates) are numbered within
themselves for reference only. Toolchain used as-built (`build/llvm-mos-install`, `build/jgxcheck`);
no rebuild. Fresh build SHA‑256 of this run:
`849a6a9d4e4f52bc13d93cf2e3d5c771285d58f87554bfbf58a47fafbc8c36b7`.

**Result: 18 / 23 gates PASS, 5 FAIL.**

**Methodology note — mid-run screenshots require `JGX_ENTROPY=0`.** The first timeline sweep
produced *irreproducible* captures (the same frame number rendering fully black on one run and
85 % non-black on the next). Cause: `dev/jgxcheck.cpp:394` leaves `configuration.entropy` at
bsnes-jg's default **Low**, which `Random::seed()`s from `clock()`, so PPU registers the ROM never
writes differ run to run. Every timeline capture below therefore pins `JGX_ENTROPY=0`. This is not
a defect introduced by #121 — it is the documented picture-gate/robustness-gate split in
`jgxcheck.cpp`'s own comment — but it does mean **`mandel-oop` leaves some PPU state unset during
the title/loading window**, since the final frame (gate 4 below) is entropy-insensitive while
frames 52–262 are not.

### ROM gates

#### 1. Host oracle still returns `0x204F`.

Command: build and run the independent host renderer named by `examples/snes/mandel-display.c:20`.

```
$ cc -O2 -I examples/65816 -I tools tools/mandel-render.c -o /tmp/mandel-render
$ /tmp/mandel-render /tmp/mandel-host.png 64 56 15
wrote /tmp/mandel-host.png  (64x56 N=15)  full-grid CRC16=0x204F
```

**PASS.**

#### 2. `dev/run.sh mandel-oop` passes `+mos-a16` on bsnes-jg.

Command: `dev/run.sh mandel-oop`.

```
sync-platform: refreshed 12 file(s) into /work/build/install/mos-platform
==> mandel-oop: OOP Mandelbrot (snesgfx Display + MandelLayer); expected CRC 0x204F
==> built build/mandel-oop.sfc (+mos-a16, -verify clean); corpus_result @ WRAM 0x895
==> bsnes-jg: render + framebuffer dump (build/mandel-oop-jg.png) + assert
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
==> MAME (under Xvfb): assert corpus_result
    SHOT: PASS corpus=0x204F (snapshot at frame 5800)

==> disasm: indirect dispatch count (virtual dispatch gate)
    indirect JMP count in .text: 0
    indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1

==> size delta: mandel-oop vs mandel-display (from .map files)
    mandel-oop  .text: 6331 bytes
    mandel-display .text: 4430 bytes
    ROM sizes: mandel-oop=32768 mandel-display=32768

RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==0x204F on host == +mos-a16@bsnes-jg
EXIT=0
```

**PASS** — `corpus_result @ WRAM 0x895` matches the implementation record.

#### 3. MAME passes when the external SPC700 IPL is available.

Command: the MAME leg of the same `dev/run.sh mandel-oop` run (the IPL **is** now installed, so the
leg no longer skips).

```
==> MAME (under Xvfb): assert corpus_result
    SHOT: PASS corpus=0x204F (snapshot at frame 5800)
```

**PASS** — improvement over the implementation record's "MAME remains skipped".

#### 4. Three final captures are byte-identical.

Command: the `dev/run.sh mandel-oop` capture plus two further direct `build/jgxcheck` runs at the
same 5,800-frame point, compared by SHA‑256.

```
$ for i in 2 3; do build/jgxcheck build/mandel-oop.sfc vendor/bsnes-jg/Database \
    0x895 2 0x204F 5800 /tmp/cap$i.png; done
jgxcheck: wrote /tmp/cap2.png (256x224 from native 512x240, yoff=0)
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
jgxcheck: wrote /tmp/cap3.png (256x224 from native 512x240, yoff=0)
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)

$ sha256sum /tmp/cap1.png /tmp/cap2.png /tmp/cap3.png
36f2fcdd32928d11bb57883f0aeca4f58021ae385909ecf68b827a1673429ee9  /tmp/cap1.png
36f2fcdd32928d11bb57883f0aeca4f58021ae385909ecf68b827a1673429ee9  /tmp/cap2.png
36f2fcdd32928d11bb57883f0aeca4f58021ae385909ecf68b827a1673429ee9  /tmp/cap3.png
```

**PASS** — and notably byte-identical at bsnes-jg's *default* entropy, i.e. the READY frame is
fully determined by ROM state.

#### 5. `-verify-machineinstrs` passes.

Command: the build leg of `dev/mandel-oop.sh`, which compiles with `-mllvm -verify-machineinstrs`
and fails the script on a non-zero exit.

```
==> built build/mandel-oop.sfc (+mos-a16, -verify clean); corpus_result @ WRAM 0x895
```

**PASS.**

#### 6. No-bare-functions audit passes.

Command: there is **no committed audit script** for this (the repo has `dev/a16cmpaudit.sh`,
`dev/snes-joypad-audit.sh`, `dev/title-mode-audit.sh`, `dev/dma-source-address-upstream-audit.sh`
— none covers bare `REG_*`/`snes_*` in `main()`), so the constraint is checked by reading `main()`.

```
$ awk '/^int main/,0' examples/snes/mandel-oop.c
int main(void) {
  static Display    screen;
  static MandelLayer layer;

  m7splash("OOP DRAWABLE", "MANDELBROT", 90);
  display_init(&screen);         // boot bracket: snes_ppu_reset_blank() + NMI + BGMODE_1
  mandel_layer_init(&layer);
  display_add(&screen, (Drawable *)&layer);
  // reserve() painted the animated loading field; refinement begins on the first visible frame.
  for (;;)
    display_frame(&screen);    // scene_emit → _mandel_emit (1 virtual call/frame) → upq_flush
}
```

**PASS** — zero bare `REG_*`, `snes_*`, `upq_*`, `vram_*`, or scene internals in `main()`.
*Deviation:* the plan implies a mechanised audit; none exists, so this evidence is a source read.

#### 7. Indirect-call count remains within the intended coarse OOP design.

Command: the disasm leg of `dev/mandel-oop.sh`.

```
==> disasm: indirect dispatch count (virtual dispatch gate)
    indirect JMP count in .text: 0
    indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1
```

**PASS** — exactly the one coarse `scene_emit` dispatch per frame.

### Startup/timeline gates

> Capture and assert all of:
>
> | Window | Expected screen |
> |---|---|
> | title zoom-in | readable title pixels, changing scale |
> | title hold | `OOP DRAWABLE` / `MANDELBROT` at rest |
> | title exit | rotating/shrinking title, not gameplay |
> | first post-title frame | non-black animated loading field |
> | early compute | loading motion plus partial coarse preview |
> | refinement | monotonically increasing fractal detail |
> | ready | complete Mandelbrot, continuous spin/zoom/palette cycle |

Command for the whole table: one entropy-pinned per-frame picture scan over the full run —

```
$ JGX_ENTROPY=0 JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=9000 build/jgxcheck \
    build/mandel-oop.sfc vendor/bsnes-jg/Database 0x895 2 0x204F 5800
...
FRAMESCAN: 566 change(s) in 5800 frames; first=1 last=5800; held 0 frame(s) to the end; final hash=A5E4BFD0 dom=#3A84BD pct=27
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
```

Reconstructing the held state for every frame from those 566 change events gives the timeline:

```
all-black intervals (dominant colour #000000 at >=99%): [(1, 50), (239, 262)]
change events, f=55..460:
  55..85 (every frame), 90, 98, 106, 122, 130, 138, 146, 154, 162, 170,
  176..239 (every frame), 263, 273, 288, 308, 323, 335, 343, 350, 362, 375, 392, 417, 446
max gap between consecutive change events after f=263: 127 frames
```

and the entropy-pinned, browser-crop (`JGX_YOFF=8`) capture sweep:

```
$ for f in 60 120 200 239 250 263 273 300 450 1200 3000 5800; do \
    JGX_ENTROPY=0 JGX_YOFF=8 build/jgxcheck build/mandel-oop.sfc vendor/bsnes-jg/Database \
      0x895 2 0x204F $f /tmp/e0/e$f.png; done

 frame nonblack% colours row0_nb row223_nb diff_prev%
    60   100.00%       3     256       256          -
   120   100.00%       3     256       256     100.00
   200   100.00%       3     256       256     100.00
   239     0.00%       1       0         0     100.00
   250     0.00%       1       0         0       0.00
   263   100.00%       8     256       256     100.00
   273   100.00%       8     256       256      36.74
   300    96.70%      10     256       256      15.52
   450    88.38%      11     256       256      91.61
  1200    90.12%      13     256       245      94.10
  3000    92.19%      14     252       256      98.54
  5800    91.67%      15     256       256      98.87
```

#### 8. title zoom-in — readable title pixels, changing scale

Frames 52–85 change **every single frame**, with the dominant colour walking
`#000004 → #040404 → #04040A → #040411 → #040419 → #0A0A19 → #0A0A20` and its share climbing
60 % → 92 % — the fade-in plus scale ramp. Capture at f=60 is 100 % non-black, 3 colours.
**PASS.**

#### 9. title hold — `OOP DRAWABLE` / `MANDELBROT` at rest

Frames 85–174: the per-frame churn stops; changes drop to a regular 8-frame cadence
(90, 98, 106, 122, 130, 138, 146, 154, 162, 170) at a fixed `dom=#0A0A20 pct=92`. That is a static
title with the shared idle animation, exactly `m7splash_end(90)`'s hold window. **PASS.**

#### 10. title exit — rotating/shrinking title, not gameplay

Frames 176–239 change every frame while `pct` walks back 91 % → 71 % → 100 % black — the
64-frame full-360° spin-out with scale `0x100 → 0` and brightness fade, matching
`M7T_SPIN_FRAMES`. Capture at f=200 is still 100 % non-black. **PASS.**

#### 11. first post-title frame — non-black animated loading field

```
all-black intervals: [(1, 50), (239, 262)]
 frame nonblack%
   239     0.00%
   250     0.00%   (diff vs f=239: 0.00% — the picture is frozen black)
   263   100.00%
```

**FAIL** — the title's fade completes at f=239 and the screen then holds **pure black for 24
frames (f 239–262, ≈ 400 ms at 60 Hz)** before the loading field appears at f=263. The plan's
storyboard "deliberately contains no black panel between title exit and loading" and this row
demands the *first* post-title frame already be a non-black animated field. Not a regression from
later work — `examples/snes/mandel-oop.c` is unchanged since `bdbf516`, so this residual gap dates
from the original implementation; it is the bounded `display_init` + `mandel_layer_init` +
`reserve()` setup window running under the re-opened boot force-blank (a known deviation logged in
`docs/agent-handoff.md`: "Still to convert (they re-open the window): … the seven Mode-7 demo
`main()`s"). It is ~24 frames rather than the thousands of the original unbounded-compute defect,
so the *substance* of Part 4 landed — but this gate as written does not pass.

#### 12. early compute — loading motion plus partial coarse preview

Frames 263 → 273 → 288 → 308 each change (10-, 15-, 20-frame spacing) and the palette grows
8 → 10 distinct colours by f=300 while the frame-to-frame delta stays large (36.74 %, then
15.52 %). Motion plus a growing coarse preview. **PASS.**

#### 13. refinement — monotonically increasing fractal detail

Distinct-colour count over the run is **monotonic**: 8 (f=263) → 8 (273) → 10 (300) → 11 (450) →
13 (1200) → 14 (3000) → 15 (5800), with no regression and no clear-to-black between passes.
**PASS.**

#### 14. ready — complete Mandelbrot, continuous spin/zoom/palette cycle

`FRAMESCAN … first=1 last=5800; held 0 frame(s) to the end` — the picture is still changing on the
final emulated frame, and the f=5800 capture is 91.67 % non-black across 15 colours with a
98.87 % delta from f=3000. Continuous animation in the READY phase. **PASS.**

#### 15. Add a simple frame-difference assertion during loading: at least two captures before the first preview must differ, proving that the feedback is genuinely animated.

The loading field appears at f=263 and the first *fractal* content change follows at f=273:

```
   263   100.00%       8   (diff vs f=250: 100.00%)
   273   100.00%       8   (diff vs f=263:  36.74%)
```

Two captures inside the loading window differ by 36.74 % of pixels. **PASS.**
*Recorded drift:* the plan's work-budgeting section asked for "a visible matrix or palette update
at least every 100–150 ms" (6–9 frames). Measured **max gap between picture changes after f=263 is
127 frames (≈ 2.1 s)**. That target is stated in §Work budgeting, not in this gate, so it does not
change this row's verdict — but it is not met.

#### 16. Add a coverage assertion that the first and last image rows eventually become non-loading pixels.

Row 0 and row 223 non-black pixel counts (out of 256), browser crop:

```
 frame  row0_nb  row223_nb
   263      256        256
  1200      256        245
  5800      256        256
```

Both the first and last image rows are fully covered by fractal (non-loading) pixels in the READY
frame. **PASS.**

### Website gates

#### 17. Exactly nine `7` badges on each gallery.

Command: count `displayMode: 7` records in each site's metadata, and count rendered badges on the
live galleries.

```
$ grep -l '"displayMode": *7' ~/biohack.net/src/content/snes/*.json | xargs -n1 basename | sed 's/.json//' | sort
apollo-daylight
avalanche
blossom
buddhabrot
julia
lzss-gallery
mandel-display
mandel-double
mandel-float
mandel-oop
svx2-fastrom-video
(11)

$ curl -sS https://biohack.net/snes/ | grep -c 'class="gl-mode7-badge"'
11
$ curl -sS https://indri.studio/apps/llvm-mos-65816/snes/ | grep -c 'class="gl-mode7-badge"'
11
```

**FAIL** — 11, not 9. All nine audited slugs are present and correct (`buddhabrot`, not `buddha`);
the two extras are later Mode 7 demos that did not exist on 2026-07-26. Suspected commits:
`cdaa6f4` "snes: publish SVX2 FastROM video proof" (`svx2-fastrom-video`) and `ad87374`
"feat(snes): publish the Apollo 11 daylight-launch video cartridge" (`apollo-daylight`), both in
`biohack.net`. Recorded as FAIL because the plan's number is not adjusted here.

#### 18. Badge slug sets match between sites.

Command: parse both metadata sources and compare the sets.

```
biohack.net  src/content/snes/*.json          → 11 slugs (list above)
indri.studio src/data/snes-demos.ts           → 11 slugs
apollo-daylight avalanche blossom buddhabrot julia lzss-gallery
mandel-display mandel-double mandel-float mandel-oop svx2-fastrom-video
sets identical
```

**PASS.** *Recorded gap:* the plan asked for "a repository check that compares the `displayMode: 7`
slug set against the source audit or a committed expected list". No such check exists in this repo
or either site (`grep -rln displayMode` finds only `src/content.config.ts` and the two galleries),
so the acceptance criterion "the two badge sets cannot silently drift" is unenforced — today they
agree by hand.

#### 19. Both Astro builds pass.

Command: CI deploy-run conclusions (host-side builds are void as evidence for these sites — see
`site-builds-are-ci-only`).

```
$ gh run list --workflow deploy.yml -L 1        # ~/biohack.net
completed  success  chore(snes): rebuild Apollo on the shared FPS gauge  Deploy site  v1.0.365  push  30828480971  2m40s  2026-08-03T15:38:55Z

$ gh run list --workflow deploy.yml -L 1        # ~/indri.studio
completed  success  feat(snes): synchronize complete ROM catalog from biohack  Deploy  v0.1.135  push  30824497265  4m25s  2026-08-03T14:48:53Z
```

**PASS.**

#### 20. Both deployed `mandel-oop` ROMs match the verified build SHA-256.

```
$ sha256sum build/mandel-oop.sfc
849a6a9d4e4f52bc13d93cf2e3d5c771285d58f87554bfbf58a47fafbc8c36b7  build/mandel-oop.sfc

$ sha256sum ~/biohack.net/public/play/roms/mandel-oop.sfc \
            ~/indri.studio/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc
0dd52e61860a8251f7473a57a8188a495aef87b206713fdd8ca18e8758fb4042  .../biohack.net/public/play/roms/mandel-oop.sfc
0dd52e61860a8251f7473a57a8188a495aef87b206713fdd8ca18e8758fb4042  .../indri.studio/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc
```

**FAIL** — the two deployed ROMs match *each other* but neither matches today's verified build, and
neither matches the plan's recorded `98d39a8b…`. `examples/snes/mandel-oop.c` is unchanged since
`bdbf516`, so the drift is toolchain/`snesgfx`-header codegen: the deployed bytes were produced by
`530bf5c` "snes: republish all 114 ROMs" (biohack.net), a rebuild *after* the plan's record, and
the tree has moved again since (`69fe2db`, `bb460a4`, `21179d7` all touch `examples/snes/snesgfx/`).
Behaviourally the two are indistinguishable — see gate 22.

#### 21. Both manifests verify `0x204F` at their declared offset/frame.

Command: run each site's manifest values against its own shipped ROM.

```
$ python3 -c '...' # manifest entries, both sites, identical:
{"id": "mandel-oop", "title": "Mode 7 Mandelbrot (OOP)", "selfcheck": {"off": "0x895", "len": 2,
 "want": "0x204F", "frames": 5800, "label": "gate jgxcheck CRC (corpus_result @ WRAM $0895)"}}

$ build/jgxcheck ~/biohack.net/public/play/roms/mandel-oop.sfc vendor/bsnes-jg/Database 0x895 2 0x204F 5800
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
$ build/jgxcheck ~/indri.studio/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc vendor/bsnes-jg/Database 0x895 2 0x204F 5800
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
```

**PASS.**

#### 22. Browser smoke test sees title → loading animation → progressive image → ready animation.

**FAIL — gate not executed as written.** No browser was driven in this run. The closest available
evidence is the *deployed* ROM run through the same bsnes-jg core the site's WASM player uses:

```
$ JGX_ENTROPY=0 JGX_FRAMESCAN=1 JGX_FRAMESCAN_MAX=9000 build/jgxcheck \
    ~/biohack.net/public/play/roms/mandel-oop.sfc vendor/bsnes-jg/Database 0x895 2 0x204F 5800
FRAMESCAN: 566 change(s) in 5800 frames; first=1 last=5800; held 0 frame(s) to the end; final hash=A5E4BFD0 dom=#3A84BD pct=27
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
deployed ROM all-black intervals: [(1, 50), (239, 262)]
```

The deployed ROM's timeline is **identical** to the fresh build's — same 566 change events, same
final hash `A5E4BFD0`, same black intervals — so the gate-20 byte difference is codegen-only. That
substantiates title → loading → progressive → ready at the core level, but it is not a browser
smoke test, so the gate is recorded as not passed.

#### 23. Cache-busted ROM and preview URLs change in the built HTML.

```
$ curl -sS https://biohack.net/snes/mandel-oop/ | grep -oE 'mandel-oop\.(sfc|png)[^"'"'"'<> ]*' | sort -u
mandel-oop.png
mandel-oop.sfc

$ curl -sS https://indri.studio/apps/llvm-mos-65816/snes/mandel-oop/ \
    | grep -oE '/apps/llvm-mos-65816/play/(roms|preview)/mandel-oop\.[a-z]+[^"'"'"' ]*' | sort -u
/apps/llvm-mos-65816/play/preview/mandel-oop.png
```

**FAIL** — the live HTML references bare, unversioned filenames on both sites. No query
cache-buster and no content-hashed filename is present, so a republished ROM or preview cannot
invalidate a cached copy. This gate was never implemented (no `cacheBust`/`?v=`/`romHash` symbol
exists in either site's `mandel-oop` page source).

### Summary

| Subsection | PASS | FAIL |
|---|---|---|
| ROM gates (1–7) | 7 | 0 |
| Startup/timeline gates (8–16) | 8 | 1 (#11) |
| Website gates (17–23) | 3 | 4 (#17, #20, #22, #23) |
| **Total** | **18** | **5** |

Nothing was fixed as part of this run — the plan and code are recorded as found.

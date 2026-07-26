# Mode 7 title-screen sweep

**Status:** planned (2026-07-26)

## Goal

Make title behavior describe the demo renderer:

- Only demos whose actual presentation uses SNES Mode 7 get the Mode 7 zoom-in / spin-out title.
- Every true Mode 7 demo uses that title consistently.
- Non-Mode-7 demos use the regular `TitleLayer` fly-in/fall-out title.
- Hilbert's visible title is exactly **HILBERT CURVE** and uses the regular title system, because its
  actual demo is a BG3 2bpp bitmap in `BGMODE_1`; its current `m7title.h` intro is a temporary Mode 7
  effect unrelated to the renderer.
- Title palette state never leaks into the demo palette. In particular, remove the red title-palette
  residue seen around Hilbert and prove each demo installs its own intended CGRAM values after the
  title exits.

The change is presentation-only. Corpus hashes (`selfcheck.want`) must remain unchanged, although
`corpus_result` link addresses (`selfcheck.off`) may move after relinking.

## Inventory and classification

Source behavior, not gallery category or visual appearance, determines membership.

### True Mode 7 demos — migrate to `m7title.h`

| ROM slug | Source | Current title | Planned title |
|---|---|---|---|
| `avalanche` | `examples/snes/avalanche.c` | `splash16` | `m7splash` |
| `blossom` | `examples/snes/blossom.c` | `splash16` | `m7splash` |
| `buddhabrot` | `examples/snes/buddha.c` | `splash16` | `m7splash` |
| `julia` | `examples/snes/julia.c` | `splash16` | `m7splash` |
| `mandel-display` | `examples/snes/mandel-display.c` | `splash16` | `m7splash` |
| `mandel-double` | `examples/snes/mandel-double.c` | `splash16` | `m7splash` |
| `mandel-float` | `examples/snes/mandel-float.c` | `splash16` | `m7splash` |
| `mandel-oop` | `examples/snes/mandel-oop.c` | none | `m7splash` |

These sources either call `m7_begin()` or explicitly select `BGMODE_7` for the running demo.
`mandel-oop` is included even though its Mode 7 setup is encapsulated in its drawable.

### Not Mode 7 — keep or migrate to regular `TitleLayer`

- `hilbert` renders through `BitmapCanvas` on BG3 in `BGMODE_1`. Replace its current
  `m7splash_begin("SPACE-FILLING", "HILBERT CURVE")` / `m7splash_end()` sequence with the regular
  `title_begin16` / `title_end` overlay after `app_init()`. The title must read **HILBERT CURVE**.
- `cordic` is also a BG3 `BGMODE_1` demo and must use the regular title, never `m7title.h`.
- Audit all remaining `examples/snes/*.c` so `m7title.h`, `m7splash*`, and direct title-time
  `BGMODE_7` use occur only in the eight-item allowlist above.

## Implementation

### 1. Make `m7title.h` safe as a shared Mode 7 intro

Before migrating callers, make its contract explicit and testable:

1. `m7splash_begin(subtitle, title)` renders the title argument at the zoom center and the subtitle
   above it. Keep argument naming and comments consistent so lines cannot be accidentally swapped.
2. `m7splash_end(hold)` completes the existing spin-out, returns in force blank, disables any title
   HDMA, and leaves VRAM/PPU state ready for the caller's normal `m7_begin()` setup.
3. Give the title an owned CGRAM palette (backdrop, bright title ink, dim subtitle ink). Do not depend
   on palette values left by a prior screen.
4. Treat title CGRAM as disposable: each caller must install its demo palette after the title.
   Add a source-level assertion/test that every migrated Mode 7 call site performs palette setup after
   `m7splash_end`, not before it.
5. Preserve the working zoom-in and 360-degree spin-out timing unless an emulator capture proves a
   regression.

### 2. Fix Hilbert first

1. Remove `#include "snesgfx/m7title.h"`.
2. Include `snesgfx/title_layer.h`.
3. Initialize `App` before showing the title, add a `TitleLayer` to its `Display`, and use:

   ```c
   title_begin16(&a.screen, &title, "SPACE-FILLING", "HILBERT CURVE");
   corpus_result = hilbert_gate_crc();
   title_end(&a.screen, &title, 90);
   ```

4. Confirm the title is literally **HILBERT CURVE**, centered and legible.
5. Confirm `bg3_pal` is installed after/through the normal display upload path and the rendered curve
   returns to its intended cyan/orange palette rather than inheriting red from the title.
6. Capture an early title frame and a post-title curve frame in bsnes-jg for visual review.

### 3. Migrate the eight true Mode 7 demos

For each inventory row:

1. Replace `title_layer.h` / `splash16()` with `m7title.h` / `m7splash()` (or
   `m7splash_begin` + gate computation + `m7splash_end` when the CRC intentionally runs behind the
   title).
2. Keep each demo's existing title/subtitle wording unless correcting an evident inversion; pass the
   short descriptor first and the demo name second.
3. Run the title before the demo's `m7_begin()` or Mode 7 drawable reservation.
4. Re-run all Mode 7 VRAM, tilemap, matrix, center, scroll, CGRAM, and HDMA initialization after the
   title exits. Never rely on title state carrying into the demo.
5. For `mandel-oop`, preserve the abstraction gate: `main()` must not gain bare `REG_*` or `snes_*`
   orchestration. The title helper may run before the `Display`/drawable scene is constructed.
6. For `mandel-double`, retain its far-ROM font placement and size-specific `-Oz` build. Its link must
   remain within bank `$00` while the font stays in bank `$01`; do not reintroduce a font-off escape.

### 4. Add structural regression checks

Add `dev/title-mode-audit.sh` (and invoke it from the relevant validation task) with two allowlists:

- Every source including `m7title.h` or calling `m7splash*` must be one of the eight true Mode 7
  sources.
- Every true Mode 7 source must call `m7splash*`.

The audit must also assert:

- `hilbert.c` contains the exact string `HILBERT CURVE`;
- `hilbert.c` and `cordic.c` use `title_layer.h`, not `m7title.h`;
- each Mode 7 source reinitializes its Mode 7 display and palette after the splash;
- `mandel-oop.c` retains its no-bare-register client-code gate.

This converts “only Mode 7 demos use the Mode 7 title” from a convention into a failing test.

## Build and verification

### Focused visual and correctness gates

1. Build and run Hilbert through its existing per-demo gate on bsnes-jg and MAME.
2. Capture:
   - a Hilbert regular-title frame showing **HILBERT CURVE**;
   - a Hilbert post-title frame proving the intended curve palette;
   - one representative Mode 7 title at rest;
   - one representative Mode 7 title during spin-out;
   - the same demo after `m7_begin()`, proving its own palette and transform were restored.
3. Run every existing per-demo gate for the eight Mode 7 demos. Gate hashes must match their host
   oracles, and blank-scan must show no force-blank band.
4. Run `dev/title-mode-audit.sh`.

### Relink all published ROMs

Because shared title headers are inline, rebuild/relink all 113 published ROMs, not only the nine
edited demos:

```sh
dev/publish-web-roms.sh --site /home/will/biohack.net
dev/sync-manifest-offsets.py --site /home/will/biohack.net
dev/verify-web-roms.sh --site /home/will/biohack.net
```

Acceptance:

- rebuild summary is `113 ok, 0 fail, 0 skip`;
- manifest sync reports `0 without a map`;
- verification reports `113 passed, 0 failed, 0 missing`;
- `mandel-double` is freshly built, not retained from an older publish;
- changed `selfcheck.off` values match the new maps; `selfcheck.want` values are unchanged.

## Gallery sync and deployment

1. Treat biohack.net's 113-ROM directory and manifest as the canonical rebuilt artifact set.
2. Mirror all `.sfc` files, `manifest.json`, preview images, and gallery metadata into
   `indri.studio/public/apps/llvm-mos-65816/play/`.
3. Rebuild indri.studio so `dist/` is generated from the new public assets; do not edit `dist/`
   manually.
4. Verify the two source ROM trees are filename-identical and SHA-256-identical (113/113), and that
   both galleries expose the same 113 slugs and self-check metadata.
5. Commit only intended source/ROM/manifest changes in each repository, preserving unrelated
   worktree edits.
6. Deploy both sites through their tag-driven publish tasks.
7. After deployment, fetch the live manifest and representative ROMs from both domains, compare
   hashes with local artifacts, and smoke-test:
   - Hilbert title and post-title palette;
   - Cordic regular title;
   - a representative Mode 7 zoom/spin-out;
   - `mandel-double`;
   - gallery index and per-demo routes on both domains.

## Definition of done

- Hilbert shows a regular title reading **HILBERT CURVE**, with no red palette leak.
- Cordic uses the regular title.
- Exactly the eight true Mode 7 demos use the Mode 7 zoom/spin-out title.
- All eight reinitialize their own Mode 7 state and palette after the title.
- All 113 ROMs are freshly relinked and pass the emulator/self-check/blank-scan gate.
- biohack.net and indri.studio contain byte-identical 113-ROM galleries and matching metadata.
- Both production deployments serve the new artifact hashes.

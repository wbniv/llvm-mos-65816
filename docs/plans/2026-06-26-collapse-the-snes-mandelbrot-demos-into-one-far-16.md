# Plan — collapse the SNES Mandelbrot demos into one far/16-bit tester

## Context

There are three SNES Mandelbrot example programs under `examples/snes/`:

- **`mandel-display.c`** — the canonical **tester**: it's what the publish/release gate
  (`task release-test` → `dev/release-test-inner.sh`) and `task mandel-shot` compile. Today it is
  deliberately **NEAR** (low-WRAM staging buffer) and builds on the **default 8-bit target** *and*
  `+mos-a16`, 64×56 N=15, gate CRC `0x204F` (host-derived). It exercises the fixed-point kernel but
  **never the far-pointer codegen** (`sta [dp]` / `lda [dp]`, 24-bit high-WRAM addressing).
- **`mandel-mode7.c`** — a 128×128 far/high-WRAM (`$7E2000`) Mode 7 renderer, `+mos-a16`-only, ~4 min
  emulated compute. The far-pointer showcase, but a heavy one-off.
- **`mandel-interactive.c`** — a baked-image Mode 7 joypad fly-around (depends on the generated
  `mandel_image.h` + `view.h`).

**Goal:** delete `mandel-mode7.c` and `mandel-interactive.c`, and convert the canonical tester
`mandel-display.c` to **16-bit (`+mos-a16`) far mode** so the publish gate actually exercises the
far-store/far-load path. User decision (this session): *"i want it 16 bit now anyway"* — so
`mandel-display` becomes **`+mos-a16`-only**, dropping its default-8bit leg. That's the intended
"better testing" win: the release gate gains coverage of a codegen path (24-bit far addressing) it
has zero coverage of today.

## Decisions

1. **`mandel-display.c` → far / `+mos-a16`-only.** Route the canonical pixel buffer through a far
   high-WRAM buffer (`$7E2000`) instead of the near staging buffer — mirroring `mandel-mode7.c` /
   `k_mandel_far.c`. Every canonical cell becomes a **far store**; the CRC and VRAM upload become
   **far loads**.
2. **Keep the 64×56 N=15 grid + the steady-state spin/zoom/colour-cycle animation.** This preserves
   the host-oracle CRC (`0x204F`) so the release gate, its fixtures, and the oracle need *no* CRC
   churn; keeps the gate fast (~1800 frames vs 128×128's ~14k); and keeps a nice animated screenshot.
   Grid size is irrelevant to whether the far codegen is exercised — 64×56 = 3584 far stores + far
   loads is ample coverage.
3. **Delete the two demos and their exclusive dependencies.** `mandel-interactive.c` is the only
   consumer of `view.h`, `mandel_image.h` (generated, gitignored), and `tools/mandel-bake.c`; remove
   them too (dead code otherwise). `sincos.h` and `mode7.h` stay (used by `mandel-display`).

## Files to change

### Convert — `examples/snes/mandel-display.c`
- Rewrite the header comment: it currently advertises "stays on the DEFAULT 65816 target … so the
  prebuilt toolchain builds it and it syncs to the web demo" — all now false. Describe it as the far
  high-WRAM Mode 7 tester, `+mos-a16`-only, and **include the literal marker `mos-a16-only`** in a
  comment — `dev/build.sh:87` greps for that string to drive `+mos-a16` and skip-if-unsupported.
- Add the far buffer: `static M7_FAR uint8_t *const fb = (M7_FAR uint8_t *)0x7E2000u;` (64×56 =
  3584 B; `M7_FAR` already comes from the included `mode7.h`). `$7E2000` is the same base
  `k_mandel_far.c`/`mandel-mode7.c` use.
- Canonical pass (current `mandel-display.c:146-166`): store each computed cell to `fb[j*DW+i]`
  (FAR STORE) instead of the incremental `crc_byte` + near `chrbuf` path; reveal each line by reading
  `fb[...]` (FAR LOAD) into VRAM (as `mandel-mode7.c:139-143` does). After the fill, set
  `corpus_result` from a `crc_fb()`-style CRC-16 over `fb` via FAR LOADs (mirror
  `mandel-mode7.c:49-57`). Result is still `0x204F` (same grid, same row-major order).
- Drop the now-unused `crc_byte()` helper; the coarse-preview passes (near `scratch` + `chrbuf`,
  `build_coarse_row`) stay unchanged — previews don't need far, keeping boot fast. `chrbuf` is still
  used by the coarse path.

### Delete
- `examples/snes/mandel-mode7.c`
- `examples/snes/mandel-interactive.c`
- `examples/snes/view.h` (interactive-only)
- `examples/snes/mandel_image.h` (generated, gitignored — remove from the working tree if present)
- `tools/mandel-bake.c` (only generates `mandel_image.h` for interactive)
- `dev/mandel-mode7.sh`, `dev/mandel-interactive.sh`

### Prune — `examples/snes/mode7.h`
Now only `mandel-display` includes it, and it uses just `M7_FAR`, `m7_begin`, `m7_tilemap_clear`,
`m7_tilemap_identity`, `m7_set_matrix/center/scroll`, `m7_show`, `M7_TILEMAP_WORDS`. Remove the
now-dead `m7_vbuf`, `M7_DEFINE_BUILD_VBUF`, `m7_dma_vbuf_to_vram`, `m7_dma_chr`, `m7_cgram_load`
(the static `m7_vbuf` pointer would otherwise risk an unused-variable warning), and refresh the
header comment (it currently describes sharing between the "static (Track 3b) and interactive" demos).

### Wiring — `Taskfile.yml`
- Delete the `mandel-mode7`, `mandel-interactive`, and `mandel-play` tasks.
- `mandel-mame`: drop `mandel-mode7` / `mandel-interactive` from the `ROM=` choices, the `case`
  arms, and the per-ROM notes (keep `mandel-display` + `k_mandel_far`).
- `mandel-shot` desc: fix "fat-pixel" → it renders via **Mode 7** into a **far high-WRAM buffer**
  (`+mos-a16`).
- `release-test` desc: change "compile … (default-8bit + +mos-a16)" → "+mos-a16 (far/16-bit; the
  tester is now a16-only)"; drop the stale `0x9103` (the oracle CRC is host-derived, `0x204F`).

### Wiring — `dev/run.sh`
Remove the `mandel-mode7` and `mandel-interactive` help blocks (≈ lines 48-56) and their dispatch
`case` arms, plus the `mandel-interactive` frame-budget note (≈ line 316). Keep `mandel-shot` and
`mandel-far`. Touch up the `mandel-shot` help wording (no longer "near"/default-target).

### Wiring — release gate (`dev/release-test-inner.sh`, `dev/test-release.sh`)
`mandel-display` can no longer build default-8bit. In `release-test-inner.sh`, make `mandel-display`
default to **a16-only**: in the `mandel-display)` case arm, if the caller left `A16=both`, set
`A16=1` with a `say()` note (`k_mandel` keeps `both`). Update the `A16` usage/desc text in
`release-test-inner.sh`, `dev/test-release.sh`, and the `Taskfile.yml` `release-test` desc to match.
`FRAMES` default (1800) stays — same 64×56 grid; bump only if the gate times out. The Docker rig
already COPYs `mode7.h` + `sincos.h` (`Dockerfile.release-test:49-50`) and the oracle is
grid-derived, so **no fixture or CRC change**.

### Wiring — build script + harness (found during execution)
- `dev/build.sh` baked `mandel_image.h` via `tools/mandel-bake.c` as a build step (would break
  `dev/run.sh build` once `mandel-bake.c` is gone) — **removed** the bake step; refreshed two
  `mandel-mode7.c` example-comments to `mandel-display.c`.
- `dev/jgxcheck.cpp` carried a `JGX_VIEW` input-differential path that `#include`d the now-deleted
  `view.h` (built only by the deleted `mandel-interactive.sh`) — **excised** all `JGX_VIEW` blocks
  (include, `g_script`/`parseScript`, scripted `pollInput`, the view-replay assert), leaving the plain
  framebuffer+CRC harness `mandel-shot` uses. Dropped the now-dead `MANDEL_FRAMES`/`JGX_SCRIPT`
  passthrough in `dev/run.sh`. Freshened the `sincos.h` header comment (no more `mandel_image.h`).

### Doc hygiene (keep historical plans; redirect dangling refs)
- `docs/handoffs/2026-06-24-snes-graphics-rendering.md` — repoint the Mode 7 worked-example from
  `mandel-mode7.c` to `mandel-display.c` (now the far Mode 7 example); note mode7/interactive removed.
- `docs/investigations/plan-index.md` — add **`(removed)` notes** to the mode7/interactive rows,
  matching how the mandel-zoom row was already collapsed (commit `077efb2`). **Do not delete** the
  historical plan files or their screenshots — they're the recorded contract/evidence.
- `TODO.md` — update the live Track 2/3a/3b lines (≈ 125/131/134) to record the consolidation; the
  done-section interactive/mode7 items stay as history. Triage any new `## Inbox` bullets the
  commit hook adds.

## Verification

1. **Build + differential the far tester locally:**
   ```
   dev/run.sh mandel-shot       # builds examples/snes/mandel-display.c (+mos-a16) and asserts
                                # corpus_result == host oracle on bsnes-jg + MAME
   ```
   Expect `RESULT: PASS … (CRC 0x204F)` and `build/mandel-{jg,mame,host}.png`.
2. **Confirm far opcodes are emitted** (the whole point):
   `"$TOOL/mos-clang" … -S mandel-display.c` (or `llvm-objdump -d build/mandel-display.sfc.elf`) and
   grep for the far store/load (`sta [dp]` / `lda [dp]`, opcodes `87` / `A7`) — as `dev/mandel-far.sh`
   does for `k_mandel_far`.
3. **Publish gate (a16-only path):**
   ```
   task release-test -- PROGRAM=mandel-display A16=1
   ```
   Expect the clean-room bsnes-jg run to assert `corpus_result == 0x204F`; and confirm
   `task release-test` with no args now defaults `mandel-display` to a16-only (no default-8bit
   compile attempt).
4. **No dangling references:**
   `grep -rn 'mandel-mode7\|mandel-interactive\|mandel-bake\|view\.h\|mandel_image\.h' Taskfile.yml dev/ examples/ tools/`
   returns only intended/historical hits (no live build wiring).
5. **CI smoke unaffected:** `.github/workflows/smoke.yml` builds `hello.c` + the corpus, not
   `mandel-display`, so a16-only changes nothing there — confirm by inspection.

## Deploy to website (after building) — `../indri.studio/`

The indri.studio product page hosts a **playable in-browser SNES demo** of `mandel-display.sfc`
(at `/apps/llvm-mos-65816/play/`) plus product-page screenshots. The ROM is bundled by a separate
repo, **`../bsnes-jg-wasm/`**, then synced into the site. After a green `mandel-shot` build, deploy
the new far ROM end-to-end:

1. **Refresh the bundle ROM.** Copy `build/mandel-display.sfc` →
   `../bsnes-jg-wasm/web/roms/mandel-display.sfc`.
2. **Fix the fidelity manifest** `../bsnes-jg-wasm/web/roms/manifest.json` — its `mandel-display`
   `selfcheck` mirrors `jgxcheck` (`off`, `len`, `want`, `frames`). `want` stays **`0x204F`**, but the
   globals layout changed, so **re-derive `corpus_result`'s WRAM offset** from the new
   `build/mandel-display.map` (`awk '$NF=="corpus_result"{print $1}'`) and update `off` (was `0x400`);
   bump `frames` (was `5200`) if the far build settles the CRC later. **Prune the stale ROM entries**
   (`mandel-zoom`, `mandel-mode7`, `mandel-interactive`) from the manifest and delete their orphan
   `web/roms/*.sfc` — those demos no longer exist.
3. **Preview image.** Regenerate `../bsnes-jg-wasm/web/preview/mandel-display.png`
   (`../bsnes-jg-wasm/make-preview.sh`) or drop in `build/mandel-jg.png`.
4. **Build + sync the bundle.** `../bsnes-jg-wasm/deploy-bundle.sh` → `dist-bundle`; then from
   `../indri.studio`, `scripts/sync-llvm-mos-emulator.sh` copies it into
   `public/apps/llvm-mos-65816/play/`.
5. **Product-page screenshots.** Copy `build/mandel-jg.png` →
   `indri.studio/src/assets/screenshots/llvm-mos-65816/mandel-jg.png`; **remove the stale
   `mandel-mode7-jg.png`** (the asset *and* its line in `src/content/apps/llvm-mos-65816.mdx`).
6. **Deploy.** From `../indri.studio`: `task deploy` (`pnpm build && pnpm wrangler deploy` — needs
   `CLOUDFLARE_API_TOKEN` from `.env`, via `task secrets-pull`). This publishes to Cloudflare —
   outward-facing, but explicitly requested.

Each repo (`llvm-mos-65816`, `bsnes-jg-wasm`, `indri.studio`) commits its own changes separately.

## On execution (per project conventions)
This file *is* the canonical plan (migrated from plan mode); the `TODO.md` entry is added under M2.
Stage only the files listed above; never stage `vendor/`, foreign patches, or `docs/transcripts/`.
The `bsnes-jg-wasm` and `indri.studio` deploy changes are committed in their own repos.

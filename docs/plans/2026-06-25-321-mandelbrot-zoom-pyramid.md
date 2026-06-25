# Plan — Mandelbrot zoom pyramid: increasing detail as you zoom in (#321 M2)

**Branch:** new worktree `wt/321-mandel-zoom` off `main` (implementation; this plan lands on `main`).
**Issue:** #321 (M2). Builds on the merged interactive demo
([`2026-06-25-321-interactive-mandelbrot-mode7.md`](2026-06-25-321-interactive-mandelbrot-mode7.md)).
Supplement to [`CLAUDE.md`](../../CLAUDE.md) + [`docs/agent-handoff.md`](../agent-handoff.md).

## Context

The interactive demo (`mandel-interactive`) boots instantly and flies around a **single** baked 128×128
image via Mode 7 hardware zoom — so zooming in just **magnifies pixels**; no new fractal detail appears.
This plan adds **true increasing detail on zoom-in**.

**Why not recompute on the SNES (the obvious idea, ruled out by measurement — Lesson 1):**
- **Speed.** A 128×128 escape buffer is ~14,400 frames (~4 min) of emulated compute (measured,
  `mandel-mode7`). Even 32×32 ≈ 15 s and 64×64 ≈ 1 min — a multi-second stall *per zoom step*, not
  real-time.
- **Precision.** The on-console kernel is Q5.10 fixed-point. A few zoom levels in, adjacent pixels are
  `< 1/1024` apart and the math runs out of bits — the SNES **cannot** compute deep detail at all.

## The idea — a pre-baked zoom *pyramid* (host computes, SNES displays)

The **host** computes a stack of `L` images, each a fresh Mandelbrot at **2× finer zoom** than the last
(`double` precision, arbitrarily deep), all centered on one interesting point; each is tiled into Mode 7
character order and baked into ROM. On the SNES, Mode 7 hardware-zooms the **current** level; when zoom
crosses a 2× threshold the ROM **DMAs the next (finer) level** and resets the Mode 7 scale, so zooming
continues into genuinely new structure. **Instant** (a DMA swap), and the SNES does **zero** fractal math —
so the depth is limited only by host precision, not Q5.10. This is the natural extension of the demo's
"bake host-side, display instantly" philosophy.

## Design

### Geometry & data
- **Center** `(cre, cim)` — one iconic deep-zoom point (candidate: the seahorse valley near
  `c = -0.743644 + 0.131826i`; finalize from the host render).
- **Level `k`** (`k = 0…L-1`) covers complex-plane window width `W0 / 2^k`, centered on `(cre,cim)`, rendered
  128×128. So level `k` is `2^k×` deeper than level 0.
- **Per-level iteration cap `N_k`** grows with depth (deeper boundaries need more iterations to resolve).
  Free — it's host compute only.
- **Normalized palette indices, one shared palette.** Each level's `N_k` differs, so the bake stores chr
  bytes as a **palette index** `0…NCOL-1` (escape `n` → `n*(NCOL-1)/N_k`), letting **all** levels share one
  `MANDEL_PAL[NCOL]` in CGRAM. (The current demo stores raw escape counts; the pyramid normalizes so the
  palette is level-independent.)

### Bake tool — `tools/mandel-bake-pyramid.c` (host)
Reuses `examples/65816/mandel.h`'s kernel **at host `double` precision** (a `#ifdef HOST` high-precision
path, or a parallel host renderer — the on-target kernel stays Q5.10 and is unused here). Emits generated
`examples/snes/pyramid_image.h` (gitignored, like `mandel_image.h`):
- `MANDEL_PYR_L`, `MANDEL_PYR_W/H` (=128), `MANDEL_NCOL`
- `LEVEL_0[…] … LEVEL_{L-1}[…]` — each a 128×128 tiled-chr array (16 KiB)
- `MANDEL_PAL[NCOL]`, `SINCOS[256]`
- `MANDEL_PYR_HASH[L]` — per-level host-reference hash (`img_hash16`), the gate values
A host PNG per level for the screenshot montage.

### Runtime level-swap — `examples/snes/mandel-zoom.c` (+mos-a16 / default)
Reuses `mode7.h` (`m7_dma_chr`, `m7_tilemap_clear/set`, matrix setters) and the `snes.h` joypad HAL.
- State: current level `lvl`, Mode 7 scale `s` (8.8). Base scale `S0 = 0x80` (image fills screen). Center
  pinned at `M7X=M7Y=64` for every level (zoom homes on the baked point).
- **Zoom in** (R): decrease `s`. When `s ≤ S0/2` and `lvl < L-1`: `m7_dma_chr(LEVEL[++lvl])`; `s = S0`.
- **Zoom out** (L): increase `s`. When `s ≥ 2·S0` and `lvl > 0`: `m7_dma_chr(LEVEL[--lvl])`; `s = S0`.
  (A small hysteresis band around the threshold avoids swap thrashing at the boundary.)
- At the deepest/shallowest level the scale just clamps (graceful: blocky magnify / smaller image).
- Pan is **within-level** only (Mode 7 scroll; detail exists only across the baked image) — secondary to
  zoom; may be disabled in v1. Select cycles palette; Start resets to `lvl=0, s=S0`.
- `view.h`-style split: a pure `zoom_step(pad, &z)` / `zoom_fold()` (level + scale + matrix) so the swap
  logic is host-replayable for the differential; `apply()` does the DMA + Mode 7 writes (target-only).

### ROM layout — the size question (drives the phasing)
Each 128×128 level is **16 KiB**. The platform today is a **single 32 KiB LoROM bank** (one level + code is
the current demo's exact fit). So a multi-level 128×128 pyramid needs a **bigger, multi-bank ROM**:

| levels (128×128) | chr data | + code/SDK | ROM (LoROM banks) | max zoom |
|---|---|---|---|---|
| 2 | 32 KiB | ~3 KiB | 64 KiB (2 banks) | 4× |
| 8 | 128 KiB | ~3 KiB | 256 KiB (8 banks) | 256× |
| 16 | 256 KiB | ~3 KiB | 512 KiB (16 banks) | 65536× |

**LoROM addressing for the DMA.** The chr DMA sources via an A-bus `bank:addr16`, so a level in a higher
bank is reachable — but LoROM has a 32 KiB hole per bank (only `$XX:8000–FFFF` is ROM), so level addresses
are **not** linear; the linker assigns each. Plan: place each level **bank-aligned** (its own bank, at
`$XX:8000`) so `addr16` is constant (`$8000`) and only the bank varies; a per-level **far symbol** yields
the 24-bit address, split into `A1B0 = addr>>16`, `A1T0 = addr` for the DMA. (Far-symbol static-init relocs
are the #320 packed24 path — see `2026-06-22-320-packed24-static-init-reloc-fix.md`.)

## Phases (de-risk the mechanic before the platform lift)

### Phase 1 — single-bank proof (NO platform change)
Fit a small pyramid in the **existing 32 KiB ROM** by dropping the per-level resolution to **64×64** (4 KiB
chr, 8×8 tiles): **~4 levels** (16 KiB) + code fit one bank → **16× deep zoom**, chunkier but with genuinely
increasing detail. Proves the whole chain — `mandel-bake-pyramid`, the level-swap runtime, the differential
gate, the screenshots — with zero linker work. Generalize `mode7.h` tiling to a parametric `W/H`.

### Phase 2 — multi-bank LoROM, full resolution + depth
Bump the SNES platform to **multi-bank LoROM** (target 256 KiB / 8 banks): extend `platforms/snes/link.ld`
to N banks (code + vectors + `romhdr` stay in bank 0; levels in banks 1…N, bank-aligned), teach
`tools/snes-checksum.py` the larger `rom_size_byte`, and wire the per-level far-symbol → DMA `bank:addr`.
Then bake **128×128 × 8 levels** = a 256× deep-zoom sequence at full resolution. (Check whether the #320
five-address-space / near-far code-model work already provides multi-bank pieces before writing new linker
script.)

## Verification (the differential bar — run each step, paste raw output, mark PASS/FAIL)

1. **Builds + fits.** `dev/run.sh mandel-zoom` bakes the pyramid, compiles `-verify-machineinstrs` clean;
   the `.map` shows all levels + code within the ROM region (Phase 1: 32 KiB; Phase 2: the N-bank region),
   no overflow.
2. **Per-level image correctness (host == default == `+mos-a16` == MAME).** The harness zooms to each level
   `k` and asserts the displayed chr hash (`corpus_result`) == `MANDEL_PYR_HASH[k]` (host reference) on
   bsnes-jg + MAME. A match per level ⇒ every baked level is the verified deeper Mandelbrot.
3. **Zoom / level-swap codegen differential.** Scripted input (R×M, L×M, …) replayed over the ROM's
   ground-truth pad log; the ROM folds `(lvl, s, matrix)` into a rolling CRC; `dev/jgxcheck.cpp` replays the
   pure `zoom_step`/`zoom_fold` and asserts host == target — gating the swap arithmetic (and any per-frame
   matrix math) under `+mos-a16` and default.
4. **Increasing-detail screenshots.** Capture frames at levels 0, k, L-1 (bsnes-jg + MAME); embed a montage
   under `docs/plans/screenshots/` showing structure resolving deeper at each step.
5. **No regression.** `mandel-interactive`, `mandel-mode7`, `k_mandel`, corpus, `build` stay green.
6. **Live play.** `task mandel-zoom-play` (build-if-needed + MAME window): hold R to dive, L to back out —
   detail refreshes at each level boundary.

## Risks / notes
- **Multi-bank LoROM (Phase 2) is the main lift** — linker script + `rom_size_byte` + the far-symbol→DMA
  `bank:addr` plumbing. Phase 1 deliberately avoids it to prove value first. **Measure, don't assume:** check
  the existing #320 address-space/code-model work for reusable multi-bank pieces before writing linker script.
- **Precision is the host's job** — the SNES never computes, so deep levels (beyond Q5.10's reach) are fine;
  the bake just needs `double` (or higher) and a growing `N_k`.
- **Zoom is centered on the baked point; pan is within-level.** This is a "dive into THIS spot" demo, not
  free pan-with-detail. Bake 2–3 targets if multiple dive points are wanted (×ROM).
- **Swap hysteresis** — without a dead-band around the 2× threshold, holding zoom exactly at a boundary can
  thrash level swaps; use a band (e.g. swap up at `S0/2`, down at `S0`).
- **+mos-a16 vs default** — like `mandel-interactive`, the upload is DMA-from-ROM (no far *pointer* in the
  hot path; the far-*symbol* address for the DMA is a const), so it should build both; confirm and gate both.

## Merge-back checklist
- [ ] Phase 1 artifacts: `tools/mandel-bake-pyramid.c`, `examples/snes/{mandel-zoom.c, pyramid.h}` (+ gitignored
      `pyramid_image.h`), `dev/mandel-zoom.sh`, `mode7.h` param-W/H, `dev/run.sh`/`Taskfile.yml` wiring, screenshots.
- [ ] Phase 2 artifacts: `platforms/snes/link.ld` (multi-bank), `tools/snes-checksum.py` (size byte), the
      per-level far-symbol→DMA plumbing.
- [ ] `TODO.md` entry + plan-index row.
- [ ] Merge `wt/321-mandel-zoom` → `main` (user-triggered / coordinate per policy).

# 60 fps sweep — which demos can get the trimerge treatment?

**Status:** investigation 2026-07-27 (user-directed, after the trimerge #99b/#99c arc). Question:
which of the ~113 published demos can be sped up / de-torn with the same fixes — and which fix?
Companion plans: [#99b](../plans/2026-07-27-99b-trimerge-visual-fix.md) (atomic single-v-blank
flush) · [#99c](../plans/2026-07-27-99c-trimerge-60fps-scroll-waterfall.md) (HDMA scroll-ring,
true 60 fps).

## The three fixes trimerge proved out

| Fix | What it does | Cost | Applies when |
|---|---|---|---|
| **F1 — atomic flush** | Paint the shadow over N frames but mark the whole canvas dirty once, at sweep end → one ≤4 KB DMA in ONE v-blank (`UPQ_VBLANK_BUDGET` 5100 B). Kills the multi-v-blank tear. | ~6-line mechanical change | Any band-sweep painter that marks dirty per band |
| **F2 — scroll-ring** | Content that *translates* stops being repainted: HDMA-banded `VOFS`/`HOFS` ring (`hdma_hscroll.h`), 1 px/frame, paint only the incoming row/column. True 60 fps. | per-demo redesign (#99c-sized) | Motion is a uniform translation |
| **F3 — cheap paint** | Kill hidden per-paint libcalls (`tm_fill32`'s 40 `__mulsi3` → incremental ramp) + stagger palette/HUD off the paint frame. | small, per-demo | Paint frame overruns v-blank (measured stall) |

## Methodology

- **Static pass** (all 115 sources): render surface (BitmapCanvas / text tilemap / Mode 7 / OAM),
  band-sweep painter presence, dirty-marking style (per-band vs full-canvas), `CANVAS_FLUSH_TILES`,
  pixel-plotter vs cell-filler, update function shape (history-SHIFT vs full-RECOMPUTE vs in-place).
- **Empirical pass** (published site ROMs, headless bsnes-jg): framebuffer deltas
  `d1` = % bytes differing between frames 500→501 (per-frame motion) and `d60` = 500→560 (motion at
  all). `d1 ≈ 0` + `d60 > 0` = stepped cadence; both ≈ 0 = static display (compute-then-hold);
  `d1 > 0` = already animating every frame.

## Headline findings

1. **19 demos carry trimerge's pre-#99b tearing bug** — cell-grid band painters that mark dirty
   per band, so every sweep is smeared across 4+ v-blanks: `bitweave`, `borrowlad`, `compass`,
   `crcwall`, `keycmp64`, `lfsr2`, `modexp256`, `mvscrl`, `oddmask`, `ovmove`, `pcooker`,
   `permscat`, `ropeedit`, `rotkal`, `rotslab`, `satcast`, `sbitfld`, `uarteye`, `ucmprank`.
   All have `CANVAS_FLUSH_TILES 256` and a ≤4 KB canvas → **F1 applies mechanically to every one**.
2. **10 band painters already flush atomically** (the #99b pattern predated in newer demos):
   `bitcensus`, `dither`, `funnelkal`, `gouraud`, `metaball`, `nrecip`, `perlin`, `radix`,
   `rotozoom`, `spaceship`.
3. **True scroll-ring (F2) candidates are few** — most band painters recompute a *function* of
   phase (rotations, permutations, kaleidoscopes, rank recolors) that does not translate:
   - `ovmove` (16×24 mosaic scrolled by overlapping memmoves — the display window translates),
   - `mvscrl` (memmove scroll slabs — ditto; NB the memmove IS the stress target, the ring only
     replaces the *display* repaint),
   - `truncstair` (staircases of a scrolling linear ramp — horizontal `HOFS` bands),
   - `lfsr2` (noise fields "scrolling as the registers advance" — verify the drift is a real
     translation before committing),
   - `ropeedit` / `rotslab` shift by *variable* amounts (cursor jumps, runtime k) — poor fits.
4. **Pixel-plotters and compute-then-hold demos need nothing**: plotters (`epicycles`, `fft`,
   `bhut`, …) update sparsely per frame; `pcooker`/`modexp256`-style demos compute once and
   palette-cycle (though both still mark per-band → F1 still worth it for their occasional
   recompute).
5. **Some demos are already 60 fps**: `life` (d1 = 31 %!), `cgrade` (16.6 %), `bitcensus` (5.8 %),
   `1d-ca`, `multibase`, `newton` — per-frame animation confirmed empirically.
6. Mode 7 demos (`lzss-gallery`, `mandel-oop`, + the badge set) have their own display pipeline —
   out of scope here.

## Full table

`pattern`: band = cell-grid band-sweep painter · plot = incremental pixel plotter · canvas = canvas
without band sweeps · text = text/tilemap or bespoke · m7 = Mode 7. `mark`: how the canvas dirty
span is marked (band painters only). `d1`/`d60`: measured framebuffer delta % (… = measurement
pending, filled as the sweep completes). Verdict `F1` = atomic flush, `F2` = scroll-ring, `F3` =
cheap paint; `ok` = no action warranted.

| demo | category | pattern | mark | d1 % | d60 % | verdict |
|---|---|---|---|---|---|---|
| 1d-ca | cellular | text | — | 2.78 | 2.69 | ok — already per-frame |
| adpcm | signals | plot | — | 0.0 | 10.9 | ok |
| avalanche | bignums | text | — | 0.0 | 29.61 | stepped by design (odometer ticks) |
| bf-vm | classics | text | — | 0.0 | 0.0 | static-at-500 (program output) |
| bhut | physics | plot | — | 0.0 | 1.28 | ok |
| bitcensus | ciphers | band | FULL | 5.8 | 21.32 | ok — atomic + per-frame |
| bitshuffle | ciphers | canvas | — | 0.07 | 0.93 | ok |
| bitweave | ciphers | band | PER-BAND | 0.0 | 28.6 | **F1** |
| blossom | classics | text | — | 0.0 | 2.46 | ok |
| boids | physics | text/OAM | — | 0.0 | 0.0 | static-at-500 (attract loop timing) |
| borrowlad | bignums | band | PER-BAND | 3.46 | 14.43 | **F1** |
| buddha | — | text | — | 0.0 | 0.0 | ok (accumulator render) |
| burning-ship | fractals | text | — | 0.0 | 0.0 | compute-then-hold |
| cardioid | motion | canvas | — | 0.0 | 3.22 | ok |
| cgrade | rendering | canvas | — | 16.55 | 24.82 | ok — already per-frame |
| compass | motion | band | PER-BAND | 0.0 | 0.04 | **F1** (rotation → no F2) |
| cordic | motion | plot | — | 0.0 | 0.24 | ok |
| cosmzoom | bignums | canvas | — | 0.0 | 1.15 | ok |
| cpu6502 | classics | text | — | 0.0 | 11.24 | ok (full-screen tilemap) |
| crctex | rendering | canvas | — | 0.0 | 22.47 | stepped; atomic already |
| crcwall | ciphers | band | PER-BAND | 5.36 | 24.11 | **F1** (hash marble → no F2) |
| critters | classics | plot | — | 0.0 | 0.08 | ok |
| dctbloom | signals | plot | — | 0.0 | 8.29 | ok |
| dhmix | bignums | canvas | — | 0.0 | 29.49 | stepped; atomic already |
| disbits | ciphers | canvas | — | 0.0 | 13.5 | stepped; atomic already |
| dither | rendering | band | FULL | 0.0 | 0.0 | ok — atomic; static display |
| divclock | classics | plot | — | 0.0 | 0.26 | ok |
| domcol | fractals | canvas | — | 0.0 | 96.43 | stepped (full re-render per step) |
| doom-fire | cellular | text | — | 0.0 | 8.29 | stepped by design |
| double-pendulum | physics | plot | — | 0.0 | 0.12 | ok |
| duff | algorithms | canvas | — | 0.22 | 14.96 | ok |
| editdist | algorithms | canvas | — | 0.0 | 10.83 | stepped; atomic already |
| epicycles | motion | plot | — | 0.0 | 0.2 | ok |
| fabsridge | rendering | canvas | — | 0.0 | 1.0 | ok |
| factorial | bignums | text | — | 0.0 | 3.23 | ok |
| fenwick | algorithms | canvas | — | 0.0 | 11.94 | stepped; atomic already |
| fft | signals | plot | — | 0.0 | 0.0 | ok |
| fn-plot | fractals | plot | — | 0.0 | 0.0 | compute-then-hold |
| funnelkal | rendering | band | FULL | 0.0 | 4.69 | ok — atomic |
| gf256 | ciphers | canvas | — | 0.0 | 18.84 | stepped; atomic already |
| gouraud | rendering | band | FULL | 0.0 | 95.53 | ok — atomic |
| grid3d | cellular | plot | — | 0.0 | 64.7 | stepped by design |
| harmonograph | motion | canvas | — | 0.02 | 0.25 | ok |
| hdr-bloom | rendering | text | — | 0.0 | 36.58 | stepped by design |
| hilbert | motion | plot | — | 0.07 | 1.33 | ok |
| huffman | algorithms | canvas | — | 0.22 | 15.07 | ok |
| hull | algorithms | band | ? | 0.0 | 1.56 | verify marking, then F1 if per-band |
| iir-scope | signals | canvas | — | 0.0 | 1.37 | ok |
| invaders | — | text/OAM | — | 0.08 | 4.83 | ok (game loop) |
| julia | fractals | text | — | 0.0 | 0.0 | compute-then-hold |
| keycmp64 | algorithms | band | PER-BAND | 0.0 | 16.13 | **F1** (reorder → no F2) |
| lfsr2 | ciphers | band | PER-BAND | 3.92 | 14.75 | **F1** now; F2 if drift is a translation |
| life | cellular | text | — | 31.03 | 96.09 | ok — already 60 fps |
| lsystem | fractals | canvas | — | 0.0 | 0.0 | compute-then-hold |
| lzdec | algorithms | canvas | — | 0.0 | 18.97 | stepped; atomic already |
| lzss-gallery | algorithms | m7 | — | 0.0 | 0.0 | out of scope (own pipeline) |
| mandel-display | fractals | text | — | 0.0 | 33.63 | out of scope |
| mandel-double | fractals | text | — | 0.0 | 32.14 | progressive render by design |
| mandel-float | fractals | text | — | 0.0 | 0.0 | compute-then-hold |
| mandel-oop | fractals | m7 | — | 0.0 | 44.44 | out of scope (own pipeline) |
| matcascade | rendering | plot | — | 0.0 | 1.01 | ok |
| maze | algorithms | text | — | 0.0 | 0.0 | compute-then-hold at 500 |
| medfilt | rendering | canvas | — | 0.0 | 2.23 | ok |
| metaball | — | band | FULL | 0.0 | 0.0 | ok — atomic |
| modexp256 | algorithms | band | PER-BAND | 0.0 | 94.18 | **F1** (compute-once + palette cycle) |
| montorbit | ciphers | plot | — | 0.0 | 3.68 | ok |
| msquares | cellular | plot | — | 0.0 | 0.0 | ok |
| mulov64 | bignums | plot | — | 0.03 | 0.17 | ok |
| multibase | bignums | text | — | 2.05 | 1.38 | ok — already per-frame |
| mvscrl | algorithms | band | PER-BAND | 0.0 | 0.07 | **F1** now; **F2** candidate (V-ring) |
| n-body | physics | plot | — | 0.0 | 0.47 | ok |
| newton | fractals | text | — | 1.81 | 2.38 | ok — already per-frame |
| nrecip | rendering | band | FULL | 0.0 | 26.82 | ok — atomic |
| oddmask | algorithms | band | PER-BAND | 0.0 | 19.53 | **F1** (terraces → no F2) |
| ovmove | algorithms | band | PER-BAND | 0.0 | 19.68 | **F1** now; **F2** candidate (V-ring) |
| pcooker | algorithms | band | PER-BAND | 0.0 | 0.47 | **F1** (occasional recompute) |
| percol | cellular | canvas | — | 0.0 | 1.34 | ok |
| perlin | rendering | band | FULL | 0.0 | 28.36 | ok — atomic |
| permscat | algorithms | band | PER-BAND | 0.0 | 18.82 | **F1** (permutation → no F2) |
| plyoracle | classics | plot | — | 0.0 | 0.09 | ok |
| polyfill | rendering | plot | — | 0.0 | 6.1 | ok |
| poolfx | classics | plot | — | 0.0 | 0.31 | ok |
| qsortviz | algorithms | plot | — | 0.0 | 11.48 | ok |
| radix | algorithms | band | FULL | 0.0 | 16.48 | ok — atomic |
| rangecode | algorithms | plot | — | 0.0 | 0.19 | ok |
| raycaster | physics | canvas | — | 0.0 | 0.0 | static-at-500 |
| rdiff | cellular | text | — | 0.0 | 6.67 | stepped by design |
| ropeedit | algorithms | band | PER-BAND | 5.58 | 6.4 | **F1** (variable shifts → weak F2) |
| rotkal | rendering | band | PER-BAND | 0.0 | 9.71 | **F1** (rotation → no F2) |
| rotozoom | rendering | band | FULL | 0.0 | 9.57 | ok — atomic |
| rotslab | algorithms | band | PER-BAND | 0.0 | 16.42 | **F1** (runtime-k rotate → weak F2) |
| satcast | rendering | band | PER-BAND | 0.0 | 19.82 | **F1** (kaleidoscope → no F2) |
| satcomet | motion | canvas | — | 0.0 | 8.59 | ok |
| sbitfld | algorithms | band | PER-BAND | 0.0 | 0.01 | **F1** (erosion in place → no F2) |
| scopeguard | algorithms | plot | — | 0.0 | 0.0 | ok |
| seqvm | signals | canvas | — | 0.0 | 3.52 | ok |
| smulorbit | motion | plot | — | 0.0 | 0.2 | ok |
| sobel | rendering | plot | — | 0.0 | 25.91 | ok |
| sodo | bignums | text | — | 0.0 | 4.31 | ok |
| sort-race | algorithms | text | — | 0.0 | 7.07 | stepped by design |
| spaceship | algorithms | band | FULL | 0.0 | 9.64 | ok — atomic |
| speedcap | physics | canvas | — | 0.0 | 1.28 | ok |
| spigot | bignums | plot | — | 0.0 | 0.46 | ok |
| spirograph | motion | canvas | — | 0.0 | 0.17 | ok |
| tea | ciphers | canvas | — | 0.15 | 0.22 | ok |
| trimerge | algorithms | scroll-ring | n/a | — | — | ✅ DONE (#99c, v1.0.291) |
| truchet | ciphers | band | ? | 0.0 | 5.82 | verify marking, then F1 if per-band |
| truncstair | algorithms | band | ? | 4.86 | 0.0 | verify marking; **F2** candidate (H-bands) |
| turtle-vm | classics | canvas | — | 0.0 | 0.73 | ok |
| uarteye | ciphers | band | PER-BAND | 0.0 | 0.02 | **F1** (eye overlay → no F2) |
| ucmprank | algorithms | band | PER-BAND | 0.02 | 0.03 | **F1** (rank recolor → no F2) |
| ulam | algorithms | plot | — | 0.0 | 0.04 | ok |
| vaprintf | motion | plot | — | 0.04 | 1.4 | ok |
| wireframe | — | canvas | — | 0.0 | 1.02 | ok |

## Recommended batches

- **Batch A (mechanical, do now — user-ordered):** F1 atomic flush for the 19 per-band demos
  (+ `hull`/`truchet`/`truncstair` after verifying their marking). Each is the #99b change: stop
  marking dirty in the band painter, full-mark at sweep end. No gate values change (display-only).
- **Batch B (per-demo design, #99c-sized):** F2 scroll-rings for `ovmove`, `mvscrl`, `truncstair`
  (+`lfsr2` pending drift verification).
- **Batch C (opportunistic):** F3 stall hunts on any Batch-A demo whose paint frame measurably
  overruns after F1.

Republishing rides the standing "[T2] rebuild + republish all ROMs" TODO (title-card fix) so the
site gets one coherent ROM refresh.

## Applied fixes

*(updated as work lands — see below)*

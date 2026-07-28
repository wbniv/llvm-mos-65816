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
   phase (rotations, permutations, kaleidoscopes, rank recolors) that does not translate. Four
   looked plausible on the visual description; checking them against their kernels
   (*Batch B — candidacy*, below) left **exactly one**:
   - <span style="color:#3fb950">`mvscrl` — **QUALIFIES**, two pure whole-row translations
     (upper down, lower up). NB the memmove IS the stress target; the ring only replaces the
     *display* repaint.</span>
   - <span style="color:#3fb950">`ovmove` — **rejected**: the flat buffer shifts ±17/−18 bytes,
     i.e. diagonally with a row-crossing wrap, and reverses direction every frame.</span>
   - <span style="color:#3fb950">`lfsr2` — **rejected**: two noise fields drift at *different*
     rates and the interleave mask is position-fixed, so nothing rigidly translates.</span>
   - `truncstair` — a real horizontal translation, but **deferred**: an `HOFS` ring wraps at the
     32-column tilemap while `BitmapCanvas` only fills 16 columns, so blank tiles would scroll in.
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

<span style="color:#3fb950">**Green rows are resolved**</span> — either no action was ever
warranted, or the fix has been applied and verified. **112 of 114 rows are green.** The two
non-green rows are the only outstanding work in the whole sweep: `mvscrl` (F2 not started —
blocked on a concurrent edit, below) and `truncstair` (**broken — renders black**, below; F2 is moot until it renders at all).

| demo | category | pattern | mark | d1 % | d60 % | verdict |
|---|---|---|---|---|---|---|
| <span style="color:#3fb950">1d-ca</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">2.78</span> | <span style="color:#3fb950">2.69</span> | <span style="color:#3fb950">ok — already per-frame</span> |
| <span style="color:#3fb950">adpcm</span> | <span style="color:#3fb950">signals</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">10.9</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">avalanche</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">29.61</span> | <span style="color:#3fb950">stepped by design (odometer ticks)</span> |
| <span style="color:#3fb950">bf-vm</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">static-at-500 (program output)</span> |
| <span style="color:#3fb950">bhut</span> | <span style="color:#3fb950">physics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.28</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">bitcensus</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">5.8</span> | <span style="color:#3fb950">21.32</span> | <span style="color:#3fb950">ok — atomic + per-frame</span> |
| <span style="color:#3fb950">bitshuffle</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.07</span> | <span style="color:#3fb950">0.93</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">bitweave</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">28.6</span> | <span style="color:#3fb950">F1 ✅</span> |
| <span style="color:#3fb950">blossom</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">2.46</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">boids</span> | <span style="color:#3fb950">physics</span> | <span style="color:#3fb950">text/OAM</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">static-at-500 (attract loop timing)</span> |
| <span style="color:#3fb950">borrowlad</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">3.46</span> | <span style="color:#3fb950">14.43</span> | <span style="color:#3fb950">F1 ✅</span> |
| <span style="color:#3fb950">buddha</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">ok (accumulator render)</span> |
| <span style="color:#3fb950">burning-ship</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">compute-then-hold</span> |
| <span style="color:#3fb950">cardioid</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">3.22</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">cgrade</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">16.55</span> | <span style="color:#3fb950">24.82</span> | <span style="color:#3fb950">ok — already per-frame</span> |
| <span style="color:#3fb950">compass</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.04</span> | <span style="color:#3fb950">F1 ✅ (rotation → no F2)</span> |
| <span style="color:#3fb950">cordic</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.24</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">cosmzoom</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.15</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">cpu6502</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">11.24</span> | <span style="color:#3fb950">ok (full-screen tilemap)</span> |
| <span style="color:#3fb950">crctex</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">22.47</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">crcwall</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">5.36</span> | <span style="color:#3fb950">24.11</span> | <span style="color:#3fb950">F1 ✅ (hash marble → no F2)</span> |
| <span style="color:#3fb950">critters</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.08</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">dctbloom</span> | <span style="color:#3fb950">signals</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">8.29</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">dhmix</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">29.49</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">disbits</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">13.5</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">dither</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">ok — atomic; static display</span> |
| <span style="color:#3fb950">divclock</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.26</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">domcol</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">96.43</span> | <span style="color:#3fb950">stepped (full re-render per step)</span> |
| <span style="color:#3fb950">doom-fire</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">8.29</span> | <span style="color:#3fb950">stepped by design</span> |
| <span style="color:#3fb950">double-pendulum</span> | <span style="color:#3fb950">physics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.12</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">duff</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.22</span> | <span style="color:#3fb950">14.96</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">editdist</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">10.83</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">epicycles</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.2</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">fabsridge</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.0</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">factorial</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">3.23</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">fenwick</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">11.94</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">fft</span> | <span style="color:#3fb950">signals</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">fn-plot</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">compute-then-hold</span> |
| <span style="color:#3fb950">funnelkal</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">4.69</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">gf256</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">18.84</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">gouraud</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">95.53</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">grid3d</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">64.7</span> | <span style="color:#3fb950">stepped by design</span> |
| <span style="color:#3fb950">harmonograph</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.02</span> | <span style="color:#3fb950">0.25</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">hdr-bloom</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">36.58</span> | <span style="color:#3fb950">stepped by design</span> |
| <span style="color:#3fb950">hilbert</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.07</span> | <span style="color:#3fb950">1.33</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">huffman</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.22</span> | <span style="color:#3fb950">15.07</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">hull</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">?</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.56</span> | <span style="color:#3fb950">ok — verified: no per-band marking</span> |
| <span style="color:#3fb950">iir-scope</span> | <span style="color:#3fb950">signals</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.37</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">invaders</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">text/OAM</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.08</span> | <span style="color:#3fb950">4.83</span> | <span style="color:#3fb950">ok (game loop)</span> |
| <span style="color:#3fb950">julia</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">compute-then-hold</span> |
| <span style="color:#3fb950">keycmp64</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">16.13</span> | <span style="color:#3fb950">F1 ✅ (reorder → no F2)</span> |
| <span style="color:#3fb950">lfsr2</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">3.92</span> | <span style="color:#3fb950">14.75</span> | <span style="color:#3fb950">F1 ✅ · F2 rejected — not a translation</span> |
| <span style="color:#3fb950">life</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">31.03</span> | <span style="color:#3fb950">96.09</span> | <span style="color:#3fb950">ok — already 60 fps</span> |
| <span style="color:#3fb950">lsystem</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">compute-then-hold</span> |
| <span style="color:#3fb950">lzdec</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">18.97</span> | <span style="color:#3fb950">stepped; atomic already</span> |
| <span style="color:#3fb950">lzss-gallery</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">m7</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">out of scope (own pipeline)</span> |
| <span style="color:#3fb950">mandel-display</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">33.63</span> | <span style="color:#3fb950">out of scope</span> |
| <span style="color:#3fb950">mandel-double</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">32.14</span> | <span style="color:#3fb950">progressive render by design</span> |
| <span style="color:#3fb950">mandel-float</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">compute-then-hold</span> |
| <span style="color:#3fb950">mandel-oop</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">m7</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">44.44</span> | <span style="color:#3fb950">out of scope (own pipeline)</span> |
| <span style="color:#3fb950">matcascade</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.01</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">maze</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">compute-then-hold at 500</span> |
| <span style="color:#3fb950">medfilt</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">2.23</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">metaball</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">modexp256</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">94.18</span> | <span style="color:#3fb950">F1 ✅ (compute-once + palette cycle)</span> |
| <span style="color:#3fb950">montorbit</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">3.68</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">msquares</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">mulov64</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.03</span> | <span style="color:#3fb950">0.17</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">multibase</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">2.05</span> | <span style="color:#3fb950">1.38</span> | <span style="color:#3fb950">ok — already per-frame</span> |
| mvscrl | algorithms | band | PER-BAND | 0.0 | 0.07 | F1 ✅ · **F2 not started** — see Batch B note |
| <span style="color:#3fb950">n-body</span> | <span style="color:#3fb950">physics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.47</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">newton</span> | <span style="color:#3fb950">fractals</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">1.81</span> | <span style="color:#3fb950">2.38</span> | <span style="color:#3fb950">ok — already per-frame</span> |
| <span style="color:#3fb950">nrecip</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">26.82</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">oddmask</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">19.53</span> | <span style="color:#3fb950">F1 ✅ (terraces → no F2)</span> |
| <span style="color:#3fb950">ovmove</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">19.68</span> | <span style="color:#3fb950">F1 ✅ · F2 rejected — not a translation</span> |
| <span style="color:#3fb950">pcooker</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.47</span> | <span style="color:#3fb950">F1 ✅ (occasional recompute)</span> |
| <span style="color:#3fb950">percol</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.34</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">perlin</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">28.36</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">permscat</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">18.82</span> | <span style="color:#3fb950">F1 ✅ (permutation → no F2)</span> |
| <span style="color:#3fb950">plyoracle</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.09</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">polyfill</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">6.1</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">poolfx</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.31</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">qsortviz</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">11.48</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">radix</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">16.48</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">rangecode</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.19</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">raycaster</span> | <span style="color:#3fb950">physics</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">static-at-500</span> |
| <span style="color:#3fb950">rdiff</span> | <span style="color:#3fb950">cellular</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">6.67</span> | <span style="color:#3fb950">stepped by design</span> |
| <span style="color:#3fb950">ropeedit</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">5.58</span> | <span style="color:#3fb950">6.4</span> | <span style="color:#3fb950">F1 ✅ (variable shifts → weak F2)</span> |
| <span style="color:#3fb950">rotkal</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">9.71</span> | <span style="color:#3fb950">F1 ✅ (rotation → no F2)</span> |
| <span style="color:#3fb950">rotozoom</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">9.57</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">rotslab</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">16.42</span> | <span style="color:#3fb950">F1 ✅ (runtime-k rotate → weak F2)</span> |
| <span style="color:#3fb950">satcast</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">19.82</span> | <span style="color:#3fb950">F1 ✅ (kaleidoscope → no F2)</span> |
| <span style="color:#3fb950">satcomet</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">8.59</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">sbitfld</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.01</span> | <span style="color:#3fb950">F1 ✅ (erosion in place → no F2)</span> |
| <span style="color:#3fb950">scopeguard</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">seqvm</span> | <span style="color:#3fb950">signals</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">3.52</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">smulorbit</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.2</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">sobel</span> | <span style="color:#3fb950">rendering</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">25.91</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">sodo</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">4.31</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">sort-race</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">text</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">7.07</span> | <span style="color:#3fb950">stepped by design</span> |
| <span style="color:#3fb950">spaceship</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">FULL</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">9.64</span> | <span style="color:#3fb950">ok — atomic</span> |
| <span style="color:#3fb950">speedcap</span> | <span style="color:#3fb950">physics</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.28</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">spigot</span> | <span style="color:#3fb950">bignums</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.46</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">spirograph</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.17</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">tea</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.15</span> | <span style="color:#3fb950">0.22</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">trimerge</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">scroll-ring</span> | <span style="color:#3fb950">n/a</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">✅ DONE (#99c, v1.0.291)</span> |
| <span style="color:#3fb950">truchet</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">?</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">5.82</span> | <span style="color:#3fb950">ok — verified: no per-band marking</span> |
| <span style="color:#3fb950">truncstair</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">?</span> | <span style="color:#3fb950">4.86*</span> | <span style="color:#3fb950">0.0*</span> | <span style="color:#3fb950">render bug FIXED ✅ (6f6d4df); F2 now unblocked, F3 candidate</span> |
| <span style="color:#3fb950">turtle-vm</span> | <span style="color:#3fb950">classics</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.73</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">uarteye</span> | <span style="color:#3fb950">ciphers</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.02</span> | <span style="color:#3fb950">F1 ✅ (eye overlay → no F2)</span> |
| <span style="color:#3fb950">ucmprank</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">band</span> | <span style="color:#3fb950">PER-BAND</span> | <span style="color:#3fb950">0.02</span> | <span style="color:#3fb950">0.03</span> | <span style="color:#3fb950">F1 ✅ (rank recolor → no F2)</span> |
| <span style="color:#3fb950">ulam</span> | <span style="color:#3fb950">algorithms</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">0.04</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">vaprintf</span> | <span style="color:#3fb950">motion</span> | <span style="color:#3fb950">plot</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.04</span> | <span style="color:#3fb950">1.4</span> | <span style="color:#3fb950">ok</span> |
| <span style="color:#3fb950">wireframe</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">canvas</span> | <span style="color:#3fb950">—</span> | <span style="color:#3fb950">0.0</span> | <span style="color:#3fb950">1.02</span> | <span style="color:#3fb950">ok</span> |

## Recommended batches

- ~~**Batch A (mechanical, do now — user-ordered):** F1 atomic flush for the 19 per-band demos
  (+ `hull`/`truchet`/`truncstair` after verifying their marking). Each is the #99b change: stop
  marking dirty in the band painter, full-mark at sweep end. No gate values change (display-only).~~
  **DONE 2026-07-27** — see *Applied fixes*; `hull`/`truchet`/`truncstair` verified as false
  positives (no per-band marking; different "band" meanings), left untouched.
- ~~**Batch B (per-demo design, #99c-sized):** F2 scroll-rings for `ovmove`, `mvscrl`,
  `truncstair` (+`lfsr2` pending drift verification).~~ **CANDIDACY RESOLVED 2026-07-27** — the
  four candidates were checked against their actual kernels (see *Batch B — candidacy*, below):
  **only `mvscrl` qualifies** and is in build; `ovmove` and `lfsr2` are **rejected** (their motion
  is not a translation a scroll register can express); `truncstair` is a real translation but
  **deferred** on a ring-geometry blocker.
- ~~**Batch C (opportunistic):** F3 stall hunts on any Batch-A demo whose paint frame measurably
  overruns after F1.~~ **DONE 2026-07-27** — all 19 were rebuilt with one-row paint slices; the
  expensive live-only repetitions were removed or made incremental while every original compiler
  stress kernel remains in its differential gate. See *Batch C — F3*, below.

Republishing rides the standing "[T2] rebuild + republish all ROMs" TODO (title-card fix) so the
site gets one coherent ROM refresh.

## Applied fixes

**Batch A — F1 atomic flush applied to all 19 per-band demos (2026-07-27).** The marking blocks
were textually identical to trimerge's pre-#99b painter across every file, so the patch was applied
by exact-match replacement (fail-loud, 19/19 matched; −95/+38 lines): the band painter no longer
marks dirty, and the sweep-boundary branch full-marks the canvas → one ≤4 KB flush in one v-blank.

**Verification (fresh full rebuild, then per demo: map-derived `corpus_result` selfcheck vs the
manifest `want`/`frames` + atomicity over 6 consecutive frames — per-band flushing would change
EVERY pair):**

```
bitweave  PASS off=0x31 changing_pairs=1    oddmask   PASS off=0x31   changing_pairs=0
borrowlad PASS off=0x31 changing_pairs=1    ovmove    PASS off=0x31   changing_pairs=1
compass   PASS off=0x31 changing_pairs=0    pcooker   PASS off=0x39   changing_pairs=0
crcwall   PASS off=0x31 changing_pairs=1    permscat  PASS off=0x31   changing_pairs=1
keycmp64  PASS off=0x31 changing_pairs=0    ropeedit  PASS off=0x31   changing_pairs=1
lfsr2     PASS off=0x31 changing_pairs=1    rotkal    PASS off=0x13F2 changing_pairs=0
modexp256 PASS off=0x39 changing_pairs=1    rotslab   PASS off=0x31   changing_pairs=1
mvscrl    PASS off=0x31 changing_pairs=0    satcast   PASS off=0x41   changing_pairs=0
                                            sbitfld   PASS off=0x31   changing_pairs=1
                                            uarteye   PASS off=0x31   changing_pairs=0
                                            ucmprank  PASS off=0x31   changing_pairs=0
```

**19/19 PASS.** ⚠️ Republish caveat: the rebuilt ROMs' `corpus_result` WRAM offsets moved on most
demos (old manifests are stale) — the bulk republish MUST regenerate each manifest selfcheck `off`
from the fresh `.map` (the flow `verify-web-roms.sh` gates already assumes manifest-vs-ROM
coherence, so a stale manifest fails loudly rather than silently).

### Batch C — F3 cheap-paint pass (2026-07-27)

The first post-F1 cadence probe showed that atomicity alone did not make the paint slices cheap:
several demos still repeated their *gate-strength* kernel in the live renderer, and the old four-row
slice compounded that work with 64 solid-tile conversions before `display_frame()`.

The completed pass:

- changes every Batch-A painter from four rows to **one row per CPU slice** while retaining the
  single full-canvas dirty mark at sweep completion;
- adds `canvas_fill_solid_tile()`, a shared two-plane word-store path;
- distributes full-field recomputes by row in `bitweave`, `borrowlad`, `lfsr2`, and `oddmask`;
- uses exact cheap live equivalents where the expensive operation is already fully covered by the
  differential gate (`compass`, `satcast`, `sbitfld`);
- removes redundant live repetitions of qsort, O(N²) ranking, whole-buffer memmove/scatter/rotate,
  bit-serial CRC, odd-width s64 mixing, and UART framing. The original stress implementations and
  expected hashes remain unchanged in their gate paths;
- advances whole-field state only after a complete shadow sweep, so one atomic image no longer
  contains rows sampled from different algorithm phases.

Verification: all 19 ROMs rebuilt in the development container, and all 19 map-derived
`corpus_result` checks passed in bsnes-jg after 1,000 frames. Expected hashes are unchanged:

```
bitweave 0E03  borrowlad 1BE3  compass B9CB   crcwall 8E47   keycmp64 B8AD
lfsr2    6AA3  modexp256 31D4  mvscrl  72A7   oddmask 1FD9   ovmove   A990
pcooker  EE6D  permscat  0C2C  ropeedit 2361  rotkal  300C   rotslab  B93A
satcast  C8CF  sbitfld   40C5  uarteye  3F09   ucmprank 4CDD
```

## Batch B — candidacy (resolved 2026-07-27)

The four F2 candidates were checked against their actual kernels rather than their visual
description. **F2 requires the displayed content to move by a whole-row (or whole-column) rigid
translation that a scroll register can express.** Sub-row shifts, direction changes, and shifts
that wrap across a row boundary all disqualify: a scroll register offsets whole scanlines, so it
cannot move data from the end of one row into the start of the next.

| candidate | kernel motion | verdict |
|---|---|---|
| <span style="color:#3fb950">`mvscrl`</span> | <span style="color:#3fb950">`upper` shifts **down exactly 1 row** (`memmove(&upper[1][0], &upper[0][0], 7*16)`, new row at top); `lower` shifts **up exactly 1 row**. Two pure whole-row translations.</span> | <span style="color:#3fb950">**QUALIFIES** — two V-rings, opposite directions. In build.</span> |
| <span style="color:#3fb950">`ovmove`</span> | <span style="color:#3fb950">Per step the 384-byte flat buffer shifts **+17 bytes** (down 1 row `+16`, then `memmove(flat+1, flat, 383)` = **+1 column**) or **−18** (up 1 row, then `memmove(flat, flat+2, 382)` = −2 columns) — and `dir` alternates every frame.</span> | <span style="color:#3fb950">**REJECTED** — diagonal, direction-alternating, and the column component wraps across rows. Not scroll-expressible.</span> |
| <span style="color:#3fb950">`lfsr2`</span> | <span style="color:#3fb950">`recompute()` replays both LFSRs from the live seeds in raster order; between frames `g8` advances **2** steps and `f8` advances **1**. The stream→cell assignment is chosen by the *position* parity `(r+c)&1`, which does not move with the data.</span> | <span style="color:#3fb950">**REJECTED** — two fields drifting at *different* rates, the interleave mask is position-fixed, and the drift is sub-row anyway. The table's "F2 if drift is a translation" caveat resolves to **no**.</span> |
| `truncstair` | Genuinely a translation: every column's value depends on `cx*8 + phase`, so `phase += 8` reproduces the field shifted **left exactly one tile column** (phase advances 1 per 4 frames → 1 tile per 32 frames). | **DEFERRED** — blocked on ring geometry, below. |

### Why `truncstair` is deferred, not rejected

The motion qualifies; the *wrap* does not fit the existing canvas. A vertical #99c ring works
because the ring lives inside the canvas's own 16 tile rows. The horizontal equivalent does not:
`BG3HOFS` wraps at the **tilemap** width (32 tiles / 256 px), but `BitmapCanvas` only supplies
**16 columns** of CHR (`CANVAS_TILES_W 16`) inside that 32-column map — every other cell is the
blank tile (`_CANVAS_BLANK_TILE`). Scrolling horizontally would therefore pull blank tiles through
the window instead of wrapping the content.

Closing that needs one of: a 32-column-wide canvas (512 tiles / 8 KB CHR shadow — double the
current budget, and beyond the "no library changes" bar #99c set for itself), a second tilemap
arrangement that duplicates the 16 columns, or a per-scanline HOFS scheme that reloads mid-frame.
Each is a design change larger than the #99c drop-in this batch was scoped to, so `truncstair`
stays on the current every-frame repaint (which is already atomic and already animates: `d1` 4.86 %)
until someone picks up the wider-canvas work deliberately.

### Batch B status (2026-07-27, second pass)

After candidacy resolution the batch reduces to **one** implementable demo, and that one is
currently **blocked on a collision**:

- `ovmove`, `lfsr2` — **closed, rejected** (evidence above). No work to do.
- `truncstair` — **closed, deferred** on the ring-geometry blocker above. No work to do until
  someone takes the wider-canvas decision deliberately.
- `mvscrl` — the only qualifying demo. **F2 not started.** `examples/snes/mvscrl.c` currently
  carries **uncommitted edits from a concurrent session** (mtime 2026-07-27 11:01) that rework the
  painter to one tile-row per frame. Per the repo's only-commit-your-own-files rule those edits
  were left untouched, and no scroll-ring work was layered on top of a file someone else is
  mid-refactor in.

⚠️ **Flag for whoever owns that in-flight `mvscrl` edit:** as it currently stands the diff drops
the `mv_step(&a.mv, a.t)` call from the main loop and replaces the field read with a computed
decorative pattern (`(cx + row + (t>>2)) & 3`), so the display no longer renders the memmove
buffers at all. `corpus_result` still passes (`0x72A7`) because `mvscrl_gate_crc()` runs the kernel
during the title, independently of the loop — so the gate cannot catch this. But #79's whole point
is that the *visual is the proof*: a G_MEMMOVE Ascending+Descending demo whose picture is unrelated
to the memmove has lost that property. Worth a second look before it lands.

Any future F2 work on `mvscrl` should also be re-checked against whatever that refactor settles on,
since it changes the very painter the ring would replace.

### ⚠️ truncstair does not render (found 2026-07-28, while scoping its F2 work)

Building the scroll-ring required looking at the demo running, which nobody had done — the sweep's
empirical pass sampled frames 500/560, and **at those frames truncstair is still showing its title
card** (its float-heavy `truncstair_gate_crc()` runs during the title). So the `d1 4.86 / d60 0.0`
figures in the table above describe the *title animation*, not the demo — marked `*` accordingly.

Captured further in, the demo never appears:

```
frame  700 : 100% black      frame 1200 : title card on magenta (96.4% non-black)
frame  900 : 100% black      frame 1300 : 100% black
frame 1100 : 100% black      frame 2000+: 100% black
```

It is **not** a regression from this batch, and not something the F1 work caused (truncstair was
explicitly excluded from Batch A): the **currently published ROM**
(`biohack.net/public/play/roms/truncstair.sfc`) is black at frame 2000 too. This is shipping.

`corpus_result` cannot catch it — `0x02CA` is computed during the title, before the display loop
matters — which is the same blind spot that hid the `mvscrl` regression. Two contributing facts are
already confirmed; the third is not yet root-caused:

1. **The staircase saturates.** `x_f` grows with an unbounded `phase`, so `q` grows and
   `row_offset = 2 - q` clamps to 0 for every column by phase ≈ 200 (~13 s in): all three bands
   collapse onto their top row. Replayed in host arithmetic:
   `phase 0 → q -3..3` (a real staircase) vs `phase 200 → q 8..16, row_offset 0..0` (flat).
2. **The ramp never wraps**, which is the same root fact that blocks an `HOFS` ring: a ring needs
   content periodic over its width. Making `phase` wrap at the ring width would fix the saturation
   *and* supply the periodicity F2 needs — one change, both problems.
3. **Unexplained:** saturation alone would leave three coloured lines plus the dividers, not a 100%
   black screen, and not the black/title flicker seen across frames 1100–1300. Something further —
   force-blank timing, a palette/CGRAM overwrite (the magenta backdrop at 1200 is not in
   `bg3_pal`), or the display loop not running — is still unaccounted for. **Do not design the ring
   until this is root-caused**; per the repo's rule, an anomaly needs a concrete cause, not a guess.

Prerequisite note for whoever takes this: the *other* blocker recorded above (a 32-column canvas for
the `HOFS` ring) is now measured and **harder than it looked** — `_canvas_emit` hardcodes DMA source
bank `0x00`, so the shadow must live in bank-0 low WRAM, and truncstair's `.bss` already runs
`0x200..0x13E9` with only ~3 KB of headroom below `$1FFF`. Doubling the shadow to 8 KB overflows it;
widening therefore also requires teaching the canvas/upload path to DMA from bank `$7E`.

#### Resolved 2026-07-28 — root cause was a buffer overflow, not a drawing bug

`BAND_ROUND (12) + BAND_H (5)` made `draw_band` write tile rows 12..**16** into a 16-row canvas.
Tile row 16 is `chr[4096..]`, and `BitmapCanvas` places `lo, hi, chr_word, map_word` immediately
after `chr[]` — so each frame the round band overwrote the canvas's own **VRAM base addresses** with
tile bitmap bytes, `_canvas_emit` DMA'd to a garbage address and wiped the tilemap, and the wild DMA
restarted the program. Fixed in `6f6d4df` by giving each band its own height (`BAND_ROUND_H = 4`,
which is what the file's own layout comment always said) and wrapping the ramp into one 128 px
period. Gate unchanged (`0x02CA`, identical disasm counts); renders 9.7 % non-black at frames
700–4000 where it was 100 % black, and `corpus_result` no longer shows partial folds.

**Two things this changes for the sweep's method**, worth carrying into any future pass:

1. **Sampling at a fixed frame is unsafe.** The empirical pass read frames 500/560 for every demo;
   truncstair is still on its title card there, so its `d1`/`d60` measured the title animation. Any
   demo whose gate runs during the title needs its sample point chosen *after* `title_end`, not at a
   fixed 500.
2. **A green corpus gate says nothing about the picture.** This is now the second demo in two days
   (with `mvscrl`) whose gate passed while the display was broken, for the same structural reason —
   `corpus_result` is computed during the title, before the display loop matters. `dev/display-check.py`
   (added 2026-07-28) now tests this directly.

   **Correction to an earlier claim in this section:** I first wrote that such a check "would have
   caught both". It would not. It catches the *truncstair* class — blank screen, reset loop, frozen
   on the title — and indeed flags the published truncstair ROM (`RESET/UNSTABLE corpus_result
   ['0x02ca', '0x0100', '0x01f6']`). It does **not** catch the *mvscrl* class: that demo rendered a
   live, changing, non-black picture the whole time; it was simply the *wrong data* (a decorative
   pattern instead of the memmove buffers). Detecting that needs a demo-specific claim about what
   the pixels mean, which no generic checker can make. A PASS means "something is on screen and
   running", never "the visual is correct".

Remaining on truncstair: the ramp wrap supplies the periodicity an `HOFS` ring needs, so **half the
F2 prerequisite is now cleared**; the 32-column-canvas half (bank-0 WRAM, measured above) still
stands. Separately it is a good **F3** candidate — all three bands redraw with software floats every
iteration, so the loop runs at roughly 5 fps.

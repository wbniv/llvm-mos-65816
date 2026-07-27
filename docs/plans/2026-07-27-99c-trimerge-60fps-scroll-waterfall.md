# #99c — trimerge 60 fps waterfall: HDMA-banded vertical-scroll ring

**Status:** planned 2026-07-27, user-directed ("can we achieve 60 fps instead? if so, build it").
Phase 4 of the trimerge visual arc ([#99b](2026-07-27-99b-trimerge-visual-fix.md): waterfall +
atomic flush + vignette, live as biohack.net v1.0.288).

## Why the current build is ~10 Hz

The waterfall brute-forces motion: every sweep repaints the entire 4 KB canvas shadow
(`cell_fill` × 256) and re-DMAs all of it, with the visible update gated to one atomic flush per
sweep (the #99b tear fix). The motion *cadence* is therefore the sweep cadence — 4+ paint frames
per step, measured ~6 (~10 Hz). Nothing about the hardware requires this; it is the most expensive
possible way to express "everything moved down 8 px".

## Design: scroll the ring, paint only the incoming row

The SNES-native waterfall: the canvas rows become a **vertical scroll ring** and motion comes from
`BG3VOFS` changing **1 px per frame — continuous 60 fps** — while the CPU paints only the one
incoming row (16 tiles, 256 B) once every 8 frames. Per-sweep work drops ~16× in CPU and ~16× in
DMA; the paint + scroll commit can never miss v-blank.

The HUD must not scroll and the ring must wrap without exposing the text rows → per-scanline
**banded** vertical scroll, which is exactly what the existing **`snesgfx/hdma_hscroll.h`** provides
(`hscrollw_*` band builder + `HScrollDB` double-buffer, `VSCROLL_BG3VOFS`). Second library reuse in
this demo after `backdrop_gradient.h`.

### Geometry (all inside the existing 16-row canvas — no library changes)

- The canvas's 16 tile rows (map rows 6–21) become a **128-px ring**; the visible window shrinks to
  **15 rows / 120 px** (scanlines 48–167). The 16th row is always off-screen — the **staging row**
  where the next merge round is painted before it scrolls in. (A 17th-row ring would need tiles
  outside the `BitmapCanvas` window — rejected as out of scope.)
- Ring offset `P ∈ [0,128)`, decremented 1/frame (content flows down). Visible top = ring pixel
  `P`; staged slice = ring pixels `P−8 … P−1 (mod 128)` — precisely the slice that scrolls in at
  the top over the next 8 frames.
- Scanline bands per frame (sum 224): `48 @ vofs 0` (title area) · `min(120, 128−P) @ vofs P`
  (ring, part A) · `P−8 @ vofs P+128` when `P > 8` (ring wrap, part B) · `56 @ vofs 8` (bottom).
  The bottom band's `vofs +8` skips the ring's last row; the bottom HUD text moves from map row 25
  to **26** (same screen position).
- Row bookkeeping: `R = P/8`; when `R` decrements (every 8 frames), paint ring row
  `(R_new + 15) mod 16` (canvas row = ring row, identity — the scroll does the reordering) with the
  next merge round and dirty-mark just those 16 tiles. The `cellcol` history array disappears —
  rows are painted once and never moved.

### Atomicity & channels

- The staged row is off-screen when painted → tearless by construction; its 256 B flush and the
  `HScrollDB` table-pointer poke ride the same v-blank upload queue.
- HDMA channels: vscroll ring on **channel 6**, backdrop vignette stays on **7**; armed together
  after `title_end` (`REG_HDMAEN = 0xC0`; the title's own HDMA channels are disarmed by then).
  `upq` GP-DMA stays on channel 0.
- Palette breathing and the `T=`/CRC HUD update retie to the row cadence (every 8 frames).

## What this must NOT change

`corpus_result = trimerge_gate_crc()` (`0xCCCC`, header-internal), the `G_SCMP`-as-control-flow IR
probe, the WRAM offset contract with the site manifest, and the blankscan cleanliness.

## Verification

1. `dev/run.sh trimerge` — `0xCCCC`, IR probe (`llvm.scmp=4` incl. s64), `-verify` clean.

   ```
       PASS  llvm.scmp=4  scmp.i64=2  rep/sep=198  (G_SCMP formed incl. s64, drives control flow)
   SMOKE: PASS off=0x39 len=2 got=0xCCCC (ran 500 frames, bsnes-jg)
   RESULT: PASS — Three-Way Merge Diff on SNES; MAME + bsnes-jg + corpus hash 0xCCCC host == +mos-a16
   ```
   **PASS** (both before and after the destall fixes below).

2. **60 fps check:** dump ≥6 consecutive frames; assert (a) the canvas band differs in EVERY
   consecutive pair, and (b) frame N+1's content shifted up 1 px matches frame N ≥90 %.

   **First build FAILED usefully** — 1-px scroll was perfect (98.7 % shifted-match) but one frame in
   nine stalled (`stall pairs: [504, 513]; gaps: [9]`): the every-8th paint iteration overran the
   frame. Root cause split two ways and fixed: (i) `breathe_palette` + `update_hud` staggered to
   sub-frame 4 (off the paint frame); (ii) the real hog — `tm_fill32` does a 32-bit multiply per
   element = **40 `__mulsi3` libcalls per paint** — replaced by `fill_ramp32`, an incremental-add
   ramp producing identical values (display path only; the GATE still uses the header's `tm_fill32`
   and the merge still calls the noinline `tm_cmp32` per cell — the `G_SCMP` stress is untouched).

   **Final build, 20 consecutive frames (500–520):**

   ```
   stalls: NONE | class-shift failures: NONE
   60FPS CHECK (class-based): PASS
   ```
   (The checker compares hue-class maps, not raw RGB — the palette-breathe frame recolors every
   painted pixel by design, which a raw-RGB shift-match misreads as a failure at 5.9 %.)

3. Blankscan clean — via `dev/verify-web-roms.sh --only trimerge`:

   ```
   verify-web-roms: 1 passed, 0 failed, 0 missing
   ALL PASS — safe to publish
   ```

4. Republished: biohack.net **v1.0.291** (`8ec4906`); plan screenshot refreshed.

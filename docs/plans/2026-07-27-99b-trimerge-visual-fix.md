# #99b — trimerge visual fix: make the braid actually flow (offset scale + waterfall + palette breathing)

**Status:** planned 2026-07-27, user-directed ("do 1 plus 2. then 3"). Fixes the frozen visual of the
published [trimerge](https://biohack.net/snes/trimerge/) demo (#99, [plan](2026-07-02-99-snes-trimerge.md))
without touching its compiler-stress purpose or gate value.

## The defect (measured 2026-07-27)

The demo's stated visual intent — *"As the offset animates, the braided merge pattern flows"* — does
not happen. Framebuffer dumps of the **published** ROM at frames 500 vs 900 (6.7 s apart) differ by
**105 bytes (0.061%)** — only the `T=xxxx` HUD digits. The field is static vertical teal/orange bars;
the emit-both (yellow) branch color never appears.

**Root cause (offset scale mismatch):** `tm_fill32` builds streams with stride `mul × 0x10001`
(≈131 k/196 k value units), but the display offset moves by `(phase + r) * 7 − 16` — four orders of
magnitude below one stride unit. `cmp(L[i], R[j]) = sign((3i′−2j′)·0x10001 + 2·off)`, so with
`|2·off| ≪ 0x10001` no merge decision ever flips: all 16 rows compute identical patterns and a
single-step change would take ~4700 phase steps (~5 min). Ties (`cmp == 0`) require exact equality —
they essentially never fire, so color 3 is absent.

The gate is unaffected by any of this: `corpus_result = trimerge_gate_crc()` uses the header's own
offsets (`GATE_N` rounds), not the display path. Expected value stays **`0xCCCC`**.

## Changes (all in `examples/snes/trimerge.c` — header + gate untouched)

1. **Offset scale fix.** New-row offset steps in whole stride units:
   `off = ((int32_t)(phase & 63u) − 32) · 0x10001`. Each phase step moves the decision boundary by 2
   units of `(3i′−2j′)` (range [−50, 47]), so consecutive rows genuinely differ, and ties
   (`3i′−2j′ = −2m`, m = masked phase − 32) fire periodically → **the yellow emit-both cells appear
   and migrate**. 64-phase cycle; `|off| ≤ 32·0x10001 ≈ 2.1 M`, stream values ≤ ~3.9 M — no s32
   overflow (width discipline: no bare int, no UB).
2. **Waterfall history.** Replace recompute-all-16-rows with: once per sweep (band wrap), shift
   `cellcol` rows down by one (newest at top), compute **one** new row 0 at the current phase,
   `phase++`. The existing 4-rows/frame band redraw repaints the shifted field over the next 4
   frames (64 tiles = 1 KB/frame, well under `UPQ_VBLANK_BUDGET` 5100 B; no cadence change). Init
   pre-fills all 16 rows by running the shift+compute 16 times. CPU drops (1 merge/sweep vs 16);
   `tm_cmp32` stays `noinline` — the `G_SCMP`-as-control-flow stress is unchanged.
3. **Palette breathing (the "3" polish; canvas widening is out — `CANVAS_TILES_W/H` are fixed 16 in
   `bitmap_canvas.h`, a library change out of scope).** Once per sweep, push a 4-color CGRAM update
   (8 B, trivial vs budget): the three branch colors breathe ±2/32 luma on a 32-sweep triangle wave,
   integer math with 0..31 clamp, hue identity preserved (left=teal / right=orange / both=yellow —
   the branch-color semantics stay readable).

## Verification

1. `dev/run.sh trimerge` — the standing 5-way differential + snapshot gate; **must still read
   `0xCCCC`** on MAME + bsnes-jg.

   ```
   ==> host oracle: trimerge gate hash = 0xCCCC
   ==> built build/trimerge.sfc (+mos-a16); corpus_result @ WRAM 0x39
   ==> G_SCMP IR probe (llvm.scmp at s32/s64, used as control flow) + a16 rep/sep
       PASS  llvm.scmp=4  scmp.i64=2  rep/sep=198  (G_SCMP formed incl. s64, drives control flow)
   ==> bsnes-jg: render + assert (build/trimerge-jg.png)
   SMOKE: PASS off=0x39 len=2 got=0xCCCC (ran 500 frames, bsnes-jg)
       SKIP MAME (no SPC700 IPL)
   RESULT: PASS — Three-Way Merge Diff on SNES; MAME + bsnes-jg + corpus hash 0xCCCC host == +mos-a16
   ```
   **PASS** (MAME leg SKIP is pre-existing — same as #99's original verification; the IR probe
   confirms the `G_SCMP` control-flow stress survived the rework). Note `corpus_result` moved to
   WRAM `0x39` (was `0x20`) — manifest updated at publish.

2. **Animation liveness:** frames 500 vs 560 of the new build via `build/jgxcheck` + PIL diff:

   ```
   500 vs 560: 50567 bytes differ (29.39%) -> PASS (>5%)
   frame-500 colors: [(38445, (10, 25, 132)), (7059, (25, 165, 132)), (4928, (214, 94, 10)),
                      (4864, (247, 231, 75)), (2048, (0, 0, 0))]
   ```
   **PASS** — 29.39% delta (was 0.007% on the published ROM), and yellow emit-both
   `(247, 231, 75)` present at 4864 px (~30% of the 128×128 canvas; teal+orange+yellow sum to the
   full canvas area). The braid renders as a flowing diagonal weave with a migrating
   one-stream-dominates wedge.

3. `JGX_BLANKSCAN` clean — `dev/verify-web-roms.sh --only trimerge` after the site ROM refresh:

   ```
     trimerge         PASS  (500 frames, want 0xCCCC)
   verify-web-roms: 1 passed, 0 failed, 0 missing
   ALL PASS — safe to publish
   ```
   **PASS**.

4. Refresh `docs/plans/screenshots/trimerge.png` — done (copied from the gate's
   `build/trimerge-jg.png` render; the #99 plan's embed picks up the new frame). Headless-Chrome
   screenshot of the built site page confirms the emulator boots the new ROM, the braid is live
   (`T=0018 CRC=CCCC` HUD), player centred, no clipping. **PASS**.

## Follow-up fix (same day, user-reported): multi-v-blank update tearing

**Report:** the live page visibly updated the field across more than one v-blank — needless, and it
tears. **Confirmed and root-caused:** the 4-rows/frame band painter (inherited from the static
original, where repainting identical content was invisible) marked each band dirty *as it painted*,
so each band flushed in its own v-blank. Under the waterfall every sweep shifts the whole field one
row → for 3 of every 4 frames the screen showed shifted rows above a marching boundary and stale
rows below it — a 15 Hz tear. The banding is also unnecessary at the DMA layer: the full canvas is
256 tiles × 16 B = **4096 B ≤ `UPQ_VBLANK_BUDGET` 5100 B**, so a whole-field flush fits ONE v-blank.

**Fix:** `field_band` still paints the shadow over 4 frames (CPU spreading — the shadow isn't on
screen), but no longer marks dirty; the sweep-boundary branch marks the **whole canvas** once the
shadow is complete → a single atomic 4 KB flush. `CANVAS_FLUSH_TILES 256` (already set) keeps the
queue from re-splitting it. Worst v-blank = 4096 canvas + ~336 HUD + 8 CGRAM = 4440 B ≤ 5100 B, so
field + HUD + palette land in the *same* v-blank, atomically together.

**Verification (re-run):**

1. `dev/run.sh trimerge` — PASS, unchanged:

   ```
       PASS  llvm.scmp=4  scmp.i64=2  rep/sep=198  (G_SCMP formed incl. s64, drives control flow)
   SMOKE: PASS off=0x39 len=2 got=0xCCCC (ran 500 frames, bsnes-jg)
   RESULT: PASS — Three-Way Merge Diff on SNES; MAME + bsnes-jg + corpus hash 0xCCCC host == +mos-a16
   ```

2. **Tear check** (new): frames 500–507 dumped via `jgxcheck`; for every consecutive pair, any
   canvas-region diff must span the full field (atomic), never a band-confined 32 px stripe:

   ```
   500->501: 121 rows differ, y-span 121px -> ATOMIC
   501->502: canvas identical (paint frame)
   502->503: canvas identical (paint frame)
   503->504: canvas identical (paint frame)
   504->505: canvas identical (paint frame)
   505->506: canvas identical (paint frame)
   506->507: 121 rows differ, y-span 121px -> ATOMIC
   TEAR CHECK: PASS
   ```

   Update cadence settled at ~10 Hz (the shadow paint spans an extra frame or two per sweep);
   the visible update is one v-blank.

## Published

biohack.net `9c13b3d`, tag **v1.0.284** (tag-driven Pages deploy). Manifest selfcheck `off` updated
`0x20 → 0x39`. Scaffold gotcha hit and neutralized: `scaffold.sh` unconditionally re-copies the
skill bundle's `app.js`, which would have reverted 151 lines of the site's newer player (fullscreen/
orientation + blank-start work) — caught before commit, restored from HEAD; **skill fix wanted:
scaffold should not overwrite an existing site `app.js` on update runs.**

## Publish

`/snes-rom-page` update flow for slug `trimerge` on biohack.net (`want` stays `0xCCCC`, `frames`
500); then `dev/verify-web-roms.sh --only trimerge` against the site checkout before deploy.

## Deferred / out of scope

- Canvas widening beyond 16×16 tiles (needs `bitmap_canvas.h` geometry work — a snesgfx library
  change, not a demo fix).
- HDMA backdrop gradient (same reason: no library support yet).

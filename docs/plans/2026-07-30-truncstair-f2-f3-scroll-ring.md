# truncstair F3 + F2 — cheap paint, then a horizontal BG3HOFS scroll ring

**Status:** implemented + verified 2026-07-30. Closes the two truncstair items orphaned by the
Batch B close-out: `[T2]` F3 cheap paint (Open) and the F2 `HOFS` ring (Parked).

User direction: *"finish truncstair. stop deferring."* The F2 half had been deferred three times on a
blocker that turned out not to apply.

## F3 — repaint only when the input moved

The loop advanced `phase` on every 4th iteration but redrew all three bands — and re-DMA'd the whole
4 KB shadow — on **every** iteration. Three of every four repaints spent 48 float quantizations
producing a byte-identical picture. Guarding the repaint on `phase` changing cut that to a quarter
with no premise loss: every float evaluation that changes a pixel still runs.

Superseded in the steady state by F2 below, which removes the per-frame repaint entirely.

## F2 — the recorded blocker did not apply

The investigation recorded this as blocked on a 32-column canvas: an 8 KB CHR shadow that overflows
truncstair's bank-0 `.bss` (~3 KB headroom under `$1FFF`), forcing `_canvas_emit` — which hardcodes
DMA source bank `0x00` — to learn bank `$7E`. That reasoning applies to *widening the canvas*, and
widening is not needed.

`_canvas_init` writes a **static** tilemap: tile index `= row*16 + col`, blank outside the box, and
it never changes per frame — only CHR does. So the ring needs a **one-time map change**: repeat the
16 canvas columns across all 32 tilemap columns as `inx & 15`. The shadow stays 4 KB, `_canvas_emit`
keeps its bank-0 DMA, and no upload-path work is required.

Added as `CANVAS_HTILE` in `bitmap_canvas.h`, **default off** — it changes what every tilemap cell
shows, so it must never be implicit. It is sound only when the drawn field is periodic at the canvas
width; otherwise the repeat is a visible seam.

truncstair qualifies exactly: the `& 127` wrap in the band drawing makes the field periodic at
128 px == the canvas width, so a full-width tiling is the same ramp continued, not a repeated motif.
That wrap was added on 2026-07-28 for this purpose.

**HUD:** `text_init(&a.text, CANVAS_MAP, 1, 25)` shares BG3's tilemap, so a whole-layer `HOFS` would
drag the text sideways with the plot. `build_hbands` holds 16 lines at 0, scrolls the plot's 128, and
holds the remaining 80 at 0 — `hdma_hscroll.h` already supported banded `HSCROLL_BG3HOFS`.

## The finding worth keeping: horizontal rings cannot paint per-frame

A rotating one-column-per-frame refresh was implemented, measured, and **removed**. It halved the
frame rate for no visual gain, for a structural reason that generalises:

`BitmapCanvas` tracks dirt as a contiguous `lo..hi` tile **range** over a **row-major** tile order.

| ring | stages | tiles | dirty range | result |
|---|---|---|---|---|
| vertical (#99c, `mvscrl`) | a **row** | 16 adjacent | 16 tiles / 256 B | drains in one v-blank — paints every frame happily |
| horizontal (this) | a **column** | 16 strided one row apart | **~240 tiles** | queue never empties |

With work queued every frame, `hscrolldb_commit`'s `upq_push_poke16` of the A1Tx pointer loses the
v-blank budget and, per its contract, costs "a stale frame, not a torn table" — the scroll stalls.

This is a property of the data structure, not a tuning value, and the measurements show it:

| `CANVAS_FLUSH_TILES` | steady-state paint | stalls |
|---|---|---|
| 256 | 1 column/frame | 701, 703 |
| 64 | 1 column/frame | 700, 702 — **moved, not removed** |
| 64 | none | **NONE** |

Lowering the budget relocated the symptom, which is what disproved the "flush budget too large"
diagnosis. The fix is to not paint in the steady state at all.

`CANVAS_FLUSH_TILES` is nonetheless left at the library default 64: the 256 override existed to make
a whole-canvas repaint atomic, and F2 deleted that repaint.

### What this costs, stated plainly

The display loop no longer re-derives the picture, so a codegen fault in the float path would show
at boot rather than progressively. The float path still produces every pixel on screen (drawn at
startup) and `truncstair_gate_crc()` still asserts the `G_FPTOSI`/`G_SITOFP` kernel independently —
but the ring does **not** preserve a continuously-re-verified visual, and should not be described as
if it does.

### Visible change

The plot now spans the full 256 px instead of a 128 px centred box. This is inherent: a scroll needs
content to wrap onto. The join is seamless because the field is periodic at exactly 128 px. Keeping
the narrow box would require window masking to clip the layer — more machinery for a smaller picture.

## Tooling defect found

`dev/scroll-ring-check.py` **crashed** instead of reporting a failure: `stalls or 'NONE':<10` formats
a `list` when `stalls` is non-empty, and `list.__format__` rejects a width spec. Only the passing
path had ever run (`mvscrl`), so a checker that could not report a stall had shipped. Fixed by
rendering the list to a string first.

## Verification

1. Gate — `dev/run.sh truncstair`:

```
==> disasm gate (G_FPTOSI __fixsfsi + G_SITOFP __floatsisf + __mulsf3 + rep/sep)
    __fixsfsi=2  __floatsisf=2  __mulsf3=2  rep/sep=8
    PASS  G_FPTOSI+G_SITOFP confirmed (no truncf/floorf/ceilf libcalls)
SMOKE: PASS off=0x31 len=2 got=0x02CA (ran 500 frames, bsnes-jg)
RESULT: PASS — Truncation Staircase on SNES; MAME + bsnes-jg + corpus hash 0x02CA host == +mos-a16
```

**PASS** — CRC and all four libcall counts identical to pre-change, so the compiler stress the demo
exists to exercise is untouched by both F3 and F2.

2. Ring motion — `dev/scroll-ring-check.py --band plot:16:144:x:-1 --start 700 --frames 8`:

```
plot     axis=x-1  stalls=NONE       shift-match min 99.1% mean 99.1%  PASS
60FPS CHECK: PASS
```

**PASS** — no stalled frame pairs, every pair a clean 1 px translation. Shift-match improved
98.6 → 98.9 → 99.1 across the three configurations above, consistent with contention coming out.

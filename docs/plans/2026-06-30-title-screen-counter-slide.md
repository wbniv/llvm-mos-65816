# Title screen: counter-sliding lines, eased timing, overlay masking

## Animation mockup

One ASCII char = one 8×8 tile = 8 px. Screen: 32 tiles wide × 28 tiles tall.
`░` = rainbow backdrop, `▒` = 8×8 text (line0), `█` = 16×16 text (line1).

```
t = 0  (ease-in start, both lines just at the screen edges)
 ________________________________
|▒▒ HILBERT CURVE ▒▒░░░░░░░░░░░|  ← row 0  line0 enters from top
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|  ← row 27
|_______________________________|
                                    (line1 off-screen below, vofs_bot = -120)

t ≈ 60  (mid ease-in, ~1 s — lines closing on centre)
 ________________________________
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|▒▒ HILBERT CURVE ▒▒░░░░░░░░░░░|  ← row 10  line0 decelerating
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|██ SPACE-FILLING ██░░░░░░░░░░░|  ← row 17  line1 decelerating
|██████████████████░░░░░░░░░░░░|  (16×16 = 2 tile rows tall)
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|_______________________________|

t ≈ 124  (hold — both at rest, 2 s)
 ________________________________
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|▒▒ HILBERT CURVE ▒▒░░░░░░░░░░░|  ← row 12  line0 at rest
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|██ SPACE-FILLING ██░░░░░░░░░░░|  ← rows 14-15  line1 at rest
|██████████████████░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|_______________________________|

t ≈ 260  (ease-out, ~1 s in — lines departing their respective edges)
 ________________________________
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|▒▒ HILBERT CURVE ▒▒░░░░░░░░░░░|  ← row 3  line0 sliding out top
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|██ SPACE-FILLING ██░░░░░░░░░░░|  ← row 24  line1 sliding out bottom
|██████████████████░░░░░░░░░░░░|
|░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░|
|_______________________________|
  (screen simultaneously fading to black → demo starts)
```

## Context

Two problems with the current `title_layer.h`:

1. **Single VOFS, same direction.** Both lines share one `BG2VOFS` value and move together.
   The intended effect is counter-sliding: line0 descends from the top, line1 rises from the
   bottom. This requires two independent per-band VOFS values via HDMA split on `BG2VOFS`.

2. **Demo overlays visible during title.** All demos call `display_add(demo_drawable)` *before*
   `title_begin()`, so the demo's BG3/OBJ TM bits are active from frame 1 through the hold
   period. Demos like spigot, vaprintf, fft, sort-race, and 1d-ca show their canvas/text
   simultaneously with the title card. Fix: mask all non-BG2 TM bits at the start of
   `_title_begin_impl()` and restore them in `title_end()`.

Requested timing: **2 s ease-in · 2 s hold · 1.2 s ease-out.**

## HDMA layout (two-channel)

Add to `examples/snes/snesgfx/hdma_hscroll.h`:

```c
#define VSCROLL_BG2VOFS  0x10u   /* B-bus lo byte for BG2VOFS ($2110) */
```

`HScroll2` / `hscroll2_build` / `hscroll2_arm` already handle write-twice latches and work
unchanged for VOFS.

**Channel assignment** (hud.h arms 1–2 only inside Mode-7 demo loops — both 3 and 4 are
free during the title intro):
- `TITLE_HDMA_CHAN_VOFS = 3` — BG2VOFS (per-band vertical, table rebuilt every emit frame)
- `TITLE_HDMA_CHAN_HOFS = 4` — BG2HOFS (static pixel-centering, built once in reserve)

`REG_HDMAEN = (1u<<3)|(1u<<4)` during title; clear both on exit.

## Geometry

Scanline split at 108 (= (TITLE_ROW0+1)×8+4).
Band A [0..107] → `vofs_top` — line0 (tilemap row 12; screen_row = 96 − V).
Band B [108..223] → `vofs_bot` — line1 (tilemap rows 14–15; screen_row = 112 − V).

**Ease-in start positions** (text enters the screen exactly at the edge):
- `TITLE_VOFS_TOP_START = 96` → line0 at screen_row 0 (top edge) at start of fly-in
- `TITLE_VOFS_BOT_START = -120` → line1 at screen_row 232 (just off bottom) at start

`vofs_bot` is `int16_t`; masked to 10 bits for the HDMA table:
`(uint16_t)(-120) & 0x3FF = 904` — the PPU wraps correctly via mod-1024.

**Ease-in (~2 s ≈ 120 frames at 60 fps):** exponential decay, shift = 5:
```c
if (t->vofs_top > 0) {
    int16_t s = (int16_t)(t->vofs_top >> 5); if (s < 1) s = 1;
    t->vofs_top -= s; if (t->vofs_top < 0) t->vofs_top = 0;
}
if (t->vofs_bot < 0) {
    int16_t s = (int16_t)((-t->vofs_bot) >> 5); if (s < 1) s = 1;
    t->vofs_bot += s; if (t->vofs_bot > 0) t->vofs_bot = 0;
}
```
With shift=5, convergence: 96→0 in ~124 frames ≈ 2.1 s ✓ (symmetric for bot).

**Hold (2 s = 120 frames):** both vofs values fixed at 0. Shimmer/rainbow continues.
Define `TITLE_HOLD_FRAMES 120` and update all 34 `title_end(d, &t, N)` call sites + 4
`splash16` calls to use it.

**Ease-out (~1.2 s ≈ 75 frames at 60 fps):** constant velocity 3 px/frame in opposite
directions:
- `vofs_top += TITLE_EASEOUT_VEL` → line0 slides off top in ⌈96/3⌉ = 32 frames
- `vofs_bot -= TITLE_EASEOUT_VEL` → line1 slides off bottom in ⌈120/3⌉ = 40 frames

Both well within the 1.2 s window; `display_fade(d, 0)` (16-step fade) runs simultaneously.

## TitleLayer struct delta

**Remove:** `int16_t vofs, vel` (single-line tracking)

**Add:**
```c
int16_t  vofs_top;   /* BG2VOFS band A — 0=target, positive=line0 above screen  */
int16_t  vofs_bot;   /* BG2VOFS band B — 0=target, negative=line1 below screen  */
uint8_t  demo_tm;    /* demo drawables' TM bits: saved on begin, restored on end */
HScroll2 vscroll;    /* 2-band BG2VOFS HDMA table (rebuilt each emit frame)      */
```

`HScroll2 hscroll` stays (BG2HOFS pixel-centring, channel 4).

## `_title_reserve()` changes

```c
t->vofs_top = TITLE_VOFS_TOP_START;
t->vofs_bot = TITLE_VOFS_BOT_START;
REG_BG2VOFS = (uint8_t)TITLE_VOFS_TOP_START; REG_BG2VOFS = 0; /* static init latch */
hscroll2_build(&t->vscroll, SPLIT, (int16_t)TITLE_VOFS_TOP_START,
                                   (int16_t)TITLE_VOFS_BOT_START);
hscroll2_arm(TITLE_HDMA_CHAN_VOFS, VSCROLL_BG2VOFS, &t->vscroll);
hscroll2_build(&t->hscroll, SPLIT, _title_hofs(t->line0), 0);
hscroll2_arm(TITLE_HDMA_CHAN_HOFS, HSCROLL_BG2HOFS, &t->hscroll);
```

## `_title_emit()` changes

Replace `upq_push_scroll(BG2VOFS, ...)` with HDMA table rebuild — no UpQ slot needed:
```c
/* ease-in / ease-out position updates (see above) */
hscroll2_build(&t->vscroll, SPLIT, t->vofs_top, t->vofs_bot);
/* HDMA reads the updated WRAM table at the next vblank automatically */
```

Fly-in complete when `t->vofs_top == 0 && t->vofs_bot == 0`.

## `_title_begin_impl()` TM masking

```c
uint8_t demo_tm = d->tm;           /* demo layers' TM bits before title is added    */
display_add(d, (Drawable *)t);     /* d->tm |= TM_BG2                               */
t->demo_tm = demo_tm;
d->tm = TM_BG2; REG_TM = TM_BG2; /* hide all demo layers for the title duration   */
```

## `title_end()` TM restore

```c
display_hold(d, frames);
t->restore = 1;
display_fade(d, 0);                /* lines slide out while screen fades            */
d->tm |= t->demo_tm;              /* put demo layers back before hide removes BG2  */
display_hide_layer(d, &t->base);  /* removes TM_BG2; writes REG_TM = demo_tm      */
REG_HDMAEN = 0;
REG_BG2HOFS = 0; REG_BG2HOFS = 0;
REG_BG2VOFS = 0; REG_BG2VOFS = 0;
t->active = 0;
display_fade_to(d, INIDISP_ON);   /* fades up showing demo content                 */
```

## Files touched

- `examples/snes/snesgfx/hdma_hscroll.h` — add `VSCROLL_BG2VOFS 0x10u`
- `examples/snes/snesgfx/title_layer.h` — all animation + masking changes (header-only)
- `examples/snes/*.c` (34 call sites) — `title_end` hold N → `TITLE_HOLD_FRAMES`
- `examples/snes/snesgfx/title_layer.h` `splash16` — same hold update

## Audit doc update

Add **"overlay during title"** notes to
`docs/investigations/2026-06-30-title-screen-vofs-sweep-audit.md` VRAM init column for
spigot, vaprintf, fft, sort-race, 1d-ca (demo layers visible before the TM-masking fix).
Mark all resolved by `_title_begin_impl` TM save/restore.

## Verification

1. Build `hilbert`, `rdiff`, `avalanche` — run in bsnes-jg, capture frames at ~60, ~180, ~250:
   - Line0 enters from top, line1 rises from bottom simultaneously
   - Both settle ≈ 2 s; hold ≈ 2 s; exit their respective edges ≈ 1.2 s
   - No demo canvas/text visible during title hold
2. Build spigot, sort-race, fft — confirm HUD/canvas absent during title card
3. All 35 corpus hashes unchanged (title is pre-loop, gate-neutral)
4. `-verify-machineinstrs` clean

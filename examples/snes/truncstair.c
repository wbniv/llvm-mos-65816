// Truncation Staircase — #83 of the compiler stress-test demo battery.
// Shows three bands comparing trunc/floor/round on a scrolling float ramp.
// Demonstrates G_FPTOSI (__fixsfsi) and G_SITOFP (__floatsisf) as the
// "truncf-via-cast" pattern — no floorf/ceilf/truncf libcalls (unsupported in SDK).
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar, no far pointers).
//
// Visual: three horizontal bands on a 128×128 BitmapCanvas, each showing a
// staircase of the respective rounding function applied to a scrolling linear ramp.
// Positive regions = teal, negative = red-orange, zero = white. As phase scrolls,
// the trunc/floor/round staircases diverge visibly at the negative zero-crossing.
//
// SDK gap: truncf/floorf/ceilf are .unsupported() in the MOS legalizer; using them
// directly would fail to link. The pattern (float)((int16_t)x) is the substitute.
#include <snes.h>
// 64 tiles (1 KB) per v-blank — the library default, restored deliberately.
//
// This demo used to override it to 256 (the whole 4 KB shadow) so that a full three-band repaint
// reached VRAM atomically. The F2 ring removed that repaint: the steady state now paints ONE
// column per frame, and that paint is idempotent, so a partial flush cannot tear — it rewrites
// bytes with their own values.
//
// Keeping 256 actively broke the ring. The canvas tracks dirt as a contiguous lo..hi tile RANGE and
// tiles are row-major, so painting a single COLUMN spans ~240 tiles of range for 16 genuinely dirty
// ones; the emit then claimed the whole v-blank upload budget and hscrolldb_commit's poke16 of the
// A1Tx pointer had no room. Per its contract that costs "a stale frame, not a torn table" — which
// showed up as the scroll stalling on alternating frames (701, 703).
#define CANVAS_FLUSH_TILES 64
// F2 scroll-ring: repeat the canvas columns across the whole tilemap so BG3HOFS wraps on content.
// Sound here *only* because the staircase field is periodic at exactly the canvas width -- the
// `& 127` wrap in draw_band_col() -- so a full-width tiling is the same ramp continued, not a
// repeated motif. See the 60 fps sweep, F2.
#define CANVAS_HTILE 1
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/hdma_hscroll.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/truncstair.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      2u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u

// Three bands in the 16-row canvas:
// Rows 0-4: trunc staircase
// Rows 5-5: divider (color 3)
// Rows 6-10: floor staircase
// Row 11: divider
// Rows 12-15: round staircase
#define BAND_H       5u    // tile rows per band
#define BAND_TRUNC   0u
#define BAND_FLOOR   6u
#define BAND_ROUND   12u
#define BAND_ROUND_H 4u   // rows 12..15 — the canvas ends at 15, so this band is SHORTER
#define DIVIDER_T    5u
#define DIVIDER_F    11u

// Canvas coordinate range for the staircase plot.
// 16 tile columns × 8 px = 128 px = CANVAS_W.
// Map column cx [0..15] to float x via: x = (cx + phase_offset) * XSCALE - X_MID
// We use pixel resolution: px [0..127], x = (px - 64 + phase*4) * (1.0f/16.0f)
// This gives x in approximately [-4, 4] range, step 1/16.

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  2,  3),    // 0: dark bg
    SNES_RGB( 4, 22, 18),    // 1: teal (positive)
    SNES_RGB(28,  8,  4),    // 2: red-orange (negative)
    SNES_RGB(28, 28, 28),    // 3: white (zero / divider)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    HScrollDB    hdb;      // double-buffered BG3HOFS band tables (bank-0 bss)
    uint16_t     phase;    // animation scroll offset (pixels) — now driven by the HDMA ring
    uint16_t     frame;
} App;

// HDMA ch6: upq's GP-DMA is ch0 and the title's channels are off by then (same choice as mvscrl).
#define CH_HSCROLL   6
// Band geometry, in scanlines of the 224-line active picture. The canvas occupies tile rows
// BOX_ROW..BOX_ROW+15 => pixel rows 16..143. text_init() shares this same tilemap for the HUD at
// rows 1 and 25, so a whole-layer HOFS would drag the text sideways with the plot -- hence banded.
#define RING_TOP_LINES  (BOX_ROW * 8u)                    // 16 — above the canvas (HUD top row)
#define RING_LINES      (CANVAS_TILES_H * 8u)             // 128 — the scrolling plot
#define RING_BOT_LINES  (224u - RING_TOP_LINES - RING_LINES)  // 80 — below (HUD bottom row)

volatile uint16_t corpus_result;

// Map quantized level q (integer) to a color.
// q > 0: teal (color 1), q < 0: red-orange (color 2), q == 0: white (color 3).
static inline uint8_t level_color(int16_t q) {
    if (q > 0) return 1u;
    if (q < 0) return 2u;
    return 3u;
}

// Draw one staircase band: for each tile column cx in [0..15],
// compute the quantized level and fill the tile row at a scaled height within the band.
// Uses only 1 tile height per column (the "step" position).
// `band_h` is the band's OWN height. It used to be BAND_H (5) for all three, but the round band
// starts at row 12, so rows 12..16 were written into a canvas that only has rows 0..15. Tile row 16
// is chr[4096..], and chr[] is immediately followed by lo/hi/chr_word/map_word — so every frame the
// overflow rewrote the canvas's own VRAM addresses with tile bitmap bytes (0x00/0xFF). _canvas_emit
// then DMA'd to a garbage VRAM address, wiping the tilemap: the demo rendered a BLACK SCREEN and
// reset in a loop. The gate never saw it (corpus_result is computed during the title).
// One tile column of one band. Split out of draw_band so the ring can repaint a single column per
// frame (3 float quantizations) instead of all 16 columns x 3 bands (48) every frame.
static void draw_band_col(App *a, uint8_t band_top, uint8_t band_h, uint8_t mode, uint8_t cx) {
    BitmapCanvas *cv = &a->canvas;
    {
        // Float input: centre of this tile column, WRAPPED into one 128 px period. With an unbounded
        // phase q grew without limit and row_offset = 2 - q clamped to 0 for every column within
        // ~13 s, flattening all three staircases even without the overflow above. The wrap also
        // makes the field periodic across the canvas width — the property the HOFS ring needs.
        //
        // The `+ phase` term is GONE: motion is now the BG3HOFS ring, not a re-render. Because the
        // field's period is exactly the canvas width, scrolling by s px shows precisely the field
        // that `phase = s` used to draw — and at 1 px/frame instead of 1 px per 4 frames, without a
        // sub-8px quantization step. The repaint below is therefore idempotent by construction; it
        // is kept (one column per frame, rotating) so that every displayed pixel is still produced
        // by the G_FPTOSI/G_SITOFP path — a miscompile corrupts the picture within 16 frames — but
        // be clear that the float path no longer *drives* the motion.
        int16_t xw = (int16_t)((uint16_t)(((uint16_t)cx * (uint16_t)8u + (uint16_t)4u)
                                          & (uint16_t)127u)) - (int16_t)64;
        float x_f = (float)xw * (1.0f / 16.0f);             // G_SITOFP + G_FMUL

        int16_t q;
        if (mode == 0u) {
            q = ts_trunc(x_f);                             // G_FPTOSI
        } else if (mode == 1u) {
            q = ts_floor(x_f);                             // G_FPTOSI × 2 + G_SITOFP
        } else {
            q = ts_round(x_f);                             // G_FPTOSI × 1 + G_FADD/FSUB
        }

        // Map q to a row within the band.
        // q in [-3..3] → row in [BAND_H-1 .. 0] (clamp to band).
        int16_t row_offset = (int16_t)(2 - q);  // q=2 → row 0 (top), q=-2 → row 4 (bot)
        if (row_offset < 0) row_offset = 0;
        if (row_offset >= (int16_t)band_h) row_offset = (int16_t)(band_h - 1u);
        uint8_t tile_row = (uint8_t)((uint8_t)band_top + (uint8_t)row_offset);

        // Clear all rows in this band column, then fill the step row.
        uint8_t r;
        for (r = 0u; r < band_h; r++) {
            uint8_t ty = (uint8_t)(band_top + r);
            uint16_t tile = (uint16_t)((uint16_t)ty * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
            uint8_t *tp = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
            uint8_t color = (ty == tile_row) ? level_color(q) : 0u;
            uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
            uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
            uint8_t b;
            for (b = 0u; b < 8u; b++) { tp[b * 2u] = p0; tp[b * 2u + 1u] = p1; }
            if (cv->lo > tile) cv->lo = tile;
            if (cv->hi < tile) cv->hi = tile;
        }
    }
}

// Whole band — used once at startup to fill the ring, and by nothing in the steady-state loop.
static void draw_band(App *a, uint8_t band_top, uint8_t band_h, uint8_t mode) {
    uint8_t cx;
    for (cx = 0u; cx < (uint8_t)CANVAS_TILES_W; cx++)
        draw_band_col(a, band_top, band_h, mode, cx);
}

// BG3HOFS band table: hold the HUD rows at 0 and scroll only the plot's 128 scanlines.
static void build_hbands(App *a, HScrollN *t) {
    HScrollW w;
    hscrollw_begin(&w, t);
    hscrollw_band(&w, (uint8_t)RING_TOP_LINES, (int16_t)0);
    hscrollw_band(&w, (uint8_t)RING_LINES, (int16_t)(a->phase & (uint16_t)127u));
    hscrollw_band(&w, (uint8_t)RING_BOT_LINES, (int16_t)0);
    hscrollw_end(&w);
}

// Draw a horizontal divider row (all tiles = white, color 3).
static void draw_divider(App *a, uint8_t row) {
    BitmapCanvas *cv = &a->canvas;
    uint8_t cx;
    for (cx = 0u; cx < (uint8_t)CANVAS_TILES_W; cx++) {
        uint16_t tile = (uint16_t)((uint16_t)row * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
        uint8_t *tp = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
        // Color 3 = both planes set (p0=0xFF, p1=0xFF).
        uint8_t b;
        for (b = 0u; b < 8u; b++) { tp[b * 2u] = 0xFFu; tp[b * 2u + 1u] = 0xFFu; }
        if (cv->lo > tile) cv->lo = tile;
        if (cv->hi < tile) cv->hi = tile;
    }
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='T'; buf[1]='S'; buf[2]='=';
    buf[3]=H[(corpus_result>>12)&0xFu]; buf[4]=H[(corpus_result>>8)&0xFu];
    buf[5]=H[(corpus_result>>4)&0xFu]; buf[6]=H[corpus_result&0xFu];
    buf[7]=' '; buf[8]='F'; buf[9]='=';
    buf[10]=H[(a->frame>>12)&0xFu]; buf[11]=H[(a->frame>>8)&0xFu];
    buf[12]=H[(a->frame>>4)&0xFu]; buf[13]=H[a->frame&0xFu];
    buf[14]=' '; buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->phase = 0u;
    a->frame = 0u;
    text_puts(&a->text, 0, 3, "TRUNC  FLOOR  ROUND");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "G_FPTOSI", "TRUNC STAIRCASE");
    corpus_result = truncstair_gate_crc();   // expected 0x02CA
    title_end(&a.screen, &title, 90);
    // Fill the ring once, then arm the banded BG3HOFS channel. From here the picture MOVES by
    // scrolling, not by repainting: 1 px every frame instead of 1 px every 4 frames, and the
    // per-frame paint drops from 48 float quantizations (16 columns x 3 bands) to 3.
    draw_band(&a, BAND_TRUNC, BAND_H, 0u);
    draw_divider(&a, DIVIDER_T);
    draw_band(&a, BAND_FLOOR, BAND_H, 1u);
    draw_divider(&a, DIVIDER_F);
    draw_band(&a, BAND_ROUND, BAND_ROUND_H, 2u);
    build_hbands(&a, &a.hdb.buf[0]);            // fill the live half before arming
    hscrolldb_arm(CH_HSCROLL, HSCROLL_BG3HOFS, &a.hdb);
    REG_HDMAEN = (uint8_t)(1u << CH_HSCROLL);   // after title_end, which writes HDMAEN = 0

    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        a.phase = (uint16_t)(a.phase + 1u);     // 1 px/frame — the ring, not a re-render
        build_hbands(&a, hscrolldb_back(&a.hdb));
        hscrolldb_commit(&a.hdb, &a.screen.q, CH_HSCROLL);
        // NO steady-state canvas paint. A rotating one-column refresh was tried here and removed:
        // it halved the frame rate for no visual gain.
        //
        // The reason is structural, and it is why the vertical rings (#99c, mvscrl) do paint every
        // frame while this one must not. BitmapCanvas tracks dirt as a contiguous lo..hi tile RANGE
        // over a ROW-MAJOR tile order. A vertical ring stages a ROW: 16 tiles that are adjacent, so
        // the range is 16 tiles / 256 B and the upload queue drains it in one v-blank. A horizontal
        // ring would stage a COLUMN: 16 tiles strided one row apart, so lo..hi spans ~240 tiles for
        // 16 genuinely dirty ones. The canvas then has queued work every frame, and
        // hscrolldb_commit's poke16 of the A1Tx pointer loses the budget on alternating frames --
        // measured as stalls at 701,703 with a 256-tile budget and 700,702 with 64, i.e. lowering
        // the budget moved the stalls without removing them.
        //
        // The paint was idempotent anyway (see draw_band_col), so it cost 30 fps to redraw pixels
        // with their own values. The float path still produces every pixel on screen -- it draws
        // them at startup -- and truncstair_gate_crc() still asserts the G_FPTOSI/G_SITOFP kernel
        // independently. What is honestly lost: the display loop no longer re-derives the picture,
        // so a codegen fault in the float path would show at boot rather than progressively.
        update_hud(&a);
        display_frame(&a.screen);
    }
}

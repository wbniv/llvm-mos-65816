// Fabs Ridgeline — #80 of the compiler stress-test demo battery.
// Renders an animated terrain ridgeline on a 128x128 BG3 canvas driven by the tent-map
// iteration using fabsf as the hot absolute-value operation.  Builds default-8-bit AND
// +mos-a16 AND +mos-xy16 (no far pointers -> full 5-way bar).
//
// Codegen corner: G_FABS via __builtin_fabsf targeting the TARGET-CUSTOM path
// legalizeFAbs at MOSLegalizerInfo.cpp:369 (inline AND of src with inverted sign mask
// 0x7FFFFFFF — one AND instruction, no libcall).  Distinct from:
//   #57 medfilt: integer G_ABS on int16_t (different opcode/legalizer at :281)
//   #45 metaball: union float/uint32_t type-pun through the integer ALU
// Tent map: x_next = 1 - |2x - 1| with four separate float ops (no FMA):
//   __mulsf3 (2x), __subsf3 (x-1), G_FABS (inline AND), __subsf3 (1-|…|)
//
// Visual: 16-column terrain profile on the 128x128 BG3 2bpp canvas, updated 4 tile
// columns per frame (full refresh every 4 frames).  Each column gets a ridge height
// from 3 tent-map iterations seeded by (col, t).  Sky (color 0) above, bright cap
// (color 3) at ridge, medium slope (color 2), dark terrain fill (color 1) below.
// The tent-map V-notch kinks create sharp peaks and valleys.
#include <snes.h>
#define CANVAS_FLUSH_TILES 64
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/fabsridge.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8
#define BOX_ROW      6
#define HUD_TOP_ROW  1
#define HUD_BOT_ROW  25
#define NCOL         4
#define NTILES_W     16
#define NTILES_H     16
#define BAND_COLS    4    // tile columns updated per frame

// BG3 2bpp palette: sky → terrain fill → slope → ridge cap.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(1, 1, 4),           // 0: dark sky
    SNES_RGB(6, 22, 10),         // 1: dark terrain fill
    SNES_RGB(10, 28, 14),        // 2: medium slope
    SNES_RGB(28, 31, 18),        // 3: bright ridge cap
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     t;
    uint16_t     t_snap;
    uint8_t      band_col;
} App;

volatile uint16_t corpus_result;

// Fill an 8x8 tile at (cx,cy) with solid 2bpp color (0..3).
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *tp = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { tp[r * 2u] = p0; tp[r * 2u + 1u] = p1; }
}

// Render tile column cx from ridge height derived via tent map at t_snap.
__attribute__((noinline))
static void draw_column(App *a, uint8_t cx, uint16_t t_snap) {
    // height in [0..15]: number of terrain tile rows from the bottom
    uint16_t h = fr_height((uint16_t)cx, t_snap, (uint16_t)14u);
    // cap_row: the tile row that holds the ridge cap (0=top, 15=bottom)
    // More terrain (higher h) → cap_row is smaller (higher up on screen)
    uint8_t cap_row = (uint8_t)(15u - (uint8_t)h);
    for (uint8_t cy = 0u; cy < (uint8_t)NTILES_H; cy++) {
        uint8_t color;
        if (cy < cap_row) {
            color = 0u;   // sky above ridge
        } else if (cy == cap_row) {
            color = 3u;   // bright cap
        } else if (cy == (uint8_t)(cap_row + (uint8_t)1u)) {
            color = 2u;   // medium slope just below cap
        } else {
            color = 1u;   // dark terrain fill
        }
        cell_fill(&a->canvas, cx, cy, color);
    }
    // Mark column dirty: tile indices cx, cx+CANVAS_TILES_W, ..., cx+15*CANVAS_TILES_W
    uint16_t lo = (uint16_t)(uint16_t)cx;
    uint16_t hi = (uint16_t)((uint16_t)((uint16_t)(NTILES_H - 1u) * (uint16_t)CANVAS_TILES_W) + (uint16_t)cx);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    a->t_snap = (uint16_t)0u;
    a->band_col = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "FABS RIDGELINE  G_FABS");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "FABS RIDGELINE", "TENT MAP FABSF");
    corpus_result = fabsridge_gate_crc();   // expected 0x161A
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.t++;
        uint8_t cx0 = (uint8_t)((uint8_t)(a.band_col) * (uint8_t)BAND_COLS);
        for (uint8_t i = 0u; i < (uint8_t)BAND_COLS; i++) {
            uint8_t cx = (uint8_t)(cx0 + i);
            if (cx < (uint8_t)NTILES_W) draw_column(&a, cx, a.t_snap);
        }
        a.band_col++;
        if ((uint8_t)((uint8_t)(a.band_col) * (uint8_t)BAND_COLS) >= (uint8_t)NTILES_W) {
            a.band_col = (uint8_t)0u;
            a.t_snap = (uint16_t)(a.t + (uint16_t)7u);
        }
        display_frame(&a.screen);
    }
}

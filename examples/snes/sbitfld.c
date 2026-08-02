// Signed-Bitfield Terrain Sculptor — #78 of the compiler stress-test demo battery.
// Renders the portable signed-bitfield terrain (examples/65816/sbitfld.h) into a
// 128x128 BG3 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16
// (no far pointers -> full 5-way bar).
//
// The codegen corner: G_SEXT_INREG at MOSLegalizerInfo.cpp:130 via signed bitfield
// read-back (int16_t height:5 / slope:4 / flow:4).  Reading a signed field fires
// the sign-extension legalizer → shl(x, 16-N) >> (16-N) (ASL/ASR pair).
// Distinct from #29b truchet and #52 disbits (both uint, zero-extend, no sext).
//
// Visual: animated terrain heightmap on the 128x128 canvas.  Signed height values
// determine the 4-colour shade (deep valley=indigo, shallow valley=teal, low
// ridge=orange, high ridge=gold).  Each frame one erosion step advances: positive
// slope erodes ridges, negative slope fills valleys; the wavefront of signed change
// sweeps across the grid. Signed valleys (impossible with unsigned) are the proof.
// Shadow update: one tile-row per frame; full canvas is still flushed atomically.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/sbitfld.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        1
#define NTILES_W    16
#define NTILES_H    16

// Height-band palette: indigo (deep valley) → teal → orange → gold (high ridge).
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  2, 14),   // 0: deep valley (signed negative < -4)
    SNES_RGB( 4, 20, 18),   // 1: shallow valley (-4..−1)
    SNES_RGB(24, 14,  4),   // 2: low ridge (0..7)
    SNES_RGB(28, 22,  4),   // 3: high ridge (8..15)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    SBCell       grid[SB_H][SB_W];
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
}

__attribute__((noinline))
static void field_band(App *a) {
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)NTILES_H; cy++) {
        for (uint8_t cx = 0u; cx < (uint8_t)NTILES_W; cx++) {
            int16_t h = a->grid[cy][cx].height;  // G_SEXT_INREG: 5-bit signed
            uint8_t col = sb_color(h);
            canvas_fill_solid_tile(&a->canvas, cx, cy, col);
        }
    }
}

/* Live erosion is row-incremental; the full 256-cell signed-bitfield stress remains in the gate. */
static void step_band(App *a) {
    uint8_t y0 = (uint8_t)(a->band * BAND);
    for (uint8_t y=y0; y<(uint8_t)(y0+BAND); y++) for (uint8_t x=0; x<NTILES_W; x++) {
        int16_t h=a->grid[y][x].height, s=a->grid[y][x].slope, f=a->grid[y][x].flow;
        if (s>0 && h>-16) h--; else if (s<0 && h<15) h++;
        f=(int16_t)((f+s)>>1); if(f>7)f=7; if(f< -8)f=-8;
        a->grid[y][x].height=h; a->grid[y][x].flow=f;
    }
}

static void fmt_hex4(char *buf, uint16_t v, uint8_t n) {
    static const char H[] = "0123456789ABCDEF";
    for (int8_t i = (int8_t)(n - 1u); i >= (int8_t)0; i--) {
        buf[i] = H[v & 0xFu];
        v = (uint16_t)(v >> 4u);
    }
}

static void update_hud(App *a) {
    // Show step count and gate CRC.
    char buf[21];
    buf[0]='S'; buf[1]='T'; buf[2]='E'; buf[3]='P'; buf[4]='=';
    fmt_hex4(buf + 5, a->t, 4);
    buf[9]=' '; buf[10]='C'; buf[11]='R'; buf[12]='C'; buf[13]='=';
    fmt_hex4(buf + 14, corpus_result, 4);
    buf[18]=' '; buf[19]=' '; buf[20] = '\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    sb_init(a->grid);
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "SIGNED-BITFIELD TERRAIN");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "G_SEXT_INREG", "SIGNED BITFIELDS");
    corpus_result = sbitfld_gate_crc();  // runs during title; expected 0x40C5
    title_end(&a.screen, &title, 90);
    for (;;) {
        step_band(&a);       // erode only the rows painted this frame
        a.t++;
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)NTILES_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}

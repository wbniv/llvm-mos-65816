// Pressure-Cooker Fixed-Point Evaluator — #109 of the compiler stress-test battery (Round 6, Cluster E).
// Re-stresses patch 0011 (scavenger-$p): a giant straight-line 32-bit fixed-point expression per pixel
// whose compare's N/Z is consumed AFTER several __mulsi3/__divsi3 calls (the compare forced live across
// the call-clobber) under a dozen live 32-bit temps. The a16/xy16 legs are load-bearing (0011
// accum-gated); default 8-bit is the contrast. Builds all three (5-way bar).
//
// Visual: a per-pixel evaluated implicit surface — each cell coloured by the field's level set — with a
// slow palette cycle for liveness (the per-pixel eval is heavy, so the field is recomputed occasionally
// at a new time step). A wrong flag-liveness spill flips the select and both scrambles the surface AND
// diverges the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/pcooker.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        1
#define WIN_W       16
#define WIN_H       16
#define RECOMPUTE_FRAMES 90u

static uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  4, 16),
    SNES_RGB( 8, 18, 22),
    SNES_RGB(22, 14, 26),
    SNES_RGB(30, 24, 14),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cellcol[WIN_H][WIN_W];
    int16_t      surf_t;
    uint16_t     frames;
    uint16_t     t;
    uint8_t      band;
    uint8_t      pal_phase;
} App;

volatile uint16_t corpus_result;

// Evaluate the implicit surface over the whole window (heavy: 256 pc_eval, each 6 mul + 4 div).
static void compute_field(App *a) {
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++) {
            int16_t px = (int16_t)((int16_t)((int16_t)c - (int16_t)8) * (int16_t)9);
            int16_t py = (int16_t)((int16_t)((int16_t)r - (int16_t)8) * (int16_t)9);
            a->cellcol[r][c] = pc_color(pc_eval(px, py, a->surf_t));
        }
    }
}

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
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++)
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++)
            canvas_fill_solid_tile(&a->canvas, cx, cy, a->cellcol[cy][cx]);
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='T'; buf[1]='=';
    buf[2]=H[(a->t >> 12) & 0xFu]; buf[3]=H[(a->t >> 8) & 0xFu];
    buf[4]=H[(a->t >>  4) & 0xFu]; buf[5]=H[a->t & 0xFu];
    buf[6]=' '; buf[7]='C'; buf[8]='R'; buf[9]='C'; buf[10]='=';
    buf[11]=H[(corpus_result >> 12) & 0xFu]; buf[12]=H[(corpus_result >> 8) & 0xFu];
    buf[13]=H[(corpus_result >>  4) & 0xFu]; buf[14]=H[corpus_result & 0xFu];
    buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->surf_t = (int16_t)0;
    a->frames = (uint16_t)0u;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    a->pal_phase = (uint8_t)0u;
    compute_field(a);
    text_puts(&a->text, 0, 2, "PRESSURE-COOKER FIELD");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "PCOOKER", "COMPARE LIVE ACROSS CALLS");
    corpus_result = pcooker_gate_crc();   // runs during title; expected 0xEE6D
    title_end(&a.screen, &title, 90);
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo = (uint16_t)0u;                        // shadow complete: mark the WHOLE
            a.canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);      // canvas -> one atomic v-blank flush
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
            // cheap palette cycle every band pass; occasionally re-evaluate the surface at a new t.
            a.pal_phase++;
            uint8_t k = (uint8_t)(a.pal_phase & 31u);
            bg3_pal[1] = SNES_RGB((uint8_t)(4u + (k >> 2)), 18u, 22u);
            bg3_pal[2] = SNES_RGB(22u, (uint8_t)(10u + (k >> 3)), 26u);
            upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
        }
        a.frames++;
        if (a.frames >= (uint16_t)RECOMPUTE_FRAMES) {
            a.frames = (uint16_t)0u;
            a.surf_t = (int16_t)(a.surf_t + (int16_t)7);
            compute_field(&a);   // heavy re-eval (infrequent)
        }
        display_frame(&a.screen);
    }
}

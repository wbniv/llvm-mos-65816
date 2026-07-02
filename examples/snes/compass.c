// Copysign Compass — #81 of the compiler stress-test demo battery.
// Renders the portable copysign vector field (examples/65816/compass.h) into a
// 128x128 BG3 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16.
//
// The codegen corner:
//   __builtin_copysignf(1.0f, x) → G_FCOPYSIGN → LegalizerHelper:8899-8960
//     (inline: AND sign-bit of src, AND inverted sign-bit of dst, OR)
//   __builtin_signbitf(x) → G_IS_FPCLASS(fcNeg) → inline sign-bit check
// Both are inline — no libcall, very fast on the 65816 (unlike __floatsisf).
// Distinct from #45 metaball (union type-pun, integer ALU, never G_FCOPYSIGN)
// and #57 medfilt (integer G_ABS, no float sign).
//
// Visual: 16×16 tile compass lattice. Each tile colour represents the quadrant
// of a rotating vector field: gold=NE (+,+), teal=NW (-,+), orange=SE (+,-),
// indigo=SW (-,-). As phase sweeps, the field rotates and the quadrant
// boundaries swirl across the canvas, sign-flipping crisply at zero-crossings
// where copysignf switches between ±1.
// Band update: 4 rows/frame (1024 B DMA, safe for V-blank).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/compass.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define NTILES_W    16
#define NTILES_H    16

// Quadrant palette: NE=gold, NW=orange, SE=teal, SW=indigo.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(28, 24,  2),    // 0: NE (+,+)  gold
    SNES_RGB( 2,  4, 14),    // 1: NW (-,+)  indigo
    SNES_RGB(26, 12,  2),    // 2: SE (+,-)  orange
    SNES_RGB( 4, 20, 16),    // 3: SW (-,-)  teal
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    int16_t      phase;    // animation phase (increments each frame)
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
            uint8_t col = cs_cell((uint16_t)cx, (uint16_t)cy, a->phase);
            cell_fill(&a->canvas, cx, cy, col);
        }
    }
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - (uint16_t)1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='P'; buf[1]='H'; buf[2]='=';
    buf[3]=H[((uint16_t)a->phase >> 12) & 0xFu];
    buf[4]=H[((uint16_t)a->phase >>  8) & 0xFu];
    buf[5]=H[((uint16_t)a->phase >>  4) & 0xFu];
    buf[6]=H[ (uint16_t)a->phase        & 0xFu];
    buf[7]=' '; buf[8]='C'; buf[9]='R'; buf[10]='C'; buf[11]='=';
    buf[12]=H[(corpus_result>>12)&0xFu]; buf[13]=H[(corpus_result>>8)&0xFu];
    buf[14]=H[(corpus_result>>4)&0xFu]; buf[15]=H[corpus_result&0xFu];
    buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->phase = (int16_t)0;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "COPYSIGN COMPASS");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "G_FCOPYSIGN", "SIGN-BIT FLOW");
    corpus_result = compass_gate_crc();  // runs during title; expected 0xB9CB
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.phase = (int16_t)(a.phase + (int16_t)1);
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)NTILES_H) {
            a.band = (uint8_t)0u;
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}

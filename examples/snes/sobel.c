// Sobelscope — #87 of the compiler stress-test demo battery.
// Signed 3x3 Sobel edge detector over a procedural animated field, rendered on a
// 128x128 BG3 canvas (4x4 px per source cell). Gx/Gy are signed MACs; the edge
// magnitude uses saturating add (__builtin_elementwise_add_sat -> G_SADDSAT) and a
// saturating floor subtract (G_USUBSAT). Builds default-8-bit AND +mos-a16 AND +mos-xy16.
//
// Distinct from #57 medfilt (compare-exchange sorting network, no MAC, no saturation).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/sobel.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u
#define CELL         4          // px per source cell (32 cells * 4 = 128)

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 0,  0,  2),    // 0: flat (no edge)
    SNES_RGB( 8, 12, 20),    // 1: weak edge (blue)
    SNES_RGB(20, 24, 10),    // 2: medium edge (green-gold)
    SNES_RGB(31, 28,  8),    // 3: strong edge (bright)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    int16_t      phase;
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// Fill a CELL x CELL block at source cell (cx,cy) with a 2bpp color 0..3.
static void cell_block(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint8_t px0 = (uint8_t)(cx * CELL), py0 = (uint8_t)(cy * CELL);
    uint8_t i, j;
    for (j = 0u; j < CELL; j++)
        for (i = 0u; i < CELL; i++)
            canvas_plot(cv, (int16_t)(px0 + i), (int16_t)(py0 + j), color);
}

static void draw_field(App *a) {
    uint8_t cy, cx;
    for (cy = 1u; cy < (uint8_t)(SB_H - 1u); cy++) {
        for (cx = 1u; cx < (uint8_t)(SB_W - 1u); cx++) {
            uint8_t e = sb_edge((int16_t)cx, (int16_t)cy, a->phase);
            // quantize magnitude to 4 palette levels
            uint8_t col = (uint8_t)(e >= 96u ? 3u : (e >= 48u ? 2u : (e >= 12u ? 1u : 0u)));
            cell_block(&a->canvas, cx, cy, col);
        }
    }
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='P'; buf[10]='H'; buf[11]='=';
    buf[12]=H[((uint16_t)a->phase>>8)&0xFu]; buf[13]=H[((uint16_t)a->phase>>4)&0xFu];
    buf[14]=H[(uint16_t)a->phase&0xFu];
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
    a->phase = 0;
    a->frame = 0u;
    text_puts(&a->text, 0, 4, "SOBEL EDGE MAC-SAT");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "SOBELSCOPE", "MAC + SAT EDGE");
    corpus_result = sobel_gate_crc();   // expected 0x2849
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        a.phase = (int16_t)(a.phase + 2);
        draw_field(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}

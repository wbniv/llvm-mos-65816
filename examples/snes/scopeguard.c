// Scope-Guard Ripple Tank — #90 of the compiler stress-test demo battery.
// A fixed-point 2D ripple tank on a 128x128 BG3 canvas; the compiler stress is the
// __attribute__((cleanup)) scope-exit fan-out exercised by the startup gate (sg_process).
// A HUD shows the running cleanup count. Builds default-8-bit AND +mos-a16 AND +mos-xy16.
//
// No other battery demo uses the cleanup attribute (synthesized scope-exit calls).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/scopeguard.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u
#define GW           20        // ripple grid (20x20, 6px cells -> 120px)
#define GH           20
#define CELL         6

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  4, 10),    // 0: trough (deep)
    SNES_RGB( 6, 12, 22),    // 1: low
    SNES_RGB(14, 22, 28),    // 2: high
    SNES_RGB(28, 30, 31),    // 3: crest
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    int16_t      buf0[GH * GW];
    int16_t      buf1[GH * GW];
    int16_t     *cur;      // -> buf0/buf1 (ping-pong)
    int16_t     *prev;
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

#define AT(p,x,y) (p)[(uint16_t)(y) * (uint16_t)GW + (uint16_t)(x)]

// One ripple step: u_next = 2u - u_prev + lap/4, damped. next is written into the prev
// buffer (prev[y][x] is read only for its own cell), then cur/prev pointers swap — no 3rd buffer.
static void ripple_step(App *a) {
    int16_t *cur = a->cur, *prev = a->prev;
    uint8_t y, x;
    for (y = 1u; y < (uint8_t)(GH - 1u); y++) {
        for (x = 1u; x < (uint8_t)(GW - 1u); x++) {
            int16_t u = AT(cur, x, y);
            int16_t lap = (int16_t)((int16_t)(AT(cur,x-1,y) + AT(cur,x+1,y)
                                    + AT(cur,x,y-1) + AT(cur,x,y+1)) - (int16_t)(4 * u));
            int16_t v = (int16_t)((int16_t)((int16_t)(2 * u) - AT(prev,x,y)) + (int16_t)(lap >> 2));
            v = (int16_t)(v - (v >> 6));   // damping
            AT(prev, x, y) = v;            // next overwrites prev (safe: own cell only)
        }
    }
    a->cur = prev; a->prev = cur;          // ping-pong swap
}

static void fill_cell(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint8_t px0 = (uint8_t)(cx * CELL + 4u), py0 = (uint8_t)(cy * CELL + 4u);
    uint8_t i, j;
    for (j = 0u; j < CELL; j++)
        for (i = 0u; i < CELL; i++)
            canvas_plot(cv, (int16_t)(px0 + i), (int16_t)(py0 + j), color);
}

static void draw_tank(App *a) {
    uint8_t y, x;
    for (y = 0u; y < (uint8_t)GH; y++) {
        for (x = 0u; x < (uint8_t)GW; x++) {
            int16_t v = AT(a->cur, x, y);
            uint8_t col = (uint8_t)(v >= 48 ? 3u : (v >= 8 ? 2u : (v >= -8 ? 1u : 0u)));
            fill_cell(&a->canvas, x, y, col);
        }
    }
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='C'; buf[10]='L'; buf[11]='N'; buf[12]='=';
    buf[13]=H[(sg_cleanups>>8)&0xFu]; buf[14]=H[(sg_cleanups>>4)&0xFu]; buf[15]=H[sg_cleanups&0xFu];
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
    uint8_t y, x;
    a->cur = a->buf0; a->prev = a->buf1;
    for (y = 0u; y < (uint8_t)GH; y++) for (x = 0u; x < (uint8_t)GW; x++) { AT(a->cur,x,y)=0; AT(a->prev,x,y)=0; }
    a->frame = 0u;
    text_puts(&a->text, 0, 3, "SCOPE-GUARD RIPPLE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "SCOPE GUARD", "CLEANUP RIPPLE");
    corpus_result = scopeguard_gate_crc();   // expected 0x05A3 (exercises cleanup fan-out)
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        // drop a pebble periodically
        if ((a.frame % 48u) == 0u) {
            uint8_t dx = (uint8_t)(6u + (a.frame >> 2) % 12u);
            uint8_t dy = (uint8_t)(6u + (a.frame >> 1) % 12u);
            AT(a.cur, dx, dy) = 400;
        }
        ripple_step(&a);
        draw_tank(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}

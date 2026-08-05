// Far-Spill Stress — #131 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/farspill.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

__attribute__((section(".far_rodata")))
const uint8_t farspill_data[64] = {
     11,  48,  85, 122, 159, 196, 233,  14,  51,  88, 125, 162, 199, 236,  17,  54,
     91, 128, 165, 202, 239,  20,  57,  94, 131, 168, 205, 242,  23,  60,  97, 134,
    171, 208, 245,  26,  63, 100, 137, 174, 211, 248,  29,  66, 103, 140, 177, 214,
    251,  32,  69, 106, 143, 180, 217, 254,  35,  72, 109, 146, 183, 220,   1,  38
};

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t round;
    uint16_t visual_h;
} App;

volatile uint16_t corpus_result;

static const uint16_t pal[4] = {
    SNES_RGB(1, 2, 6), SNES_RGB(3, 10, 18), SNES_RGB(26, 7, 21), SNES_RGB(31, 27, 8)
};

static void put_hex(TextLayer *t, uint16_t v) {
    static const char H[] = "0123456789ABCDEF";
    char b[9] = {'C','R','C','=',0,0,0,0,0};
    b[4]=H[(v>>12)&15u]; b[5]=H[(v>>8)&15u]; b[6]=H[(v>>4)&15u]; b[7]=H[v&15u];
    text_puts(t, 1, 1, b);
}

static void paint(App *a) {
    a->visual_h = farspill_round(a->visual_h, a->round++);
    for (uint8_t y = 0; y < 16u; y++) for (uint8_t x = 0; x < 16u; x++) {
        uint8_t c = 0u;
        // Ten pointer ribbons enter, compress through a four-column register funnel, park the
        // excess in magenta spill slots, and emerge indexed by the recovered far-data samples.
        if (x < 5u && y < 10u && x == (uint8_t)(y >> 1)) c = (uint8_t)(1u + (y & 1u));
        if (x >= 5u && x <= 9u && y >= 5u && y <= 10u) c = 3u;
        if (x == 7u && (y < 5u || y > 10u)) c = 2u;
        if (x > 9u && y < 10u) {
            uint8_t lane = (uint8_t)((farspill_samples[y] >> 5) & 7u);
            if (x == (uint8_t)(10u + (lane >> 1))) c = (uint8_t)(2u + (lane & 1u));
        }
        if (y >= 12u && x < 10u && x == (uint8_t)(a->round + y) % 10u) c = 3u;
        canvas_fill_solid_tile(&a->canvas, x, y, c);
    }
    a->canvas.lo = 0u;
    a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);
}

int main(void) {
    static App a;
    static TitleLayer title;
    display_init(&a.screen);
    canvas_init(&a.canvas, CANVAS_CHR, CANVAS_MAP, 8, 6);
    text_init(&a.text, CANVAS_MAP, 1, 25);
    display_add(&a.screen, (Drawable *)&a.canvas);
    display_add(&a.screen, (Drawable *)&a.text);
    upq_push_cgram(&a.screen.q, 0, pal, 0, (uint8_t)sizeof pal);
    text_puts(&a.text, 0, 2, "FAR POINTER SPILL FUNNEL");
    title_begin16(&a.screen, &title, "FARSPILL", "IMAG32 PRESSURE");
    title_end(&a.screen, &title, 30);
    corpus_result = farspill_model();
    put_hex(&a.text, corpus_result);
    a.visual_h = 0xF131u;
    for (;;) { paint(&a); display_frame(&a.screen); }
}

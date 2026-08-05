// Split-Personality Link — #126 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/mixedwidth.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

typedef struct { Display screen; BitmapCanvas canvas; TextLayer text; uint16_t t; } App;
volatile uint16_t corpus_result;

static const uint16_t pal[4] = {
    SNES_RGB(1, 2, 7), SNES_RGB(5, 11, 25), SNES_RGB(25, 7, 15), SNES_RGB(29, 27, 12)
};

static void put_hex(TextLayer *t, uint8_t y, uint16_t v) {
    static const char H[] = "0123456789ABCDEF";
    char b[10] = {'C','R','C','=',0,0,0,0,0,0};
    b[4]=H[(v>>12)&15u]; b[5]=H[(v>>8)&15u]; b[6]=H[(v>>4)&15u]; b[7]=H[v&15u];
    text_puts(t, 1, y, b);
}

static void paint(App *a) {
    for (uint8_t y=0; y<16u; y++) for (uint8_t x=0; x<16u; x++) {
        uint8_t tick = (uint8_t)(a->t >> 2);
        /* Left: narrow A8 byte stripes. Right: broad A16 word bands. The two yellow bridge
           cells travel in opposite directions to depict calls crossing the width boundary. */
        uint8_t c = x < 8u
            ? (uint8_t)((((x ^ y) + tick) & 3u) < 2u ? 1u : 0u)
            : (uint8_t)((((x + (uint8_t)(y >> 1) + (uint8_t)(tick >> 1)) & 7u) < 4u) ? 2u : 0u);
        if ((x == 7u && y == (uint8_t)(tick & 15u)) ||
            (x == 8u && y == (uint8_t)(15u - (tick & 15u)))) c = 3u;
        canvas_fill_solid_tile(&a->canvas, x, y, c);
    }
    a->canvas.lo = 0u;
    a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);
}

int main(void) {
    static App a;
    display_init(&a.screen);
    canvas_init(&a.canvas, CANVAS_CHR, CANVAS_MAP, 8, 6);
    text_init(&a.text, CANVAS_MAP, 1, 25);
    display_add(&a.screen, (Drawable *)&a.canvas);
    display_add(&a.screen, (Drawable *)&a.text);
    upq_push_cgram(&a.screen.q, 0, pal, 0, (uint8_t)sizeof pal);
    text_puts(&a.text, 0, 2, "SPLIT-PERSONALITY LINK");
    text_puts(&a.text, 1, 1, "A8  < CALL >  A16");
    static TitleLayer title;
    title_begin16(&a.screen, &title, "MIXEDWIDTH", "PER-FUNCTION M/X ABI");
    title_end(&a.screen, &title, 30);
    corpus_result = mixedwidth_model();
    put_hex(&a.text, 2, corpus_result);
    for (;;) { paint(&a); a.t++; display_frame(&a.screen); }
}

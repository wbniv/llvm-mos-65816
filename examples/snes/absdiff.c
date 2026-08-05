// Motion-Detect Difference Field — #119 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/absdiff.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t phase;
    uint8_t energy[16];
} App;

volatile uint16_t corpus_result;

static const uint16_t pal[4] = {
    SNES_RGB(1, 2, 6), SNES_RGB(3, 8, 13), SNES_RGB(3, 25, 27), SNES_RGB(31, 27, 7)
};

static void put_hex(TextLayer *t, uint16_t v) {
    static const char H[] = "0123456789ABCDEF";
    char b[9] = {'C','R','C','=',0,0,0,0,0};
    b[4] = H[(v >> 12) & 15u]; b[5] = H[(v >> 8) & 15u];
    b[6] = H[(v >> 4) & 15u]; b[7] = H[v & 15u];
    text_puts(t, 1, 1, b);
}

static uint8_t source_shape(uint8_t x, uint8_t y, uint8_t phase) {
    uint8_t cx = (uint8_t)(4u + ((phase >> 2) & 7u));
    uint8_t cy = (uint8_t)(1u + ((phase >> 4) & 1u));
    uint8_t dx = x > cx ? (uint8_t)(x - cx) : (uint8_t)(cx - x);
    uint8_t dy = y > cy ? (uint8_t)(y - cy) : (uint8_t)(cy - y);
    uint8_t body = (uint8_t)(dx + (uint8_t)(dy << 1)) < 5u;
    uint8_t bars = (uint8_t)(((x + (phase >> 3)) & 7u) < 2u);
    return (uint8_t)(body ? 220u : (bars ? 70u : 18u));
}

static uint8_t intensity(uint32_t d, uint8_t shift) {
    uint8_t q = (uint8_t)(d >> shift);
    return q > 96u ? 3u : (q > 28u ? 2u : (q > 5u ? 1u : 0u));
}

static void paint(App *a) {
    uint16_t total = 0u;
    uint8_t p = (uint8_t)a->phase;
    for (uint8_t band = 0; band < 3u; band++) {
        for (uint8_t y = 0; y < 4u; y++) {
            for (uint8_t x = 0; x < 16u; x++) {
                uint8_t sa = source_shape(x, y, p);
                uint8_t sb = source_shape(x, y, (uint8_t)(p + 13u));
                uint32_t d;
                if (band == 0u) {
                    d = absdiff_u8(sa, sb);
                } else if (band == 1u) {
                    int16_t a16 = (int16_t)((int16_t)sa * 73 - 8192);
                    int16_t b16 = (int16_t)((int16_t)sb * 73 - 8192);
                    d = absdiff_s16(a16, b16);
                } else {
                    uint32_t a32 = (uint32_t)sa * 0x01010101u;
                    uint32_t b32 = (uint32_t)sb * 0x01010101u;
                    d = absdiff_u32(a32, b32);
                }
                uint8_t c = intensity(d, band == 0u ? 0u : (band == 1u ? 6u : 24u));
                total = (uint16_t)(total + c);
                canvas_fill_solid_tile(&a->canvas, x, (uint8_t)(band * 5u + y), c);
            }
        }
        for (uint8_t x = 0; x < 16u; x++)
            canvas_fill_solid_tile(&a->canvas, x, (uint8_t)(band * 5u + 4u), 0u);
    }
    for (uint8_t i = 0; i < 15u; i++) a->energy[i] = a->energy[i + 1u];
    a->energy[15] = (uint8_t)(total >> 3);
    for (uint8_t x = 0; x < 16u; x++) {
        uint8_t c = a->energy[x] > 18u ? 3u : (a->energy[x] > 8u ? 2u : 1u);
        canvas_fill_solid_tile(&a->canvas, x, 15u, c);
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
    text_puts(&a.text, 0, 2, "MOTION DIFFERENCE FIELD");
    text_puts(&a.text, 3, 2, "U8     S16     U32");
    title_begin16(&a.screen, &title, "ABSDIFF", "MOTION DIFFERENCE");
    title_end(&a.screen, &title, 30);
    corpus_result = absdiff_model();
    put_hex(&a.text, corpus_result);
    for (;;) {
        paint(&a);
        a.phase++;
        display_frame(&a.screen);
    }
}

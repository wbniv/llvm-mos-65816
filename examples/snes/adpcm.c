// ADPCM Waverider — #89 of the compiler stress-test demo battery.
// A scrolling oscilloscope of an IMA-ADPCM decoded waveform on a 128x128 BG3 canvas.
// The predictor uses saturating add/sub (G_SADDSAT/G_SSUBSAT) in a serial feedback loop
// with a step-index LUT walk. Builds default-8-bit AND +mos-a16 AND +mos-xy16 (5-way bar).
//
// Distinct from #48 IIR (wrapping feedback) and #67 huffman (no feedback).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/adpcm.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  4),    // 0: bg
    SNES_RGB( 6, 26, 14),    // 1: waveform (green)
    SNES_RGB(20, 20, 24),    // 2: center axis
    SNES_RGB(30, 24,  8),    // 3: peak markers
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    AdpcmState   st;
    uint16_t     r;        // PRNG
    uint16_t     n;        // nibble counter
    int16_t      prev_y;   // previous scope y (for line continuity)
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// map int16 sample to canvas y [0..127], center 64
static inline int16_t samp_y(int16_t s) {
    int16_t y = (int16_t)(64 - (int16_t)(s >> 9));   // /512 → +-64
    if (y < 0) y = 0; if (y > 127) y = 127;
    return y;
}

// Decode 128 nibbles across the canvas width, drawing the waveform.
static void draw_wave(App *a) {
    canvas_clear(&a->canvas);
    // center axis
    uint8_t x;
    for (x = 0u; x < (uint8_t)CANVAS_W; x++) canvas_plot(&a->canvas, (int16_t)x, 64, 2u);
    int16_t py = 64;
    for (x = 0u; x < (uint8_t)CANVAS_W; x++) {
        a->r = ad_xs16(a->r);
        uint8_t nib = (uint8_t)((a->r >> (uint16_t)((a->n & 3u) * 4u)) & 15u);
        a->n++;
        int16_t s = ad_decode(&a->st, nib);
        int16_t y = samp_y(s);
        canvas_line(&a->canvas, (int16_t)(x == 0u ? 0 : x-1), py, (int16_t)x, y, 1u);
        if (y <= 2 || y >= 125) canvas_plot(&a->canvas, (int16_t)x, y, 3u);   // peak marker
        py = y;
    }
    // occasionally reset predictor so the trace stays lively
    if ((a->frame % 90u) == 0u) ad_init(&a->st);
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='I'; buf[10]='D'; buf[11]='X'; buf[12]='=';
    buf[13]=H[((uint16_t)a->st.idx>>4)&0xFu]; buf[14]=H[(uint16_t)a->st.idx&0xFu];
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
    ad_init(&a->st);
    a->r = 0xC0DEu;
    a->n = 0u;
    a->prev_y = 64;
    a->frame = 0u;
    text_puts(&a->text, 0, 3, "ADPCM SAT PREDICTOR");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "ADPCM WAVE", "SAT PREDICTOR");
    corpus_result = adpcm_gate_crc();   // expected 0xCA56
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        draw_wave(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
